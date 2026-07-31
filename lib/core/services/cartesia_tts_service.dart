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
// 依赖：dio（HTTP 客户端）、just_audio（音频播放）、path_provider（临时文件）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class CartesiaTtsService {
  late final Dio _dio;
  final AudioPlayer _player = AudioPlayer();

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
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => true,
    ));

    // 监听播放完成事件
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        onPlayingChanged?.call(false);
      }
    });

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

    // 播放前先停掉之前的
    await _player.stop();

    _isPlaying = true;
    onPlayingChanged?.call(true);

    File? tempFile;
    try {
      final endpoint = emotion != null ? '/tts/emotion' : '/tts';
      final data = emotion != null
          ? {'text': text, 'emotion': emotion}
          : {'text': text, 'lang': 'zh-CN'};

      final resp = await _dio.post<ResponseBody>(
        '$_baseUrl$endpoint',
        data: data,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final bytes = resp.data!.cast<int>().toList();
      print('[CartesiaTts] 收到音频: ${bytes.length} bytes');

      // 写入临时 mp3 文件，用 just_audio 播放
      final tmpDir = await getTemporaryDirectory();
      tempFile = File('${tmpDir.path}/zhuy_tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await tempFile.writeAsBytes(bytes);

      await _player.setFilePath(tempFile.path);
      await _player.play();
    } on DioException catch (e) {
      print('[CartesiaTts] 请求失败: $e');
    } finally {
      // 清理临时文件（稍后异步删）
      if (tempFile != null) {
        tempFile.delete().catchError((_) {});
      }
      _isPlaying = false;
      onPlayingChanged?.call(false);
    }
  }

  // ── 停止播放 ──
  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    onPlayingChanged?.call(false);
  }

  // ── 切换后端地址 ──
  /// 手动指定后端地址（真机测试时用）
  void setBaseUrl(String url) {
    _baseUrl = url;
    _isInitialized = false;
  }

  void dispose() {
    _player.dispose();
  }
}
