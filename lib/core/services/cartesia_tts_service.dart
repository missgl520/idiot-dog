// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Cartesia TTS 服务（竹芽升级版）
//
// 调用竹芽后端 /tts 端点，由 FastAPI → Cartesia Sonic 3.5 生成音频。
// 相比系统 TTS（flutter_tts）：
//   ✅ 音色自然、有情感
//   ✅ 支持 13 种情感控制
//   ✅ 跨平台一致（Android/iOS/Web）
//
// 使用方式：
//   final tts = CartesiaTtsService();
//   await tts.init();
//   await tts.speak('你好，今天怎么样？');
//   await tts.speakEmotion('太好了！', 'happy');
//   await tts.stop();
//
// 依赖：dio（HTTP 客户端）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'dart:typed_data';
import 'package:dio/dio.dart';

class CartesiaTtsService {
  late final Dio _dio;

  /// 竹芽后端地址
  /// - Android 模拟器：10.0.2.2:8000
  /// - Android 真机（局域网）：电脑局域网IP:8000
  /// - iOS 模拟器：localhost:8000
  String _baseUrl = 'http://missgl.cc.cd:8000';

  bool _isInitialized = false;
  bool _isPlaying = false;

  /// 当前是否正在播放
  bool get isPlaying => _isPlaying;

  /// 播放状态回调（供 UI 更新竹芽状态）
  void Function(bool)? onPlayingChanged;

  // ── 初始化 ──
  Future<void> init({String? baseUrl}) async {
    if (_isInitialized && baseUrl == null) return;

    if (baseUrl != null) {
      _baseUrl = baseUrl;
    }

    _dio = Dio(BaseOptions(
      // 连接超时 10s，接收超时 30s（TTS 音频稍大）
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      // 允许 HTTP（开发环境）
      // 生产环境建议切换到 HTTPS
      validateStatus: (status) => true,
    ));

    _isInitialized = true;

    // 验证后端连通性
    try {
      final resp = await _dio.get('$_baseUrl/health');
      print('[CartesiaTts] 后端连通: ${resp.data}');
    } on DioException catch (e) {
      print('[CartesiaTts] 后端连通失败: $e');
      print('[CartesiaTts] 请确认后端已启动且地址正确: $_baseUrl');
    }
  }

  // ── 基础 TTS ──
  /// 把文字转成语音并播放
  Future<void> speak(String text) async {
    await _speak(text, emotion: null);
  }

  /// 带情感朗读
  /// emotion 可选：neutral / happy / sad / calm / angry / excited / curious 等
  Future<void> speakEmotion(String text, String emotion) async {
    await _speak(text, emotion: emotion);
  }

  Future<void> _speak(String text, {String? emotion}) async {
    if (!_isInitialized) await init();

    _isPlaying = true;
    onPlayingChanged?.call(true);

    try {
      // 调用竹芽后端 /tts 或 /tts/emotion
      final endpoint = emotion != null ? '/tts/emotion' : '/tts';
      final data = emotion != null
          ? {'text': text, 'emotion': emotion}
          : {'text': text, 'lang': 'zh-CN'};

      final resp = await _dio.post<ResponseBody>(
        '$_baseUrl$endpoint',
        data: data,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Content-Type': 'application/json',
            // 后端兼容：如果有 Content-Length 相关问题可加
          },
        ),
      );

      final bytes = Uint8List.fromList(resp.data!.cast<int>());
      print('[CartesiaTts] 收到音频: ${bytes.length} bytes');

      // 播放音频
      await _playAudioBytes(bytes);
    } on DioException catch (e) {
      print('[CartesiaTts] 请求失败: $e');
      // 网络失败静默降级，不打断用户体验
    } finally {
      _isPlaying = false;
      onPlayingChanged?.call(false);
    }
  }

  // ── 播放音频字节 ──
  Future<void> _playAudioBytes(Uint8List bytes) async {
    // TODO: 接入 audioPlayers 或 just_audio 包播放 MP3
    // 临时：直接打印，大小正常即说明通了
    print('[CartesiaTts] 播放音频，大小: ${bytes.length} bytes');
  }

  // ── 停止播放 ──
  Future<void> stop() async {
    _isPlaying = false;
    onPlayingChanged?.call(false);
  }

  // ── 切换后端地址 ──
  /// 手动指定后端地址（真机测试时用）
  void setBaseUrl(String url) {
    _baseUrl = url;
    _isInitialized = false; // 触发重连
  }

  void dispose() {
    stop();
  }
}
