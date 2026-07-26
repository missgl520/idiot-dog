// 语音输入按钮（按住说话）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _isPressed = false; // ignore: unused_field;

  @override
  void initState() {
    super.initState();
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

  Future<void> _startListening() async {
    setState(() => _isPressed = true);
    _pulseController.repeat();

    final asr = ref.read(asrServiceProvider);
    ref.read(asrListeningProvider.notifier).state = true;

    try {
      // 开始语音识别
      await asr.startListening(
        onResult: (String text) {
          if (text.isNotEmpty) {
            debugPrint('ASR result: $text');
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
    // 释放状态在 stopListening 里处理，这里只管开始
  }

  void _stopListening() {
    final asr = ref.read(asrServiceProvider);
    asr.stopListening();
    setState(() => _isPressed = false);
    _pulseController.stop();
    _pulseController.reset();
    ref.read(asrListeningProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final isListening = ref.watch(asrListeningProvider);

    return GestureDetector(
      onTapDown: (_) => _startListening(),
      onTapUp: (_) => _stopListening(),
      onTapCancel: _stopListening,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: isListening ? _pulseAnim.value : 1.0,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isListening
                    ? const Color(0xFFE53935)  // 录音中：红色
                    : const Color(0xFF4CAF50),  // 默认：绿色
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: (isListening
                            ? const Color(0xFFE53935)
                            : const Color(0xFF4CAF50))
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
          );
        },
      ),
    );
  }
}
