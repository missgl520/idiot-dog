// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 设置页（SettingsPage）
//
// 功能分区：
//   AI 配置    → Agnes API Key 输入
//   语音设置   → TTS 开关
//   外观       → 深色/亮色主题切换
//   数据管理   → 清空聊天记录 / 清空 AI 记忆
//   关于       → 版本信息 / 技术栈
//
// 状态管理：
//   所有设置均持久化到 Hive 'settings' 盒子
//   切换主题：ref.read(themeProvider.notifier).toggle()
//   TTS 开关：ref.read(ttsEnabledProvider.notifier).state = v
//   API Key：存入 Hive + 调用 agnes.setApiKey()
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _apiKeyController = TextEditingController();
  final _backendUrlController = TextEditingController();
  bool _obscureKey = true;  // 是否隐藏 API Key

  @override
  void initState() {
    super.initState();
    // 初始化时从 Hive 读取已保存的 API Key 和后端地址
    final box = Hive.box('settings');
    _apiKeyController.text = box.get('agnesApiKey', defaultValue: '') as String;
    _backendUrlController.text = BackendConfig.instance.baseUrl;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _backendUrlController.dispose();
    super.dispose();
  }

  // ── 保存 API Key ──
  void _saveApiKey() {
    final key = _apiKeyController.text.trim();
    Hive.box('settings').put('agnesApiKey', key);

    // 同步更新 AgnesService 实例（当前会话内存中的）
    final agnes = ref.read(agnesServiceProvider);
    if (key.isNotEmpty) agnes.setApiKey(key);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API Key 已保存')),
    );
  }

  // ── 后端地址弹窗 ──
  void _showBackendUrlDialog(BuildContext ctx) {
    _backendUrlController.text = BackendConfig.instance.baseUrl;
    showDialog(
      context: ctx,
      builder: (ctx) => AlertDialog(
        title: const Text('后端地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '填写竹芽后端服务地址',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _backendUrlController,
              decoration: const InputDecoration(
                labelText: '地址',
                hintText: 'http://localhost:8000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            const Text(
              '局域网：电脑 IP + :8000\n例如：http://192.168.1.100:8000',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = _backendUrlController.text.trim();
              BackendConfig.instance.setBaseUrl(url);
              setState(() {}); // 刷新 UI
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('后端地址已保存：$url')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // ── 清空聊天记录 ──
  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空？'),
        content: const Text('此操作不可恢复，所有聊天记录将被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              ref.read(messagesProvider.notifier).clear();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('聊天记录已清空')),
              );
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── 清空 AI 记忆 ──
  void _confirmClearMemory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空记忆？'),
        content: const Text('此操作不可恢复，AI 将忘记所有之前的对话内容。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final mem = ref.read(memoryServiceProvider);
              await mem.clearCategory('chat_memory');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('记忆已清空')),
                );
              }
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final ttsEnabled = ref.watch(ttsEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── AI 配置 ──
          _SectionTitle('AI 配置'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Agnes API Key', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      '国内版/国际版二选一',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 10),
                    // CN/国际版切换
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('🇨🇳 国内版（推荐）'),
                          selected: ref.watch(agnesUseCNProvider),
                          onSelected: (v) {
                            ref.read(agnesUseCNProvider.notifier).state = v;
                            Hive.box('settings').put('agnesUseCN', v);
                            ref.read(agnesServiceProvider).setUseCN(v);
                          },
                          selectedColor: Colors.green[100],
                        ),
                        ChoiceChip(
                          label: const Text('🌐 国际版'),
                          selected: !ref.watch(agnesUseCNProvider),
                          onSelected: (v) {
                            if (v) {
                              ref.read(agnesUseCNProvider.notifier).state = false;
                              Hive.box('settings').put('agnesUseCN', false);
                              ref.read(agnesServiceProvider).setUseCN(false);
                            }
                          },
                          selectedColor: Colors.blue[100],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureKey,  // 密码式显示
                      decoration: InputDecoration(
                        hintText: '输入你的 API Key',
                        suffixIcon: IconButton(
                          icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureKey = !_obscureKey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveApiKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.bamboo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── 后端配置 ──
          _SectionTitle('后端配置'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_outlined, color: Colors.blue),
                title: const Text('后端地址'),
                subtitle: Text(
                  BackendConfig.instance.baseUrl,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showBackendUrlDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── 语音设置 ──
          _SectionTitle('语音设置'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              SwitchListTile(
                title: const Text('TTS 语音播报'),
                subtitle: const Text('AI 回复自动朗读'),
                value: ttsEnabled,
                activeTrackColor: AppTheme.bamboo,
                onChanged: (v) {
                  ref.read(ttsEnabledProvider.notifier).state = v;
                  Hive.box('settings').put('ttsEnabled', v);
                },
              ),
              if (ttsEnabled) ...[
                const Divider(height: 1),
                ListTile(
                  title: const Text('语音音色'),
                  subtitle: const Text(
                    'cartesia = 情感TTS（自然好听）\nsystem = 系统TTS（降级方案）',
                  ),
                  trailing: DropdownButton<String>(
                    value: ref.watch(ttsModeProvider),
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(ttsModeProvider.notifier).state = v;
                        Hive.box('settings').put('ttsMode', v);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'cartesia',
                        child: Text('情感 TTS ✨'),
                      ),
                      DropdownMenuItem(
                        value: 'system',
                        child: Text('系统 TTS'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),

          // ── 外观 ──
          _SectionTitle('外观'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              SwitchListTile(
                title: const Text('深色模式'),
                subtitle: Text(isDark ? '当前：深色' : '当前：亮色'),
                value: isDark,
                activeTrackColor: AppTheme.bamboo,
                onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── 数据管理 ──
          _SectionTitle('数据管理'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('清空聊天记录'),
                subtitle: const Text('删除所有消息'),
                onTap: _confirmClear,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.storage_outlined, color: Colors.orange),
                title: const Text('清空记忆'),
                subtitle: const Text('删除 AI 长期记忆'),
                onTap: _confirmClearMemory,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── 关于 ──
          _SectionTitle('关于'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline, color: AppTheme.bamboo),
                title: Text('竹芽'),
                subtitle: Text('版本 1.0.0'),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.code, color: Colors.grey),
                title: Text('技术栈'),
                subtitle: Text('Flutter + Riverpod + GoRouter'),
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── 分区标题（小号绿色标签）──
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.bamboo,
        letterSpacing: 1,
      ),
    );
  }
}

// ── 设置卡片（白色/深色背景 + 圆角 + 阴影）──
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A4A)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
