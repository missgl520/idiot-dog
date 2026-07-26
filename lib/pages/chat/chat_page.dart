// 主对话页面
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../../widgets/live2d_widget.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/voice_button.dart';
import '../../widgets/image_picker_button.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // Live2D 区域透明度（文字滚动过半后渐隐）
  double _live2dOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll <= 0) return;

    // 滚动超过50%时，Live2D渐隐
    final ratio = (currentScroll / maxScroll).clamp(0.0, 1.0);
    setState(() {
      _live2dOpacity = 1.0 - (ratio - 0.5).clamp(0.0, 0.5) * 2;
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final agnesService = ref.read(agnesServiceProvider);
    final messages = ref.read(messagesProvider);

    // 发送用户消息
    final userMsg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    ref.read(messagesProvider.notifier).addMessage(userMsg);
    _inputController.clear();
    _scrollToBottom();

    // 更新聊天状态
    ref.read(chatStatusProvider.notifier).state = ChatStatus.thinking;

    // 发送AI请求
    _chatWithAI(agnesService, messages, text);
  }

  Future<void> _chatWithAI(
    dynamic agnesService,
    List<Message> history,
    String userText,
  ) async {
    try {
      final memoryService = ref.read(memoryServiceProvider);
      final memoryContext = await memoryService.buildMemoryContext(userText);

      final systemPrompt = '''你是竹芽，一个温柔的情感陪伴AI助手。
你正在陪伴用户聊天，请保持温暖、真诚、倾听的态度。
如果用户情绪低落，请给予安慰和陪伴。
$memoryContext''';

      final msgs = history
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final aiMsgId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
      final aiMsg = Message(
        id: aiMsgId,
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true,
      );
      ref.read(messagesProvider.notifier).addMessage(aiMsg);

      // 流式输出
      final stream = agnesService.chatStream(
        messages: msgs,
        systemPrompt: systemPrompt,
      );

      String fullContent = '';
      await for (final chunk in stream) {
        fullContent += chunk;
        ref.read(messagesProvider.notifier).updateMessage(aiMsgId, fullContent);
        _scrollToBottom();
      }

      // 保存记忆
      if (fullContent.isNotEmpty) {
        await memoryService.saveMemory('$userText || $fullContent');
      }

      // TTS 播报
      final ttsEnabled = ref.read(ttsEnabledProvider);
      if (ttsEnabled) {
        ref.read(chatStatusProvider.notifier).state = ChatStatus.speaking;
        final tts = ref.read(ttsServiceProvider);
        await tts.speak(fullContent);
      }

      ref.read(chatStatusProvider.notifier).state = ChatStatus.idle;
    } catch (e) {
      ref.read(chatStatusProvider.notifier).state = ChatStatus.idle;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI回复失败: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶栏
            _buildAppBar(context, themeMode),

            // 中间：Live2D + 聊天记录
            Expanded(
              child: Stack(
                children: [
                  // 下层：Live2D 角色（随滚动渐隐）
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _live2dOpacity,
                      duration: const Duration(milliseconds: 300),
                      child: const Live2DWidget(),
                    ),
                  ),

                  // 上层：消息列表
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => _focusNode.unfocus(),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
                            ],
                            stops: const [0.3, 0.5],
                          ),
                        ),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                          itemCount: messages.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return const SizedBox(height: 80);
                            }
                            final msg = messages[index - 1];
                            return ChatBubble(
                              message: msg,
                              onLongPress: () {
                                ref.read(messagesProvider.notifier).removeMessage(msg.id);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 底栏：输入框 + 按钮
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // 左：竹芽logo
          GestureDetector(
            onTap: () => context.go('/'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/logo.png', fit: BoxFit.cover),
              ),
            ),
          ),
          const Spacer(),
          // 右：设置 + 主题切换
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: isDarkMode ? Colors.amber : Colors.grey,
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggle(),
            tooltip: '切换主题',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: '设置',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左：语音按钮
          const VoiceButton(),
          const SizedBox(width: 8),

          // 中：输入框
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: '说点什么...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 右：图片/相机按钮
          const ImagePickerButton(),
        ],
      ),
    );
  }
}
