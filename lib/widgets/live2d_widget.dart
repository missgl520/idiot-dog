// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Live2D 虚拟角色组件
//
// 当前实现：占位展示（用 logo 图片 + 呼吸动画）
//
// 后续接入 flutter_live2d 包后替换方向：
//   1. pubspec.yaml 添加依赖：flutter_live2d: ^1.0.2
//   2. 替换 Image.asset 为 Cubism4Widget / Live2DWidget
//   3. 加载 .model3.json 模型文件
//   4. 根据竹芽状态（thinking/writing/speaking）触发不同动画
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class Live2DWidget extends StatefulWidget {
  const Live2DWidget({super.key});

  @override
  State<Live2DWidget> createState() => _Live2DWidgetState();
}

class _Live2DWidgetState extends State<Live2DWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _breatheAnim;

  @override
  void initState() {
    super.initState();

    // 呼吸动画：上下微微浮动，3 秒一个周期，循环往复
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _breatheAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          // 呼吸浮动
          offset: Offset(0, _breatheAnim.value),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () {},  // 未来可点击触发互动动画
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppTheme.bamboo.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.cover,
              // 资源不存在时用竹子图标兜底
              errorBuilder: (ctx, err, stack) => Container(
                color: const Color(0xFFE8F5E9),
                child: const Icon(Icons.smart_toy_outlined, size: 60, color: AppTheme.bamboo),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
