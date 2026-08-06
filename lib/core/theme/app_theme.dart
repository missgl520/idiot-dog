// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 情感主题（App Theme）
//
// 位于：core/theme/app_theme.dart
// 职责：定义 App 的颜色、字体、圆角等视觉规范
//
// 设计原则：
//   竹芽定位"情感树洞"，视觉上要有温暖、治愈感。
//   不用冰冷的蓝紫色系，而是竹绿 + 暖黄 + 米白。
//
// 颜色语义：
//   bamboo      竹绿 → 品牌色，代表竹芽的"竹"
//   warmYellow  暖黄 → 阳光感，呼应"少年感"定位
//   paper      米白 → 背景色，不刺眼，护眼
//   softText   深棕 → 正文字色，比纯黑更温和
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ════════════════════════════════════════════════════════
  // 品牌色
  // ════════════════════════════════════════════════════════

  /// 竹绿：品牌主色
  /// 用于：按钮、高亮、AppBar、Logo
  static const Color bamboo = Color(0xFF5DB075);

  /// 暖黄：辅助色，代表阳光/少年感
  /// 用于：用户头像边框、hover 状态、强调
  static const Color warmYellow = Color(0xFFFFB347);

  /// 珊瑚橙：次辅助色
  /// 用于：警告、动态提示
  static const Color coral = Color(0xFFFF7F7F);

  /// 薄荷绿：治愈感
  /// 用于：成功提示、空状态插画背景
  static const Color mint = Color(0xFFB5EAD7);

  // ════════════════════════════════════════════════════════
  // 背景 & 文字
  // ════════════════════════════════════════════════════════

  /// 米白背景（护眼）
  static const Color paper = Color(0xFFF9F6F1);

  /// 深棕正文（比纯黑柔和）
  static const Color softText = Color(0xFF3D3A36);

  /// 次要文字（灰色）
  static const Color subText = Color(0xFF8A8680);

  // ════════════════════════════════════════════════════════
  // 消息气泡
  // ════════════════════════════════════════════════════════

  /// 用户消息气泡：暖黄底
  static const Color userBubble = Color(0xFFFFF3E0);

  /// 竹芽消息气泡：竹绿底
  static const Color assistantBubble = Color(0xFFE8F5E9);

  // ════════════════════════════════════════════════════════
  // 暗色模式颜色
  // ════════════════════════════════════════════════════════

  /// 暗色模式背景
  static const Color darkBg = Color(0xFF1A1A2E);

  /// 暗色模式卡片
  static const Color darkCard = Color(0xFF252540);

  // ════════════════════════════════════════════════════════
  // 间距 & 圆角
  // ════════════════════════════════════════════════════════

  /// 标准间距
  static const double padding = 16.0;
  static const double paddingSm = 8.0;
  static const double paddingLg = 24.0;

  /// 圆角
  static const double radiusSm = 8.0;
  static const double radius = 16.0;
  static const double radiusLg = 24.0;

  // ════════════════════════════════════════════════════════
  // 字体
  // ════════════════════════════════════════════════════════

  /// 标题字号
  static const double fontTitle = 20.0;

  /// 正文字号
  static const double fontBody = 16.0;

  /// 辅助字（小字、标签）
  static const double fontCaption = 12.0;

  // ════════════════════════════════════════════════════════
  // 主题数据
  // ════════════════════════════════════════════════════════

  /// 亮色主题
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: bamboo,
          brightness: Brightness.light,
          surface: paper,
        ),
        scaffoldBackgroundColor: paper,
        appBarTheme: const AppBarTheme(
          backgroundColor: bamboo,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        // 圆角输入框
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: bamboo, width: 1.5),
          ),
        ),
        // 圆角按钮
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: bamboo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      );

  /// 暗色主题
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: bamboo,
          brightness: Brightness.dark,
          surface: darkBg,
        ),
        scaffoldBackgroundColor: darkBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkCard,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: darkCard,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
}
