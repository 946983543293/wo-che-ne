import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 「我车呢」设计令牌 —— 圆角 / 字号 / 间距 / 动效，以及 Tokens → ThemeData 装配。
///
/// 来源：PRD §5 Design Tokens（圆角 12–20、字号 24–28/15/12–13、动效 150–250ms）。
abstract final class AppTokens {
  AppTokens._();

  // ---------- 圆角（dp） ----------
  /// 小控件圆角（标签、小气泡）。
  static const double radiusS = 12;

  /// 常规卡片圆角。
  static const double radiusM = 16;

  /// 大圆角（主按钮、大卡）。
  static const double radiusL = 20;

  // ---------- 字号（sp） ----------
  /// 大标题（如「车停好了？」）。
  static const double fontHeadline = 26;

  /// 页面标题（AppBar）。
  static const double fontTitle = 24;

  /// 副标题级：AppBar 标题与主按钮文字。
  static const double fontSubtitle = 18;

  /// 正文。
  static const double fontBody = 15;

  /// 辅助说明。
  static const double fontCaption = 13;

  /// 弱辅助（最次级）。
  static const double fontCaptionS = 12;

  /// 大数字（距离等，等宽数字）。
  static const double fontBigNumber = 28;

  // ---------- 间距（dp） ----------
  /// 页面水平边距（大留白基调）。
  static const double pagePadding = 24;

  /// 卡片间距。
  static const double cardGap = 12;

  // ---------- 动效时长（150–250ms 克制区间） ----------
  /// 快速反馈（按钮按压）。
  static const Duration motionFast = Duration(milliseconds: 150);

  /// 常规过渡。
  static const Duration motionNormal = Duration(milliseconds: 200);

  /// 较慢过渡（页面级）。
  static const Duration motionSlow = Duration(milliseconds: 250);

  // ---------- 主按钮规格（PRD §5：高 64dp、主色填充、白色粗体字） ----------
  /// 主按钮高度。
  static const double primaryButtonHeight = 64;
}

/// 「我车呢」主题工厂：浅色 / 深色 ThemeData。
abstract final class AppTheme {
  AppTheme._();

  /// 浅色主题（清新校园风，默认）。
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.card,
      onPrimary: AppColors.onPrimary,
      onSecondary: AppColors.onAccent,
    );
    return _base(colorScheme).copyWith(
      scaffoldBackgroundColor: AppColors.background,
    );
  }

  /// 深色主题（跟随系统，P1-3；主色不变）。
  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.cardDark,
      onPrimary: AppColors.onPrimary,
      onSecondary: AppColors.onAccent,
    );
    return _base(colorScheme).copyWith(
      scaffoldBackgroundColor: AppColors.backgroundDark,
    );
  }

  /// 两套主题共享的骨架：字体层级、圆角体系、按钮/卡片/阴影规格。
  static ThemeData _base(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final shadowColor = isDark ? AppColors.shadowDark : AppColors.shadow;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: AppTokens.fontHeadline,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: AppTokens.fontTitle,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: AppTokens.fontBody,
          color: textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: AppTokens.fontCaption,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: AppTokens.fontCaptionS,
          color: textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: AppTokens.fontSubtitle,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
        ),
        shadowColor: shadowColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(AppTokens.primaryButtonHeight),
          textStyle: const TextStyle(
            fontSize: AppTokens.fontSubtitle,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusL),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusL),
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
