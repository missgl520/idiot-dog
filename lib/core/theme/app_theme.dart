// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹芽主题 - 安静、纸质感
//
// 设计语言：宣纸 + 墨色 + 竹绿
// - 纸质感：背景用米白（paper）而非纯白，减少屏幕刺激
// - 竹绿：主色是低饱和的绿色（bamboo），非高饱和荧光绿
// - 墨色：深色区域用墨灰（ink）而非纯黑
//
// 颜色层级：
//   bamboo (#6B9E78)   → 主按钮 / 强调
//   bambooLight        → 次级绿
//   bambooDark         → 深绿
//   paper (#FAF8F5)    → 亮色背景
//   paperDark (#1A1A1A) → 暗色背景
//   ink (#2C2C2C)      → 亮色正文
//   mist (#F0EDE8)     → 分割线
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter/material.dart';

class AppTheme {
  // ── 竹芽专属色板 ──
  static const Color bamboo      = Color(0xFF6B9E78);  // 竹绿 - 主色
  static const Color bambooLight = Color(0xFFA8C5AB);  // 浅竹绿
  static const Color bambooDark  = Color(0xFF4A7055);  // 深竹绿
  static const Color warmYellow = Color(0xFFFFD54F);  // 暖黄 - 强调色（设计规范 #FFD54F）
  static const Color paper       = Color(0xFFFAF8F5);  // 宣纸白 - 亮色背景
  static const Color paperDark   = Color(0xFF1A1A1A);  // 深色背景
  static const Color ink         = Color(0xFF2C2C2C);  // 墨色 - 亮色正文
  static const Color inkLight    = Color(0xFF6B6B6B);  // 浅墨 - 次要文字
  static const Color mist        = Color(0xFFF0EDE8);  // 雾色 - 分割线

  // ── 亮色主题 ──
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.light(
        primary: bamboo,
        onPrimary: Colors.white,
        secondary: bambooLight,
        surface: paper,
        onSurface: ink,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          fontSize: 17,
          color: ink,
          height: 1.8,    // 行高宽松，阅读舒适
          letterSpacing: 0.3,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: ink,
          height: 1.9,
          letterSpacing: 0.5,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          color: inkLight,
          height: 1.6,
        ),
      ),

      dividerColor: mist,
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // 输入框：无边框，像写在纸上
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintStyle: TextStyle(
          color: inkLight.withValues(alpha: 0.5),
          fontSize: 17,
          height: 1.8,
        ),
      ),
    );
  }

  // ── 深色主题 ──
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: paperDark,
      colorScheme: ColorScheme.dark(
        primary: bamboo,
        onPrimary: Colors.white,
        secondary: bambooLight,
        surface: paperDark,
        onSurface: const Color(0xFFE8E4DE),  // 暖白，而非纯白
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          fontSize: 17,
          color: Color(0xFFE8E4DE),
          height: 1.8,
          letterSpacing: 0.3,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: Color(0xFFE8E4DE),
          height: 1.9,
          letterSpacing: 0.5,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          color: Color(0xFF9A958F),
          height: 1.6,
        ),
      ),

      dividerColor: const Color(0xFF2A2A2A),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintStyle: TextStyle(
          color: const Color(0xFF9A958F).withValues(alpha: 0.6),
          fontSize: 17,
          height: 1.8,
        ),
      ),
    );
  }
}

// 兼容性别名（main.dart 中用过）
typedef AppThemeData = AppTheme;
