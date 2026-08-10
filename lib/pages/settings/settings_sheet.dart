// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 设置 Sheet（底部弹出面板）
//
// 触发：聊天页顶栏 ⚙️ 按钮
// 关闭：下拉 Sheet / 点击遮罩层
//
// 菜单项（从上到下）：
//   1. 拖拽条（装饰横条，居中，灰色）
//   2. 关于竹笌
//   3. 声音设置
//   4. 语音设置
//   5. 模型设置
//
// 展开行为：点击菜单项 → 该项展开为详情面板，其他项收起
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../presentation/providers/app_providers.dart';

// 当前展开项（null = 全部收起）
final settingsExpandedProvider = StateProvider<String?>((ref) => null);

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  // 显示 Sheet 的入口方法（供外部调用）
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(settingsExpandedProvider);
    final isDark = ref.watch(themeProvider);

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
            _dragHandle,

            // ── 菜单项列表 ──
            _MenuItem(
              title: '关于竹笌',
              icon: Icons.info_outline,
              expanded: expanded == 'about',
              onTap: () => _toggle(ref, 'about'),
              children: const _AboutContent(),
            ),

            _MenuDivider(isDark: isDark),

            _MenuItem(
              title: '声音设置',
              icon: Icons.volume_up_outlined,
              expanded: expanded == 'sound',
              onTap: () => _toggle(ref, 'sound'),
              children: const _SoundContent(),
            ),

            _MenuDivider(isDark: isDark),

            _MenuItem(
              title: '语音设置',
              icon: Icons.mic_outlined,
              expanded: expanded == 'voice',
              onTap: () => _toggle(ref, 'voice'),
              children: const _VoiceContent(),
            ),

            _MenuDivider(isDark: isDark),

            _MenuItem(
              title: '模型设置',
              icon: Icons.smart_toy_outlined,
              expanded: expanded == 'model',
              onTap: () => _toggle(ref, 'model'),
              children: const _ModelContent(),
            ),

            // 底部安全距离
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _toggle(WidgetRef ref, String key) {
    final cur = ref.read(settingsExpandedProvider);
    ref.read(settingsExpandedProvider.notifier).state = cur == key ? null : key;
  }
}

// ── 拖拽条 ──
Widget get _dragHandle => Padding(
  padding: const EdgeInsets.only(top: 10, bottom: 6),
  child: Container(
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(2),
    ),
  ),
);

// ── 分隔线 ──
class _MenuDivider extends StatelessWidget {
  final bool isDark;
  const _MenuDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
    );
  }
}

// ── 可展开菜单项 ──
class _MenuItem extends ConsumerWidget {
  final String title;
  final IconData icon;
  final bool expanded;
  final VoidCallback onTap;
  final Widget children;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.bamboo),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 展开内容
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: children,
          crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}

// ── 关于竹笌 内容 ──
class _AboutContent extends StatelessWidget {
  const _AboutContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bamboo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.bamboo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.eco, color: AppTheme.bamboo, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '竹笌',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '版本 1.0.0',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '竹笌是一个情感陪伴 AI，随时倾听你的心声。',
                  style: TextStyle(fontSize: 14, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 声音设置 内容 ──
class _SoundContent extends ConsumerWidget {
  const _SoundContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsEnabled = ref.watch(ttsEnabledProvider);
    final ttsMode = ref.watch(ttsModeProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        children: [
          // TTS 总开关
          _SwitchRow(
            title: '语音播报',
            subtitle: 'AI 回复自动朗读',
            value: ttsEnabled,
            onChanged: (v) {
              ref.read(ttsEnabledProvider.notifier).state = v;
              Hive.box('settings').put('ttsEnabled', v);
            },
          ),
          if (ttsEnabled) ...[
            const SizedBox(height: 12),
            // 音色选择
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('音色', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ModeChip(
                          label: '✨ 情感 TTS',
                          selected: ttsMode == 'cartesia',
                          onTap: () {
                            ref.read(ttsModeProvider.notifier).state = 'cartesia';
                            Hive.box('settings').put('ttsMode', 'cartesia');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ModeChip(
                          label: '🔊 系统 TTS',
                          selected: ttsMode == 'system',
                          onTap: () {
                            ref.read(ttsModeProvider.notifier).state = 'system';
                            Hive.box('settings').put('ttsMode', 'system');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 语音设置 内容 ──
class _VoiceContent extends StatelessWidget {
  const _VoiceContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        children: [
          _InfoRow(icon: Icons.mic, text: '语音识别引擎', value: '系统默认'),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.record_voice_over, text: '唤醒词', value: BackendConfig.instance.wakeWord),
        ],
      ),
    );
  }
}

// ── 模型设置 内容 ──
class _ModelContent extends ConsumerWidget {
  const _ModelContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCN = ref.watch(agnesUseCNProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI 模型来源',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: '🇨🇳 国内版',
                  selected: useCN,
                  onTap: () {
                    ref.read(agnesUseCNProvider.notifier).state = true;
                    Hive.box('settings').put('agnesUseCN', true);
                    ref.read(agnesServiceProvider).setUseCN(true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeChip(
                  label: '🌐 国际版',
                  selected: !useCN,
                  onTap: () {
                    ref.read(agnesUseCNProvider.notifier).state = false;
                    Hive.box('settings').put('agnesUseCN', false);
                    ref.read(agnesServiceProvider).setUseCN(false);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 开关行 ──
class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Switch(
          value: value,
          // ignore: deprecated_member_use
  activeColor: AppTheme.bamboo,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── 信息行 ──
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String value;

  const _InfoRow({required this.icon, required this.text, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}

// ── 选择标签 ──
class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.bamboo.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.bamboo : Colors.transparent,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? AppTheme.bamboo : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
