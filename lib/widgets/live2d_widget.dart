// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Live2D 虚拟角色 Widget
//
// 集成 flutter_live2d，接 Atago 模型（碧蓝航线）
//
// 竹芽状态 → 动画映射：
//   idle        → idle 待机动画（循环）+ f01 表情
//   thinking    → f02 表情（等 AI 回复）
//   speaking    → tap_body 动画 + f03 表情（竹芽在说话）
//   listening   → f04 表情（用户在说话，竹芽专注）
//   点击身体    → 触发摇晃动画（tap_body）
//
// 模型：assets/live2d/shizuku/
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_live2d/flutter_live2d.dart';

/// 竹芽 Live2D 虚拟角色 Widget
///
/// 必须配合 ZhuaLive2DController 使用：
///   final controller = ref.read(live2dControllerProvider);
///   ZhuaLive2DWidget(controller: controller.viewController)
///
/// 模型加载中 / 失败 → 显示加载动画兜底
class ZhuaLive2DWidget extends StatelessWidget {
  final Live2DViewController controller;
  final VoidCallback? onTap;

  const ZhuaLive2DWidget({
    super.key,
    required this.controller,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ValueListenableBuilder<Live2DViewState>(
        valueListenable: controller,
        builder: (context, state, _) {
          if (!state.isAttached || state.loadedModel == null) {
            return const _ModelLoadingPlaceholder();
          }
          return const Live2DView(controller: null);
        },
      ),
    );
  }
}

/// 模型加载中 / 失败时的兜底 UI
class _ModelLoadingPlaceholder extends StatelessWidget {
  const _ModelLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B9E78).withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(child: _LoadingBounce()),
    );
  }
}

/// 加载中动画（三个点跳动）
class _LoadingBounce extends StatefulWidget {
  const _LoadingBounce();

  @override
  State<_LoadingBounce> createState() => _LoadingBounceState();
}

class _LoadingBounceState extends State<_LoadingBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
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
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final phase = ((_c.value + delay) % 1.0);
            final bounce = phase < 0.5 ? phase * 2 : 2 - phase * 2;
            return Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6B9E78)
                    .withValues(alpha: 0.4 + bounce * 0.6),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
