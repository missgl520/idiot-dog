// Live2D 虚拟角色组件
// 说明：这里是模拟展示（用 logo 图片代替）
// 后续接入 flutter_live2d 包后替换为真实 Live2D 模型渲染
import 'package:flutter/material.dart';

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

    // 呼吸动画（微微上下浮动）
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
        return Positioned(
          bottom: 120,
          right: 16,
          child: Transform.translate(
            offset: Offset(0, _breatheAnim.value),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
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
              errorBuilder: (ctx, err, stack) => Container(
                color: const Color(0xFFE8F5E9),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  size: 60,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
