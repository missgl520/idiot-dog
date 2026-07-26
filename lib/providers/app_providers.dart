// 全局状态 Providers
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/services/agnes_service.dart';
import '../core/services/tts_service.dart';
import '../core/services/asr_service.dart';
import '../core/services/memory_service.dart';
import '../models/message.dart';

// ============ 主题 ============
final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  final box = Hive.box('settings');
  return ThemeNotifier(box.get('isDarkMode', defaultValue: false) as bool);
});

class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier(super.state) {
    final box = Hive.box('settings');
    state = box.get('isDarkMode', defaultValue: false) as bool;
  }

  void toggle() {
    state = !state;
    Hive.box('settings').put('isDarkMode', state);
  }
}

// ============ Services ============
final agnesServiceProvider = Provider<AgnesService>((ref) {
  final service = AgnesService();
  final box = Hive.box('settings');
  final apiKey = box.get('agnesApiKey', defaultValue: '') as String;
  if (apiKey.isNotEmpty) service.setApiKey(apiKey);
  return service;
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

final asrServiceProvider = Provider<AsrService>((ref) {
  return AsrService();
});

final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService();
});

// ============ API Key ============
final apiKeyProvider = StateProvider<String>((ref) {
  final box = Hive.box('settings');
  return box.get('agnesApiKey', defaultValue: '') as String;
});

// ============ 消息列表 ============
final messagesProvider = StateNotifierProvider<MessagesNotifier, List<Message>>((ref) {
  final box = Hive.box('messages');
  final messages = <Message>[];

  // 加载历史消息
  for (final key in box.keys) {
    try {
      final data = Map<String, dynamic>.from(box.get(key));
      messages.add(Message.fromJson(data));
    } catch (_) {}
  }

  // 按时间排序
  messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

  return MessagesNotifier(messages);
});

class MessagesNotifier extends StateNotifier<List<Message>> {
  final Box _box;

  MessagesNotifier(super.state) : _box = Hive.box('messages');

  void addMessage(Message msg) {
    state = [...state, msg];
    _box.put(msg.id, msg.toJson());
  }

  void updateMessage(String id, String content) {
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(content: content, isStreaming: false);
      }
      return m;
    }).toList();
  }

  void removeMessage(String id) {
    state = state.where((m) => m.id != id).toList();
    _box.delete(id);
  }

  void clear() {
    state = [];
    _box.clear();
  }
}

// ============ 对话状态 ============
enum ChatStatus { idle, thinking, speaking }

final chatStatusProvider = StateProvider<ChatStatus>((ref) => ChatStatus.idle);

// ============ TTS 播放状态 ============
final ttsEnabledProvider = StateProvider<bool>((ref) {
  final box = Hive.box('settings');
  return box.get('ttsEnabled', defaultValue: true) as bool;
});

// ============ ASR 监听状态 ============
final asrListeningProvider = StateProvider<bool>((ref) => false);
