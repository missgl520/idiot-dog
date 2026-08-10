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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/backend_service.dart';
import '../../presentation/providers/app_providers.dart';
import '../voice/voice_call_page.dart';

class MenuPanel extends ConsumerStatefulWidget {
  const MenuPanel({super.key});

  @override
  ConsumerState<MenuPanel> createState() => _MenuPanelState();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MenuPanel(),
    );
  }
}

class _MenuPanelState extends ConsumerState<MenuPanel> {
  @override
  Widget build(BuildContext context) {
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
              subtitle: '设置专属唤醒词',
              onTap: () => _showWakeWordEditor(context),
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
      builder: (_) => _Live2DModelPickerDialog(),
    );
  }

  void _showWakeWordEditor(BuildContext context) {
    final controller = TextEditingController(text: BackendConfig.instance.wakeWord);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.record_voice_over, color: AppTheme.bamboo, size: 20),
            SizedBox(width: 8),
            Text('唤醒词'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '说出唤醒词，竹芽就会回应你。',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '唤醒词',
                hintText: '例如：竹芽竹芽',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLength: 20,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => _saveWakeWord(ctx, controller.text, ctx),
            ),
            const SizedBox(height: 4),
            Text(
              '2-20字，中英文均可',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _saveWakeWord(ctx, controller.text, context),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _saveWakeWord(BuildContext dialogContext, String word, BuildContext scaffoldContext) {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;
    // 存本地
    BackendConfig.instance.setWakeWord(trimmed);
    // 同步后端
    BackendService.instance.syncWakeWord(trimmed);
    // 关闭弹窗
    Navigator.pop(dialogContext);
    // 刷新菜单 UI
    setState(() {});
    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
      SnackBar(
        content: Text('唤醒词已保存为：$trimmed'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
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
                context.push('/memory-history');
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Live2D 模型选择器弹窗
//
// 逻辑：
//   Step 1 → 扫描本地 .model3.json 文件（file_picker）
//   Step 2a → 找到模型 → 列出供选择 → 加载
//   Step 2b → 没找到 → 询问是否去官网下载
//             → 是 → 跳转 live2d.com/sample
//             → 否 → 关闭弹窗
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _Live2DModelPickerDialog extends ConsumerStatefulWidget {
  const _Live2DModelPickerDialog();

  @override
  ConsumerState<_Live2DModelPickerDialog> createState() =>
      _Live2DModelPickerDialogState();
}

class _Live2DModelPickerDialogState
    extends ConsumerState<_Live2DModelPickerDialog> {
  /// 扫描到的本地模型列表
  /// 每个元素：模型所在文件夹路径
  List<String> _localModels = [];

  /// 当前选中索引（-1 = 未选）
  int _selectedIndex = -1;

  /// 加载状态
  bool _loading = false;

  /// 错误信息
  String? _error;

  /// Step 1：扫描本地模型文件
  Future<void> _scanLocalModels() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 打开目录选择器（仅限目录）
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择 Live2D 模型文件夹',
      );

      if (result == null) {
        // 用户取消 → 保持当前状态
        setState(() => _loading = false);
        return;
      }

      // 在选定目录中递归查找 .model3.json
      final dir = Directory(result);
      final allEntries = await dir.list(recursive: true, followLinks: false).toList();
      final entries = allEntries
          .whereType<File>()
          .where((e) => e.path.endsWith('.model3.json'))
          .map((e) => e.parent.path)
          .toSet()
          .toList();

      if (!mounted) return;
      setState(() {
        _localModels = entries;
        _selectedIndex = entries.isNotEmpty ? 0 : -1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '扫描失败：$e';
        _loading = false;
      });
    }
  }

  /// Step 2：确认加载选中模型
  Future<void> _loadSelectedModel() async {
    if (_selectedIndex < 0 || _selectedIndex >= _localModels.length) return;

    setState(() => _loading = true);

    final modelPath = _localModels[_selectedIndex];
    final modelFileName = Directory(modelPath)
        .listSync()
        .where((e) => e.path.endsWith('.model3.json'))
        .firstOrNull
        ?.path
        .split('/')
        .last;

    if (modelFileName == null) {
      if (mounted) {
        setState(() {
          _error = '未找到 .model3.json 文件';
          _loading = false;
        });
      }
      return;
    }

    try {
      // 通知 Controller 切换模型
      await ref.read(live2dControllerProvider).loadExternalModel(
            modelPath,
            modelFileName,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('模型已切换：${_getModelName(modelPath)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败：$e';
          _loading = false;
        });
      }
    }
  }

  /// 从路径提取模型名称（文件夹名）
  String _getModelName(String path) {
    // pathSeparator 是 /，在 Android 上也一样
    return path.split('/').last;
  }

  /// 打开 Live2D 官方示例下载页（复制链接给用户手动打开）
  Future<void> _openLive2DWebsite() async {
    const url = 'https://www.live2d.com/en/learn/sample/';
    await Clipboard.setData(const ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('链接已复制，打开浏览器粘贴访问'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.pets, color: AppTheme.bamboo, size: 20),
          SizedBox(width: 8),
          Text('Live2D 模型'),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: _buildContent(),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade300, size: 40),
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Colors.red.shade600, fontSize: 13)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _scanLocalModels,
            child: const Text('重新选择'),
          ),
        ],
      );
    }

    if (_localModels.isEmpty) {
      // Step 2b：没找到模型，显示下载提示
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_off_outlined, color: Colors.grey.shade400, size: 48),
          const SizedBox(height: 12),
          const Text(
            '未在选定目录中找到 Live2D 模型文件',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            '请下载 Live2D 示例模型后，选择包含 .model3.json 的文件夹',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _openLive2DWebsite,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('去 Live2D 官网下载'),
          ),
        ],
      );
    }

    // Step 2a：显示找到的模型列表
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '选择要使用的 Live2D 模型',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),
        ...List.generate(_localModels.length, (i) {
          final name = _getModelName(_localModels[i]);
          final selected = _selectedIndex == i;
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppTheme.bamboo : Colors.grey,
              size: 20,
            ),
            title: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              _localModels[i],
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => setState(() => _selectedIndex = i),
          );
        }),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _scanLocalModels,
          icon: const Icon(Icons.folder_open, size: 16),
          label: const Text('重新选择文件夹'),
        ),
      ],
    );
  }

  List<Widget> _buildActions() {
    if (_loading) return [];

    if (_localModels.isEmpty) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _selectedIndex >= 0 ? _loadSelectedModel : null,
        child: const Text('加载'),
      ),
    ];
  }
}