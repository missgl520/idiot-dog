# 竹芽 · 对话链路规格（SDD）

> **Spec-Driven Development**：本文件是竹芽对话链路的唯一事实来源。
> 代码与本文件不符 → 以本文件为准，先改文件再改代码。

---

## 1. 系统架构（现状确认）

```
┌─────────────────────────┐      ┌──────────────────────┐
│    Flutter App          │      │   Backend (FastAPI)  │
│                         │      │   localhost:8000     │
│  AgnesService           │      │                      │
│  ┌───────────────────┐  │      │  SinoMem ────────────┼─── 本地 SQLite
│  │ chatStream()      │  │      │  Cartesia TTS         │
│  │ 直连 Agnes API    │  │      │  Persona Manager      │
│  └───────────────────┘  │      │  LiveKit Token Gen    │
│          │              │      │                      │
│          ▼              │      │  Agnes (key=空，未通)  │
│     Agnes API ──────────┼──────│ ← 目前不经过 backend   │
│  Agnes CN/intl          │      │                      │
│                         │      └──────────────────────┘
│  MemoryService          │
│  ┌───────────────────┐  │      ┌──────────────────────┐
│  │ buildContext()   │  │      │   Agnes API           │
│  │ → backend SinoMem│  │      │   (apihub.agnes-ai.cn) │
│  └───────────────────┘  │      └──────────────────────┘
│                         │
│  CartesiaTTSService     │
│  ┌───────────────────┐  │
│  │ speak() → backend │  │
│  │ /tts endpoint     │  │
│  └───────────────────┘  │
│                         │
│  MemoryService.store()  │      ← 独立存本地 SQLite
│  (对话结束后调用)       │
└─────────────────────────┘
```

**核心原则：**
- Agnes 对话**不经过 backend**，Flutter 直连 Agnes API
- Backend 只负责：SinoMem 记忆、TTS、LiveKit Token、人格管理
- Agnes API Key 只需填在 **Flutter 设置页**（不需要填 backend）

---

## 2. 对话链路时序

```
用户按"发送"
     │
     ▼
┌──────────────────────────────────────────────────────────┐
│  Step 1: 消息入列                                        │
│  - Message(role=user) 加入 Hive messages 盒              │
│  - 输入框清空，软键盘收起                                 │
│  - status → thinking                                      │
└──────────────────────────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────────────────────────┐
│  Step 2: 召回记忆上下文（并行，不阻塞主流程）           │
│  - MemoryService.buildContext(userText)                 │
│  - 路径：Flutter → backend /memory/search               │
│  - 超时 5s，后端不通则降级本地 SQLite BM25              │
│  - 返回："\n\n[相关记忆]\n【chat_memory】...\n[/相关记忆]" │
└──────────────────────────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────────────────────────┐
│  Step 3: 拼装 System Prompt                             │
│  - 固定人设 prompt（见 §4）                              │
│  - 附加记忆上下文（Step 2 结果）                         │
└──────────────────────────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────────────────────────┐
│  Step 4: 流式调用 Agnes                                 │
│  - AgnesService.chatStream() 直连 Agnes API             │
│  - history → 前 N 条对话历史（需限长，见 §5）            │
│  - stream=true，每个 chunk 是一个字/词                   │
│  - status → writing（收到第一个 chunk 时）              │
└──────────────────────────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────────────────────────┐
│  Step 5: 增量渲染 UI（每个 chunk 到来时）               │
│  - messagesProvider.updateMessage(id, full, isStreaming=true)│
│  - 自动滚动到底部                                        │
│  - 打字光标闪烁（streaming=true 时显示）                │
└──────────────────────────────────────────────────────────┘
     │
     ▼ （流结束）
┌──────────────────────────────────────────────────────────┐
│  Step 6: 流结束                                          │
│  - updateMessage(id, full, isStreaming=false)            │
│  - 打字光标消失                                          │
│  - status → speaking 或 idle（取决于 TTS 开关）         │
└──────────────────────────────────────────────────────────┘
     │
     ├────────────────────────────────────┐
     ▼                                    ▼
┌─────────────────────────┐    ┌─────────────────────────────┐
│  Step 7a: 存本地记忆    │    │  Step 7b: TTS 播报（可选）  │
│  - memory.store()       │    │  - ttsEnabled = true 时触发│
│    内容："用户||AI回复" │    │  - backend /tts → Cartesia │
│  - category: chat_memory│    │  - 或降级 flutter_tts      │
│  - 异步，不阻塞          │    │  - 播完 → status → idle    │
└─────────────────────────┘    └─────────────────────────────┘
```

---

## 3. 状态机

```dart
enum ZhuaStatus {
  idle,      // 在的 — 等待用户，空闲
  thinking,  // 在想 — AI 正在推理（从发送消息到收到第一个 chunk）
  writing,   // 在写 — AI 正在输出（第一个 chunk 收到后）
  speaking,  // 在说 — TTS 正在播报
}
```

**状态 → UI 映射：**

| 状态 | 状态徽章 | Live2D | 输入框 | 思考动画 |
|------|---------|--------|--------|---------|
| idle | 在的（绿） | 正常显示 | 可输入 | 无 |
| thinking | 在想（棕） | 变透明 | 禁用 | 三点浮动 |
| writing | 在写（绿） | 变透明 | 禁用 | 三点浮动 |
| speaking | 在说（绿） | 变透明 | 禁用 | 无 |

**状态转换规则（严格）：**
```
idle → thinking   （用户发送消息）
thinking → writing （收到 Agnes 第一个 chunk）
writing → speaking （TTS 开启，full 非空）
speaking → idle   （TTS 播报结束）
writing → idle    （TTS 关闭，收到最后一个 chunk）
any → idle        （异常捕获，统一归位）
```

---

## 4. System Prompt（固定人设）

```text
你是竹芽，一个温柔的情感陪伴者。
你正在陪伴一个人聊天。你不着急，不刷屏，不给建议除非对方真的需要。
你的回复像手写的信，有呼吸感，有停顿，不是聊天消息。
你可以沉默，可以问一句不急着回答的问题，可以不接话茬。
保持真诚，不需要总是正能量。
```

**注入 RAG 后（记忆上下文存在时）：**

```text
你是竹芽，一个温柔的情感陪伴者...
[竹芽人设不变]

[相关记忆]
【chat_memory】用户：今天心情不太好
【chat_memory】竹芽：怎么了，愿意说说吗
[/相关记忆]
```

---

## 5. 对话历史管理

**问题：** history 无限增长 → token 超限、响应变慢

**规则：**
- 传给 Agnes 的 history = **最近 10 条**（user + assistant 成对）
- Hive messages 盒存储**全部历史**（用于 UI 展示，不传给 API）
- 单条消息最大字符数：**2000 字**（超长截断）

**实现：**
```dart
// 取最近 10 条，转 API 格式
final recentMsgs = history.length > 10
    ? history.sublist(history.length - 10)
    : history;
final msgs = recentMsgs.map((m) => {'role': m.role, 'content': m.content}).toList();
```

---

## 6. 记忆上下文（Context Building）

**调用时机：** 每次发送消息前，**并行执行**（不等结果）

**数据源优先级：**
1. Backend SinoMem（`GET /memory/search`）
2. 本地 SQLite BM25（`memory_service.search()`）

**返回格式（注入 System Prompt）：**
```
\n\n[相关记忆]
【chat_memory】内容...
【preference】内容...
[/相关记忆]
```

**若无相关记忆：** 返回空字符串，System Prompt 不变。

**存储时机：** AI 回复结束后（收到 `[DONE]`），异步存储到本地 SQLite。
- 内容：`"$userText || $fullReply"`
- category：`chat_memory`
- 重要度：`0.5`（默认）

---

## 7. TTS 播报策略

**触发条件：** `ttsEnabled = true`（用户在设置页开启）

**链路：**
```
AI 回复文本 full
     │
     ├─ [ttsMode = 'cartesia'] → backend /tts → Cartesia API
     │                                              ↓
     └─ [ttsMode = 'system']  → flutter_tts ←──────┘
                                      ↓
                               音频播放（just_audio）
                                      ↓
                               status → idle
```

**错误降级：**
- Cartesia 失败 → 降级 flutter_tts
- TTS 失败 → 不提示用户，静默跳过，继续 `idle`

**播报时机：** AI 回复**全部收完后**开始播（不是逐句），避免打断流式输出。

---

## 8. 错误处理

| 错误场景 | 处理方式 | 用户可见 |
|---------|---------|---------|
| Agnes API Key 为空 | 抛出提示"请先配置 API Key" | SnackBar |
| Agnes API 网络错误 | 进入 idle，提示"竹芽走神了" | SnackBar |
| Agnes 401/403 | 进入 idle，提示"API Key 无效" | SnackBar |
| Agnes 429 超限 | 进入 idle，提示"竹芽累了，稍后再试" | SnackBar |
| backend /memory/search 超时 | 静默降级本地 SQLite，不提示 | 无 |
| Cartesia TTS 失败 | 静默降级 flutter_tts，不提示 | 无 |
| flutter_tts 也失败 | 静默跳过，不提示 | 无 |

**通用兜底：** 任何异常 → `status = idle`，不留下悬挂状态。

---

## 9. 流式 SSE 解析规范

**来源：** Agnes API 流式响应（`stream: true`）

**Flutter 端解析：**
```
SSE 格式：
  data: {"choices":[{"delta":{"content":"字"}}]}\n\n
  data: [DONE]\n\n

解析规则：
  1. 按 '\n' 分割行
  2. 跳过非 'data: ' 开头行
  3. data = line.substring(6).trim()
  4. data == '[DONE]' → 结束
  5. JSON parse → delta.content → yield
```

**Backend agnes.py 重新组 SSE（供其他客户端）：**
```
内部：原生 SSE
对外：重新组 SSE，同格式输出
```

---

## 10. 待接入功能（规划中）

| 功能 | 阻塞条件 | 优先级 |
|-----|---------|--------|
| ASR 语音输入 | speech_to_text 插件集成 | P1 |
| LiveKit 实时语音 | LiveKit Server + Flutter 客户端 | P2 |
| Live2D 真实模型 | flutter_live2d 真机测试 | P2 |
| 后端公开部署 | Agnes API Key 填 backend / 找公网 host | P3 |

---

## 11. 关键文件索引

| 文件 | 职责 |
|-----|------|
| `lib/core/services/agnes_service.dart` | Agnes 直连 API，流式输出 |
| `lib/core/services/memory_service.dart` | 本地 SQLite + backend SinoMem |
| `lib/core/services/cartesia_tts_service.dart` | TTS 服务，调 backend /tts |
| `lib/providers/app_providers.dart` | 全局状态，ZhuaStatus，BackendConfig |
| `lib/pages/chat/chat_page.dart` | 唯一对话页面，状态机入口 |
| `backend/main.py` | FastAPI 主入口，/tts, /memory |
| `backend/services/agnes.py` | Backend 端 Agnes 调用（未启用） |
| `backend/services/memory.py` | SinoMem/SimpleMemory 抽象 |

---

## Changelog

| 日期 | 改动 |
|-----|------|
| 2026-08-01 | 初稿，基于代码分析建立规格 |
