// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹芽后端服务（v1.3，统一对话 + RAG + 情绪 + 好感度）
//
// 架构说明：
// - 所有对话统一走 /chat/v2 接口（推荐）
// - 后端完成：RAG 记忆召回 → 注入 system prompt → Agnes 对话
// - 流式返回：SSE 格式，支持 text / emotion / affinity / done 事件
//
// SSE 事件格式：
// - (默认) text: AI 输出片段
// - event: emotion → {"emotion": "happy", "confidence": 0.8}
// - event: affinity → {"trust": 35, "intimacy": 22, ...}
// - event: done → 对话结束
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 数据结构
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 情绪识别结果
class EmotionResult {
  final String emotion;       // neutral / happy / sad / angry / surprised / anxious
  final double confidence;    // 0.0-1.0
  final Map<String, double> scores;

  EmotionResult({
    required this.emotion,
    required this.confidence,
    required this.scores,
  });

  factory EmotionResult.fromJson(Map<String, dynamic> json) {
    return EmotionResult(
      emotion: json['emotion'] as String? ?? 'neutral',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      scores: (json['scores'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
    );
  }
}

/// 好感度数据
class AffinityData {
  final double trust;        // 信任度 0-100
  final double intimacy;    // 亲密度 0-100
  final double familiarity; // 熟悉度 0-100
  final int totalInteractions;
  final int streakDays;
  final String level;       // 陌生人/认识/朋友/好友/知己/灵魂伴侣

  AffinityData({
    this.trust = 30,
    this.intimacy = 20,
    this.familiarity = 5,
    this.totalInteractions = 0,
    this.streakDays = 0,
    this.level = '陌生人',
  });

  AffinityData copyWith({
    double? trust,
    double? intimacy,
    double? familiarity,
    int? totalInteractions,
    int? streakDays,
    String? level,
  }) => AffinityData(
    trust: trust ?? this.trust,
    intimacy: intimacy ?? this.intimacy,
    familiarity: familiarity ?? this.familiarity,
    totalInteractions: totalInteractions ?? this.totalInteractions,
    streakDays: streakDays ?? this.streakDays,
    level: level ?? this.level,
  );

  factory AffinityData.fromJson(Map<String, dynamic> json) {
    return AffinityData(
      trust: (json['trust'] as num?)?.toDouble() ?? 30,
      intimacy: (json['intimacy'] as num?)?.toDouble() ?? 20,
      familiarity: (json['familiarity'] as num?)?.toDouble() ?? 5,
      totalInteractions: (json['total_interactions'] as num?)?.toInt() ?? 0,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      level: json['level'] as String? ?? '陌生人',
    );
  }
}

/// 对话流事件
sealed class ChatEvent {}

class TextChunk extends ChatEvent {
  final String text;
  TextChunk(this.text);
}

class EmotionEvent extends ChatEvent {
  final EmotionResult emotion;
  EmotionEvent(this.emotion);
}

class AffinityEvent extends ChatEvent {
  final AffinityData affinity;
  AffinityEvent(this.affinity);
}

class DoneEvent extends ChatEvent {}

class ErrorEvent extends ChatEvent {
  final String message;
  ErrorEvent(this.message);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BackendService（统一后端通信）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class BackendService {
  static BackendService? _instance;
  static BackendService get instance => _instance ??= BackendService._();
  BackendService._();

  /// 统一对话接口（/chat/v2）
  /// 一次调用：对话 + 记忆召回 + 情绪识别 + 好感度更新
  ///
  /// [message] 用户输入
  /// [history] 历史对话（用于上下文）
  /// [systemPrompt] 自定义 system prompt
  /// [temperature] 创造性参数
  /// [onEmotion] 情绪识别回调（对话结束时触发）
  /// [onAffinity] 好感度更新回调（对话结束时触发）
  ///
  /// 返回：Stream<ChatEvent>
  Stream<ChatEvent> chatStream({
    required String message,
    List<Map<String, String>> history = const [],
    String? systemPrompt,
    double temperature = 0.7,
    String? apiKey,
    void Function(EmotionResult)? onEmotion,
    void Function(AffinityData)? onAffinity,
  }) async* {
    final baseUrl = BackendConfig.instance.baseUrl;

    final allMessages = [
      ...history,
      {'role': 'user', 'content': message},
    ];

    final body = <String, dynamic>{
      'message': message,
      'history': allMessages,
      'temperature': temperature,
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system_prompt'] = systemPrompt;
    }
    if (apiKey != null && apiKey.isNotEmpty) {
      body['api_key'] = apiKey;
    }

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/chat/v2'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);

      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        yield ErrorEvent('后端错误 ${streamedResponse.statusCode}：$body');
        return;
      }

      String buffer = '';

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // 按 \n\n 分割 SSE 事件
        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          String rawEvent = buffer.substring(0, eventEnd).trim();
          buffer = buffer.substring(eventEnd + 2);

          if (rawEvent.isEmpty) continue;

          // 解析事件类型
          if (rawEvent.startsWith('event:')) {
            // 多行格式：event: xxx\ndata: {...}\n
            final lines = rawEvent.split('\n');
            final eventType = lines.first.substring(6).trim();
            final dataLine = lines.length > 1 ? lines[1].substring(5).trim() : '{}';

            if (dataLine.isEmpty) continue;

            try {
              final data = jsonDecode(dataLine) as Map<String, dynamic>;

              switch (eventType) {
                case 'emotion':
                  final emotion = EmotionResult.fromJson(data);
                  onEmotion?.call(emotion);
                  yield EmotionEvent(emotion);
                  break;
                case 'affinity':
                  final affinity = AffinityData.fromJson(data);
                  onAffinity?.call(affinity);
                  yield AffinityEvent(affinity);
                  break;
                case 'done':
                  yield DoneEvent();
                  break;
                case 'error':
                  yield ErrorEvent(data['error']?.toString() ?? '未知错误');
                  break;
              }
            } catch (_) {
              // 非 JSON，跳过
            }
          } else if (rawEvent.startsWith('data: ')) {
            // 默认事件：text chunk
            final dataStr = rawEvent.substring(6).trim();
            if (dataStr.isNotEmpty && dataStr != '{}') {
              try {
                // 有些后端直接发 text，有些发 {"content": "..."}
                final data = jsonDecode(dataStr);
                if (data is String) {
                  yield TextChunk(data);
                } else if (data is Map && data.containsKey('content')) {
                  yield TextChunk(data['content'].toString());
                }
              } catch (_) {
                // 纯文本，直接 yield
                yield TextChunk(dataStr);
              }
            }
          }
        }
      }
    } catch (e) {
      yield ErrorEvent('连接失败：$e');
    }
  }

  // ━━━ 情绪识别（独立接口） ━━━

  /// 单独调用情绪识别
  Future<EmotionResult> detectEmotion(String text, {String aiReply = ''}) async {
    final baseUrl = BackendConfig.instance.baseUrl;

    final resp = await http.post(
      Uri.parse('$baseUrl/emotion'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text, 'ai_reply': aiReply}),
    );

    if (resp.statusCode != 200) {
      return EmotionResult(emotion: 'neutral', confidence: 0.5, scores: {});
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return EmotionResult.fromJson(data);
  }

  // ━━━ 好感度 ━━━

  /// 获取好感度状态
  Future<AffinityData> getAffinity() async {
    final baseUrl = BackendConfig.instance.baseUrl;

    final resp = await http.get(Uri.parse('$baseUrl/affinity'));

    if (resp.statusCode != 200) {
      return AffinityData(
        trust: 30,
        intimacy: 20,
        familiarity: 5,
        totalInteractions: 0,
        streakDays: 0,
        level: '陌生人',
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return AffinityData.fromJson(data);
  }

  /// 重置好感度
  Future<void> resetAffinity() async {
    final baseUrl = BackendConfig.instance.baseUrl;
    await http.put(Uri.parse('$baseUrl/affinity?action=reset'));
  }

  /// 清空对话记忆（调用后端 DELETE /memory）
  Future<bool> clearMemory({String category = 'chat_memory'}) async {
    final baseUrl = BackendConfig.instance.baseUrl;
    try {
      final resp = await http.delete(
        Uri.parse('$baseUrl/memory?category=$category'),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 获取关系等级描述
  Future<String> getAffinityLevel() async {
    final baseUrl = BackendConfig.instance.baseUrl;

    final resp = await http.get(Uri.parse('$baseUrl/affinity/level'));
    if (resp.statusCode != 200) return '陌生人';

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['level'] as String? ?? '陌生人';
  }

  // ━━━ 摘要 ━━━

  /// 获取最近摘要
  Future<List<Map<String, dynamic>>> getSummaries({int limit = 3}) async {
    final baseUrl = BackendConfig.instance.baseUrl;

    final resp = await http.get(
      Uri.parse('$baseUrl/summary?limit=$limit'),
    );

    if (resp.statusCode != 200) return [];

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final summaries = data['summaries'] as List<dynamic>? ?? [];
    return summaries.cast<Map<String, dynamic>>();
  }

  // ━━━ 健康检查 ━━━

  /// 检查后端是否在线
  Future<bool> isOnline() async {
    final baseUrl = BackendConfig.instance.baseUrl;
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}