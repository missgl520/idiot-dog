// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Live2D 虚拟角色 Widget
//
// 集成 flutter_live2d，接 Atago 模型（碧蓝航线）
//
// 触摸交互（v1.9 新增）：
//   单击上半区（头/脸） → 随机表情变化
//   单击下半区（身体） → 摇晃动画
//   双击任意位置       → 害羞脸红彩蛋
//
// 竹芽状态 → 动画映射：
//   idle        → idle 待机动画（循环）+ f01 表情
//   thinking    → f02 表情（等 AI 回复）
//   speaking    → tap_body 动画 + f03 表情（竹芽在说话）
//   listening   → f04 表情（用户在说话，竹芽专注）
//
// 模型：assets/live2d/zhuyabudoll/
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_live2d/flutter_live2d.dart';
import 'live2d_controller.dart';

/// 竹芽 Live2D 虚拟角色 Widget
///
/// 必须配合 ZhuaLive2DController 使用：
///   final controller = ref.read(live2dControllerProvider);
///   ZhuaLive2DWidget(controller: controller.viewController)
///
/// 触摸交互（v1.9）：
///   onSingleTapUp → handleTouch 按位置分区反应
///   onDoubleTap   → playDoubleTap 害羞彩蛋
class ZhuaLive2DWidget extends StatefulWidget {
  final Live2DViewController controller;
  final VoidCallback? onTap;

  const ZhuaLive2DWidget({
    super.key,
    required this.controller,
    this.onTap,
  });

  @override
  State<ZhuaLive2DWidget> createState() => _ZhuaLive2DWidgetState();
}

class _ZhuaLive2DWidgetState extends State<ZhuaLive2DWidget> {
  /// 双击间隔阈值（毫秒）
  static const _doubleTapTimeout = Duration(milliseconds: 300);

  DateTime? _lastTapTime;

  /// 处理单击：按位置分区触发反应
  void _handleSingleTap(TapUpDetails details) {
    final size = context.size ?? const Size(120, 200);
    ZhuaLive2DController.instance.handleTouch(
      details.localPosition,
      size,
    );
    widget.onTap?.call();
  }

  /// 处理双击：害羞彩蛋
  void _handleDoubleTap() {
    ZhuaLive2DController.instance.playDoubleTap();
    widget.onTap?.call();
  }

  /// GestureDetector 单击回调（含双击拦截）
  void _onTapUp(TapUpDetails details) {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapTimeout) {
      // 是双击
      _lastTapTime = null;
      _handleDoubleTap();
    } else {
      // 是单击，延迟触发（等一下看有没有第二次点击）
      _lastTapTime = now;
      Future.delayed(_doubleTapTimeout, () {
        if (_lastTapTime != null &&
            DateTime.now().difference(_lastTapTime!) >= _doubleTapTimeout) {
          _handleSingleTap(details);
          _lastTapTime = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: _onTapUp,
          child: ValueListenableBuilder<Live2DViewState>(
            valueListenable: widget.controller,
            builder: (context, state, _) {
              if (!state.isAttached || state.loadedModel == null) {
                return const _ModelLoadingPlaceholder();
              }
              return const Live2DView(controller: null);
            },
          ),
        );
      },
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
      builder: (_, _) {
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
