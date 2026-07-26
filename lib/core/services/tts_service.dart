// TTS 服务 - 小米离线语音引擎
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  bool _isInitialized = false;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> init() async {
    if (_isInitialized) return;

    await _tts.setLanguage('zh-CN');      // 中文
    await _tts.setSpeechRate(0.5);         // 语速 0.0-1.0
    await _tts.setVolume(1.0);             // 音量
    await _tts.setPitch(1.0);              // 音调

    // 小米 MIUI 会自动使用系统离线语音引擎
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() => _isPlaying = true);
    _tts.setCompletionHandler(() => _isPlaying = false);
    _tts.setErrorHandler((msg) => _isPlaying = false);
    _tts.setCancelHandler(() => _isPlaying = false);

    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isPlaying = false;
  }

  Future<void> setRate(double rate) async {
    // rate: 0.0-1.0
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  Future<void> setPitch(double pitch) async {
    // pitch: 0.5-2.0
    await _tts.setPitch(pitch.clamp(0.5, 2.0));
  }

  void dispose() {
    _tts.stop();
  }
}
