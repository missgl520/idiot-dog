# 竹芽 App 产品规划文档 v1

> 版本：v1.0 | 更新日期：2026-07-25
> 状态：规划阶段，开发中

---

## 一、产品定位

**产品名称：** 竹芽
**产品类型：** 移动端语音陪聊助手
**产品定位：** 2D 虚拟角色情感陪伴 AI

**核心功能：**
- 🎭 2D 虚拟角色（Live2D）实时互动
- 💬 文字聊天
- 🎤 语音聊天（按下录音，松开结束）
- 🖼️ 图片/相册/文件发送
- 🧠 长期记忆（记住你说的话）
- 🫂 情感树洞 / 情感陪伴

**主要场景：** 深夜倾诉、情感陪伴、日常闲聊

**商业模式：** 免费优先

---

## 二、视觉设计

### 2.1 品牌 Logo

使用竹芽 3D 形象图标（见 assets/logo.png）：
- 圆润可爱的绿色小精灵
- 头顶竹芽装饰
- 手持竹笋
- 整体风格：3D 玩具风，温暖治愈

### 2.2 配色方案

| 用途 | 颜色 |
|------|------|
| 主色 | #4CAF50（竹绿） |
| 辅助色 | #81C784（浅绿） |
| 背景色（亮） | #F5F5DC（米色） |
| 背景色（暗） | #1A1A2E（深蓝紫） |
| 卡片色（暗） | #2A2A4A |
| 强调色 | #A5D6A7 |

### 2.3 主题

- 亮色模式 + 暗色模式切换
- 温暖绿色调为主

---

## 三、页面结构

### 3.1 启动加载页（Splash）

- 全屏显示竹芽 Logo 动画（弹性放大 + 淡入）
- 显示文案："情感陪伴 · 随时倾听"
- 2 秒后自动渐变进入主页面

### 3.2 主页面（对话页）

**整体布局：**

```
┌─────────────────────────────────┐
│  [🎋竹芽]              [⚙️设置] │  ← 顶栏
├─────────────────────────────────┤
│                                 │
│   【2D雫活动框 - 下层】          │  ← 背景层
│   （消息滚动过半后渐隐）          │
│                                 │
│   【文字聊天框 - 上层】           │  ← 消息列表层
│                                 │
├─────────────────────────────────┤
│ [🎤语音]  [输入框...]  [➕]    │  ← 底栏
└─────────────────────────────────┘
```

**顶栏：**
- 左：竹芽 Logo 图标（点击回首页）
- 右：设置图标 + 主题切换图标

**中间区域：**
- 下层：Live2D 雫角色活动框
  - 背景显示，文字滚动过半后自动渐隐（300ms 过渡）
- 上层：消息列表（气泡形式展示）

**底栏：**
- 左：🎤 语音按钮（按下录音，松开结束）
- 中：文字输入框
- 右：➕ 加号按钮（弹出相机/相册/文件选择）

### 3.3 设置页

- API Key 配置（Agnes AI）
- TTS 开关
- 记忆管理（查看/清空）
- 主题切换

---

## 四、技术架构

### 4.1 技术栈

| 模块 | 技术选型 | 说明 |
|------|---------|------|
| 框架 | Flutter 3.44.6 | 双平台 Android/iOS |
| 状态管理 | Riverpod | 响应式状态管理 |
| 路由 | GoRouter | 页面路由 |
| LLM | Agnes 2.0 Flash | 免费 OpenAI 兼容 API |
| TTS | flutter_tts | 小米 MIUI 离线语音引擎 |
| ASR | speech_to_text | 语音识别 |
| Live2D | flutter_live2d | 虚拟角色动画 |
| 本地存储 | Hive | 消息历史、设置、记忆 |
| 权限 | permission_handler | 麦克风/存储权限 |

### 4.2 LLM API 信息

**Agnes AI**
- Base URL：`https://apihub.agnes-ai.com`
- Endpoint：`POST /v1/chat/completions`
- 模型：`agnes-2.0-flash`
- 认证：Bearer Token
- 价格：完全免费
- 上下文：512K tokens
- 特殊能力：Tool Calling

### 4.3 数据存储

| 数据 | 存储方式 |
|------|---------|
| 对话历史 | Hive（messages） |
| 用户设置 | Hive（settings） |
| 长期记忆 | Hive（memory）+ 关键词检索 |

---

## 五、虚拟角色

**角色名：** Shizuku 雫

**来源：** Live2D 官方免费示例模型
- 下载自：https://model.hacxy.cn/shizuku/
- 原始作者：Kasai
- 授权：Live2D Free Material License，可商用/非商用

**性格：** 活泼、会做手势、表达丰富

**动作系统：**
- idle_00/01/02：待机动画（循环）
- tapBody：点击身体响应
- shake：摇晃
- flickHead：摇头
- pinchIn/Out：缩放

**表情（f01-f04）：**
- f01：默认
- f02：开心
- f03：生气
- f04：惊讶

**与竹芽 App 的结合：**
- AI 思考时：雫显示倾听状态
- AI 回复时：雫显示说话状态
- 情绪低落时：雫切换到 f03/f04 表情

---

## 六、开发阶段

### Phase 1 - 核心框架 ✅
- [x] 项目初始化
- [x] pubspec.yaml 依赖配置
- [x] 目录结构搭建
- [x] 核心服务层（Agnes/TTS/ASR/Memory）
- [ ] 启动加载页 ✅（代码已写）
- [ ] 主对话页面 ✅（代码已写）
- [ ] 主题切换
- [ ] 设置页面

### Phase 2 - 语音能力
- [ ] flutter_tts 接入 + 小米离线引擎
- [ ] speech_to_text 接入
- [ ] 语音自动播报
- [ ] 语音打断
- [ ] 按下录音松开结束逻辑

### Phase 3 - Live2D 虚拟角色
- [ ] flutter_live2d 接入
- [ ] Shizuku 模型加载
- [ ] 角色动作系统（待机/说话/倾听）
- [ ] 表情变化逻辑
- [ ] 文字过半渐隐

### Phase 4 - 图片/文件功能
- [ ] image_picker 接入
- [ ] 相机/相册/文件选择弹窗
- [ ] 图片消息展示

### Phase 5 - 长期记忆
- [ ] 记忆存储
- [ ] 记忆召回
- [ ] 记忆上下文注入 LLM

---

## 七、文件结构

```
zhuyapp/
├── assets/
│   ├── logo.png              # 竹芽 Logo 图标
│   ├── live2d/shizuku/       # Shizuku 模型文件
│   │   ├── shizuku.moc
│   │   ├── shizuku.model.json
│   │   ├── shizuku.physics.json
│   │   ├── shizuku.pose.json
│   │   ├── shizuku.1024/     # 纹理图片
│   │   ├── expressions/      # 表情文件
│   │   └── motions/          # 动作文件
│   └── audio/                # 音频资源
├── lib/
│   ├── main.dart             # 入口
│   ├── models/
│   │   └── message.dart      # 消息模型
│   ├── core/
│   │   ├── services/
│   │   │   ├── agnes_service.dart  # LLM 服务
│   │   │   ├── tts_service.dart    # TTS 服务
│   │   │   ├── asr_service.dart    # ASR 服务
│   │   │   └── memory_service.dart # 记忆服务
│   │   ├── theme/
│   │   │   └── app_theme.dart      # 主题
│   │   └── router/
│   │       └── app_router.dart     # 路由
│   ├── providers/
│   │   └── app_providers.dart      # 全局状态
│   ├── pages/
│   │   ├── splash/splash_page.dart # 启动页
│   │   ├── home/home_page.dart     # 首页
│   │   ├── chat/chat_page.dart     # 对话页
│   │   └── settings/settings_page.dart
│   └── widgets/
│       ├── live2d_widget.dart      # Live2D 组件
│       ├── chat_bubble.dart        # 消息气泡
│       ├── voice_button.dart       # 语音按钮
│       └── image_picker_button.dart # 图片选择按钮
└── SPEC.md
```

---

## 八、参考项目

- [Open-LLM-VTuber](https://github.com/AI-Hobbyist/Open-LLM-VTuber) — 桌面端参考架构
- [Agnes AI 文档](https://wiki.agnes-ai.com) — LLM API 文档
- [flutter_live2d](https://pub.dev/packages/flutter_live2d) — Flutter Live2D SDK
- [Shizuku 模型](https://model.hacxy.cn/shizuku/) — 模型文件下载

---

> 文档由竹芽 AI（狗子）整理 | 如有调整随时更新
