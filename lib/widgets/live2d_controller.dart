// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ZhuaLive2DController - 竹芽 Live2D 全局控制器
//
// 单例模式：全局唯一，整个 App 共享
//
// 用法：
//   ZhuaLive2DController.instance.init()         // App 启动时
//   ZhuaLive2DController.instance.setStatus(...)  // 对话时更新状态
//   ZhuaLive2DController.instance.handleTouch()   // 单击触摸（Widget 内部调用）
//   ZhuaLive2DController.instance.playTap()       // 摇晃动画
//   ZhuaLive2DController.instance.playDoubleTap() // 双击彩蛋
//   ZhuaLive2DController.instance.dispose()        // App 销毁时
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_live2d/flutter_live2d.dart';

/// 竹芽的 Live2D 动画状态
enum ZhuaLive2DStatus {
  idle,      // 待机
  thinking,  // 等回复
  speaking,  // 竹芽在说话（TTS）
  listening, // 用户在说话（ASR）
}

/// 触摸交互区域
enum TouchZone { head, body }

/// Live2D 全局控制器（单例）
class ZhuaLive2DController {
  static ZhuaLive2DController? _instance;
  static ZhuaLive2DController get instance =>
      _instance ??= ZhuaLive2DController._();

  ZhuaLive2DController._();

  Live2DViewController? _viewController;
  bool _modelLoaded = false;

  /// Flutter 层的 Live2DViewController，供 ZhuaLive2DWidget 使用
  Live2DViewController get viewController {
    _viewController ??= Live2DViewController();
    return _viewController!;
  }

  static const String _modelDir = 'assets/live2d/zhuyabudoll/';
  static const String _modelFile = 'zhuyabudoll.model3.json';

  bool get modelLoaded => _modelLoaded;

  /// 初始化并加载竹芽 Live2D 模型
  Future<void> init() async {
    if (_modelLoaded) return;
    try {
      await viewController.whenAttached;
      final ok = await viewController.loadModel(
        modelDir: _modelDir,
        modelFileName: _modelFile,
      );
      _modelLoaded = ok;
      if (ok) {
        await viewController.startMotion(group: 'idle', priority: 1);
        await viewController.setExpression(0); // f01 默认表情
      }
    } catch (e) {
      debugPrint('[ZhuaLive2D] 加载失败: $e');
      _modelLoaded = false;
    }
  }

  /// 根据竹芽状态播放对应动画和表情
  Future<void> setStatus(ZhuaLive2DStatus status) async {
    if (!_modelLoaded) return;
    try {
      switch (status) {
        case ZhuaLive2DStatus.idle:
          await viewController.setExpression(0);
          await viewController.startMotion(group: 'idle', priority: 1);
          await viewController.setParameter('ParamMouthOpenY', 0.0);
        case ZhuaLive2DStatus.thinking:
          await viewController.setExpression(1); // f02 思考
        case ZhuaLive2DStatus.speaking:
          await viewController.setExpression(2); // f03 说话
          await viewController.startMotion(
            group: 'tap_body',
            index: Random().nextInt(3),
            priority: 2,
          );
        case ZhuaLive2DStatus.listening:
          await viewController.setExpression(3); // f04 专注
      }
    } catch (e) {
      debugPrint('[ZhuaLive2D] 动画失败: $e');
    }
  }

  /// 设置口型开度（唇形同步专用）
  /// value: 0=闭嘴，1=张嘴最大
  Future<void> setMouthOpen(double value) async {
    if (!_modelLoaded) return;
    try {
      await viewController.setParameter('ParamMouthOpenY', value.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('[ZhuaLive2D] 口型设置失败: $e');
    }
  }

  /// 根据情绪标签切换 Live2D 表情
  ///
  /// 情绪 → Live2D 表情索引映射：
  ///   neutral   → 0（默认）
  ///   happy     → 4（开心，f05）
  ///   sad       → 5（难过，f06）
  ///   angry     → 6（生气，f07）
  ///   surprised → 7（惊讶，f08）
  ///   anxious   → 8（焦虑，f09）
  Future<void> setEmotion(String emotion) async {
    if (!_modelLoaded) return;
    final mapping = {
      'happy':     4,
      'sad':       5,
      'angry':     6,
      'surprised': 7,
      'anxious':   8,
    };
    final idx = mapping[emotion] ?? 0;
    try {
      await viewController.setExpression(idx);
    } catch (e) {
      debugPrint('[ZhuaLive2D] 表情切换失败 ($emotion): $e');
    }
  }

  // ━━━ 触摸交互（v1.9 新增） ━━━

  /// 处理用户触摸：按位置分区触发不同反应
  ///
  /// 分区逻辑（基于 Widget 尺寸）：
  ///   上半区（y < height * 0.45） → 随机表情变化
  ///   下半区（y >= height * 0.45）→ 摇晃动画
  Future<void> handleTouch(Offset localPosition, Size widgetSize) async {
    if (!_modelLoaded) return;

    final zone = localPosition.dy < widgetSize.height * 0.45
        ? TouchZone.head
        : TouchZone.body;

    try {
      if (zone == TouchZone.head) {
        // 头/脸区：随机切换表情
        final expressions = [4, 5, 6];
        await viewController.setExpression(
          expressions[Random().nextInt(expressions.length)],
        );
        await viewController.startMotion(group: 'tap_body', index: 0, priority: 3);
      } else {
        // 身体区：播放摇晃动画
        await playTap();
      }
    } catch (e) {
      debugPrint('[ZhuaLive2D] 触摸反应失败: $e');
    }
  }

  /// 双击彩蛋：害羞脸红
  /// 触发后 2 秒自动恢复默认表情
  Future<void> playDoubleTap() async {
    if (!_modelLoaded) return;
    try {
      await viewController.setExpression(7); // f07 害羞
      await viewController.startMotion(group: 'tap_body', index: 1, priority: 4);
      await Future.delayed(const Duration(seconds: 2));
      if (_modelLoaded) await viewController.setExpression(0);
    } catch (e) {
      debugPrint('[ZhuaLive2D] 双击彩蛋失败: $e');
    }
  }

  /// 单击竹芽身体：随机播放 tap_body 动画
  Future<void> playTap() async {
    if (!_modelLoaded) return;
    await viewController.startMotion(
      group: 'tap_body',
      index: Random().nextInt(3),
      priority: 3,
    );
  }

  void dispose() {
    _viewController?.dispose();
    _viewController = null;
    _modelLoaded = false;
    _instance = null;
  }
}
