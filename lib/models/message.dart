// 消息模型
class Message {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isStreaming; // 是否正在流式输出

  Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
  });

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'],
        role: json['role'],
        content: json['content'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}
