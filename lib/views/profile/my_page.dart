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
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/shared/components/overlays/custom_dialog.dart';

const Color appBackgroundColor = AppColors.background;
const Color appSurfaceColor = AppColors.surface;
const Color appTextPrimary = AppColors.textPrimary;
const Color appTextSecondary = AppColors.textSecondary;
const Color appPrimaryColor = AppColors.primary;
const Color appDividerColor = AppColors.divider;

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
      backgroundColor: appBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
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

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      color: appSurfaceColor,
      child: const Text(
        '我的',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: appTextPrimary,
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appSurfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(),
          const SizedBox(width: 16),
          Expanded(child: _buildUserTextsAndExp()),
          const Icon(Icons.chevron_right, size: 18, color: appDividerColor),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final hasAvatar = _user.avatar.isNotEmpty;
    return SizedBox(
      width: 60,
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: hasAvatar
            ? Image.network(_user.avatar, fit: BoxFit.cover)
            : Container(
                color: appBackgroundColor,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/icons/default_avatar.svg',
                  width: 40,
                  height: 40,
                ),
              ),
      ),
    );
  }

  Widget _buildUserTextsAndExp() {
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: appTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: appBackgroundColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                levelName,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: appPrimaryColor,
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
            style: const TextStyle(
              fontSize: 12,
              color: appTextSecondary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '经验: $score / $nextExp',
          style: const TextStyle(fontSize: 12, color: appTextSecondary),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: appDividerColor,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4D4D)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '下一级: ${LevelUtils.getNextLevelName(score)}',
          style: const TextStyle(fontSize: 12, color: appTextSecondary),
        ),
      ],
    );
  }

  Widget _buildMainMenu(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: appSurfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            context,
            title: '修改资料',
            iconSvg: 'assets/icons/ic_edit.svg',
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
          const Divider(height: 1, color: Color(0xFFF0F0F0), indent: 16, endIndent: 16),
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
          const Divider(height: 1, color: Color(0xFFF0F0F0), indent: 16, endIndent: 16),
          _buildMenuItem(
            context,
            title: '设置',
            iconSvg: 'assets/icons/ic_settings.svg',
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
        color: appSurfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            context,
            title: '关于本应用',
            iconSvg: 'assets/icons/ic_info.svg',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AboutPage(),
                ),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0), indent: 16, endIndent: 16),
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
          const Divider(height: 1, color: Color(0xFFF0F0F0), indent: 16, endIndent: 16),
          _buildMenuItem(
            context,
            title: '退出登录',
            iconSvg: 'assets/icons/ic_logout.svg',
            iconColor: const Color(0xFFE53935),
            textColor: const Color(0xFFE53935),
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
    Color iconColor = appTextSecondary,
    Color textColor = appTextPrimary,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: SvgPicture.asset(
        iconSvg,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 16, color: textColor),
      ),
      trailing: SvgPicture.asset(
        'assets/icons/ic_arrow_right.svg',
        width: 18,
        height: 18,
        colorFilter: const ColorFilter.mode(appDividerColor, BlendMode.srcIn),
      ),
      onTap: onTap,
    );
  }
}

