// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 菜单页面（底部弹出面板）
//
// 触发：聊天页顶栏 Logo 点击
// 关闭：点击遮罩 / 上滑
//
// 职责（对照 Soul of Waifu / 成熟产品）：
//   账户管理 / Live2D 模型选择 / 记忆管理 / 角色设定 / 唤醒词设置
//
// 入口分工（对照 zhuyapp-design-2.0.md）：
//   菜单页 ← Logo（账户、模型、记忆、唤醒词、角色）
//   设置 Sheet ← ⚙️（声音、语音、模型切换、版本信息）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/backend_service.dart';
import '../../providers/app_providers.dart';
import '../voice/voice_call_page.dart';

class MenuPanel extends ConsumerWidget {
  const MenuPanel({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MenuPanel(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final affinity = ref.watch(affinityProvider);
    final currentEmotion = ref.watch(currentEmotionProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 拖拽条 ──
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── 竹芽头像 + 关系状态 ──
            _RelationshipBanner(
              affinity: affinity,
              currentEmotion: currentEmotion?.emotion ?? 'neutral',
            ),

            const Divider(height: 1, indent: 20, endIndent: 20),

            // ── Live2D 模型选择 ──
            _MenuTile(
              icon: Icons.pets,
              title: 'Live2D 模型',
              subtitle: '选择竹芽的虚拟形象',
              onTap: () => _showModelPicker(context),
            ),

            // ── 角色设定（只读展示） ──
            _MenuTile(
              icon: Icons.person_outline,
              title: '角色设定',
              subtitle: '少年感 · 阳光 · 直接',
              trailing: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
              onTap: null,  // 仅展示，不可修改
            ),

            // ── 唤醒词设置 ──
            _MenuTile(
              icon: Icons.record_voice_over,
              title: '唤醒词',
              subtitle: '设置专属唤醒词（待实现）',
              onTap: () => _showWakeWordHint(context),
            ),

            // ── 实时语音通话 ──
            _MenuTile(
              icon: Icons.phone_in_talk,
              title: '语音通话',
              subtitle: '实时语音对话',
              onTap: () {
                Navigator.of(context).pop();
                VoiceCallPage.show(context);
              },
            ),

            // ── 记忆管理 ──
            _MenuTile(
              icon: Icons.psychology_outlined,
              title: '记忆管理',
              subtitle: affinity.totalInteractions > 0
                  ? '累计 ${affinity.totalInteractions} 轮对话'
                  : '暂无对话记忆',
              badge: affinity.level != '陌生人' ? affinity.level : null,
              onTap: () => _showMemoryManager(context, ref),
            ),

            // ── 好感度详情 ──
            _AffinityPanel(affinity: affinity),

            // 底部安全距离
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showModelPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Live2D 模型'),
        content: const Text(
          '模型选择功能待实现。\n目前使用默认竹芽形象。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showWakeWordHint(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('唤醒词'),
        content: const Text(
          '唤醒词功能需要系统级权限。\n目前仅支持 App 内语音输入。\n\n未来版本计划支持：\n· 自定义唤醒词\n· 息屏唤醒\n· App 外唤起',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  void _showMemoryManager(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.psychology, color: AppTheme.bamboo, size: 20),
            const SizedBox(width: 8),
            const Text('记忆管理'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.list, size: 20),
              title: const Text('查看对话记忆'),
              onTap: () async {
                Navigator.pop(context);
                // TODO: 跳转记忆历史页
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('记忆历史页待实现')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize, size: 20),
              title: const Text('查看对话摘要'),
              onTap: () async {
                Navigator.pop(context);
                final summaries = await ref.read(backendServiceProvider).getSummaries();
                if (context.mounted) {
                  _showSummaries(context, summaries);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              title: const Text('清空对话记忆', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                _confirmClearMemory(context, ref);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showSummaries(BuildContext context, List<Map<String, dynamic>> summaries) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('对话摘要'),
        content: SizedBox(
          width: double.maxFinite,
          child: summaries.isEmpty
              ? const Text('暂无摘要，对话够长会自动生成。')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: summaries.length,
                  itemBuilder: (_, i) {
                    final s = summaries[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['created_at']?.toString().substring(0, 10) ?? '',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(s['summary'] ?? '', style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _confirmClearMemory(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认清空记忆？'),
        content: const Text(
          '清空后竹芽会忘记所有对话历史。\n此操作不可恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ref.read(backendServiceProvider).clearMemory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '记忆已清空' : '清空失败')),
                );
              }
            },
            child: const Text('确认清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── 关系状态横幅 ──
class _RelationshipBanner extends StatelessWidget {
  final AffinityData affinity;
  final String currentEmotion;

  const _RelationshipBanner({
    required this.affinity,
    required this.currentEmotion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.bamboo.withValues(alpha: 0.15),
            AppTheme.warmYellow.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // 竹芽头像
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.bamboo.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                _emotionEmoji(currentEmotion),
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '竹芽',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.bamboo.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        affinity.level,
                        style: const TextStyle(fontSize: 12, color: AppTheme.bamboo),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _levelDescription(affinity.level),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          // 连续天数
          if (affinity.streakDays > 0)
            Column(
              children: [
                Text(
                  '🔥 ${affinity.streakDays}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Text('连续', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
        ],
      ),
    );
  }

  String _emotionEmoji(String emotion) {
    return switch (emotion) {
      'happy' => '😊',
      'sad' => '😢',
      'angry' => '😠',
      'surprised' => '😲',
      'anxious' => '😰',
      _ => '🌱',
    };
  }

  String _levelDescription(String level) {
    return switch (level) {
      '灵魂伴侣' => '彼此理解，心有灵犀',
      '知己' => '懂你心思，默契十足',
      '好友' => '相处融洽，互相关心',
      '朋友' => '开始熟悉，愿意倾听',
      '认识' => '初次相识，还在了解',
      _ => '我们刚认识，可以随便聊聊',
    };
  }
}

// ── 好感度详情面板 ──
class _AffinityPanel extends StatelessWidget {
  final AffinityData affinity;

  const _AffinityPanel({required this.affinity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '关系状态',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          _AffinityBar(label: '信任', value: affinity.trust, max: 100),
          const SizedBox(height: 6),
          _AffinityBar(label: '亲密', value: affinity.intimacy, max: 100),
          const SizedBox(height: 6),
          _AffinityBar(label: '熟悉', value: affinity.familiarity, max: 100),
        ],
      ),
    );
  }
}

class _AffinityBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;

  const _AffinityBar({required this.label, required this.value, required this.max});

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.bamboo,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '${value.toInt()}/$max',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

// ── 通用菜单项 ──
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final String? badge;
  final void Function()? onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppTheme.bamboo),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: onTap == null ? Colors.grey : null,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.warmYellow.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(fontSize: 11, color: Colors.orange),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}