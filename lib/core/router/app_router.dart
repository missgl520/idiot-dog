// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 路由配置（GoRouter）
//
// 声明式路由：路径 → 页面
//
// 路由列表（对齐 zhuyapp-design-2.0.md）：
//   /        → 启动页（SplashPage，2.5s 后自动跳转 /chat）
//   /chat    → 对话页（ChatPage），带淡入+上滑过渡动画
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../pages/splash/splash_page.dart';
import '../../pages/chat/chat_page.dart';
import '../../pages/voice/voice_call_page.dart';

/// GoRouter 实例 Provider
/// main.dart 用 ref.watch(routerProvider) 注入到 MaterialApp.router
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // 启动页：/ → SplashPage → 2.5s 后 context.go('/chat')
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),

      // 对话页：自定义过渡动画（淡入 + 微微上滑）
      GoRoute(
        path: '/chat',
        name: 'chat',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ChatPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
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
      // 实时语音通话页（全屏覆盖）
      GoRoute(
        path: '/voice-call',
        name: 'voice-call',
        builder: (context, state) => const VoiceCallPage(),
      ),
    ],
  );
});
