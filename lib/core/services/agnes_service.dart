// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Agnes LLM 服务
//
// Agnes 是小米的 AI 对话模型（agnes-2.0-flash）
// API Hub 地址：https://apihub.agnes-ai.com
//
// 提供两种调用方式：
// - chat()     : 同步调用，一次性返回完整内容
// - chatStream(): 流式调用，逐字返回（打字机效果）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:convert';
import 'package:http/http.dart' as http;

class AgnesService {
  static const String _baseUrl = 'https://apihub.agnes-ai.com';
  static const String _model = 'agnes-2.0-flash';

  // 默认 API Key（可在设置页覆盖）
  static const String _defaultApiKey =
      'sk-CcGTt05Z92jl64ZwrBuyaah2PHansRHuK0KniCV90hz8mwLI';

  String? _apiKey;

  /// 设置自定义 API Key（从设置页传入）
  void setApiKey(String key) => _apiKey = key;

  /// 当前使用的 API Key（优先用用户设置的，否则用默认的）
  String get apiKey => _apiKey ?? _defaultApiKey;

  // ━━━━━━━━━━━━━━━ 同步对话 ━━━━━━━━━━━━━━━

  /// 一次返回完整回复（不推荐，响应慢）
  /// messages      : 对话历史 [{role: 'user'|'assistant', content: '...'}]
  /// systemPrompt  : 系统提示词（人设）
  /// temperature   : 创造性 0.0-1.0（越高越随机）
  /// maxTokens     : 最大生成 token 数
  Future<String> chat({
    required List<Map<String, String>> messages,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async {
    final allMessages = <Map<String, String>>[];
    if (systemPrompt != null) {
      allMessages.add({'role': 'system', 'content': systemPrompt});
    }
    allMessages.addAll(messages);

    final response = await http.post(
      Uri.parse('$_baseUrl/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': allMessages,
        'temperature': temperature,
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error']?['message'] ?? '请求失败');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  // ━━━━━━━━━━━━━━━ 流式对话（打字机） ━━━━━━━━━━━━━━━

  /// 流式返回：每个 chunk 是一个字/词，实现打字机效果
  /// 用法：await for (final chunk in agnes.chatStream(...)) { ... }
  Stream<String> chatStream({
    required List<Map<String, String>> messages,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async* {
    final allMessages = <Map<String, String>>[];
    if (systemPrompt != null) {
      allMessages.add({'role': 'system', 'content': systemPrompt});
    }
    allMessages.addAll(messages);

    // 构造 HTTP 请求（流式模式）
    final request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/v1/chat/completions'),
    );
    request.headers.addAll({
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode({
      'model': _model,
      'messages': allMessages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': true,  // 开启流式输出
    });

    // 发送请求
    final streamedResponse = await http.Client().send(request);

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      final error = jsonDecode(body);
      throw Exception(error['error']?['message'] ?? '请求失败');
    }

    // 逐块解析 SSE 格式（Server-Sent Events）
    // 格式：data: {"choices":[{"delta":{"content":"字"}}]}
    // 结束：data: [DONE]
    await for (final chunk
        in streamedResponse.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data);
            // delta.content 是这次增量返回的内容（一个字或一个词）
            final content = json['choices'][0]['delta']['content'];
            if (content != null) {
              yield content as String;
            }
          } catch (_) {
            // JSON 解析失败（如心跳 ping），跳过
          }
        }
      }
    }
  }
}
