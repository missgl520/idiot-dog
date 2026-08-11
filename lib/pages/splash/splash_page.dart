// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 启动页（Splash Page）
//
// 竹子 Logo + 品牌名 + 竹叶飘落动效
// 动画结束或点击屏幕后自动跳转到对话页 /chat
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 隐私政策 / 用户协议版本号。条款更新时务必同步此版本，
/// 以便未同意新版本的用户在下次启动时被要求重新确认。
const String _legalVersion = '2026-08-11';

/// 启动页 Widget：有状态，需要管理多个动画控制器
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  // 人物上下浮动动画控制器（呼吸感）
  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  // Logo 整体缩放动画控制器（弹性放大）
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  // 整体淡入动画控制器
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // 竹叶飘落动画控制器
  late AnimationController _leafController;
  late Animation<double> _leafAnim;

  /// 用户是否已同意隐私政策 / 用户协议
  bool _agreed = false;

  @override
  void initState() {
    super.initState();

    // 人物浮动：上下微微飘动，呼吸感
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // 整体缩放：从0.6弹性放大到1.0
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // 整体淡入
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // 竹叶飘落循环
    _leafController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();

    _leafAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_leafController);

    // 启动所有动画
    _fadeController.forward();
    _scaleController.forward();

    // 合规同意检查：已同意则延时跳转，未同意则弹窗
    _initConsent();
  }

  /// 检查是否已同意当前版本的法律条款
  Future<void> _initConsent() async {
    final box = await Hive.openBox('settings');
    final agreed = box.get('agreedToLegal', defaultValue: false) as bool;
    final agreedVersion = box.get('agreedToLegalVersion', defaultValue: '') as String;
    if (agreed && agreedVersion == _legalVersion) {
      if (mounted) setState(() => _agreed = true);
      _scheduleNavigate();
    } else {
      if (mounted) _showConsentDialog();
    }
  }

  /// 已同意后延时跳转到对话页
  void _scheduleNavigate() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) context.go('/chat');
    });
  }

  /// 首次启动 / 条款更新时的同意弹窗（不可点击遮罩关闭）
  void _showConsentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('欢迎使用竹笌'),
        content: const SingleChildScrollView(
          child: Text(
            '竹笌是一款情感陪伴 AI，会收集并处理您的对话内容、语音及好感度等数据'
            '以提供陪伴服务。\n\n'
            '为保护您的权益，使用前请阅读并同意《隐私政策》与《用户协议》。'
            '我们已对 AI 生成内容进行显著标识，并采用接口鉴权与多用户数据隔离等措施保护您的信息。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.push('/legal?type=privacy'),
            child: const Text('隐私政策'),
          ),
          TextButton(
            onPressed: () => ctx.push('/legal?type=terms'),
            child: const Text('用户协议'),
          ),
          FilledButton(
            onPressed: () async {
              final box = await Hive.openBox('settings');
              await box.put('agreedToLegal', true);
              await box.put('agreedToLegalVersion', _legalVersion);
              if (mounted) {
                Navigator.of(ctx).pop();
                setState(() => _agreed = true);
                context.go('/chat');
              }
            },
            child: const Text('我已知晓并同意'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _scaleController.dispose();
    _fadeController.dispose();
    _leafController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 根据当前主题亮度选择背景色
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F5DC),
      body: GestureDetector(
        onTap: () {
          if (_agreed) {
            context.go('/chat');
          } else {
            _showConsentDialog();
          }
        }, // 已同意则跳过，否则弹同意框
        child: Stack(
          children: [
            // 背景：淡绿渐变
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF1A1A2E), const Color(0xFF2A3A2E)]
                      : [const Color(0xFFF5F5DC), const Color(0xFFE8F5E9)],
                ),
              ),
            ),

            // 竹叶飘落装饰
            AnimatedBuilder(
              animation: _leafAnim,
              builder: (context, _) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: LeafPainter(_leafAnim.value),
                );
              },
            ),

            // 中央内容
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_fadeAnim, _scaleAnim]),
                builder: (context, _) {
                  return Opacity(
                    opacity: _fadeAnim.value,
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 竹笌人物 - 浮动动画
                          AnimatedBuilder(
                            animation: _floatAnim,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _floatAnim.value),
                                child: child,
                              );
                            },
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6B9E78).withValues(alpha: 0.4),
                                    blurRadius: 40,
                                    offset: const Offset(0, 20),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                // 全局 Logo 竹子图案（v1.9）
                                child: Image.asset(
                                  'assets/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // 品牌名称 "竹  笌"（加宽字间距，营造书卷气）
                          Text(
                            '竹  笌',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF6B9E78),
                              letterSpacing: 12,
                              shadows: [
                                Shadow(
                                  color: const Color(0xFF6B9E78).withValues(alpha: 0.3),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 品牌 Slogan
                          Text(
                            '情感陪伴 · 随时倾听',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 底部跳过提示
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _fadeAnim,
                builder: (context, _) {
                  return Opacity(
                    opacity: _fadeAnim.value * 0.5,
                    child: const Center(
                      child: Text(
                        '点击屏幕跳过',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 竹叶飘落动画画家
/// 通过 CustomPainter 在背景上绘制动态飘落的竹叶
class LeafPainter extends CustomPainter {
  /// 动画进度，0.0 ~ 1.0 循环
  final double progress;

  LeafPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4CAF50).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

      // 绘制 5 片飘落的竹叶，每片有独立的起始位置、速度和旋转角度
    final leafCount = 5;
    for (int i = 0; i < leafCount; i++) {
      // 起始水平位置均匀分布
      final startX = size.width * (0.1 + 0.2 * i);
      // 垂直方向根据进度循环下落，每片有 0.2 的相位差
      final offset = ((progress + i * 0.2) % 1.0) * size.height;
      // 左右轻微摆动，偶数片向右、奇数片向左
      final x = startX + (progress * 30 - 15) * (i % 2 == 0 ? 1 : -1);
      final y = offset;
      // 旋转角度随进度增加，每片有基础旋转偏移
      final rotation = progress * 3.14 + i;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 12, height: 6), paint);
      canvas.restore();
    }
  }

  @override
  // 当动画进度变化时重绘
  bool shouldRepaint(covariant LeafPainter oldDelegate) => oldDelegate.progress != progress;
}
