// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹芽主页 - 信纸式对话
//
// 核心理念：没有"发送"按钮，没有气泡，只有纸和笔
// 用户输入 → 回车/软键盘发送 → 竹芽"想"→"写"→"说"
//
// 状态机流程：
//   idle → (用户发消息) → thinking → writing → (TTS可选) → speaking → idle
//
// 流式输出：AI 一个字一个字来，每收到一个字更新 UI
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../../models/message.dart';
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
  // 文本输入控制器：读取用户正在输入的文字
  final TextEditingController _inputController = TextEditingController();

  // 滚动控制器：新消息来了自动滚到底
  final ScrollController _scrollController = ScrollController();

  // 焦点节点：控制软键盘弹出/收起
  final FocusNode _focusNode = FocusNode();

  // 竹芽"想"的动画控制器：三个墨点上下浮动
  late AnimationController _thinkingController;

  @override
  void initState() {
    super.initState();

    // 动画：1.2 秒循环，结束后从头开始（无限循环）
    _thinkingController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,  // TickerProvider，驱动动画帧
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _thinkingController.forward(from: 0);
        }
      });

    // 监听竹芽状态：变"想"或"写"时启动动画，变"idle"时停止
    // addPostFrameCallback 保证 context 和 ref 已就绪后再监听
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 初始化 Live2D
      ref.read(live2dControllerProvider).init();

      // 竹芽状态 → 动画控制
      ref.listenManual(zhuaStatusProvider, (_, status) {
        if (status == ZhuaStatus.thinking || status == ZhuaStatus.writing) {
          _thinkingController.repeat(reverse: true);
        } else {
          _thinkingController.stop();
        }
        // 同步驱动 Live2D 动画
        _syncLive2DStatus(status);
      });

      // 语音识别结果来了 → 填入输入框 + 自动发送
      ref.listenManual(asrResultProvider, (_, text) {
        if (text != null && text.isNotEmpty) {
          _inputController.text = text;
          _send();
          // 清空 provider，避免重复触发
          ref.read(asrResultProvider.notifier).state = null;
        }
      });
    });
  }

  // ── Live2D 状态同步 ──────────────────────────

  void _syncLive2DStatus(ZhuaStatus status) {
    final ctrl = ref.read(live2dControllerProvider);
    switch (status) {
      case ZhuaStatus.idle:
        ctrl.setStatus(ZhuaLive2DStatus.idle);
      case ZhuaStatus.thinking:
        ctrl.setStatus(ZhuaLive2DStatus.thinking);
      case ZhuaStatus.writing:
        ctrl.setStatus(ZhuaLive2DStatus.thinking);
      case ZhuaStatus.speaking:
        ctrl.setStatus(ZhuaLive2DStatus.speaking);
    }
  }

  @override
  void dispose() {
    // 资源清理：每个 controller / node 用完必须 dispose，避免内存泄漏
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _thinkingController.dispose();
    super.dispose();
  }

  // ━━━━━━━ 用户发送消息 ━━━━━━━
  // 触发时机：TextField 回车 / 点击发送图标
  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;  // 空消息不发送

    final agnes = ref.read(agnesServiceProvider);
    final history = ref.read(messagesProvider);

    // 1. 把用户"写"的信加入消息列表
    final userMsg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    ref.read(messagesProvider.notifier).addMessage(userMsg);

    // 2. 清空输入框，收起软键盘
    _inputController.clear();
    _focusNode.unfocus();
    _scrollToBottom();

    // 3. 竹芽进入"想"的状态
    ref.read(zhuaStatusProvider.notifier).state = ZhuaStatus.thinking;

    // 4. 调用 AI，开始对话
    _chatWithAI(agnes, history, text);
  }

  // ━━━━━━━ AI 对话核心逻辑 ━━━━━━━
  // 完整流程：
  //   构建上下文 → 调流式 API → 增量更新 UI → 存记忆 → TTS 播报 → 恢复 idle
  Future<void> _chatWithAI(
    dynamic agnes,          // AgnesService 实例
    List<Message> history,  // 当前对话历史
    String userText,        // 用户刚发的消息
  ) async {
    try {
      // ===== Step 1: 构建长期记忆上下文（SinoMem）=====
      final memory = ref.read(memoryServiceProvider);
      final memoryCtx = await memory.buildContext(userText);

      // ===== Step 2: System Prompt — 竹芽的人设定义 =====
      const systemPrompt = '''你是竹芽，一个温柔的情感陪伴者。
你正在陪伴一个人聊天。你不着急，不刷屏，不给建议除非对方真的需要。
你的回复像手写的信，有呼吸感，有停顿，不是聊天消息。
你可以沉默，可以问一句不急着回答的问题，可以不接话茬。
保持真诚，不需要总是正能量。''';

      // 如果有记忆上下文，追加到 System Prompt 后面
      final effectiveSystem = memoryCtx.isNotEmpty
          ? '$systemPrompt\n$memoryCtx'
          : systemPrompt;

      // ===== Step 3: 构建消息列表（history 转 API 格式）=====
      final msgs = history.map((m) => {
        'role': m.role,
        'content': m.content,
      }).toList();

      // ===== Step 4: 先占位一个空的 AI 消息 =====
      // isStreaming=true 告诉 UI：这条消息还在输出中（显示光标）
      final aiMsgId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
      final aiMsg = Message(
        id: aiMsgId,
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true,
      );
      ref.read(messagesProvider.notifier).addMessage(aiMsg);

      // ===== Step 5: 竹芽进入"写"的状态 =====

      ref.read(zhuaStatusProvider.notifier).state = ZhuaStatus.writing;

      // ===== Step 6: 逐字接收 AI 输出，增量更新 UI =====
      // 后端接口：message=当前消息，history=对话历史
      String full = '';
      await for (final chunk in agnes.chatStream(
        message: userText,
        history: msgs,
        systemPrompt: effectiveSystem,
      )) {
        full += chunk;  // 累加这个字
        ref.read(messagesProvider.notifier).updateMessage(aiMsgId, full);
        _scrollToBottom();
      }

      // ===== Step 7: 流式输出结束，关闭光标 =====
      ref.read(messagesProvider.notifier).updateMessage(aiMsgId, full, isStreaming: false);

      // ===== Step 8: 存入长期记忆 =====
      if (full.isNotEmpty) {
        await memory.store('$userText || $full', category: 'chat_memory');
      }

      // ===== Step 9: TTS 语音播报（如果开关打开）=====
      final ttsOn = ref.read(ttsEnabledProvider);
      if (ttsOn) {
        ref.read(zhuaStatusProvider.notifier).state = ZhuaStatus.speaking;

        // 优先：Cartesia API TTS（自然音色 + 情感）
        final ttsMode = ref.read(ttsModeProvider);
        if (ttsMode == 'cartesia') {
          try {
            final cartesiaTts = ref.read(cartesiaTtsServiceProvider);
            await cartesiaTts.speak(full);
          } catch (e) {
            // Cartesia 失败，降级到系统 TTS
            print('[Chat] Cartesia TTS 失败，降级: $e');
            final tts = ref.read(ttsServiceProvider);
            await tts.speak(full);
          }
        } else {
          // 系统 TTS（flutter_tts）
          final tts = ref.read(ttsServiceProvider);
          await tts.speak(full);
        }
      }

      // ===== Step 10: 回到空闲状态 =====
      ref.read(zhuaStatusProvider.notifier).state = ZhuaStatus.idle;

    } catch (e) {
      // 异常处理：无论哪里出错，都要回到 idle 并提示用户
      ref.read(zhuaStatusProvider.notifier).state = ZhuaStatus.idle;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('竹芽走神了: $e')),
        );
      }
    }
  }

  // ━━━━━━━ 滚动到底部 ━━━━━━━
  // addPostFrameCallback 确保在下一帧绘制前执行，此时 scrollController 已就绪
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
  // UI 布局（从上到下）
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);  // 消息列表
    final status = ref.watch(zhuaStatusProvider); // 竹芽当前状态
    final isDark = ref.watch(themeProvider);      // 是否暗色主题

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶栏：竹芽名字 + 状态徽章 + 设置入口
            _buildTopBar(isDark),

            // 中间：信纸区域
            Expanded(
              child: Stack(
                children: [
                  // Live2D 角色（右下角，工作中时变透明）
                  Positioned(
                    bottom: 160,
                    right: 20,
                    child: AnimatedOpacity(
                      opacity: status == ZhuaStatus.idle ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 600),
                      child: Consumer(
                        builder: (context, ref, _) {
                          final l2dCtrl = ref.watch(live2dControllerProvider);
                          return ZhuaLive2DWidget(
                            controller: l2dCtrl.viewController,
                            onTap: () => l2dCtrl.playTap(),
                          );
                        },
                      ),
                    ),
                  ),

                  // 消息列表（空白处点击收起键盘）
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

            // 底部输入区
            _buildInputArea(status),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━ 顶栏 ━━━━━━━
  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          const Spacer(),
          // 竹芽状态徽章（在的 / 在想 / 在写 / 在说）
          _buildStatusBadge(),
          const SizedBox(width: 12),
          // 设置入口
          IconButton(
            onPressed: () => context.push('/settings'),
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

  // 竹芽状态徽章：根据状态显示不同文字和颜色
  Widget _buildStatusBadge() {
    final status = ref.watch(zhuaStatusProvider);

    // 徽章文字
    final label = switch (status) {
      ZhuaStatus.idle     => '在的',
      ZhuaStatus.thinking => '在想',
      ZhuaStatus.writing  => '在写',
      ZhuaStatus.speaking => '在说',
    };

    // 徽章颜色（idle 用绿色，thinking 用暖棕色，其他用绿色）
    final color = switch (status) {
      ZhuaStatus.idle     => const Color(0xFF6B9E78),
      ZhuaStatus.thinking => const Color(0xFFB8A07A),
      ZhuaStatus.writing  => const Color(0xFF6B9E78),
      ZhuaStatus.speaking => const Color(0xFF6B9E78),
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

  // ━━━━━━━ 空状态 ━━━━━━━
  // 没有历史消息时，显示竹芽在那里等着
  Widget _buildEmpty(bool isDark, ZhuaStatus status) {
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
            status == ZhuaStatus.idle ? '竹芽在这里' : '竹芽在等你',
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

  // ━━━━━━━ 信纸列表 ━━━━━━━
  Widget _buildLetterList(List<Message> messages, ZhuaStatus status) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      // +1 是因为头部留 40px 空白
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return const SizedBox(height: 40);
        final msg = messages[index - 1];
        return _LetterEntry(message: msg);
      },
    );
  }

  // ━━━━━━━ 底部输入区 ━━━━━━━
  Widget _buildInputArea(ZhuaStatus status) {
    // thinking / writing 时禁用输入，避免用户抢发
    final isWorking = status == ZhuaStatus.thinking || status == ZhuaStatus.writing;

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
              // 竹芽在想/在写的提示（三点动画 + 文字）
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isWorking ? _buildThinkingIndicator() : const SizedBox.shrink(),
              ),

              // 文字输入框 + 语音按钮（Row 布局）
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 语音按钮（左侧）
                  VoiceButton(),
                  const SizedBox(width: 12),

                  // 输入框
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

                  // 发送按钮（有文字时才显示）
                  ListenableBuilder(
                    listenable: _inputController,
                    builder: (_, __) {
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

  // ━━━━━━━ 思考中动画 ━━━━━━━
  // 三个点上下浮动 + "竹芽在想"文字
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
// 一封"信"：用户或竹芽的文字条目
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _LetterEntry extends StatelessWidget {
  final Message message;

  const _LetterEntry({required this.message});

  bool get isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 谁写的标签
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

          // 消息内容
          // AI 消息有左侧竖线装饰（模拟引用）
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: isUser
                ? null
                : BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: const Color(0xFF6B9E78).withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                  ),
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

          // AI 正在输出时，打字光标闪烁
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
// 打字光标：AI 输出中时闪烁的竖线
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
    )..repeat(reverse: true);  // 透明度 0↔1 循环
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
// 思考中的三个点：带相位差的上下浮动
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _Dot extends StatelessWidget {
  final int delay;   // 相位延迟（0/1/2，模拟错开的动画）
  final double anim; // 动画进度 0.0 ~ 1.0

  const _Dot({required this.delay, required this.anim});

  @override
  Widget build(BuildContext context) {
    // 每个点的偏移量错开 1/3 周期，制造波浪感
    final offset = (anim + delay * 0.33) % 1.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // alpha 从 0.3 到 0.8 循环
          color: const Color(0xFFB8A07A).withValues(alpha: 0.3 + offset * 0.5),
        ),
      ),
    );
  }
}
