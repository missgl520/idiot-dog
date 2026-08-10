// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹笌记忆服务 v3.0（前后端联调版）
//
// 架构：
// - 本地 SQLite  → 快速存储，支持离线，BM25 搜索
// - 后端 SinoMem → AI 端到端长期记忆，buildContext 数据源
//
// 后端接口：
//   POST /memory        存储记忆
//   GET  /memory/search 搜索记忆
//   DEL  /memory        清空分类
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../presentation/providers/app_providers.dart';

// ━━━━━━━━━━━━━━━ 后端接口（HTTP） ━━━━━━━━━━━━━━━

/// 调后端 SinoMem 搜索，返回格式化上下文字符串
///
/// [query]  用户当前消息，用于匹配相关记忆
/// [limit]  返回条数，默认 5 条
///
/// 后端格式：GET /memory/search?q=...&mode=keyword&limit=5
/// 返回 {"results": [...], "count": N}
Future<String> _fetchMemoryContextFromBackend(
  String query, {
  int limit = 5,
}) async {
  final baseUrl = BackendConfig.instance.baseUrl;
  final uri = Uri.parse('$baseUrl/memory/search').replace(
    queryParameters: {
      'q': query,
      'mode': 'keyword',
      'limit': limit.toString(),
    },
  );

  try {
    final resp = await http.get(uri).timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) return '';

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    if (results.isEmpty) return '';

    final buf = StringBuffer('\n\n[相关记忆]\n');
    for (final r in results) {
      final m = r as Map<String, dynamic>;
      final content = m['content'] as String? ?? '';
      final category = m['category'] as String? ?? 'general';
      buf.writeln('【$category】$content');
    }
    buf.writeln('[/相关记忆]');
    return buf.toString();
  } catch (_) {
    return '';
  }
}

// ━━━━━━━━━━━━━━━ 单条记忆数据结构 ━━━━━━━━━━━━━━━

class MemoryItem {
  final int id;
  final String content;
  final String category;
  final List<String> tags;
  final double importance;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? ttl;
  final double? score;

  MemoryItem({
    required this.id,
    required this.content,
    required this.category,
    this.tags = const [],
    this.importance = 0.5,
    required this.createdAt,
    this.updatedAt,
    this.ttl,
    this.score,
  });
}

// ━━━━━━━━━━━━━━━ 记忆服务（本地 SQLite） ━━━━━━━━━━━━━━━

/// 记忆服务
///
/// SQLite Schema：
/// - memories      主表（id, content, category, tags, importance, created_at）
/// - memories_fts  FTS5 虚拟表（中文全文搜索，BM25 评分）
///
/// 搜索策略：BM25 关键词匹配 + 时间衰减
class MemoryService {
  static const _dbName = 'zhuyu_memory.db';
  static const _dbVersion = 1;

  Database? _db;
  bool _isInitialized = false;

  static final MemoryService _instance = MemoryService._internal();
  factory MemoryService() => _instance;

  MemoryService._internal();

  // ━━━ 初始化 ━━━

  Future<void> init() async {
    if (_isInitialized && _db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _db = await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
    _isInitialized = true;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS memories (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        content     TEXT    NOT NULL,
        category    TEXT    NOT NULL DEFAULT 'general',
        tags        TEXT    NOT NULL DEFAULT '[]',
        importance  REAL    NOT NULL DEFAULT 0.5,
        created_at  TEXT    NOT NULL,
        updated_at  TEXT,
        ttl         TEXT
      )
    ''');

    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(
        content,
        category,
        content='memories',
        content_rowid='id'
      )
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS memories_ai AFTER INSERT ON memories BEGIN
        INSERT INTO memories_fts(rowid, content, category)
        VALUES (new.id, new.content, new.category);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS memories_ad AFTER DELETE ON memories BEGIN
        INSERT INTO memories_fts(memories_fts, rowid, content, category)
        VALUES ('delete', old.id, old.content, old.category);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS memories_au AFTER UPDATE ON memories BEGIN
        INSERT INTO memories_fts(memories_fts, rowid, content, category)
        VALUES ('delete', old.id, old.content, old.category);
        INSERT INTO memories_fts(rowid, content, category)
        VALUES (new.id, new.content, new.category);
      END
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memories_category ON memories(category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memories_created ON memories(created_at)',
    );
  }

  // ━━━ 基础 CRUD ━━━

  Future<int> store(
    String content, {
    String category = 'general',
    List<String>? tags,
    double importance = 0.5,
    String? ttl,
  }) async {
    if (!_isInitialized) await init();
    final now = DateTime.now().toIso8601String();
    return await _db!.insert('memories', {
      'content': content,
      'category': category,
      'tags': (tags ?? []).toString(),
      'importance': importance,
      'created_at': now,
      'ttl': ttl,
    });
  }

  Future<List<int>> storeBatch(List<Map<String, dynamic>> items) async {
    if (!_isInitialized) await init();
    final ids = <int>[];
    await _db!.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      for (final item in items) {
        final id = await txn.insert('memories', {
          'content': item['content'] as String,
          'category': item['category'] as String? ?? 'general',
          'tags': (item['tags'] as List<String>? ?? []).toString(),
          'importance': item['importance'] as double? ?? 0.5,
          'created_at': now,
          'ttl': item['ttl'],
        });
        ids.add(id);
      }
    });
    return ids;
  }

  Future<MemoryItem?> get(int id) async {
    if (!_isInitialized) await init();
    final rows = await _db!.query('memories', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _rowToMemory(rows.first);
  }

  Future<void> update(int id, {String? content, String? category}) async {
    if (!_isInitialized) await init();
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (content != null) updates['content'] = content;
    if (category != null) updates['category'] = category;
    await _db!.update('memories', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    if (!_isInitialized) await init();
    await _db!.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearCategory(String category) async {
    if (!_isInitialized) await init();
    await _db!.delete('memories', where: 'category = ?', whereArgs: [category]);
  }

  // ━━━ 搜索（本地 BM25） ━━━

  String _ftsQuery(String query) {
    final words = query.trim().split(RegExp(r'\s+'));
    final terms = <String>[];
    for (final w in words) {
      terms.add('$w*');
      for (int i = 0; i < w.length; i++) {
        terms.add('${w[i]}*');
      }
    }
    return terms.join(' ');
  }

  Future<List<MemoryItem>> keywordSearch(String query, {int limit = 10}) async {
    if (!_isInitialized) await init();
    if (query.trim().isEmpty) return [];

    final rows = await _db!.rawQuery('''
      SELECT memories.*, -bm25(memories_fts) AS score
      FROM memories
      JOIN memories_fts ON memories.id = memories_fts.rowid
      WHERE memories_fts MATCH ?
      ORDER BY score DESC
      LIMIT ?
    ''', [_ftsQuery(query), limit]);

    return rows.map(_rowToMemory).toList();
  }

  Future<List<MemoryItem>> search(String query, {int limit = 10}) async {
    if (!_isInitialized) await init();
    if (query.trim().isEmpty) return [];

    final now = DateTime.now();
    final rows = await _db!.rawQuery('''
      SELECT memories.*,
             (-bm25(memories_fts)) * 0.7 +
             (1 - MIN(1.0, julianday(?) - julianday(created_at))) * 0.3 AS score
      FROM memories
      JOIN memories_fts ON memories.id = memories_fts.rowid
      WHERE memories_fts MATCH ?
      ORDER BY score DESC
      LIMIT ?
    ''', [now.toIso8601String(), _ftsQuery(query), limit]);

    return rows.map(_rowToMemory).toList();
  }

  Future<List<MemoryItem>> searchByCategory(
    String query,
    String category, {
    int limit = 10,
  }) async {
    if (!_isInitialized) await init();
    if (query.trim().isEmpty) return [];

    final now = DateTime.now();
    final rows = await _db!.rawQuery('''
      SELECT memories.*,
             (-bm25(memories_fts)) * 0.7 +
             (1 - MIN(1.0, julianday(?) - julianday(created_at))) * 0.3 AS score
      FROM memories
      JOIN memories_fts ON memories.id = memories_fts.rowid
      WHERE memories_fts MATCH ? AND memories.category = ?
      ORDER BY score DESC
      LIMIT ?
    ''', [now.toIso8601String(), _ftsQuery(query), category, limit]);

    return rows.map(_rowToMemory).toList();
  }

  Future<List<MemoryItem>> getRecent({int limit = 20, String? category}) async {
    if (!_isInitialized) await init();

    final where = category != null
        ? 'category = ? ORDER BY created_at DESC LIMIT ?'
        : 'ORDER BY created_at DESC LIMIT ?';

    final args = category != null
        ? [category, limit]
        : [limit];

    final rows = await _db!.rawQuery(
      'SELECT * FROM memories $where',
      args,
    );
    return rows.map(_rowToMemory).toList();
  }

  // ━━━ 上下文构建（调后端 SinoMem） ━━━

  /// 构建 AI 系统提示用的记忆上下文
  ///
  /// 数据源：后端 SinoMem（AI 端到端长期记忆）
  /// 兜底：本地 SQLite 搜索（后端不通时）
  Future<String> buildContext(String query, {int limit = 5}) async {
    // 优先调后端 SinoMem
    final backendCtx = await _fetchMemoryContextFromBackend(query, limit: limit);
    if (backendCtx.isNotEmpty) return backendCtx;

    // 兜底：本地 SQLite
    final locals = await search(query, limit: limit);
    if (locals.isEmpty) return '';

    final buf = StringBuffer('\n\n[相关记忆]\n');
    for (final m in locals) {
      buf.writeln('【${m.category}】${m.content}');
    }
    buf.writeln('[/相关记忆]');
    return buf.toString();
  }

  // ━━━ 内部 ━━━

  MemoryItem _rowToMemory(Map<String, dynamic> row) {
    final tagsStr = row['tags'] as String? ?? '[]';
    List<String> tags;
    try {
      tags = tagsStr.startsWith('[')
          ? tagsStr
              .substring(1, tagsStr.length - 1)
              .split(',')
              .map((s) => s.trim().replaceAll(RegExp(r"^'|'$"), ''))
              .where((s) => s.isNotEmpty)
              .toList()
          : <String>[];
    } catch (_) {
      tags = [];
    }

    return MemoryItem(
      id: row['id'] as int,
      content: row['content'] as String,
      category: row['category'] as String,
      tags: tags,
      importance: (row['importance'] as num?)?.toDouble() ?? 0.5,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
      ttl: row['ttl'] as String?,
      score: (row['score'] as num?)?.toDouble(),
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _isInitialized = false;
  }
}
