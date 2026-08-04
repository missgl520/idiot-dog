// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹芽主页 - 信纸式对话
//
// 新架构（v2）：
//   UI → ChatNotifier → ChatRepository → BackendApiDataSource → 后端
//
// 状态机：idle → thinking → writing → speaking → idle
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings/settings_sheet.dart';
import '../settings/menu_panel.dart';
import '../../models/message.dart' as old_msg;
import '../../providers/app_providers.dart' as old_providers;
import '../../domain/entities/entities.dart' as entities;
import '../../presentation/providers/chat_provider.dart';
import '../../widgets/live2d_controller.dart';
import '../../widgets/live2d_widget.dart';
import '../../widgets/voice_button.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late AnimationController _thinkingController;

  // ━━━ 生命周期 ━━━

  @override
  void initState() {
    super.initState();
    _thinkingController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _thinkingController.forward(from: 0);
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 初始化 Live2D
      ref.read(old_providers.live2dControllerProvider).init();

      // 新架构：监听 ChatNotifier 状态
      ref.listenManual(chatNotifierProvider, (_, state) {
        if (state.errorMessage != null || state.messages.any((m) => m.isStreaming)) {
          _thinkingController.repeat(reverse: true);
        } else {
          _thinkingController.stop();
        }
        _scrollToBottom();
      });

      // 新架构：监听对话状态，同步 Live2D
      ref.listenManual(conversationStatusProvider, (_, status) {
        _syncLive2DStatus(status);
      });

      // 新架构：监听情绪变化，同步 Live2D 表情
      ref.listenManual(currentEmotionProvider, (_, emotion) {
        _syncLive2DEmotion(emotion.label.name);
      });

      // 旧架构：语音识别结果
      ref.listenManual(old_providers.asrResultProvider, (_, text) {
        if (text != null && text.isNotEmpty) {
          _inputController.text = text;
          _send();
          ref.read(old_providers.asrResultProvider.notifier).state = null;
        }
      });
    });
  }

  // ━━━ Live2D 同步 ━━━

  void _syncLive2DStatus(ConversationStatus status) {
    final ctrl = ref.read(old_providers.live2dControllerProvider);
    switch (status) {
      case ConversationStatus.idle:
        ctrl.setStatus(ZhuaLive2DStatus.idle);
      case ConversationStatus.thinking:
        ctrl.setStatus(ZhuaLive2DStatus.thinking);
      case ConversationStatus.writing:
        ctrl.setStatus(ZhuaLive2DStatus.thinking);
      case ConversationStatus.speaking:
        ctrl.setStatus(ZhuaLive2DStatus.speaking);
    }
  }

  void _syncLive2DEmotion(String emotion) {
    final ctrl = ref.read(old_providers.live2dControllerProvider);
    switch (emotion) {
      case 'happy':  ctrl.setEmotion('happy');
      case 'sad':    ctrl.setEmotion('sad');
      case 'angry':  ctrl.setEmotion('angry');
      case 'surprised': ctrl.setEmotion('surprised');
      case 'anxious': ctrl.setEmotion('anxious');
      default:       ctrl.setEmotion('neutral');
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _thinkingController.dispose();
    super.dispose();
  }

  // ━━━ 发送消息 ━━━

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    // 旧 provider（Hive 持久化兼容）
    final userMsg = old_msg.Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    ref.read(old_providers.messagesProvider.notifier).addMessage(userMsg);

    // 清空输入框，收起键盘
    _inputController.clear();
    _focusNode.unfocus();
    _scrollToBottom();

    // 交给 ChatNotifier（核心逻辑走新架构）
    ref.read(chatNotifierProvider.notifier).sendMessage(text);
  }

  // ━━━ 滚动 ━━━

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // UI
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider);
    final status = ref.watch(conversationStatusProvider);
    final isDark = ref.watch(old_providers.themeProvider);

    final messages = chatState.messages;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isDark),
            Expanded(
              child: Stack(
                children: [
                  // Live2D
                  Positioned(
                    bottom: 160,
                    right: 20,
                    child: AnimatedOpacity(
                      opacity: status == ConversationStatus.idle ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 600),
                      child: Consumer(
                        builder: (context, ref, _) {
                          final l2dCtrl =
                              ref.watch(old_providers.live2dControllerProvider);
                          return ZhuaLive2DWidget(
                            controller: l2dCtrl.viewController,
                            onTap: () => l2dCtrl.playTap(),
                          );
                        },
                      ),
                    ),
                  ),

                  // 消息列表
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => _focusNode.unfocus(),
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: messages.isEmpty
                            ? _buildEmpty(isDark, status)
                            : _buildLetterList(messages, status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildInputArea(status, chatState.errorMessage),
          ],
        ),
      ),
    );
  }

  // ━━━ 顶栏 ━━━

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => MenuPanel.show(context),
            child: Row(
              children: [
                Text(
                  '竹芽',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.menu, size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
          const Spacer(),
          _buildStatusBadge(),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => SettingsSheet.show(context),
            icon: Icon(
              Icons.settings_outlined,
              size: 22,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = ref.watch(conversationStatusProvider);
    final chatState = ref.watch(chatNotifierProvider);

    // 错误优先显示
    if (chatState.errorMessage != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '出错了',
          style: TextStyle(
            fontSize: 12,
            color: Colors.red.shade700,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      );
    }

    final label = switch (status) {
      ConversationStatus.idle     => '在的',
      ConversationStatus.thinking => '在想',
      ConversationStatus.writing => '在写',
      ConversationStatus.speaking => '在说',
    };

    final color = switch (status) {
      ConversationStatus.idle     => const Color(0xFF6B9E78),
      ConversationStatus.thinking => const Color(0xFFB8A07A),
      ConversationStatus.writing  => const Color(0xFF6B9E78),
      ConversationStatus.speaking => const Color(0xFF6B9E78),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // ━━━ 空状态 ━━━

  Widget _buildEmpty(bool isDark, ConversationStatus status) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '…',
            style: TextStyle(
              fontSize: 48,
              color: const Color(0xFF6B9E78).withValues(alpha: 0.3),
              height: 1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            status == ConversationStatus.idle ? '竹芽在这里' : '竹芽在等你',
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).textTheme.bodySmall?.color,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ━━━ 信纸列表 ━━━

  Widget _buildLetterList(List<entities.Message> messages, ConversationStatus status) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return const SizedBox(height: 40);
        return _LetterEntry(message: messages[index - 1]);
      },
    );
  }

  // ━━━ 输入区 ━━━

  Widget _buildInputArea(ConversationStatus status, String? errorMessage) {
    final isWorking =
        status == ConversationStatus.thinking ||
        status == ConversationStatus.writing;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 思考中提示
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isWorking ? _buildThinkingIndicator() : const SizedBox.shrink(),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  VoiceButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      maxLines: null,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enabled: !isWorking,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: '写给竹芽…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 0.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFF6B9E78),
                            width: 1,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ListenableBuilder(
                    listenable: _inputController,
                    builder: (_, _) {
                      final hasText = _inputController.text.trim().isNotEmpty;
                      return !isWorking && hasText
                          ? IconButton(
                              onPressed: _send,
                              icon: const Icon(
                                Icons.arrow_upward,
                                color: Color(0xFF6B9E78),
                              ),
                            )
                          : const SizedBox(width: 48);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ━━━ 思考中动画 ━━━

  Widget _buildThinkingIndicator() {
    return AnimatedBuilder(
      animation: _thinkingController,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 3; i++)
                _Dot(delay: i, anim: _thinkingController.value),
              const SizedBox(width: 8),
              Text(
                '竹芽在想',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 消息条目
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _LetterEntry extends StatelessWidget {
  final entities.Message message;

  const _LetterEntry({required this.message});

  bool get isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            isUser ? '我' : '竹芽',
            style: TextStyle(
              fontSize: 11,
              color: isUser
                  ? Theme.of(context).textTheme.bodySmall?.color
                  : const Color(0xFF6B9E78).withValues(alpha: 0.7),
              letterSpacing: 3,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: isUser
                ? null
                : BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: const Color(0xFF6B9E78).withValues(alpha: 0.28),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                  ),
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (message.isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _TypingCursor(),
            ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 打字光标
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _TypingCursor extends StatefulWidget {
  @override
  State<_TypingCursor> createState() => _TypingCursorState();
}

class _TypingCursorState extends State<_TypingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        width: 2,
        height: 16,
        color: const Color(0xFF6B9E78).withValues(alpha: _c.value),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 思考中的三个点
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _Dot extends StatelessWidget {
  final int delay;
  final double anim;

  const _Dot({required this.delay, required this.anim});

  @override
  Widget build(BuildContext context) {
    final offset = (anim + delay * 0.33) % 1.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFB8A07A).withValues(alpha: 0.3 + offset * 0.5),
        ),
      ),
    );
  }
}
