// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 仓库实现（data/repositories/）
//
// 职责：
// - 实现 domain 层定义的接口
// - 协调多个 DataSource
// - 做必要的 DTO → Entity 转换
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/backend_api.dart';

/// 对话仓库实现
class ChatRepositoryImpl implements ChatRepository {
  final BackendApiDataSource _api;

  ChatRepositoryImpl(this._api);

  @override
  Stream<ChatEvent> sendMessage({
    required String message,
    required List<Message> history,
    String? systemPrompt,
  }) {
    return _api.chatStream(
      message: message,
      history: history,
      systemPrompt: systemPrompt,
    );
  }

  @override
  Future<Affinity> getAffinity() => _api.fetchAffinity();

  @override
  Future<void> resetAffinity() => _api.resetAffinity();

  @override
  Future<bool> clearMemory({String category = 'chat_memory'}) =>
      _api.clearMemory(category: category);

  @override
  Future<bool> isOnline() => _api.isOnline();
}
