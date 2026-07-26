// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 消息数据模型
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 对话消息的数据结构
/// - id         : 唯一标识（时间戳毫秒数）
/// - role       : 'user' | 'assistant'
/// - content    : 消息正文
/// - timestamp  : 创建时间（用于排序）
/// - isStreaming: AI 正在输出中（控制打字光标显示）
class Message {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;

  const Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
  });

  /// 复制一个修改后的实例（不可变对象的惯用写法）
  Message copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
  }) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  /// 序列化为 JSON（存入 Hive）
  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  /// 从 JSON 反序列化（从 Hive 读取）
  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
