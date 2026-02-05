import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/services/watch_later_service.dart';
import 'package:sse_market_x/core/services/blur_effect_service.dart';
import 'package:sse_market_x/core/utils/level_utils.dart';
import 'package:sse_market_x/shared/components/lists/settings_list_item.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/profile/browse_history_page.dart';
import 'package:sse_market_x/views/profile/edit_profile_page.dart';
import 'package:sse_market_x/views/profile/favorites_page.dart';
import 'package:sse_market_x/views/profile/feedback_page.dart';
import 'package:sse_market_x/views/profile/post_history_page.dart';
import 'package:sse_market_x/views/profile/settings_page.dart';
import 'package:sse_market_x/views/profile/watch_later_page.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  UserModel? _user;
  bool _isLoading = false;
  bool _isWatchLaterEnabled = false;
  final WatchLaterService _watchLaterService = WatchLaterService();

  @override
  void initState() {
    super.initState();
    _initUserData();
    _loadWatchLaterStatus();
  }

  /// 初始化用户数据：先从缓存加载，再后台刷新
  void _initUserData() {
    // 1. 先从 StorageService 获取缓存的用户数据
    final cachedUser = StorageService().user;
    
    // 2. 判断缓存数据是否完整（包含 score 等详细信息）
    // 如果 score 为 0 且 intro 为空，可能是不完整的数据，显示骨架屏
    // 但如果用户确实是新用户（score 真的是 0），也应该显示
    // 所以我们采用更保守的策略：只要有缓存就先显示
    if (cachedUser != null) {
      setState(() {
        _user = cachedUser;
        _isLoading = false;
      });
      // 后台静默刷新最新数据
      _refreshUser();
    } else {
      // 如果没有缓存，显示骨架屏并加载
      setState(() {
        _isLoading = true;
      });
      _refreshUser();
    }
  }

  Future<void> _loadWatchLaterStatus() async {
    final enabled = await _watchLaterService.isEnabled();
    if (mounted) {
      setState(() {
        _isWatchLaterEnabled = enabled;
      });
    }
  }

  /// 刷新用户数据（后台静默更新）
  Future<void> _refreshUser() async {
    try {
      final basic = await widget.apiService.getUserInfo();
      UserModel detailed = basic;
      if (basic.phone.isNotEmpty) {
        final d = await widget.apiService.getDetailedUserInfo(basic.phone);
        detailed = basic.copyWith(score: d.score, intro: d.intro);
      }
      if (!mounted) return;
      setState(() {
        _user = detailed;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 强制重新加载用户数据（用于编辑后刷新）
  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
    });
    await _refreshUser();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 56; // Header height
    final bottomPadding = kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Content Layer
          SingleChildScrollView(
            padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding + 16),
            child: Column(
              children: [
                _buildUserInfoCard(context),
                _buildMainMenu(context),
                _buildOtherOptions(context),
              ],
            ),
          ),
          // Blurred Header Layer
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final blurService = BlurEffectService();
    
    return ValueListenableBuilder<bool>(
      valueListenable: blurService.enabledNotifier,
      builder: (context, isBlurEnabled, _) {
        Widget content = Container(
          height: 56 + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 16,
            right: 16,
          ),
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
          alignment: Alignment.centerLeft,
          child: Text(
            '我的',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
          ),
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

  Widget _buildUserInfoCard(BuildContext context) {
    if (_isLoading) {
      return _buildUserInfoSkeleton(context);
    }

    if (_user == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '加载用户信息失败',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditProfilePage(
                  apiService: widget.apiService,
                  initialUser: _user!,
                ),
              ),
            );
            if (result == true) {
              _loadUser();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatar(context),
                const SizedBox(width: 16),
                Expanded(child: _buildUserTextsAndExp(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final hasAvatar = _user?.avatar.isNotEmpty ?? false;
    final defaultAvatar = SvgPicture.asset(
      'assets/icons/default_avatar.svg',
      fit: BoxFit.cover,
    );
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.backgroundColor,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasAvatar
          ? CachedImage(
              imageUrl: _user!.avatar,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              category: CacheCategory.avatar,
              errorWidget: defaultAvatar,
            )
          : defaultAvatar,
    );
  }

  Widget _buildUserTextsAndExp(BuildContext context) {
    final name = _user?.name.isNotEmpty ?? false ? _user!.name : '匿名用户';
    final score = _user?.score ?? 0;
    final levelName = LevelUtils.getLevelName(score);
    final nextExp = LevelUtils.getNextLevelExp(score);
    final progress = LevelUtils.getExpProgressPercent(score);
    final intro = _user?.intro ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              levelName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: LevelUtils.getLevelColor(score),
              ),
            ),
          ],
        ),
        if (intro.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            intro,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondaryColor,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '经验: $score / $nextExp',
          style: TextStyle(fontSize: 12, color: context.textSecondaryColor),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: context.dividerColor,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4D4D)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '下一级: ${LevelUtils.getNextLevelName(score)}',
          style: TextStyle(fontSize: 12, color: context.textSecondaryColor),
        ),
      ],
    );
  }

  Widget _buildMainMenu(BuildContext context) {
    // 构建菜单项列表
    final menuItems = <Widget>[
      SettingsListItem(
        title: '浏览历史',
        leadingIcon: 'assets/icons/ic_history_view.svg',
        type: SettingsListItemType.navigation,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BrowseHistoryPage(apiService: widget.apiService),
            ),
          );
        },
        isFirst: true,
      ),
      SettingsListItem(
        title: '我的收藏',
        leadingIcon: 'assets/icons/ic_favorite.svg',
        type: SettingsListItemType.navigation,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FavoritesPage(apiService: widget.apiService),
            ),
          );
        },
      ),
      SettingsListItem(
        title: '我的发帖',
        leadingIcon: 'assets/icons/ic_article.svg',
        type: SettingsListItemType.navigation,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostHistoryPage(apiService: widget.apiService),
            ),
          );
        },
        isLast: !_isWatchLaterEnabled, // 如果稍后再看未启用，这是最后一项
      ),
    ];

    // 如果启用了稍后再看，添加该菜单项
    if (_isWatchLaterEnabled) {
      menuItems.add(
        SettingsListItem(
          title: '稍后再看',
          leadingIcon: 'assets/icons/ic_watch_later.svg',
          type: SettingsListItemType.navigation,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WatchLaterPage(apiService: widget.apiService),
              ),
            );
          },
          isLast: true,
        ),
      );
    }

    return SettingsListGroup(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: menuItems,
    );
  }

  Widget _buildOtherOptions(BuildContext context) {
    return SettingsListGroup(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        SettingsListItem(
          title: '设置',
          leadingIcon: 'assets/icons/ic_settings.svg',
          type: SettingsListItemType.navigation,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsPage(
                  apiService: widget.apiService,
                  userEmail: _user?.email ?? '',
                ),
              ),
            );
            // 从设置页面返回后，重新加载稍后再看状态
            _loadWatchLaterStatus();
          },
          isFirst: true,
        ),
        SettingsListItem(
          title: '反馈',
          leadingIcon: 'assets/icons/ic_feedback.svg',
          type: SettingsListItemType.navigation,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FeedbackPage(apiService: widget.apiService),
              ),
            );
          },
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildUserInfoSkeleton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 头像骨架
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.backgroundColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 用户名和等级骨架
                Row(
                  children: [
                    Container(
                      width: 100,
                      height: 18,
                      decoration: BoxDecoration(
                        color: context.backgroundColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 40,
                      height: 14,
                      decoration: BoxDecoration(
                        color: context.backgroundColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 经验文本骨架
                Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: context.backgroundColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                // 经验条骨架
                Container(
                  width: double.infinity,
                  height: 6,
                  decoration: BoxDecoration(
                    color: context.backgroundColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 4),
                // 下一级文本骨架
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: context.backgroundColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

