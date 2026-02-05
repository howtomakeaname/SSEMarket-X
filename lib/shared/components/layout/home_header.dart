import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/core/services/blur_effect_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class HomeHeader extends StatelessWidget {
  final UserModel user;
  final String currentPartition;
  final List<String> displayPartitions;
  final ScrollController tabScrollController;
  final Map<String, GlobalKey> tabKeys;
  final Function(String) onPartitionTap;
  final VoidCallback onSearchTap;
  final VoidCallback onAddPostTap;
  final VoidCallback? onAvatarTap;
  final bool showAvatar;
  final bool showAddButton;

  const HomeHeader({
    super.key,
    required this.user,
    required this.currentPartition,
    required this.displayPartitions,
    required this.tabScrollController,
    required this.tabKeys,
    required this.onPartitionTap,
    required this.onSearchTap,
    required this.onAddPostTap,
    this.onAvatarTap,
    this.showAvatar = true,
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate horizontal padding based on visible elements
    final horizontalPadding = showAvatar && showAddButton ? 12.0 : 16.0;
    // Adjust vertical padding when elements are hidden for better visual balance
    final verticalPaddingTop = showAvatar && showAddButton ? 4.0 : 8.0;
    final verticalPaddingBottom = showAvatar && showAddButton ? 4.0 : 8.0;
    
    final blurService = BlurEffectService();
    
    return ValueListenableBuilder<bool>(
      valueListenable: blurService.enabledNotifier,
      builder: (context, isBlurEnabled, child) {
        Widget content = Container(
          decoration: BoxDecoration(
            color: isBlurEnabled 
                ? context.blurBackgroundColor.withOpacity(0.82)
                : context.surfaceColor,
            border: Border(
              bottom: BorderSide(
                color: context.dividerColor.withOpacity(0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                // Remove solid color, use transparency from parent
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 
                  verticalPaddingTop + MediaQuery.of(context).padding.top, // Add SafeArea top padding
                  horizontalPadding, 
                  verticalPaddingBottom
                ),
                child: Row(
                  children: [
              if (showAvatar) ...[
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.backgroundColor,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: user.avatar.isNotEmpty
                        ? CachedImage(
                            imageUrl: user.avatar,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            category: CacheCategory.avatar,
                            errorWidget: Icon(Icons.person,
                                size: 18, color: context.dividerColor),
                          )
                        : Icon(Icons.person, size: 18, color: context.dividerColor),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: onSearchTap,
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.backgroundColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/ic_search.svg',
                          width: 16,
                          height: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '在$currentPartition分区内搜索',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showAddButton) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/add_icon.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                  onPressed: onAddPostTap,
                ),
              ],
            ])),
          // Tabs Container
          Container(
            height: 36,
            // Remove solid color
            padding: EdgeInsets.fromLTRB(horizontalPadding - 4, 0, horizontalPadding - 4, 0), // Adjust padding for underline style
            child: SingleChildScrollView(
            controller: tabScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: displayPartitions.asMap().entries.map((entry) {
                final index = entry.key;
                final p = entry.value;
                final selected = p == currentPartition;
                return GestureDetector(
                  key: tabKeys[p],
                  onTap: () => onPartitionTap(p),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            p,
                            style: TextStyle(
                              fontSize: 15,
                              color: selected ? AppColors.primary : context.textSecondaryColor,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        // Indicator
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 3,
                          width: selected ? 20 : 0,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                          margin: const EdgeInsets.only(bottom: 1),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ]),
    );
        
        if (isBlurEnabled) {
          return ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: content,
            ),
          );
        } else {
          return content;
        }
      },
    );
  }
}
