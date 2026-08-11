// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 法律文档页（LegalPage）
//
// 从后端 /legal/{type} 拉取隐私政策 / 用户协议并展示。
// 该接口为公开路径（免签名），便于未登录用户查看。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart';

class LegalPage extends StatefulWidget {
  final String type; // 'privacy' | 'terms'

  const LegalPage({super.key, required this.type});

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  String _text = '';
  bool _loading = true;

  String get _title => widget.type == 'terms' ? '用户协议' : '隐私政策';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final base = BackendConfig.instance.baseUrl;
      final resp = await http.get(Uri.parse('$base/legal/${widget.type}'));
      if (mounted) {
        setState(() {
          _text = resp.statusCode == 200 ? resp.body : '加载失败（${resp.statusCode}）';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _text = '加载失败：$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
    );
  }
}
