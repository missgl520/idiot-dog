// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 聊天服务（data/services/）
//
// 职责：
// - 封装"怎么拿数据"的业务逻辑
// - 协调 DataSource，处理 SSE 流式事件转换
// - 纯 Dart，不直接依赖 Flutter
//
// 边界：
// - 不知道 UI 是什么（与 Flutter/Riverpod 解耦）
// - 不知道上层要做什么（由 Repository 决定怎么用）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/chat_repository.dart';

/// 聊天服务 — 封装对话核心业务逻辑
class ChatService {
  ChatService();

  String get _baseUrl => BackendConfig.instance.baseUrl;

  // ━━━ 对话流（SSE 解析 + 事件转换） ━━━
  //
  // 这个方法是"怎么拿"的核心：
  // - 构造请求体
  // - 发起 HTTP 请求
  // - 解析 SSE 双层 data: 前缀
  // - 将原始 JSON 转为领域事件
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Stream<ChatEvent> sendMessageStream({
    required String message,
    required List<Message> history,
    String? systemPrompt,
  }) async* {
    final allMessages = [
      ...history.map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': message},
    ];

    final body = <String, dynamic>{
      'message': message,
      'history': allMessages,
      'temperature': 0.7,
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system_prompt'] = systemPrompt;
    }

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/chat/v2'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);

      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode != 200) {
        final bodyStr = await streamedResponse.stream.bytesToString();
        yield ErrorChatEvent('后端错误 ${streamedResponse.statusCode}：$bodyStr');
        return;
      }

      String buffer = '';

      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;

        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          String rawEvent = buffer.substring(0, eventEnd).trim();
          buffer = buffer.substring(eventEnd + 2);

          if (rawEvent.isEmpty) continue;

          if (rawEvent.startsWith('event:')) {
            // 命名事件：emotion / affinity / done / error
            final lines = rawEvent.split('\n');
            final eventType = lines.first.substring(6).trim();
            final dataLine =
                lines.length > 1 ? lines[1].substring(5).trim() : '{}';

            if (dataLine.isEmpty) continue;

            try {
              final data = jsonDecode(dataLine) as Map<String, dynamic>;
              yield* _handleNamedEvent(eventType, data);
            } catch (_) {}
          } else if (rawEvent.startsWith('data:')) {
            // 匿名文本行（双层 data: 前缀容错）
            String dataStr = _stripDataPrefix(rawEvent);
            if (dataStr.isNotEmpty && dataStr != '{}') {
              yield* _parseTextEvent(dataStr);
            }
          }
        }
      }
    } catch (e) {
      yield ErrorChatEvent('连接失败：$e');
    }
  }

  /// 解析命名 SSE 事件
  Stream<ChatEvent> _handleNamedEvent(
      String eventType, Map<String, dynamic> data) async* {
    switch (eventType) {
      case 'emotion':
        yield EmotionChatEvent(_toEmotion(data));
      case 'affinity':
        yield AffinityChatEvent(_toAffinity(data));
      case 'done':
        yield const DoneChatEvent();
      case 'error':
        yield ErrorChatEvent(data['error']?.toString() ?? '未知错误');
    }
  }

  /// 解析文本数据行（data: data: {...} 双层前缀兼容）
  Stream<ChatEvent> _parseTextEvent(String dataStr) async* {
    try {
      final data = jsonDecode(dataStr);
      final text = data is String
          ? data
          : (data as Map)['content']?.toString() ?? '';
      if (text.isNotEmpty) yield TextChatEvent(text);
    } catch (_) {
      yield TextChatEvent(dataStr);
    }
  }

  String _stripDataPrefix(String raw) {
    if (raw.startsWith('data: data: ')) return raw.substring(11);
    if (raw.startsWith('data: ')) return raw.substring(6);
    return raw.substring(5).trimLeft();
  }

  // ━━━ 好感度（简单 HTTP GET/PUT） ━━━

  Future<Affinity> getAffinity() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/affinity'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return _toAffinity(data);
      }
    } catch (_) {}
    return const Affinity.initial();
  }

  Future<void> resetAffinity() async {
    try {
      await http
          .put(Uri.parse('$_baseUrl/affinity?action=reset'))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ━━━ 记忆 ━━━

  Future<bool> clearMemory({String category = 'chat_memory'}) async {
    try {
      final resp = await http
          .delete(Uri.parse('$_baseUrl/memory?category=$category'))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ━━━ 健康检查 ━━━

  Future<bool> isOnline() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ━━━ DTO → Entity 转换 ━━━

  Emotion _toEmotion(Map<String, dynamic> data) {
    final label = data['emotion'] as String? ?? 'neutral';
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.5;
    return Emotion(
      label: EmotionLabel.fromString(label),
      confidence: confidence,
    );
  }

  Affinity _toAffinity(Map<String, dynamic> data) {
    return Affinity(
      trust: (data['trust'] as num?)?.toDouble() ?? 30,
      intimacy: (data['intimacy'] as num?)?.toDouble() ?? 20,
      familiarity: (data['familiarity'] as num?)?.toDouble() ?? 5,
      totalInteractions: (data['total_interactions'] as num?)?.toInt() ?? 0,
      streakDays: (data['streak_days'] as num?)?.toInt() ?? 0,
    );
  }
}
