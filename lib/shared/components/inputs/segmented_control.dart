import 'package:flutter/material.dart';

/// iOS 18 风格的胶囊按钮组件（Sliding Segmented Control）
class SegmentedControl<T> extends StatefulWidget {
  final List<T> segments;
  final T selectedSegment;
  final ValueChanged<T> onSegmentChanged;
  final String Function(T) labelBuilder;
  /// 紧凑尺寸（如 28），不传则默认 36
  final double? height;
  /// 文字大小，不传则根据 height 推断（紧凑时 12，默认 14）
  final double? fontSize;

  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selectedSegment,
    required this.onSegmentChanged,
    required this.labelBuilder,
    this.height,
    this.fontSize,
  });

  @override
  State<SegmentedControl<T>> createState() => _SegmentedControlState<T>();
}

class _SegmentedControlState<T> extends State<SegmentedControl<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int? _pressedIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    
    // 按下时轻微缩小
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(int index) {
    setState(() {
      _pressedIndex = index;
    });
    _animationController.forward();
  }

  void _handleTapUp(int index) {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _pressedIndex = null;
        });
      }
    });
    // 触发回调
    widget.onSegmentChanged(widget.segments[index]);
  }

  void _handleTapCancel() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _pressedIndex = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.segments.isEmpty) return const SizedBox();

    final double controlHeight = widget.height ?? 36;
    final double fontSize = widget.fontSize ?? (controlHeight <= 30 ? 12 : 14);
    final double padding = 2;
    final double innerRadius = (controlHeight - padding * 2) / 2;

    final int selectedIndex = widget.segments.indexOf(widget.selectedSegment);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 背景色（与项目主题契合的 iOS 18 风格）
    final backgroundColor = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA);

    // 滑块颜色
    final thumbColor = isDark
        ? const Color(0xFF636366)
        : Colors.white;

    // 文字颜色
    final selectedTextColor = isDark ? Colors.white : Colors.black;
    final unselectedTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      height: controlHeight,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(controlHeight / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double segmentWidth = constraints.maxWidth / widget.segments.length;

          return Stack(
            children: [
              // 1. 滑动的滑块层
              AnimatedAlign(
                alignment: Alignment(
                  widget.segments.length > 1
                      ? -1.0 + (selectedIndex * 2 / (widget.segments.length - 1))
                      : 0.0,
                  0.0,
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastOutSlowIn,
                child: SizedBox(
                  width: segmentWidth,
                  height: double.infinity,
                  child: ScaleTransition(
                    scale: _pressedIndex == selectedIndex
                        ? _scaleAnimation
                        : const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: thumbColor,
                        borderRadius: BorderRadius.circular(innerRadius - 1),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // 2. 交互层
              Row(
                children: List.generate(widget.segments.length, (index) {
                  final segment = widget.segments[index];
                  final isSelected = index == selectedIndex;

                  return Expanded(
                    child: GestureDetector(
                      onTapDown: (_) => _handleTapDown(index),
                      onTapUp: (_) => _handleTapUp(index),
                      onTapCancel: _handleTapCancel,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        alignment: Alignment.center,
                        child: ScaleTransition(
                          scale: _pressedIndex == index
                              ? _scaleAnimation
                              : const AlwaysStoppedAnimation(1.0),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? selectedTextColor : unselectedTextColor,
                              fontFamily: '.SF Pro Text',
                              letterSpacing: -0.2,
                            ),
                            child: Text(
                              widget.labelBuilder(segment),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
