import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/services/websocket_service.dart';
import 'package:sse_market_x/core/utils/level_utils.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/core/services/notice_service.dart';

class SideMenu extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTap;
  final VoidCallback onAvatarTap;
  final ApiService apiService;

  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
    required this.onAvatarTap,
    required this.apiService,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  int _unreadCount = 0;
  int _noticeUnreadCount = 0;
  StreamSubscription<int>? _unreadSubscription;
  StreamSubscription<int>? _noticeUnreadSubscription;

  @override
  void initState() {
    super.initState();
    _initUnreadListener();
    _fetchNoticeUnreadCount();
  }

  Future<void> _fetchNoticeUnreadCount() async {
    try {
      final noticeNum = await widget.apiService.getNoticeNum();
      final noticeService = NoticeService();
      noticeService.updateUnreadCount(noticeNum.unreadTotalNum);
      
      // 监听通知未读数变化
      _noticeUnreadSubscription?.cancel();
      _noticeUnreadSubscription = noticeService.unreadCount.listen((count) {
        if (mounted) {
          setState(() {
            _noticeUnreadCount = count;
          });
        }
      });
      
      if (mounted) {
        setState(() {
          _noticeUnreadCount = noticeNum.unreadTotalNum;
        });
      }
    } catch (e) {
      debugPrint('SideMenu fetch notice count error: $e');
    }
  }

  void _initUnreadListener() {
    try {
      final ws = WebSocketService();
      _unreadCount = ws.totalUnreadCount;
      _unreadSubscription = ws.unreadCount.listen((count) {
        if (mounted) {
          setState(() {
            _unreadCount = count;
          });
        }
      });
    } catch (e) {
      // Ignore errors during initialization
      debugPrint('SideMenu unread listener error: $e');
    }
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    _noticeUnreadSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          right: BorderSide(color: context.dividerColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header / Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images/logo.png',
                width: 64,
                height: 64,
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Menu Items
          _buildMenuItem(0, '首页', iconSvg: 'assets/icons/home_normal.svg', iconSvgSelected: 'assets/icons/home_selected.svg'),
          _buildMenuItem(1, '新建', iconData: Icons.add_circle_outline, iconDataSelected: Icons.add_circle),
          _buildMenuItem(2, '打分', iconSvg: 'assets/icons/todo_normal_new.svg', iconSvgSelected: 'assets/icons/todo_selected_new.svg'),
          _buildMenuItem(3, '闲置', iconSvg: 'assets/icons/shop_normal.svg', iconSvgSelected: 'assets/icons/shop_selected.svg'),
          _buildMenuItem(4, '消息', iconSvg: 'assets/icons/notice_normal.svg', iconSvgSelected: 'assets/icons/notice_selected.svg', badgeCount: _noticeUnreadCount + _unreadCount),
          
          const Spacer(),
          
          Divider(height: 1, color: context.dividerColor),
          // User Avatar / My Page - 响应用户信息变更
          ValueListenableBuilder<UserModel?>(
            valueListenable: storage.userNotifier,
            builder: (context, user, _) {
              return InkWell(
                onTap: widget.onAvatarTap,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.backgroundColor,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: user?.avatar.isNotEmpty == true
                            ? CachedImage(
                                imageUrl: user!.avatar,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                category: CacheCategory.avatar,
                                errorWidget: Icon(Icons.person, color: context.textSecondaryColor),
                              )
                            : Icon(Icons.person, color: context.textSecondaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? '未登录',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: context.textPrimaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (user != null)
                              Text(
                                LevelUtils.getLevelName(user.score),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, String label, {String? iconSvg, String? iconSvgSelected, IconData? iconData, IconData? iconDataSelected, int badgeCount = 0}) {
    final isSelected = widget.selectedIndex == index;
    return InkWell(
      onTap: () => widget.onItemTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.08) : null,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (iconSvg != null)
                  SvgPicture.asset(
                    isSelected ? (iconSvgSelected ?? iconSvg) : iconSvg,
                    width: 24,
                    height: 24,
                  )
                else if (iconData != null)
                  Icon(
                    isSelected ? (iconDataSelected ?? iconData) : iconData,
                    size: 24,
                    color: isSelected ? AppColors.primary : context.textSecondaryColor,
                  ),
                // 未读消息红点
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                      child: Center(
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : context.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
