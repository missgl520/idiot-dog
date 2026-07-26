import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  await Hive.initFlutter();
  await Hive.openBox('settings');
  final box = Hive.box('settings');
  await box.put('agnesApiKey', 'sk-CcGTt05Z92jl64ZwrBuyaah2PHansRHuK0KniCV90hz8mwLI');
  print('写入成功: ${box.get("agnesApiKey")}');
}
