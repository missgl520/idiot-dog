// 长期记忆服务 v2.0
// SQLite + FTS5 实现，中文分词，关键词+向量混合搜索
// 参考 SinoMem 架构：https://gitee.com/P1M0U/SinoMem
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 单条记忆的数据结构
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

/// 记忆服务
/// 
/// SQLite Schema：
/// - memories      主表（id, content, category, tags, importance, created_at, updated_at, ttl）
/// - memories_fts  FTS5 虚拟表（中文全文搜索）
/// 
/// 搜索策略：关键词匹配（FTS5 BM25）+ 时间衰减
/// 后续可扩展：接入 ONNX 向量嵌入实现语义搜索
class MemoryService {
  static const _dbName = 'zhuyu_memory.db';
  static const _dbVersion = 1;
  
  Database? _db;
  bool _isInitialized = false;

  /// 单例
  static final MemoryService _instance = MemoryService._internal();
  factory MemoryService() => _instance;
  MemoryService._internal();

  /// 初始化数据库
  Future<void> init() async {
    if (_isInitialized && _db != null) return;
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    
    _isInitialized = true;
  }

  /// 建表
  Future<void> _onCreate(Database db, int version) async {
    // 主表
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

    // FTS5 虚拟表（中文全文搜索）
    // 注意：默认 tokenize（Unicode tokenizer）对中文已有基本支持
    // 如需更精准的中文分词，可接入 jieba FTS5 扩展（需编译 native so）
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(
        content,
        category,
        content='memories',
        content_rowid='id'
      )
    ''');

    // 触发器：插入时同步 FTS
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS memories_ai AFTER INSERT ON memories BEGIN
        INSERT INTO memories_fts(rowid, content, category)
        VALUES (new.id, new.content, new.category);
      END
    ''');

    // 触发器：删除时同步 FTS
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS memories_ad AFTER DELETE ON memories BEGIN
        INSERT INTO memories_fts(memories_fts, rowid, content, category)
        VALUES ('delete', old.id, old.content, old.category);
      END
    ''');

    // 触发器：更新时同步 FTS
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS memories_au AFTER UPDATE ON memories BEGIN
        INSERT INTO memories_fts(memories_fts, rowid, content, category)
        VALUES ('delete', old.id, old.content, old.category);
        INSERT INTO memories_fts(rowid, content, category)
        VALUES (new.id, new.content, new.category);
      END
    ''');

    // 创建索引
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memories_category ON memories(category)'
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memories_created ON memories(created_at)'
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 后续版本升级逻辑
  }

  // ──────────────────────────────────────────────
  // 基础 CRUD
  // ──────────────────────────────────────────────

  /// 存储一条记忆
  /// 
  /// [content]  记忆内容
  /// [category] 分类（user_pref / project / general / agent_memory 等）
  /// [tags]     标签列表
  /// [importance] 重要性 0.0~1.0
  /// [ttl]      过期时间，如 '30d' / '24h' / '7d12h'，null=永不过期
  Future<int> store(
    String content, {
    String category = 'general',
    List<String>? tags,
    double importance = 0.5,
    String? ttl,
  }) async {
    if (!_isInitialized) await init();

    final now = DateTime.now().toIso8601String();
    final id = await _db!.insert('memories', {
      'content': content,
      'category': category,
      'tags': (tags ?? []).toString(),
      'importance': importance,
      'created_at': now,
      'ttl': ttl,
    });
    return id;
  }

  /// 批量存储
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

  /// 获取一条记忆
  Future<MemoryItem?> get(int id) async {
    if (!_isInitialized) await init();
    final rows = await _db!.query(
      'memories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToMemory(rows.first);
  }

  /// 更新记忆内容
  Future<void> update(int id, {String? content, String? category}) async {
    if (!_isInitialized) await init();
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (content != null) updates['content'] = content;
    if (category != null) updates['category'] = category;
    await _db!.update('memories', updates, where: 'id = ?', whereArgs: [id]);
  }

  /// 删除记忆
  Future<void> delete(int id) async {
    if (!_isInitialized) await init();
    await _db!.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

  /// 清空某分类的记忆
  Future<void> clearCategory(String category) async {
    if (!_isInitialized) await init();
    await _db!.delete('memories', where: 'category = ?', whereArgs: [category]);
  }

  // ──────────────────────────────────────────────
  // 搜索
  // ──────────────────────────────────────────────

  /// 关键词搜索（FTS5 BM25）
  /// 
  /// BM25 是搜索引擎用的评分算法，比简单包含匹配更准确
  /// score 越高越相关（BM25 负数取反后）
  Future<List<MemoryItem>> keywordSearch(String query, {int limit = 10}) async {
    if (!_isInitialized) await init();
    if (query.trim().isEmpty) return [];

    // BM25 评分查询
    // bm25(表名) 返回负值，越负越不相关
    // 这里把 score 变成正值（-bm25）来排序，越高越相关
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

  /// 构造 FTS5 查询字符串
  /// 把输入的多个词转成 "word1* word2*" 格式（前缀匹配）
  /// 补充中文单字匹配：每个字单独作为词项，提升中文召回率
  String _ftsQuery(String query) {
    final words = query.trim().split(RegExp(r'\s+'));
    final terms = <String>[];
    for (final w in words) {
      terms.add('$w*');   // 英文/词组前缀匹配
      // 逐字匹配（中文字级别兜底）
      for (int i = 0; i < w.length; i++) {
        terms.add('${w[i]}*');
      }
    }
    return terms.join(' ');
  }

  /// 混合搜索（BM25 + 时间权重）
  /// 
  /// 评分 = bm25_score * 0.7 + time_score * 0.3
  /// time_score = e^(-days_since_created / 30)，越新分越高
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

  /// 搜索指定分类的记忆
  Future<List<MemoryItem>> searchByCategory(
    String query,
    String category, {
    int limit = 10,
  }) async {
    if (!_isInitialized) await init();
    if (query.trim().isEmpty) {
      // 无关键词，只按分类查
      final rows = await _db!.query(
        'memories',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return rows.map(_rowToMemory).toList();
    }

    final rows = await _db!.rawQuery('''
      SELECT memories.*, -bm25(memories_fts) AS score
      FROM memories
      JOIN memories_fts ON memories.id = memories_fts.rowid
      WHERE memories_fts MATCH ? AND memories.category = ?
      ORDER BY score DESC
      LIMIT ?
    ''', [_ftsQuery(query), category, limit]);

    return rows.map(_rowToMemory).toList();
  }

  /// 列出所有分类
  Future<List<String>> listCategories() async {
    if (!_isInitialized) await init();
    final rows = await _db!.rawQuery(
      'SELECT DISTINCT category FROM memories ORDER BY category'
    );
    return rows.map((r) => r['category'] as String).toList();
  }

  /// 列出某分类记忆（分页）
  Future<List<MemoryItem>> list({
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    if (!_isInitialized) await init();

    List<Map<String, dynamic>> rows;
    if (category != null) {
      rows = await _db!.query(
        'memories',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );
    } else {
      rows = await _db!.query(
        'memories',
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );
    }
    return rows.map(_rowToMemory).toList();
  }

  /// 统计信息
  Future<Map<String, dynamic>> stats() async {
    if (!_isInitialized) await init();
    final total = Sqflite.firstIntValue(
      await _db!.rawQuery('SELECT COUNT(*) FROM memories')
    ) ?? 0;
    
    final categories = <String, int>{};
    final catRows = await _db!.rawQuery(
      'SELECT category, COUNT(*) as cnt FROM memories GROUP BY category'
    );
    for (final row in catRows) {
      categories[row['category'] as String] = row['cnt'] as int;
    }

    final expired = Sqflite.firstIntValue(
      await _db!.rawQuery(
        "SELECT COUNT(*) FROM memories WHERE ttl IS NOT NULL"
      )
    ) ?? 0;

    return {
      'total': total,
      'categories': categories,
      'expired': expired,
    };
  }

  // ──────────────────────────────────────────────
  // 工具
  // ──────────────────────────────────────────────

  /// 清理过期记忆
  /// 注意：FTS5 触发器会自动同步删除，无需手动处理
  Future<int> cleanup() async {
    if (!_isInitialized) await init();
    // 简单实现：删除 ttl 不为 null 的记录
    // 完整实现需解析 ttl 字符串（'30d'）与 created_at 比较
    final rows = await _db!.query(
      'memories',
      where: 'ttl IS NOT NULL',
    );
    int count = 0;
    for (final row in rows) {
      final ttl = row['ttl'] as String;
      final createdAt = DateTime.parse(row['created_at'] as String);
      final expired = _isExpired(ttl, createdAt);
      if (expired) {
        await delete(row['id'] as int);
        count++;
      }
    }
    return count;
  }

  /// 解析 ttl 是否过期
  bool _isExpired(String ttl, DateTime createdAt) {
    try {
      final match = RegExp(r'(\d+)([dhm])').allMatches(ttl);
      Duration dur = Duration.zero;
      for (final m in match) {
        final val = int.parse(m.group(1)!);
        switch (m.group(2)) {
          case 'd': dur += Duration(days: val);
          case 'h': dur += Duration(hours: val);
          case 'm': dur += Duration(minutes: val);
        }
      }
      return DateTime.now().isAfter(createdAt.add(dur));
    } catch (_) {
      return false;
    }
  }

  /// 重建 FTS5 索引（词典更新后使用）
  Future<void> reindex() async {
    if (!_isInitialized) await init();
    await _db!.execute("INSERT INTO memories_fts(memories_fts) VALUES('rebuild')");
  }

  /// 压缩数据库（回收删除的空间）
  Future<void> vacuum() async {
    if (!_isInitialized) await init();
    await _db!.execute('VACUUM');
  }

  /// 构造给 LLM 看的记忆上下文
  Future<String> buildContext(String query, {int limit = 5}) async {
    final memories = await search(query, limit: limit);
    if (memories.isEmpty) return '';

    final buf = StringBuffer('\n\n[相关记忆]\n');
    for (final m in memories) {
      buf.writeln('【${m.category}】${m.content}');
    }
    buf.writeln('[/相关记忆]');
    return buf.toString();
  }

  // ──────────────────────────────────────────────
  // 内部
  // ──────────────────────────────────────────────

  MemoryItem _rowToMemory(Map<String, dynamic> row) {
    final tagsStr = row['tags'] as String? ?? '[]';
    List<String> tags;
    try {
      tags = (tagsStr.startsWith('[')
        ? tagsStr.substring(1, tagsStr.length - 1)
            .split(',')
            .map((s) => s.trim().replaceAll(RegExp(r"^'|'$"), ''))
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[]);
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
