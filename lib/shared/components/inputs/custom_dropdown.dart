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
        isDense: true,
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: context.textSecondaryColor,
          size: 20,
        ),
        style: TextStyle(
          fontSize: 16,
          color: context.textPrimaryColor,
        ),
        dropdownColor: context.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        elevation: 8,
        menuMaxHeight: 300,
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                itemBuilder(item),
                style: TextStyle(
                  fontSize: 16,
                  color: context.textPrimaryColor,
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
