// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹芽对话服务（调后端 FastAPI）
//
// 后端地址：http://localhost:8000
// 对话接口：POST /chat
// 健康检查：GET /health
//
// 后端 SSE 格式（标准）：
//   data: {"content":"字"}\n\n
//   data: [DONE]\n\n
//
// 注意：
// - 本文件调竹芽后端，由后端统一调用 Agnes API
// - 不再直连 apihub.agnes-ai.com
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:convert';
import 'package:http/http.dart' as http;

class AgnesService {
  // 单例：所有 ref.read 拿到同一个实例，setApiKey 永久生效
  static AgnesService? _instance;
  static AgnesService get instance => _instance ??= AgnesService._();
  AgnesService._();

  // 前端连后端
  // Android 模拟器：10.0.2.2 → 开发机 localhost
  // iOS 模拟器：localhost
  // 真机：局域网 IP（如 192.168.x.x:8000）
  String _baseUrl = 'http://10.0.2.2:8000';

  /// 运行时覆盖 baseUrl（真机部署时用）
  void setBaseUrl(String url) => _baseUrl = url;

  /// 运行时覆盖 API Key（设置页写入后同步）
  String? _runtimeApiKey;
  void setApiKey(String key) => _runtimeApiKey = key;

  // ━━━━━━━━━━━━━━━ 同步对话 ━━━━━━━━━━━━━━━

  /// 一次返回完整回复
  Future<String> chat({
    required String message,
    List<Map<String, String>> history = const [],
    String? systemPrompt,
    double temperature = 0.7,
    bool saveToMemory = true,
  }) async {
    final body = <String, dynamic>{
      'message': message,
      'history': history,
      'system_prompt': systemPrompt,
      'temperature': temperature,
      'stream': false,
      'save_to_memory': saveToMemory,
    };
    if (_runtimeApiKey != null) body['api_key'] = _runtimeApiKey;

    final response = await http.post(
      Uri.parse('$_baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('后端响应失败: ${response.statusCode}\n${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['reply'] as String;
  }

  // ━━━━━━━━━━━━━━━ 流式对话（打字机） ━━━━━━━━━━━━━━━

  /// 流式返回：每个 chunk 是一个字/词，实现打字机效果
  ///
  /// 后端 SSE 格式（标准）：
  ///   data: {"content":"字"}\n\n
  ///   data: [DONE]\n\n
  Stream<String> chatStream({
    required String message,
    List<Map<String, String>> history = const [],
    String? systemPrompt,
    double temperature = 0.7,
    bool saveToMemory = true,
  }) async* {
    final body = <String, dynamic>{
      'message': message,
      'history': history,
      'system_prompt': systemPrompt,
      'temperature': temperature,
      'stream': true,
      'save_to_memory': saveToMemory,
    };
    if (_runtimeApiKey != null) body['api_key'] = _runtimeApiKey;

    final request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/chat'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode(body);

    final streamedResponse = await http.Client().send(request);

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw Exception('后端响应失败: ${streamedResponse.statusCode}\n$body');
    }

    // 解析标准 SSE：data: {"content":"字"}\n\n
    String buffer = '';
    await for (final chunk
        in streamedResponse.stream.transform(utf8.decoder)) {
      buffer += chunk;

      while (buffer.contains('\n')) {
        final lineEnd = buffer.indexOf('\n');
        String line = buffer.substring(0, lineEnd).trim();
        buffer = buffer.substring(lineEnd + 1);

        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]') return;

        try {
          final json = jsonDecode(data);
          // 标准格式
          final content = json['content'] ?? json['choices']?[0]?['delta']?['content'];
          if (content != null && content.toString().isNotEmpty) {
            yield content.toString();
          }
        } catch (_) {
          // 非 JSON 行（如空行、注释），跳过
        }
      }
    }
  }
}
