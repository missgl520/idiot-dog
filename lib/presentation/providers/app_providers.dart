// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹芽全局 Provider 配置
//
// 新架构（v2）统一 Provider 入口
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/chat_service.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../providers/app_providers.dart' as old_providers;

// ━━━ DataSource / Service ━━━

/// 聊天服务（封装"怎么拿"）
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

// ━━━ Repository ━━━

/// 对话仓库（只管"要什么"，调 Service）
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final service = ref.watch(chatServiceProvider);
  return ChatRepositoryImpl(service);
});

// ━━━ TTS（委托旧 providers） ━━━

/// Cartesia 情感 TTS 服务
final cartesiaTtsServiceProvider = old_providers.cartesiaTtsServiceProvider;

/// Lip Sync 口型服务
final lipSyncServiceProvider = old_providers.lipSyncServiceProvider;

/// 口型值流（实时驱动 Live2D 唇形）
final lipSyncStreamProvider = StreamProvider<double>((ref) {
  final service = ref.watch(lipSyncServiceProvider);
  return service.mouthStream;
});

/// TTS 是否启用
final ttsEnabledProvider = old_providers.ttsEnabledProvider;

// ━━━ 后端状态 ━━━

/// 后端是否在线
final backendOnlineProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(chatServiceProvider);
  return service.isOnline();
});
