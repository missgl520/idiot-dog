// Agnes LLM 服务 - 对话 + 流式输出
import 'dart:convert';
import 'package:http/http.dart' as http;

class AgnesService {
  static const String _baseUrl = 'https://apihub.agnes-ai.com';
  static const String _model = 'agnes-2.0-flash';

  String? _apiKey;

  void setApiKey(String key) => _apiKey = key;

  // 同步对话（普通调用）
  Future<String> chat({
    required List<Map<String, String>> messages,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('请先在设置中配置 Agnes API Key');
    }

    final allMessages = <Map<String, String>>[];
    if (systemPrompt != null) {
      allMessages.add({'role': 'system', 'content': systemPrompt});
    }
    allMessages.addAll(messages);

    final response = await http.post(
      Uri.parse('$_baseUrl/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
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

  // 流式对话（打字机效果）
  Stream<String> chatStream({
    required List<Map<String, String>> messages,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async* {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('请先在设置中配置 Agnes API Key');
    }

    final allMessages = <Map<String, String>>[];
    if (systemPrompt != null) {
      allMessages.add({'role': 'system', 'content': systemPrompt});
    }
    allMessages.addAll(messages);

    final request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/v1/chat/completions'),
    );
    request.headers.addAll({
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode({
      'model': _model,
      'messages': allMessages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': true,
    });

    final streamedResponse = await http.Client().send(request);

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      final error = jsonDecode(body);
      throw Exception(error['error']?['message'] ?? '请求失败');
    }

    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data);
            final content = json['choices'][0]['delta']['content'];
            if (content != null) {
              yield content as String;
            }
          } catch (_) {}
        }
      }
    }
  }
}
