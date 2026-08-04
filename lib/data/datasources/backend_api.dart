// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 后端 API 数据源（data/datasources/）
//
// 职责：
// - 唯一处理 HTTP / SSE 通信的地方
// - 解析原始响应，转换为领域事件
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/chat_repository.dart';

/// 后端 API 数据源
class BackendApiDataSource {
  BackendApiDataSource();

  String get _baseUrl => BackendConfig.instance.baseUrl;

  // ━━━ 对话流 ━━━

  Stream<ChatEvent> chatStream({
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
        final body = await streamedResponse.stream.bytesToString();
        yield ErrorChatEvent('后端错误 ${streamedResponse.statusCode}：$body');
        return;
      }

      String buffer = '';

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;

        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          String rawEvent = buffer.substring(0, eventEnd).trim();
          buffer = buffer.substring(eventEnd + 2);

          if (rawEvent.isEmpty) continue;

          if (rawEvent.startsWith('event:')) {
            final lines = rawEvent.split('\n');
            final eventType = lines.first.substring(6).trim();
            final dataLine = lines.length > 1 ? lines[1].substring(5).trim() : '{}';

            if (dataLine.isEmpty) continue;

            try {
              final data = jsonDecode(dataLine) as Map<String, dynamic>;

              switch (eventType) {
                case 'emotion':
                  yield EmotionChatEvent(_parseEmotion(data));
                case 'affinity':
                  yield AffinityChatEvent(_parseAffinity(data));
                case 'done':
                  yield DoneChatEvent();
                case 'error':
                  yield ErrorChatEvent(data['error']?.toString() ?? '未知错误');
              }
            } catch (_) {}
          } else if (rawEvent.startsWith('data:')) {
            // 容错：兼容后端发送的 "data: data: {...}" 双层前缀
            String dataStr = rawEvent.startsWith('data: data: ')
                ? rawEvent.substring(10)
                : rawEvent.startsWith('data: ')
                    ? rawEvent.substring(6)
                    : rawEvent.substring(5).trimLeft();
            dataStr = dataStr.trim();
            if (dataStr.isNotEmpty && dataStr != '{}') {
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
          }
        }
      }
    } catch (e) {
      yield ErrorChatEvent('连接失败：$e');
    }
  }

  // ━━━ 好感度 ━━━

  Future<Affinity> fetchAffinity() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/affinity'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return _parseAffinity(data);
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

  // ━━━ 内部转换 ━━━

  Emotion _parseEmotion(Map<String, dynamic> data) {
    final label = data['emotion'] as String? ?? 'neutral';
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.5;
    return Emotion(
      label: EmotionLabel.fromString(label),
      confidence: confidence,
    );
  }

  Affinity _parseAffinity(Map<String, dynamic> data) {
    return Affinity(
      trust: (data['trust'] as num?)?.toDouble() ?? 30,
      intimacy: (data['intimacy'] as num?)?.toDouble() ?? 20,
      familiarity: (data['familiarity'] as num?)?.toDouble() ?? 5,
      totalInteractions: (data['total_interactions'] as num?)?.toInt() ?? 0,
      streakDays: (data['streak_days'] as num?)?.toInt() ?? 0,
    );
  }
}
