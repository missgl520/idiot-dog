// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 语音输入按钮（长按说话）
//
// 交互方式：长按开始录音，松开停止并自动发送识别文字
//
// 状态：
//   默认（绿色 mic_none）→ 按下（红色 mic，脉冲动画）→ 停止（恢复默认）
//
// 依赖：AsrService（speech_to_text 插件）
// 注意：需要麦克风权限（Android: RECORD_AUDIO，iOS: NSMicrophoneUsageDescription）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../providers/app_providers.dart';

class VoiceButton extends ConsumerStatefulWidget {
  const VoiceButton({super.key});

  @override
  ConsumerState<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends ConsumerState<VoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // 脉冲动画：录音时图标缩放 1.0→1.3，循环
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── 按下：开始语音识别 ──
  Future<void> _startListening() async {
    setState(() {});
    _pulseController.repeat();
    ref.read(asrListeningProvider.notifier).state = true;

    final asr = ref.read(asrServiceProvider);
    try {
      await asr.startListening(
        onResult: (String text) {
          if (text.isNotEmpty) {
            debugPrint('ASR result: $text');
            // TODO: 识别结果回填输入框或自动发送
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音识别失败: $e')),
        );
      }
    }
    // 状态释放在 stopListening() 处理
  }

  // ── 松开：停止语音识别 ──
  void _stopListening() {
    final asr = ref.read(asrServiceProvider);
    asr.stopListening();

    _pulseController.stop();
    _pulseController.reset();
    ref.read(asrListeningProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final isListening = ref.watch(asrListeningProvider);

    return GestureDetector(
      // 手势：按下开始，松开/取消停止
      onTapDown: (_) => _startListening(),
      onTapUp: (_) => _stopListening(),
      onTapCancel: _stopListening,

      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: isListening ? _pulseAnim.value : 1.0,
            child: child,
          );
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isListening
                ? const Color(0xFFE53935)  // 录音中：红色
                : AppTheme.bamboo,         // 默认：竹绿
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (isListening ? const Color(0xFFE53935) : AppTheme.bamboo)
                    .withValues(alpha: 0.3),
                blurRadius: isListening ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            isListening ? Icons.mic : Icons.mic_none,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
