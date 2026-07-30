// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 全局状态 Providers（Riverpod）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// Provider 架构说明：
// - StateNotifierProvider : 可变状态，有 .notifier 操作状态
// - Provider              : 只读服务（AgnesService / TTS / ASR / Memory）
// - StateProvider         : 简单状态（布尔/字符串）
//
// 所有状态默认是 App 全局共享的，放在这里统一管理。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/services/agnes_service.dart';
import '../core/services/tts_service.dart';
import '../core/services/cartesia_tts_service.dart';
import '../core/services/asr_service.dart';
import '../core/services/memory_service.dart';
import '../models/message.dart';
import '../widgets/live2d_controller.dart';

// ━━━━━━━━━━━━━━━ 主题 ━━━━━━━━━━━━━━━

/// 主题 Provider：
/// - isDarkMode = true  → 暗色主题
/// - isDarkMode = false → 亮色主题
/// 持久化到 Hive 'settings' 盒子
final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  final box = Hive.box('settings');
  return ThemeNotifier(box.get('isDarkMode', defaultValue: false) as bool);
});

class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier(super.state) {
    // 从持久化存储读取上次的主题设置
    final box = Hive.box('settings');
    state = box.get('isDarkMode', defaultValue: false) as bool;
  }

  /// 切换主题并写入 Hive
  void toggle() {
    state = !state;
    Hive.box('settings').put('isDarkMode', state);
  }
}

// ━━━━━━━━━━━━━━━ Services（只读） ━━━━━━━━━━━━━━━

/// AI 对话服务（Agnes / 小米小猫）
/// 负责：流式返回 / System Prompt / API 调用
final agnesServiceProvider = Provider<AgnesService>((ref) {
  return AgnesService.instance;
});

/// TTS 服务（文字转语音，播报竹芽回复）
final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

/// ASR 服务（语音识别，暂未接入）
final asrServiceProvider = Provider<AsrService>((ref) {
  return AsrService();
});

/// 长期记忆服务（SinoMem）
/// 负责：构建上下文 / 存储对话记忆
final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService();
});

// ━━━━━━━━━━━━━━━ API Key ━━━━━━━━━━━━━━━

/// Agnes API Key（从设置页输入）
/// 持久化到 Hive 'settings' 盒子
final apiKeyProvider = StateProvider<String>((ref) {
  final box = Hive.box('settings');
  return box.get('agnesApiKey', defaultValue: '') as String;
});

// ━━━━━━━━━━━━━━━ Agnes 服务器区域 ━━━━━━━━━━━━━━━

/// Agnes 使用的 API 服务器
/// - true  = 国内版 platform.agnes-ai.cn
/// - false = 国际版 apihub.agnes-ai.com
/// 持久化到 Hive
final agnesUseCNProvider = StateProvider<bool>((ref) {
  final box = Hive.box('settings');
  return box.get('agnesUseCN', defaultValue: true) as bool;
});

// ━━━━━━━━━━━━━━━ 消息列表 ━━━━━━━━━━━━━━━

/// 对话消息列表 Provider
/// - 初始化时从 Hive 'messages' 盒子加载历史
/// - 按时间戳升序排列
/// - 支持 add / update / remove / clear
final messagesProvider = StateNotifierProvider<MessagesNotifier, List<Message>>((ref) {
  final box = Hive.box('messages');
  final messages = <Message>[];

  // 从 Hive 恢复历史消息
  for (final key in box.keys) {
    try {
      final data = Map<String, dynamic>.from(box.get(key));
      messages.add(Message.fromJson(data));
    } catch (_) {
      // 损坏的数据跳过
    }
  }

  // 按时间升序
  messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return MessagesNotifier(messages);
});

/// 消息状态管理器
/// 每次操作同步写入 Hive，保证重启后数据不丢失
class MessagesNotifier extends StateNotifier<List<Message>> {
  final Box _box;

  MessagesNotifier(super.state) : _box = Hive.box('messages');

  /// 新增一条消息（用户或 AI）
  void addMessage(Message msg) {
    state = [...state, msg];
    _box.put(msg.id, msg.toJson());
  }

  /// 更新消息内容（用于 AI 流式输出的增量更新）
  /// id         : 要更新的消息 ID
  /// content    : 最新完整内容（非增量）
  /// isStreaming: 是否仍在输出中（影响光标显示）
  void updateMessage(String id, String content, {bool? isStreaming}) {
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(
          content: content,
          isStreaming: isStreaming ?? m.isStreaming,
        );
      }
      return m;
    }).toList();
  }

  /// 删除单条消息
  void removeMessage(String id) {
    state = state.where((m) => m.id != id).toList();
    _box.delete(id);
  }

  /// 清空所有历史
  void clear() {
    state = [];
    _box.clear();
  }
}

// ━━━━━━━━━━━━━━━ 竹芽状态机 ━━━━━━━━━━━━━━━

/// 竹芽当前的心理/行为状态
/// 用于 UI 展示（状态徽章、Live2D 透明度、输入框禁用）
enum ZhuaStatus {
  idle,     // 在的 - 空闲，等待用户
  thinking, // 在想 - 用户发了消息，AI 正在推理
  writing,  // 在写 - AI 开始输出文字
  speaking, // 在说 - TTS 正在播报
}

/// 状态 Provider
/// UI 通过 watch 这个 Provider 来响应竹芽状态变化
final zhuaStatusProvider = StateProvider<ZhuaStatus>((ref) => ZhuaStatus.idle);

// ━━━━━━━━━━━━━━━ 其他 UI 状态 ━━━━━━━━━━━━━━━

/// 用户当前正在输入的草稿（暂未使用）
final draftProvider = StateProvider<String>((ref) => '');

/// TTS 服务（文字转语音，播报竹芽回复）
/// 优先使用 Cartesia API TTS（自然音色+情感）
/// 系统 TTS（flutter_tts）为降级方案
final cartesiaTtsServiceProvider = Provider<CartesiaTtsService>((ref) {
  return CartesiaTtsService();
});

/// TTS 开关（竹芽说话是否自动播报语音）
final ttsEnabledProvider = StateProvider<bool>((ref) {
  final box = Hive.box('settings');
  return box.get('ttsEnabled', defaultValue: true) as bool;
});

/// TTS 模式切换
/// - 'cartesia'：调用竹芽后端 API TTS（情感音色，推荐）
/// - 'system'：系统 TTS（flutter_tts，降级）
final ttsModeProvider = StateProvider<String>((ref) {
  final box = Hive.box('settings');
  return box.get('ttsMode', defaultValue: 'cartesia') as String;
});

/// ASR 监听状态
final asrListeningProvider = StateProvider<bool>((ref) => false);

/// ASR 识别结果（语音输入完成后写入，chat_page 监听并发送）
final asrResultProvider = StateProvider<String?>((ref) => null);

// ━━━━━━━━━━━━━━━ Live2D ━━━━━━━━━━━━━━━

/// Live2D 控制器单例
/// 在 App 启动时初始化，对话过程中复用
final live2dControllerProvider = Provider<ZhuaLive2DController>((ref) {
  return ZhuaLive2DController.instance;
});
