// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹芽 App - 主入口
// 负责：Hive 初始化 → 全局 ProviderScope → MaterialApp.router
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/app_providers.dart';

void main() async {
  // Flutter 异步初始化必须调用
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive 本地存储（类 IndexedDB，用于持久化）
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('messages');
  await Hive.openBox('memory');

  // 初始化后端配置（必须先于 App 运行，因为它决定 Dio baseUrl）
  await BackendConfig.instance.init();

  // 首次启动：写入穿透后端地址（localtunnel 每次重启会变，需同步更新）
  // 生产环境可改为固定 ngrok/cloudflare tunnel 地址
  if (Hive.box('settings').get('backendUrl') == null) {
    Hive.box('settings').put('backendUrl', 'https://mature-are-blocking-centres.trycloudflare.com');
  }

  // Riverpod 跨组件状态管理，child 能通过 ref.watch/read 获取 providers
  runApp(const ProviderScope(child: ZhuyApp()));
}

/// 根 Widget：
/// - MaterialApp.router：用 go_router 做声明式路由
/// - 根据 themeProvider 切换亮/暗主题
class ZhuyApp extends ConsumerWidget {
  const ZhuyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);      // GoRouter 实例
    final isDarkMode = ref.watch(themeProvider);  // true = 暗色主题

    return MaterialApp.router(
      title: '竹芽',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,    // 亮色主题配色
      darkTheme: AppTheme.dark,  // 暗色主题配色
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,          // 注入路由配置
    );
  }
}
