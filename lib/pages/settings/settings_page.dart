// 设置页
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _apiKeyController = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final box = Hive.box('settings');
    _apiKeyController.text = box.get('agnesApiKey', defaultValue: '') as String;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _saveApiKey() {
    final key = _apiKeyController.text.trim();
    Hive.box('settings').put('agnesApiKey', key);

    // 更新 AgnesService
    final agnes = ref.read(agnesServiceProvider);
    if (key.isNotEmpty) agnes.setApiKey(key);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API Key 已保存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final ttsEnabled = ref.watch(ttsEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- AI 配置 ---
          _SectionTitle('AI 配置'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              // Agnes API Key
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Agnes API Key',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '从 apihub.agnes-ai.com 获取',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureKey,
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
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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

          // --- 语音设置 ---
          _SectionTitle('语音设置'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              SwitchListTile(
                title: const Text('TTS 语音播报'),
                subtitle: const Text('AI 回复自动朗读'),
                value: ttsEnabled,
                activeColor: const Color(0xFF4CAF50),
                onChanged: (v) {
                  ref.read(ttsEnabledProvider.notifier).state = v;
                  Hive.box('settings').put('ttsEnabled', v);
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- 外观 ---
          _SectionTitle('外观'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              SwitchListTile(
                title: const Text('深色模式'),
                subtitle: Text(isDark ? '当前：深色' : '当前：亮色'),
                value: isDark,
                activeColor: const Color(0xFF4CAF50),
                onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- 数据管理 ---
          _SectionTitle('数据管理'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('清空聊天记录'),
                subtitle: const Text('删除所有消息'),
                onTap: () => _confirmClear(),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.storage_outlined, color: Colors.orange),
                title: const Text('清空记忆'),
                subtitle: const Text('删除 AI 长期记忆'),
                onTap: () => _confirmClearMemory(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- 关于 ---
          _SectionTitle('关于'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline, color: Color(0xFF4CAF50)),
                title: Text('竹芽'),
                subtitle: Text('版本 1.0.0'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.code, color: Colors.grey),
                title: const Text('技术栈'),
                subtitle: const Text('Flutter + Riverpod + GoRouter'),
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空？'),
        content: const Text('此操作不可恢复，所有聊天记录将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
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

  void _confirmClearMemory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空记忆？'),
        content: const Text('此操作不可恢复，AI 将忘记所有之前的对话内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
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
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4CAF50),
          letterSpacing: 1,
        ),
      ),
    );
  }
}

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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
