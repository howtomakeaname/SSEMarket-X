import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// iOS风格的胶囊按钮组件（SegmentedControl）
class SegmentedControl<T> extends StatelessWidget {
  final List<T> segments;
  final T selectedSegment;
  final ValueChanged<T> onSegmentChanged;
  final String Function(T) labelBuilder;

  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selectedSegment,
    required this.onSegmentChanged,
    required this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.dividerColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(segments.length, (index) {
          final segment = segments[index];
          final isSelected = segment == selectedSegment;
          
          return Expanded(
            child: GestureDetector(
              onTap: () => onSegmentChanged(segment),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: _getBorderRadius(index, segments.length),
                ),
                alignment: Alignment.center,
                child: Text(
                  labelBuilder(segment),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : context.textSecondaryColor,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 根据索引和总数计算圆角
  BorderRadius _getBorderRadius(int index, int total) {
    if (total == 1) {
      return BorderRadius.circular(16);
    }
    
    if (index == 0) {
      return const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      );
    } else if (index == total - 1) {
      return const BorderRadius.only(
        topRight: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    } else {
      return BorderRadius.zero;
    }
  }
}
