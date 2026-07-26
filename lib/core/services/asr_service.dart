// ASR 语音识别服务
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class AsrService {
  final SpeechToText _stt = SpeechToText();

  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;

  // 可用语言列表
  List<LocaleName> _availableLocales = [];

  Future<void> init() async {
    if (_isInitialized) return;
    _availableLocales = await _stt.locales();
    _isInitialized = true;
  }

  // 检查并请求麦克风权限
  Future<bool> requestPermission() async {
    return await _stt.initialize(
      onStatus: (status) {
        _isListening = status == 'listening';
      },
      onError: (error) {
        _isListening = false;
      },
    );
  }

  // 开始监听
  Future<void> startListening({
    required Function(String) onResult,
    String? localeId, // 例如 'zh_CN'
  }) async {
    if (!_isInitialized) await init();
    if (_isListening) await stopListening();

    _isListening = true;
    await _stt.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords);
        if (result.finalResult) {
          _isListening = false;
        }
      },
      localeId: localeId ?? 'zh_CN',
      listenMode: ListenMode.dictation,
      cancelOnError: true,
      partialResults: true,
    );
  }

  // 停止监听
  Future<void> stopListening() async {
    await _stt.stop();
    _isListening = false;
  }

  // 获取中文 localeId
  String? get zhLocaleId {
    // 优先找 zh_CN
    final zhCN = _availableLocales.where(
      (l) => l.localeId == 'zh_CN' || l.localeId == 'zh_Hans_CN',
    );
    if (zhCN.isNotEmpty) return zhCN.first.localeId;
    // 再找 zh
    final zh = _availableLocales.where((l) => l.localeId.startsWith('zh'));
    return zh.isNotEmpty ? zh.first.localeId : null;
  }

  void dispose() {
    _stt.cancel();
  }
}
