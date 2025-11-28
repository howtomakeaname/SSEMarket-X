import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF007DFF);
  static const Color secondary = Color(0xFF4CAF50);
  static const Color background = Color(0xFFF1F3F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFF9800);

  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);

  static const Color divider = Color(0xFFE0E0E0);

  // Rating Colors - Reverted to Blue Scheme
  static const Color ratingStar = primary; // Unified with primary color
  static const Color ratingText = primary; // Unified with primary color
  static Color ratingBg = primary.withOpacity(0.1); // Light blue background
}
