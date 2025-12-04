import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/views/profile/about_page.dart';
import 'package:sse_market_x/views/profile/edit_profile_page.dart';
import 'package:sse_market_x/views/profile/feedback_page.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/utils/level_utils.dart';
import 'package:sse_market_x/views/profile/favorites_page.dart';
import 'package:sse_market_x/views/profile/post_history_page.dart';
import 'package:sse_market_x/views/auth/login_page.dart';
import 'package:sse_market_x/views/profile/settings_page.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/shared/components/overlays/custom_dialog.dart';
import 'package:sse_market_x/shared/components/lists/settings_list_item.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  UserModel _user = UserModel.empty();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
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
      });
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    _buildUserInfoCard(context),
                    _buildMainMenu(context),
                    _buildOtherOptions(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      color: context.surfaceColor,
      child: Text(
        '我的',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: context.textPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context) {
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
          _buildAvatar(context),
          const SizedBox(width: 16),
          Expanded(child: _buildUserTextsAndExp(context)),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final hasAvatar = _user.avatar.isNotEmpty;
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
              imageUrl: _user.avatar,
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
    final name = _user.name.isNotEmpty ? _user.name : '匿名用户';
    final score = _user.score;
    final levelName = LevelUtils.getLevelName(score);
    final nextExp = LevelUtils.getNextLevelExp(score);
    final progress = LevelUtils.getExpProgressPercent(score);
    final intro = _user.intro;

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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondaryColor,
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
    return SettingsListGroup(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        SettingsListItem(
          title: '修改资料',
          leadingIcon: 'assets/icons/ic_edit.svg',
          type: SettingsListItemType.navigation,
          onTap: () {
            Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => EditProfilePage(
                  apiService: widget.apiService,
                  initialUser: _user,
                ),
              ),
            ).then((result) {
              if (result == true) {
                _loadUser();
              }
            });
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
          title: '发帖历史',
          leadingIcon: 'assets/icons/ic_history.svg',
          type: SettingsListItemType.navigation,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostHistoryPage(apiService: widget.apiService),
              ),
            );
          },
        ),
        SettingsListItem(
          title: '设置',
          leadingIcon: 'assets/icons/ic_settings.svg',
          type: SettingsListItemType.navigation,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsPage(
                  apiService: widget.apiService,
                  userEmail: _user.email,
                ),
              ),
            );
          },
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildOtherOptions(BuildContext context) {
    return SettingsListGroup(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        SettingsListItem(
          title: '关于本应用',
          leadingIcon: 'assets/icons/ic_info.svg',
          type: SettingsListItemType.navigation,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AboutPage(),
              ),
            );
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
        ),
        SettingsListItem(
          title: '退出登录',
          leadingIcon: 'assets/icons/ic_logout.svg',
          leadingIconColor: AppColors.error,
          titleColor: AppColors.error,
          type: SettingsListItemType.navigation,
          onTap: () {
            () async {
              final confirm = await showCustomDialog(
                context: context,
                title: '退出登录',
                content: '确定要退出登录吗？',
                cancelText: '取消',
                confirmText: '确定',
                confirmColor: AppColors.error,
              );

              if (confirm == true) {
                // 清除持久化登录数据
                await StorageService().logout();

                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            }();
          },
          isLast: true,
        ),
      ],
    );
  }
}

