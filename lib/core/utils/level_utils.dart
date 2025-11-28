import 'package:flutter/material.dart';

class LevelUtils {
  /// 获取等级名称
  static String getLevelName(int userScore) {
    if (userScore < 100) return 'Lv0 菜鸟';
    if (userScore < 300) return 'Lv1 大虾';
    if (userScore < 600) return 'Lv2 码农';
    if (userScore < 1000) return 'Lv3 程序猿';
    if (userScore < 2000) return 'Lv4 工程师';
    if (userScore < 3000) return 'Lv5 大牛';
    if (userScore < 4000) return 'Lv6 专家';
    if (userScore < 5000) return 'Lv7 大神';
    return '祖师爷';
  }

  /// 获取等级颜色
  static Color getLevelColor(int userScore) {
    if (userScore < 100) return const Color(0xFF18B5CA);
    if (userScore < 300) return const Color(0xFF378814);
    if (userScore < 600) return const Color(0xFFD74A4A);
    if (userScore < 1000) return const Color(0xFFF08527);
    if (userScore < 2000) return const Color(0xFFFF7D7D);
    if (userScore < 3000) return const Color(0xFFFF5A99);
    if (userScore < 4000) return const Color(0xFFE376E5);
    if (userScore < 5000) return const Color(0xFF9A7EF8);
    return const Color(0xFF9A7EF8);
  }

  /// 获取身份背景色
  static Color getIdentityBackgroundColor(String identity) {
    switch (identity) {
      case 'teacher':
        return const Color(0xFF0000BB);
      case 'organization':
        return const Color(0xFFFFBB00);
      default:
        return const Color(0xFF666666);
    }
  }

  /// 获取下一等级所需经验值
  static int getNextLevelExp(int userScore) {
    if (userScore < 100) return 100;
    if (userScore < 300) return 300;
    if (userScore < 600) return 600;
    if (userScore < 1000) return 1000;
    if (userScore < 2000) return 2000;
    if (userScore < 3000) return 3000;
    if (userScore < 4000) return 4000;
    if (userScore < 5000) return 5000;
    return 5000;
  }

  /// 获取当前等级起始经验值
  static int getCurrentLevelStartExp(int userScore) {
    if (userScore < 100) return 0;
    if (userScore < 300) return 100;
    if (userScore < 600) return 300;
    if (userScore < 1000) return 600;
    if (userScore < 2000) return 1000;
    if (userScore < 3000) return 2000;
    if (userScore < 4000) return 3000;
    if (userScore < 5000) return 4000;
    return 5000;
  }

  /// 获取经验条进度百分比
  static double getExpProgressPercent(int userScore) {
    if (userScore >= 5000) return 1.0;
    final next = getNextLevelExp(userScore).toDouble();
    if (next <= 0) return 0;
    return (userScore / next).clamp(0.0, 1.0);
  }

  /// 获取下一等级名称
  static String getNextLevelName(int userScore) {
    final next = getNextLevelExp(userScore);
    return getLevelName(next);
  }
}
