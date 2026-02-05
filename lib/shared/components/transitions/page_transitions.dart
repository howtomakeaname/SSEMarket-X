import 'package:flutter/material.dart';

/// 优化：
/// 1. 只对新页面做动画，旧页面保持不动（减少一半的动画计算）
/// 2. 使用 SlideTransition 而非自定义 Transform（Flutter 内部优化）
/// 3. 不使用阴影效果（GPU 开销大）
/// 4. 使用 easeOutCubic 曲线，开始快结束慢，感觉更自然丝滑
class CustomPageTransitionsBuilder extends PageTransitionsBuilder {
  const CustomPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 性能优化版本：仅保留最核心的左滑进入动画
    // 移除了视差（SlideOut）和淡入（FadeIn）叠加，大幅降低 GPU 和 Raster 线程压力
    // 解决了旧版 Flutter 引擎和低端设备上的丢帧卡顿问题
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        // 使用标准的 fastOutSlowIn (Material 标准 ease)
        // 这种曲线符合物理直觉，且计算开销小
        curve: Curves.fastOutSlowIn, 
      )),
      child: child,
    );
  }
}

/// 简洁的滑动页面路由
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlidePageRoute({
    required this.page,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideIn = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ));

            return SlideTransition(
              position: slideIn,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
}

/// 淡入页面路由（模态页面）
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadePageRoute({
    required this.page,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 200),
        );
}

/// 从底部滑入页面路由
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpPageRoute({
    required this.page,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ));

            return SlideTransition(
              position: slideAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
}

/// 页面切换主题配置
class AppPageTransitionsTheme {
  static PageTransitionsTheme get theme => const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CustomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CustomPageTransitionsBuilder(),
          TargetPlatform.windows: CustomPageTransitionsBuilder(),
          TargetPlatform.linux: CustomPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CustomPageTransitionsBuilder(),
          TargetPlatform.ohos: CustomPageTransitionsBuilder(),
        },
      );
}
