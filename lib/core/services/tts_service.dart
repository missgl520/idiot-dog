// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TTS 服务（Text-to-Speech / 文字转语音）
//
// 底层依赖：flutter_tts，调用系统语音引擎
// - Android：系统 TTS（MIUI 使用小米离线引擎）
// - iOS：AVSpeechSynthesizer
//
// 配置项：
//   speechRate  语速（0.0-1.0，默认 0.5）
//   pitch       音调（0.5-2.0，默认 1.0）
//   volume      音量（0.0-1.0，默认 1.0）
//   language    语言（zh-CN=中文）
//
// awaitSpeakCompletion=true：
//   speak() 在语音播完前会阻塞，确保 AI 回复完整朗读后再继续
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  bool _isInitialized = false;
  bool _isPlaying = false;

  /// 当前是否正在播放
  bool get isPlaying => _isPlaying;

  // ── 初始化 ──
  Future<void> init() async {
    if (_isInitialized) return;

    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.5);   // 适中语速
    await _tts.setVolume(1.0);       // 全音量
    await _tts.setPitch(1.0);        // 正常音调

    // 阻塞等待播完，避免 AI 回复和语音交叉
    await _tts.awaitSpeakCompletion(true);

    // 回调：记录播放状态（供 UI 显示竹芽"在说"）
    _tts.setStartHandler(()  => _isPlaying = true);
    _tts.setCompletionHandler(() => _isPlaying = false);
    _tts.setErrorHandler((_) => _isPlaying = false);
    _tts.setCancelHandler(()  => _isPlaying = false);

    _isInitialized = true;
  }

  // ── 朗读文本 ──
  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    await _tts.speak(text);
  }

  // ── 停止朗读 ──
  Future<void> stop() async {
    await _tts.stop();
    _isPlaying = false;
  }

  // ── 调节语速 ──
  Future<void> setRate(double rate) async {
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  // ── 调节音调 ──
  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch.clamp(0.5, 2.0));
  }

  void dispose() {
    _tts.stop();
  }
}
