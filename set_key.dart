// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Agnes API Key 写入工具
//
// 用途：
//   - 初始化 Hive 本地存储
//   - 把 Agnes API Key 写入 settings 盒子
//   - 运行后输出写入结果，供调试验证
//
// 运行方式：
//   dart run set_key.dart
//
// 注意：
//   - 本文件不会被 Flutter App 直接打包引用
//   - 实际生产环境建议在设置页由用户手动输入 API Key
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  // 初始化 Hive 本地数据库（Flutter 版本）
  await Hive.initFlutter();
  // 打开 settings 盒子，用于存储用户配置
  await Hive.openBox('settings');
  final box = Hive.box('settings');

  // 把 Agnes API Key 写入本地存储
  await box.put('agnesApiKey', 'sk-CcGTt05Z92jl64ZwrBuyaah2PHansRHuK0KniCV90hz8mwLI');

  // 回显确认写入成功
  print('写入成功: ${box.get("agnesApiKey")}');
}
