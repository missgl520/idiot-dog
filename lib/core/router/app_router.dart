// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 路由配置（GoRouter）
//
// 声明式路由：路径 → 页面
// 使用 Provider 包装 GoRouter 实例，方便在 ProviderScope 外注入
//
// 路由列表：
//   /          → 首页（HomePage）
//   /chat      → 对话页（ChatPage），带淡入+上滑过渡动画
//   /settings  → 设置页（SettingsPage）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../pages/home/home_page.dart';
import '../../pages/chat/chat_page.dart';
import '../../pages/settings/settings_page.dart';

/// GoRouter 实例 Provider
/// 注入到 MaterialApp.router 的 routerConfig
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // 首页
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),

      // 对话页：自定义过渡动画（淡入 + 微微上滑）
      GoRoute(
        path: '/chat',
        name: 'chat',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ChatPage(),
          // 过渡动画：FadeTransition + SlideTransition 叠加
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  // 从下方 10% 位置滑入
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                )),
                child: child,
              ),
            );
          },
        ),
      ),

      // 设置页
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
