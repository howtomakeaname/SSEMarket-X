import 'package:flutter/material.dart';

import 'package:sse_market_x/core/models/post_model.dart';

class LayoutConfig extends InheritedWidget {
  final bool isDesktop;
  final bool isThreeColumn;
  final Function(int postId, {bool isScorePost, PostModel? post})? onPostTap;

  const LayoutConfig({
    super.key,
    required this.isDesktop,
    required this.isThreeColumn,
    this.onPostTap,
    required super.child,
  });

  static LayoutConfig? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LayoutConfig>();
  }

  @override
  bool updateShouldNotify(LayoutConfig oldWidget) {
    return isDesktop != oldWidget.isDesktop ||
           isThreeColumn != oldWidget.isThreeColumn ||
           onPostTap != oldWidget.onPostTap;
  }
}
