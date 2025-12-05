import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 下拉选项
class TeacherOption {
  final String? value;
  final String label;
  final int? count;

  const TeacherOption({
    required this.value,
    required this.label,
    this.count,
  });
}

/// 教师下拉选择器（带浮层样式）
class TeacherDropdown extends StatefulWidget {
  final List<TeacherOption> options;
  final String? value;
  final String hint;
  final ValueChanged<String?>? onChanged;
  final bool showCount;

  const TeacherDropdown({
    super.key,
    required this.options,
    this.value,
    this.hint = '请选择',
    this.onChanged,
    this.showCount = false,
  });

  @override
  State<TeacherDropdown> createState() => _TeacherDropdownState();
}

class _TeacherDropdownState extends State<TeacherDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  @override
  void dispose() {
    // 直接移除 overlay，不调用 setState
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 点击外部关闭
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // 下拉列表
          Positioned(
            width: size.width + 40, // 稍微宽一点
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(-20, size.height + 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: context.surfaceColor.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.dividerColor.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: widget.options.length,
                      itemBuilder: (context, index) {
                        final option = widget.options[index];
                        final isSelected = option.value == widget.value;
                        return InkWell(
                          onTap: () {
                            widget.onChanged?.call(option.value);
                            _removeOverlay();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.08)
                                : null,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected
                                          ? AppColors.primary
                                          : context.textPrimaryColor,
                                      fontWeight: isSelected
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (widget.showCount && option.count != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.backgroundColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${option.count}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.textTertiaryColor,
                                      ),
                                    ),
                                  ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  String get _displayText {
    if (widget.value == null) return widget.hint;
    final selected = widget.options.where((o) => o.value == widget.value);
    if (selected.isEmpty) return widget.hint;
    return selected.first.label;
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null;
    
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: hasValue || _isOpen
                ? AppColors.primary
                : context.backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _displayText,
                style: TextStyle(
                  fontSize: 14,
                  color: hasValue || _isOpen
                      ? Colors.white
                      : context.textPrimaryColor,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 2),
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: hasValue || _isOpen
                      ? Colors.white
                      : context.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
