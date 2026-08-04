// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 仓库接口（domain 层，只定义契约，不关心实现）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import '../entities/entities.dart';

/// 对话流事件类型
enum ChatEventType {
  textChunk, // AI 文本片段
  emotion,   // 情绪识别结果
  affinity,  // 好感度更新
  done,      // 本轮结束
  error,     // 错误
}

/// 统一对话事件（sealed class，Dart 3 新语法）
sealed class ChatEvent {
  const ChatEvent();
}

/// 文本片段
class TextChatEvent extends ChatEvent {
  final String text;
  const TextChatEvent(this.text);
}

/// 情绪事件
class EmotionChatEvent extends ChatEvent {
  final Emotion emotion;
  const EmotionChatEvent(this.emotion);
}

/// 好感度事件
class AffinityChatEvent extends ChatEvent {
  final Affinity affinity;
  const AffinityChatEvent(this.affinity);
}

/// 结束事件
class DoneChatEvent extends ChatEvent {
  const DoneChatEvent();
}

/// 错误事件
class ErrorChatEvent extends ChatEvent {
  final String message;
  const ErrorChatEvent(this.message);
}

/// 对话仓库接口
abstract class ChatRepository {
  /// 发送消息，返回流式事件
  Stream<ChatEvent> sendMessage({
    required String message,
    required List<Message> history,
    String? systemPrompt,
  });

  /// 获取好感度状态
  Future<Affinity> getAffinity();

  /// 重置好感度
  Future<void> resetAffinity();

  /// 清空对话记忆
  Future<bool> clearMemory({String category = 'chat_memory'});

  /// 检查后端是否在线
  Future<bool> isOnline();
}

/// TTS 仓库接口
abstract class TtsRepository {
  Future<void> speak(String text, {String emotion = 'neutral'});
  Future<void> stop();
  bool get isPlaying;
}

/// 记忆仓库接口
abstract class MemoryRepository {
  Future<List<Message>> getRecentMemories({int limit = 10});
  Future<bool> clearMemory({String category = 'chat_memory'});
}
