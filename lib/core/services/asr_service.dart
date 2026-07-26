// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ASR 语音识别服务（Automatic Speech Recognition）
//
// 底层依赖：speech_to_text 插件，调用系统语音识别引擎
// - Android：Google 语音识别 / 小米语音
// - iOS：Apple Speech Framework
//
// 工作流程：
//   用户长按语音按钮 → startListening() → 系统录音+识别 → onResult 回调
// → 用户松开 / 自动停 → stopListening()
//
// 注意事项：
// - 需要麦克风权限（permission_handler）
// - 部分设备/语言需要联网才能识别
// - partialResults=true 时，识别过程中会多次回调（中间结果）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class AsrService {
  final SpeechToText _stt = SpeechToText();

  bool _isInitialized = false;
  bool _isListening = false;

  /// 当前是否正在监听（录音中）
  bool get isListening => _isListening;

  /// 系统支持的识别语言列表（用于切换语言）
  List<LocaleName> _availableLocales = [];

  // ── 初始化 ──
  // 必须先调用一次，检查权限并加载语言包
  Future<void> init() async {
    if (_isInitialized) return;
    _availableLocales = await _stt.locales();
    _isInitialized = true;
  }

  // ── 请求麦克风权限 ──
  Future<bool> requestPermission() async {
    return await _stt.initialize(
      onStatus: (status) {
        // status 枚举：listening / notListening / done / ...（部分平台）
        _isListening = status == 'listening';
      },
      onError: (error) {
        _isListening = false;
        // error.errorMsg 可用于展示错误原因
      },
    );
  }

  // ── 开始监听 ──
  // localeId: 语言标识，zh_CN=中文简体，zh_Hans_CN=中文简体（新版 API）
  Future<void> startListening({
    required Function(String) onResult,
    String? localeId,
  }) async {
    if (!_isInitialized) await init();
    if (_isListening) await stopListening();

    _isListening = true;

    final options = SpeechListenOptions(
      localeId: localeId ?? 'zh_CN',
      listenMode: ListenMode.dictation,  // 听写模式，适合口语
      cancelOnError: true,               // 出错自动停止
      partialResults: true,              // 中间结果也回调（打字效果）
    );

    await _stt.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords);
        // finalResult=true 表示一句话说完了
        if (result.finalResult) {
          _isListening = false;
        }
      },
      listenOptions: options,
    );
  }

  // ── 停止监听 ──
  Future<void> stopListening() async {
    await _stt.stop();
    _isListening = false;
  }

  // ── 工具：找中文 localeId ──
  // 兼容旧版（zh_CN）和新版（zh_Hans_CN）格式
  String? get zhLocaleId {
    final zhCN = _availableLocales.where(
      (l) => l.localeId == 'zh_CN' || l.localeId == 'zh_Hans_CN',
    );
    if (zhCN.isNotEmpty) return zhCN.first.localeId;
    final zh = _availableLocales.where((l) => l.localeId.startsWith('zh'));
    return zh.isNotEmpty ? zh.first.localeId : null;
  }

  void dispose() {
    _stt.cancel();  // 取消当前识别，释放资源
  }
}
