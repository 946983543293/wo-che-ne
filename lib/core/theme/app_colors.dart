import 'package:flutter/material.dart';

/// 「我车呢」设计令牌 —— 颜色常量（唯一事实来源）。
///
/// 来源：PRD §5 Design Tokens。架构 §7.2 红线：**禁止在页面里写死色值**，
/// 一切颜色必须从这里取。
abstract final class AppColors {
  AppColors._();

  /// 主色：薄荷青绿（按钮、车标记）。
  static const Color primary = Color(0xFF2BB673);

  /// 强调色：暖橙（「我的车」图钉、关键提醒）。
  static const Color accent = Color(0xFFFF8A3D);

  // ---------- 浅色模式 ----------

  /// 页面背景：米白。
  static const Color background = Color(0xFFFAFAF7);

  /// 卡片：纯白。
  static const Color card = Color(0xFFFFFFFF);

  /// 主要文字。
  static const Color textPrimary = Color(0xFF1F2D2B);

  /// 次要文字。
  static const Color textSecondary = Color(0xFF6B7B78);

  // ---------- 深色模式 ----------

  /// 深色页面背景。
  static const Color backgroundDark = Color(0xFF121A18);

  /// 深色卡片。
  static const Color cardDark = Color(0xFF1E2926);

  /// 深色模式主要文字（PRD 未定义，按米白底同族低饱和推导出，设计走查时可调）。
  static const Color textPrimaryDark = Color(0xFFEEF3F1);

  /// 深色模式次要文字（同上的推导值）。
  static const Color textSecondaryDark = Color(0xFF93A49F);

  // ---------- 语义色 ----------

  /// 主色之上的内容色（白）。
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// 强调色之上的内容色（白）。
  static const Color onAccent = Color(0xFFFFFFFF);

  /// 极浅阴影色（卡片用，「极轻且有层次」的设计要求）。
  static const Color shadow = Color(0x0F1F2D2B);

  /// 深色模式阴影（几乎不可见，仅分层次）。
  static const Color shadowDark = Color(0x33000000);

  // ---------- 中性 / 遮罩（非品牌色，集中管理以满足「页面不写死色值」走查） ----------

  /// 引导层与相机提示条的半透明黑遮罩（PRD §5：界面压暗约 60% 黑）。
  static const Color scrim = Color(0x9E000000);

  /// 遮罩之上的内容色（白字/白图标）。
  static const Color onScrim = Color(0xFFFFFFFF);

  /// 拍照页沉浸式取景背景（纯黑）。
  static const Color immersive = Color(0xFF000000);
}
