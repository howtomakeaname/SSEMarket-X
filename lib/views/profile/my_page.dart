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
import 'package:sse_market_x/views/auth/login_page.dart';
import 'package:sse_market_x/views/profile/settings_page.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/shared/components/overlays/custom_dialog.dart';

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
          Icon(Icons.chevron_right, size: 18, color: context.dividerColor),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final hasAvatar = _user.avatar.isNotEmpty;
    return SizedBox(
      width: 60,
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: hasAvatar
            ? CachedImage(
                imageUrl: _user.avatar,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                category: CacheCategory.avatar,
                errorWidget: _buildDefaultAvatar(context),
              )
            : _buildDefaultAvatar(context),
      ),
    );
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    return Container(
      color: context.backgroundColor,
      alignment: Alignment.center,
      child: SvgPicture.asset(
        'assets/icons/default_avatar.svg',
        width: 40,
        height: 40,
      ),
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
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.backgroundColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                levelName,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            context,
            title: '修改资料',
            iconSvg: 'assets/icons/ic_edit.svg',
            isFirst: true,
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
          ),
          Divider(height: 1, color: context.dividerColor, indent: 16, endIndent: 16),
          _buildMenuItem(
            context,
            title: '我的收藏',
            iconSvg: 'assets/icons/ic_favorite.svg',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FavoritesPage(apiService: widget.apiService),
                ),
              );
            },
          ),
          Divider(height: 1, color: context.dividerColor, indent: 16, endIndent: 16),
          _buildMenuItem(
            context,
            title: '设置',
            iconSvg: 'assets/icons/ic_settings.svg',
            isLast: true,
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
          ),
        ],
      ),
    );
  }

  Widget _buildOtherOptions(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            context,
            title: '关于本应用',
            iconSvg: 'assets/icons/ic_info.svg',
            isFirst: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AboutPage(),
                ),
              );
            },
          ),
          Divider(height: 1, color: context.dividerColor, indent: 16, endIndent: 16),
          _buildMenuItem(
            context,
            title: '反馈',
            iconSvg: 'assets/icons/ic_feedback.svg',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FeedbackPage(apiService: widget.apiService),
                ),
              );
            },
          ),
          Divider(height: 1, color: context.dividerColor, indent: 16, endIndent: 16),
          _buildMenuItem(
            context,
            title: '退出登录',
            iconSvg: 'assets/icons/ic_logout.svg',
            iconColor: AppColors.error,
            textColor: AppColors.error,
            isLast: true,
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
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required String iconSvg,
    Color? iconColor,
    Color? textColor,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final effectiveIconColor = iconColor ?? context.textSecondaryColor;
    final effectiveTextColor = textColor ?? context.textPrimaryColor;
    
    // 根据位置设置圆角
    BorderRadius? borderRadius;
    if (isFirst && isLast) {
      borderRadius = BorderRadius.circular(12);
    } else if (isFirst) {
      borderRadius = const BorderRadius.vertical(top: Radius.circular(12));
    } else if (isLast) {
      borderRadius = const BorderRadius.vertical(bottom: Radius.circular(12));
    }
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SvgPicture.asset(
                iconSvg,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(effectiveIconColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 16, color: effectiveTextColor),
                ),
              ),
              SvgPicture.asset(
                'assets/icons/ic_arrow_right.svg',
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(context.dividerColor, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

