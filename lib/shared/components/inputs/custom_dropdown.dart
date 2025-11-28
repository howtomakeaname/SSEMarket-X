import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 自定义下拉选择器
class CustomDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) itemBuilder;
  final ValueChanged<T?>? onChanged;
  final String? hint;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.itemBuilder,
    this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        isDense: true, // 减小整体上下 padding
        icon: const Icon(
          Icons.keyboard_arrow_down,
          color: AppColors.textSecondary,
          size: 20,
        ),
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
        dropdownColor: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        elevation: 8,
        menuMaxHeight: 300,
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2), // 更小的上下内边距
              child: Text(
                itemBuilder(item),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
