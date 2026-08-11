// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 对话仓库实现（Chat Repository Impl）
//
// 位于：data/repositories/chat_repository_impl.dart
// 职责：实现 ChatRepository 接口，把 SSE 流封装成 Repository 格式
//
// 实现策略：
//   ChatService 负责 SSE 解析，返回 token 片段。
//   本类把片段攒起来，生成完整的 Message 对象，
//   再通过 ChatEvent 分发给 Provider/UI。
//
// 这样拆分的好处：
//   - ChatService 可以单独测试（Mock HTTP 响应）
//   - Repository 层可以换数据源（本地缓存/离线优先）而不改上层代码
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import '../../core/services/backend_service.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../services/chat_service.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({ChatService? service})
      : _service = service ?? ChatService();

  final ChatService _service;

  @override
  Stream<ChatEvent> sendMessageStream({
    required String message,
    required List<Message> history,
    String? systemPrompt,
  }) async* {
    final controller = StreamController<ChatEvent>();

    await _service.streamChat(
      message: message,
      history: history,
      systemPrompt: systemPrompt,
      onText: (token) {
        controller.add(ChatEvent.token(token));
      },
      onEmotion: (emotion, confidence) {
        controller.add(ChatEvent.emotion(emotion));
      },
      onAffinity: (affinity) {
        controller.add(ChatEvent(
          type: ChatEventType.affinity,
          affinity: affinity,
        ));
      },
      onDone: () {
        controller.add(ChatEvent.done());
        controller.close();
      },
      onError: (error) {
        controller.add(ChatEvent.error(error));
        controller.close();
      },
    );

    yield* controller.stream;
  }

  @override
  Future<String> detectEmotion(String text) {
    return _service.detectEmotion(text);
  }

  @override
  Future<dynamic> getAffinity() async {
    try {
      return await BackendService.instance.getAffinity();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isOnline() {
    return _service.isOnline();
  }
}
