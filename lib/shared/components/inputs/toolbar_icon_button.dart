import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 通用的工具栏图标按钮，统一评论区和发帖页等位置的样式
class ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;
  final double size;

  const ToolbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    final Color iconColor = !enabled
        ? context.dividerColor
        : (isActive ? AppColors.primary : context.textSecondaryColor);

    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: enabled ? onPressed : null,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: AppColors.primary.withOpacity(0.06),
            child: Container(
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withOpacity(0.08)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(6),
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              child: Icon(
                icon,
                size: size,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
