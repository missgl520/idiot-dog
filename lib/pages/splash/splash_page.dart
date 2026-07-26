// Splash 启动页 - 竹芽人物动画版
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  // 人物浮动动画
  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  // Logo 缩放动画
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  // 整体淡入
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // 竹叶飘落动画
  late AnimationController _leafController;
  late Animation<double> _leafAnim;

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

    // 2.5秒后跳主页
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) context.go('/chat');
    });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F5DC),
      body: GestureDetector(
        onTap: () => context.go('/chat'), // 点击跳过
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
                          // 竹芽人物 - 浮动动画
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
                                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: Image.asset(
                                  'assets/splash_char_transparent.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // 竹芽文字
                          Text(
                            '竹  芽',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF4CAF50),
                              letterSpacing: 12,
                              shadows: [
                                Shadow(
                                  color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Slogan
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

// 竹叶飘落动画画家
class LeafPainter extends CustomPainter {
  final double progress;

  LeafPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4CAF50).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // 画几片飘落的竹叶
    final leafCount = 5;
    for (int i = 0; i < leafCount; i++) {
      final startX = size.width * (0.1 + 0.2 * i);
      final offset = ((progress + i * 0.2) % 1.0) * size.height;
      final x = startX + (progress * 30 - 15) * (i % 2 == 0 ? 1 : -1);
      final y = offset;
      final rotation = progress * 3.14 + i;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 12, height: 6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant LeafPainter oldDelegate) => oldDelegate.progress != progress;
}
