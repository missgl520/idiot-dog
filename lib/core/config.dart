// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹芽配置（单例，无依赖，可被任何层 import）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:hive_flutter/hive_flutter.dart';

/// 后端地址配置单例
///
/// 用法：
///   BackendConfig.instance.baseUrl  // 读取
///   BackendConfig.instance.setBaseUrl('http://...')  // 写入
///
/// 所有服务统一从这里读后端地址，避免硬编码
class BackendConfig {
  BackendConfig._();
  static final BackendConfig _instance = BackendConfig._();
  static BackendConfig get instance => _instance;

  /// 读取当前后端地址（默认 http://localhost:8000）
  String get baseUrl =>
      Hive.box('settings').get('backendUrl', defaultValue: 'http://localhost:8000') as String;

  /// 写入后端地址
  void setBaseUrl(String url) {
    Hive.box('settings').put('backendUrl', url);
  }

  /// 读取唤醒词（默认"竹芽竹芽"）
  String get wakeWord =>
      Hive.box('settings').get('wakeWord', defaultValue: '竹芽竹芽') as String;

  /// 写入唤醒词
  void setWakeWord(String word) {
    Hive.box('settings').put('wakeWord', word);
  }
}
