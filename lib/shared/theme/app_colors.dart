import 'package:flutter/material.dart';

/// BuildContext 扩展，方便获取主题相关颜色
extension AppColorsExtension on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get backgroundColor => AppColors.getBackground(this);
  Color get surfaceColor => AppColors.getSurface(this);
  Color get textPrimaryColor => AppColors.getTextPrimary(this);
  Color get textSecondaryColor => AppColors.getTextSecondary(this);
  Color get textTertiaryColor => AppColors.getTextTertiary(this);
  Color get dividerColor => AppColors.getDivider(this);
  Color get inputFillColor => AppColors.getInputFill(this);
}

/// 应用颜色配置
/// 支持亮色和深色模式
class AppColors {
  // 主题色 - 两种模式共用
  static const Color primary = Color(0xFF007DFF);
  static const Color secondary = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFF9800);

  // ===== 亮色模式颜色 =====
  static const Color _lightBackground = Color(0xFFF1F3F5);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightTextPrimary = Color(0xFF333333);
  static const Color _lightTextSecondary = Color(0xFF666666);
  static const Color _lightTextTertiary = Color(0xFF999999);
  static const Color _lightDivider = Color(0xFFE0E0E0);

  // ===== 深色模式颜色 =====
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkTextPrimary = Color(0xFFE0E0E0);
  static const Color _darkTextSecondary = Color(0xFFB0B0B0);
  static const Color _darkTextTertiary = Color(0xFF808080);
  static const Color _darkDivider = Color(0xFF2C2C2C);

  // ===== 静态颜色（向后兼容，默认亮色） =====
  static const Color background = _lightBackground;
  static const Color surface = _lightSurface;
  static const Color textPrimary = _lightTextPrimary;
  static const Color textSecondary = _lightTextSecondary;
  static const Color textTertiary = _lightTextTertiary;
  static const Color divider = _lightDivider;

  // Rating Colors
  static const Color ratingStar = primary;
  static const Color ratingText = primary;
  static Color ratingBg = primary.withOpacity(0.1);

  // ===== 根据亮度获取颜色的方法 =====
  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkBackground
        : _lightBackground;
  }

  static Color getSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkSurface
        : _lightSurface;
  }

  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkTextPrimary
        : _lightTextPrimary;
  }

  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkTextSecondary
        : _lightTextSecondary;
  }

  static Color getTextTertiary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkTextTertiary
        : _lightTextTertiary;
  }

  static Color getDivider(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkDivider
        : _lightDivider;
  }

  static Color getRatingBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? primary.withOpacity(0.2)
        : primary.withOpacity(0.1);
  }

  // ===== 输入框填充色 =====
  static Color getInputFill(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : _lightSurface; // 亮色模式使用白色，与灰色背景区分
  }

  // ===== 卡片阴影色 =====
  static Color getCardShadow(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withOpacity(0.3)
        : Colors.black.withOpacity(0.08);
  }
}

/// 主题数据扩展
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors._lightBackground,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors._lightSurface,
      error: AppColors.error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors._lightSurface,
      foregroundColor: AppColors._lightTextPrimary,
      elevation: 0,
    ),
    dividerColor: AppColors._lightDivider,
    cardColor: AppColors._lightSurface,
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors._darkBackground,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors._darkSurface,
      error: AppColors.error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors._darkSurface,
      foregroundColor: AppColors._darkTextPrimary,
      elevation: 0,
    ),
    dividerColor: AppColors._darkDivider,
    cardColor: AppColors._darkSurface,
  );
}
