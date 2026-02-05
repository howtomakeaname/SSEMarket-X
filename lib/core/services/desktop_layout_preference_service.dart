import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 持久化桌面多栏布局宽度设置
class DesktopLayoutPreferenceService {
  DesktopLayoutPreferenceService._internal();
  static final DesktopLayoutPreferenceService _instance =
      DesktopLayoutPreferenceService._internal();
  factory DesktopLayoutPreferenceService() => _instance;

  static const String _keySideWidth = 'desktop_side_menu_width';
  static const String _keyMiddleWidth = 'desktop_middle_column_width';

  static const double defaultSideWidth = 240.0;
  static const double defaultMiddleWidth = 480.0;

  final ValueNotifier<double> sideWidthNotifier =
      ValueNotifier<double>(defaultSideWidth);
  final ValueNotifier<double> middleWidthNotifier =
      ValueNotifier<double>(defaultMiddleWidth);

  SharedPreferences? _prefs;
  bool _initialized = false;

  double get sideWidth => sideWidthNotifier.value;
  double get middleWidth => middleWidthNotifier.value;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    final storedSide = _prefs?.getDouble(_keySideWidth);
    final storedMiddle = _prefs?.getDouble(_keyMiddleWidth);

    sideWidthNotifier.value = storedSide ?? defaultSideWidth;
    middleWidthNotifier.value = storedMiddle ?? defaultMiddleWidth;
    _initialized = true;
  }

  Future<void> setSideWidth(double width) async {
    sideWidthNotifier.value = width;
    await _prefs?.setDouble(_keySideWidth, width);
  }

  Future<void> setMiddleWidth(double width) async {
    middleWidthNotifier.value = width;
    await _prefs?.setDouble(_keyMiddleWidth, width);
  }

  Future<void> reset() async {
    sideWidthNotifier.value = defaultSideWidth;
    middleWidthNotifier.value = defaultMiddleWidth;
    await _prefs?.setDouble(_keySideWidth, defaultSideWidth);
    await _prefs?.setDouble(_keyMiddleWidth, defaultMiddleWidth);
  }
}
