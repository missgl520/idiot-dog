// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹芽对话服务（直连 Agnes API，无需后端）
//
// 支持：国际版 apihub.agnes-ai.com + 国内版 platform.agnes-ai.cn
// 接口格式：OpenAI 兼容 /v1/chat/completions
//
// 直连模式：AgnesService 直接调 API，绕过后端
// SSE 格式：data: {"choices":[{"delta":{"content":"字"}}]}\n\n
//   data: [DONE]\n\n
//
// 注意：
// - Agnes CN 仅限国内访问
// - 竹芽记忆（sinomem）暂时不可用，待后续方案
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:convert';
import 'package:http/http.dart' as http;

class AgnesService {
  // 单例
  static AgnesService? _instance;
  static AgnesService get instance => _instance ??= AgnesService._();
  AgnesService._() {
    // 启动时读取上次的服务器偏好（避免每次都要重新选）
    try {
      final box = Hive.box('settings');
      _useCN = box.get('agnesUseCN', defaultValue: true) as bool;
    } catch (_) {
      _useCN = true; // 默认国内版
    }
  }

  // Agnes 国际版
  static const _apiIntl = 'https://apihub.agnes-ai.com/v1/chat/completions';
  // Agnes 国内版
  static const _apiCN = 'https://platform.agnes-ai.cn/api/chat/completions';

  // 当前选中的 API（由 App 在设置页控制）
  bool _useCN = true;  // 默认国内版

  String? _runtimeApiKey;

  /// 运行时设置 API Key
  void setApiKey(String key) => _runtimeApiKey = key;

  /// 切换 CN/国际版
  void setUseCN(bool cn) => _useCN = cn;

  bool get useCN => _useCN;

  String get _baseUrl => _useCN ? _apiCN : _apiIntl;

  // ━━━━━━━━━━━━━━━ 同步对话 ━━━━━━━━━━━━━━━

  /// 一次返回完整回复
  Future<String> chat({
    required String message,
    List<Map<String, String>> history = const [],
    String? systemPrompt,
    double temperature = 0.7,
    bool saveToMemory = true,  // 直连模式：忽略，由 App 本地处理
  }) async {
    final body = <String, dynamic>{
      'model': 'agnes-2.0-flash',
      'messages': _buildMessages(message, history, systemPrompt),
      'max_tokens': 2000,
      'temperature': temperature,
      'stream': false,
    };

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_runtimeApiKey ?? ''}',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Agnes API 错误 ${response.statusCode}：${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  // ━━━━━━━━━━━━━━━ 流式对话（打字机） ━━━━━━━━━━━━━━━

  /// 流式返回：每个 chunk 是一个字/词
  Stream<String> chatStream({
    required String message,
    List<Map<String, String>> history = const [],
    String? systemPrompt,
    double temperature = 0.7,
    bool saveToMemory = true,
  }) async* {
    final body = <String, dynamic>{
      'model': 'agnes-2.0-flash',
      'messages': _buildMessages(message, history, systemPrompt),
      'max_tokens': 2000,
      'temperature': temperature,
      'stream': true,
    };

    final request = http.Request('POST', Uri.parse(_baseUrl));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer ${_runtimeApiKey ?? ''}';
    request.body = jsonEncode(body);

    final streamedResponse = await http.Client().send(request);

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw Exception('Agnes API 错误 ${streamedResponse.statusCode}：$body');
    }

    String buffer = '';
    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
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
          final content = json['choices']?[0]?['delta']?['content'];
          if (content != null && content.toString().isNotEmpty) {
            yield content.toString();
          }
        } catch (_) {
          // 非 JSON 行跳过
        }
      }
    }
  }

  // ━━━━━━━━━━━━━━━ 工具方法 ━━━━━━━━━━━━━━━

  List<Map<String, String>> _buildMessages(
    String message,
    List<Map<String, String>> history,
    String? systemPrompt,
  ) {
    final messages = <Map<String, String>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    for (final h in history) {
      messages.add({'role': h['role'] ?? 'user', 'content': h['content'] ?? ''});
    }
    messages.add({'role': 'user', 'content': message});
    return messages;
  }
}
