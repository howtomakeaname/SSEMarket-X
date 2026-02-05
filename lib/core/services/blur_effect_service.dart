import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 模糊效果设置服务
/// 控制全局的背景模糊效果开关
class BlurEffectService {
  static final BlurEffectService _instance = BlurEffectService._internal();
  factory BlurEffectService() => _instance;
  BlurEffectService._internal();

  static const String _keyBlurEnabled = 'blur_effect_enabled';
  
  // 使用 ValueNotifier 实现响应式更新
  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);

  /// 是否启用模糊效果
  bool get isEnabled => enabledNotifier.value;

  /// 初始化服务，从本地存储读取设置
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyBlurEnabled) ?? true; // 默认启用
    enabledNotifier.value = enabled;
  }

  /// 设置是否启用模糊效果
  Future<void> setEnabled(bool enabled) async {
    enabledNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBlurEnabled, enabled);
  }

  /// 切换模糊效果状态
  Future<void> toggle() async {
    await setEnabled(!isEnabled);
  }
}
