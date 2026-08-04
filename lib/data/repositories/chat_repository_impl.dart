// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 仓库实现（data/repositories/）
//
// 职责：
// - 实现 domain 层定义的接口
// - 协调 Service，构造领域语义
// - DTO 转换已在 Service 层完成，这里只做路由
//
// Repository 接口契约（domain 层）：
//   "我要一个对话流" / "我要好感度" / "我要清记忆"
// Service 实现细节（data 层）：
//   "怎么构造请求、怎么解析 SSE、怎么转 Entity"
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/chat_repository.dart';
import '../services/chat_service.dart';

/// 对话仓库实现
/// 只负责"要什么"，不问"怎么拿"
class ChatRepositoryImpl implements ChatRepository {
  final ChatService _service;

  ChatRepositoryImpl(this._service);

  @override
  Stream<ChatEvent> sendMessage({
    required String message,
    required List<Message> history,
    String? systemPrompt,
  }) {
    return _service.sendMessageStream(
      message: message,
      history: history,
      systemPrompt: systemPrompt,
    );
  }

  @override
  Future<Affinity> getAffinity() => _service.getAffinity();

  @override
  Future<void> resetAffinity() => _service.resetAffinity();

  @override
  Future<bool> clearMemory({String category = 'chat_memory'}) =>
      _service.clearMemory(category: category);

  @override
  Future<bool> isOnline() => _service.isOnline();
}
