// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹芽全局 Provider 配置
//
// 新架构（v2）统一 Provider 入口
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/backend_api.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/repositories/chat_repository.dart';

// ━━━ DataSource ━━━

/// 后端 API 数据源（单例）
final backendApiProvider = Provider<BackendApiDataSource>((ref) {
  return BackendApiDataSource();
});

// ━━━ Repository ━━━

/// 对话仓库（依赖 DataSource）
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final api = ref.watch(backendApiProvider);
  return ChatRepositoryImpl(api);
});

// ━━━ 后端状态 ━━━

/// 后端是否在线
final backendOnlineProvider = FutureProvider<bool>((ref) async {
  final api = ref.read(backendApiProvider);
  return api.isOnline();
});
