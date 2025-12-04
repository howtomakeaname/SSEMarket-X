import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/shared/components/inputs/custom_switch.dart';

/// 设置列表项类型
enum SettingsListItemType {
  /// 普通导航项（带右箭头）
  navigation,
  /// 开关项
  toggle,
  /// 自定义尾部组件
  custom,
}

/// 统一的设置列表项组件
/// 解决跨平台高度不一致问题，提供统一的交互体验
class SettingsListItem extends StatelessWidget {
  /// 标题
  final String title;
  
  /// 副标题（可选）
  final String? subtitle;
  
  /// 左侧图标（可选）
  final String? leadingIcon;
  
  /// 左侧图标颜色
  final Color? leadingIconColor;
  
  /// 列表项类型
  final SettingsListItemType type;
  
  /// 点击回调
  final VoidCallback? onTap;
  
  /// 开关状态（仅 toggle 类型）
  final bool? switchValue;
  
  /// 开关变化回调（仅 toggle 类型）
  final ValueChanged<bool>? onSwitchChanged;
  
  /// 自定义尾部组件（仅 custom 类型）
  final Widget? trailing;
  
  /// 标题颜色
  final Color? titleColor;
  
  /// 是否是第一项（影响圆角）
  final bool isFirst;
  
  /// 是否是最后一项（影响圆角）
  final bool isLast;
  
  const SettingsListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leadingIconColor,
    this.type = SettingsListItemType.navigation,
    this.onTap,
    this.switchValue,
    this.onSwitchChanged,
    this.trailing,
    this.titleColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    // 根据位置设置圆角
    BorderRadius? borderRadius;
    if (isFirst && isLast) {
      borderRadius = BorderRadius.circular(12);
    } else if (isFirst) {
      borderRadius = const BorderRadius.vertical(top: Radius.circular(12));
    } else if (isLast) {
      borderRadius = const BorderRadius.vertical(bottom: Radius.circular(12));
    }
    
    final effectiveTitleColor = titleColor ?? context.textPrimaryColor;
    final effectiveLeadingIconColor = leadingIconColor ?? context.textSecondaryColor;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: type == SettingsListItemType.toggle 
            ? (onSwitchChanged != null && switchValue != null 
                ? () => onSwitchChanged!(!switchValue!) 
                : null)
            : onTap,
        borderRadius: borderRadius,
        child: Container(
          constraints: BoxConstraints(
            minHeight: subtitle != null ? 56 : 52, // 有副标题时更高
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: subtitle != null ? 12 : 10, // 有副标题时内边距更大
          ),
          child: Row(
            children: [
              // 左侧图标
              if (leadingIcon != null) ...[
                SvgPicture.asset(
                  leadingIcon!,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    effectiveLeadingIconColor,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              
              // 标题和副标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        color: effectiveTitleColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 尾部组件
              const SizedBox(width: 12),
              _buildTrailing(context),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTrailing(BuildContext context) {
    switch (type) {
      case SettingsListItemType.navigation:
        return SvgPicture.asset(
          'assets/icons/ic_arrow_right.svg',
          width: 18,
          height: 18,
          colorFilter: ColorFilter.mode(
            context.dividerColor,
            BlendMode.srcIn,
          ),
        );
        
      case SettingsListItemType.toggle:
        if (switchValue != null && onSwitchChanged != null) {
          return CustomSwitch(
            value: switchValue!,
            onChanged: onSwitchChanged!,
          );
        }
        return const SizedBox.shrink();
        
      case SettingsListItemType.custom:
        return trailing ?? const SizedBox.shrink();
    }
  }
}

/// 设置列表组（包含多个列表项）
class SettingsListGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  
  const SettingsListGroup({
    super.key,
    required this.children,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final widget = entry.value;
          return Column(
            children: [
              widget,
              if (index < children.length - 1)
                Divider(
                  height: 1,
                  color: context.dividerColor,
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

extension _SettingsListItemContext on BuildContext {
  Color get backgroundColor => Theme.of(this).scaffoldBackgroundColor;
  Color get surfaceColor => Theme.of(this).brightness == Brightness.dark
      ? const Color(0xFF1E1E1E)
      : Colors.white;
  Color get textPrimaryColor => Theme.of(this).brightness == Brightness.dark
      ? Colors.white
      : Colors.black87;
  Color get textSecondaryColor => Theme.of(this).brightness == Brightness.dark
      ? Colors.white70
      : Colors.black54;
  Color get dividerColor => Theme.of(this).brightness == Brightness.dark
      ? Colors.white12
      : Colors.black12;
}
