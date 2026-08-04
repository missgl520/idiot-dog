// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 聊天状态管理器（presentation/providers/）
//
// 职责（单一）：
// - 管理对话状态机（idle/thinking/writing/speaking）
// - 管理消息列表
// - 驱动对话流程：发送消息 → 监听流 → 更新状态
//
// 禁止：
// - 直接操作 HTTP（交给 Repository）
// - 直接写 UI（交给 Widget）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/chat_repository.dart';
import 'app_providers.dart';

// ━━━ 状态定义 ━━━

enum ConversationStatus {
  idle,     // 空闲，等待用户
  thinking, // AI 正在推理
  writing,  // AI 正在输出文字
  speaking, // TTS 播放中
}

// ━━━ Provider ━━━

/// 对话状态
final conversationStatusProvider =
    StateProvider<ConversationStatus>((ref) => ConversationStatus.idle);

/// 当前情绪（驱动 Live2D 表情）
final currentEmotionProvider =
    StateProvider<Emotion>((ref) => const Emotion.neutral());

/// 好感度（FutureProvider，懒加载）
final affinityProvider = FutureProvider<Affinity>((ref) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.getAffinity();
});

/// 聊天通知器（核心）
final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, ChatNotifierState>((ref) {
  return ChatNotifier(ref);
});

// ━━━ State ━━━

class ChatNotifierState {
  final List<Message> messages;
  final String? errorMessage;

  const ChatNotifierState({
    this.messages = const [],
    this.errorMessage,
  });

  ChatNotifierState copyWith({
    List<Message>? messages,
    String? errorMessage,
  }) {
    return ChatNotifierState(
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
    );
  }
}

// ━━━ Notifier ━━━

class ChatNotifier extends StateNotifier<ChatNotifierState> {
  final Ref _ref;
  StreamSubscription<ChatEvent>? _streamSub;
  String? _currentAssistantId;

  ChatNotifier(this._ref) : super(const ChatNotifierState());

  /// 发送消息
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final status = _ref.read(conversationStatusProvider);
    if (status != ConversationStatus.idle) return;

    // 加入用户消息
    final userMsg = Message(
      id: _newId(),
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      errorMessage: null,
    );

    // 切换状态
    _ref.read(conversationStatusProvider.notifier).state =
        ConversationStatus.thinking;

    // 发起对话流
    final repo = _ref.read(chatRepositoryProvider);
    _streamSub?.cancel();
    _streamSub = repo
        .sendMessage(
          message: text.trim(),
          history: _recentHistory(),
        )
        .listen(_onEvent, onDone: _onDone, onError: _onError);
  }

  /// 停止当前对话
  void cancel() {
    _streamSub?.cancel();
    _streamSub = null;
    _currentAssistantId = null;
    _ref.read(conversationStatusProvider.notifier).state =
        ConversationStatus.idle;
  }

  /// 清空对话
  void clearMessages() {
    state = const ChatNotifierState();
    _currentAssistantId = null;
  }

  // ━━━ 事件处理（sealed class 模式匹配） ━━━

  void _onEvent(ChatEvent event) {
    switch (event) {
      case TextChatEvent(text: final t):
        _handleTextChunk(t);
      case EmotionChatEvent(emotion: final e):
        _handleEmotion(e);
      case AffinityChatEvent(affinity: final a):
        _handleAffinity(a);
      case DoneChatEvent():
        _onDone();
      case ErrorChatEvent(message: final m):
        _onError(m);
    }
  }

  void _handleTextChunk(String text) {
    if (_currentAssistantId == null) {
      // 首次收到文字：创建空消息体
      _ref.read(conversationStatusProvider.notifier).state =
          ConversationStatus.writing;
      _currentAssistantId = _newId();
      final assistantMsg = Message(
        id: _currentAssistantId!,
        role: 'assistant',
        content: text,
        timestamp: DateTime.now(),
        isStreaming: true,
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
      );
    } else {
      // 追加到当前消息
      final msgs = state.messages.toList();
      final lastIdx = msgs.length - 1;
      msgs[lastIdx] = msgs[lastIdx].copyWith(
        content: msgs[lastIdx].content + text,
      );
      state = state.copyWith(messages: msgs);
    }
  }

  void _handleEmotion(Emotion emotion) {
    _ref.read(currentEmotionProvider.notifier).state = emotion;
  }

  void _handleAffinity(Affinity affinity) {
    // FutureProvider 用 invalidate + future 重载
    _ref.invalidate(affinityProvider);
  }

  void _onDone() {
    _streamSub?.cancel();
    _streamSub = null;

    if (_currentAssistantId != null) {
      final msgs = state.messages.toList();
      final lastIdx = msgs.length - 1;
      if (lastIdx >= 0) {
        msgs[lastIdx] = msgs[lastIdx].copyWith(isStreaming: false);
        state = state.copyWith(messages: msgs);
      }
    }

    _currentAssistantId = null;
    _ref.read(conversationStatusProvider.notifier).state =
        ConversationStatus.speaking;

    // 触发 TTS 播放
    _playTts();
  }

  Future<void> _playTts() async {
    final ttsEnabled = _ref.read(ttsEnabledProvider);
    if (!ttsEnabled) {
      _ref.read(conversationStatusProvider.notifier).state =
          ConversationStatus.idle;
      return;
    }

    // 取最后一条 AI 回复
    final msgs = state.messages;
    final lastMsg = msgs.isNotEmpty ? msgs.last : null;
    if (lastMsg == null || lastMsg.role != 'assistant') {
      _ref.read(conversationStatusProvider.notifier).state =
          ConversationStatus.idle;
      return;
    }

    final tts = _ref.read(cartesiaTtsServiceProvider);
    await tts.init(baseUrl: null); // 使用 CartesiaService 默认地址

    // 绑定 LipSync → 播放器，唇形自动跟随 TTS 播放状态
    final lipSync = _ref.read(lipSyncServiceProvider);
    lipSync.bind(tts.player);

    try {
      await tts.speak(lastMsg.content);
    } catch (e) {
      // TTS 失败不阻塞对话
    }

    final current = _ref.read(conversationStatusProvider);
    if (current == ConversationStatus.speaking) {
      _ref.read(conversationStatusProvider.notifier).state =
          ConversationStatus.idle;
    }
  }

  void _onError(String message) {
    _streamSub?.cancel();
    _streamSub = null;
    _currentAssistantId = null;
    state = state.copyWith(errorMessage: message);
    _ref.read(conversationStatusProvider.notifier).state =
        ConversationStatus.idle;
  }

  // ━━━ 工具 ━━━

  List<Message> _recentHistory() {
    return state.messages.where((m) => !m.isStreaming).toList();
  }

  int _msgCount = 0;
  String _newId() =>
      'msg_${DateTime.now().millisecondsSinceEpoch}_${_msgCount++}';
}
