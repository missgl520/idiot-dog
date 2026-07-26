// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 首页（HomePage）
//
// 入口页，展示 App Logo + 品牌文字 + 两个快捷入口
// 风格：纸感 + 竹绿，安静克制
//
// 布局（从上到下）：
//   Spacer() → Logo + 品牌 → Spacer() → 快捷入口 → 底部留白
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // ── 快捷入口卡片 ──
  // 白色卡片 + 左侧色块图标 + 标题/副标题 + 右侧箭头
  // onTap: 点击后路由跳转
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Logo：圆角卡片 + 阴影
              // 优先加载 assets/logo.png；加载失败时用竹子图标兜底
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.bamboo.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, _) => Container(
                      color: const Color(0xFFE8F5E9),
                      child: const Icon(Icons.eco, size: 60, color: AppTheme.bamboo),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 品牌文字："竹  芽"（字间宽字间距）
              const Text(
                '竹  芽',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.bamboo,
                  letterSpacing: 12,  // 宽字间距，书卷气
                ),
              ),
              const SizedBox(height: 8),

              // Slogan
              Text(
                '情感陪伴 · 随时倾听',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  letterSpacing: 3,
                ),
              ),

              const Spacer(),

              // 快捷入口：开始聊天
              _QuickCard(
                icon: Icons.chat_bubble_outline,
                title: '开始聊天',
                subtitle: '和竹芽说说话',
                onTap: () => context.go('/chat'),  // go = 替换当前页（无返回）
              ),
              const SizedBox(height: 16),

              // 快捷入口：设置
              _QuickCard(
                icon: Icons.settings_outlined,
                title: '设置',
                subtitle: '配置你的竹芽',
                onTap: () => context.push('/settings'),  // push = 压栈（有返回箭头）
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 快捷入口卡片组件
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      // InkWell：点击涟漪效果
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 左侧图标色块
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.bamboo),
              ),
              const SizedBox(width: 16),

              // 标题 + 副标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),

              // 右侧箭头
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
