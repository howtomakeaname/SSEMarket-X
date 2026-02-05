import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sse_market_x/core/services/blur_effect_service.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 模糊背景容器
/// 根据用户设置决定是否显示模糊效果
class BlurContainer extends StatelessWidget {
  final Widget? child;
  final double sigmaX;
  final double sigmaY;
  final double opacity;
  final BoxDecoration? decoration;
  final Border? border;

  const BlurContainer({
    super.key,
    this.child,
    this.sigmaX = 20,
    this.sigmaY = 20,
    this.opacity = 0.82,
    this.decoration,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final blurService = BlurEffectService();
    
    return ValueListenableBuilder<bool>(
      valueListenable: blurService.enabledNotifier,
      builder: (context, isBlurEnabled, _) {
        final baseDecoration = decoration ?? BoxDecoration(
          color: isBlurEnabled 
              ? context.blurBackgroundColor.withOpacity(opacity)
              : context.blurBackgroundColor, // 不透明
          border: border ?? Border(
            bottom: BorderSide(
              color: context.dividerColor.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        );

        if (isBlurEnabled) {
          return ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
              child: Container(
                decoration: baseDecoration,
                child: child,
              ),
            ),
          );
        } else {
          // 不启用模糊时，使用纯色背景
          return Container(
            decoration: baseDecoration.copyWith(
              color: context.surfaceColor,
            ),
            child: child,
          );
        }
      },
    );
  }
}

/// 模糊 FlexibleSpace 用于 AppBar
/// 包含完整的模糊效果和底部边框
class BlurFlexibleSpace extends StatelessWidget {
  const BlurFlexibleSpace({super.key});

  @override
  Widget build(BuildContext context) {
    final blurService = BlurEffectService();
    
    return ValueListenableBuilder<bool>(
      valueListenable: blurService.enabledNotifier,
      builder: (context, isBlurEnabled, _) {
        if (isBlurEnabled) {
          return ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: context.blurBackgroundColor.withOpacity(0.82),
                  border: Border(
                    bottom: BorderSide(
                      color: context.dividerColor.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          return Container(
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(
                bottom: BorderSide(
                  color: context.dividerColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
