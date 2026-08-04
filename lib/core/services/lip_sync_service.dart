// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Lip Sync 服务（唇形同步）
//
// 原理：
//   订阅 AudioPlayer 的 positionStream，用正弦波模拟说话口型。
//   竹芽 TTS 说话时口型随音频节拍自然开合，停止时口型归零。
//
//   ParamMouthOpenY 范围：0（闭嘴）~ 1（张嘴最大）
//   说话时用正弦波驱动，频率约 3Hz（自然语速的音节节奏）
//
// 用法：
//   LipSyncService().bind(audioPlayer);
//   LipSyncService().start(controller);   // 开始口型动画
//   LipSyncService().stop();              // 停止，归零
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:math' as math;

import 'package:just_audio/just_audio.dart';

/// 唇形同步服务（单例）
class LipSyncService {
  /// 当前口型值（0=闭嘴，1=张嘴最大）
  double _mouthOpen = 0.0;

  /// 口型更新回调（每次口型值变化时调用，参数为当前开度 0~1）
  void Function(double)? onMouthUpdated;

  /// 说话中
  bool _isTalking = false;

  /// 是否正在驱动口型（与竹芽说话状态同步）
  bool _isActive = false;

  /// 驱动定时器
  Timer? _timer;

  /// 正在监听的 AudioPlayer
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  /// 当前相位（正弦波相位）
  double _phase = 0.0;

  /// 正弦频率（Hz），说话时约 3Hz
  static const double _frequency = 3.0;

  /// 最小口型值（闭口）
  static const double _minMouth = 0.0;

  /// 最大口型值（张口）
  static const double _maxMouth = 0.75;

  // ── 公开接口 ──

  /// 当前口型值（供 UI 读取）
  double get mouthOpen => _mouthOpen;

  /// 是否正在说话（供 UI 判断竹芽状态）
  bool get isTalking => _isTalking;

  /// 绑定 AudioPlayer，开始监听播放状态
  /// 说话开始时自动启动口型动画，停止时自动归零
  void bind(AudioPlayer player) {
    // 监听播放状态：自动启动/停止口型
    _stateSub?.cancel();
    _stateSub = player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed ||
          state.processingState == ProcessingState.idle) {
        stop();
      } else if (state.playing) {
        _isTalking = true;
        if (!_isActive) _startTalking();
      }
    });
  }

  /// 手动启动口型（通常由 TTS 的 onPlayingChanged 回调触发）
  void start() {
    _isTalking = true;
    _startTalking();
  }

  /// 手动停止口型（竹芽停止说话时调用）
  void stop() {
    _isActive = false;
    _isTalking = false;
    _timer?.cancel();
    _timer = null;
    _mouthOpen = _minMouth;
  }

  // ── 内部 ──

  void _startTalking() {
    _isActive = true;
    _phase = 0.0;
    _timer?.cancel();
    // 约 60fps 更新口型
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_isActive) return;
      _phase += 2 * math.pi * _frequency / 60.0;
      if (_phase > 2 * math.pi) _phase -= 2 * math.pi;

      // 正弦波驱动，映射到 [min, max]
      // |sin| 确保每个周期有开口有闭口（双唇交替）
      final sinVal = _phase <= 2 * math.pi
          ? math.sin(_phase).abs()
          : math.sin(_phase % (2 * math.pi)).abs();
      _mouthOpen = _minMouth + sinVal * (_maxMouth - _minMouth);
      onMouthUpdated?.call(_mouthOpen);
    });
  }

  void dispose() {
    stop();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _positionSub = null;
    _stateSub = null;
  }
}
