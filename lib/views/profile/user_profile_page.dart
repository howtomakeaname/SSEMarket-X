import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/utils/level_utils.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/chat/chat_detail_page.dart';

class UserProfilePage extends StatefulWidget {
  final ApiService apiService;
  final int userId;
  final String? userPhone;
  final bool isEmbedded;
  final Function(UserModel user)? onStartChat;

  const UserProfilePage({
    super.key,
    required this.apiService,
    required this.userId,
    this.userPhone,
    this.isEmbedded = false,
    this.onStartChat,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    if (widget.userPhone != null && widget.userPhone!.isNotEmpty) {
      // Use phone to get detailed info if available
      final user = await widget.apiService.getDetailedUserInfo(widget.userPhone!);
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } else {
      // Use ID to get detailed info
      final user = await widget.apiService.getInfoById(widget.userId);
       if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    }
  }

  void _handleStartChat() {
    if (_user == null) return;
    
    final currentUser = StorageService().user;
    if (currentUser?.userId == _user!.userId) {
      SnackBarHelper.show(context, '不能和自己聊天哦');
      return;
    }

    if (widget.onStartChat != null) {
      widget.onStartChat!(_user!);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(
            apiService: widget.apiService,
            targetUser: _user!,
            isEmbedded: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.isEmbedded
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          '用户详情',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null || _user!.userId == 0
              ? const Center(child: Text('获取用户信息失败'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildUserInfoCard(context),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _handleStartChat,
                            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                            label: const Text(
                              '发私信',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(),
          const SizedBox(width: 16),
          Expanded(child: _buildUserTextsAndExp()),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final hasAvatar = _user!.avatar.isNotEmpty;
    final defaultAvatar = Container(
      color: context.backgroundColor,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 40, color: context.textSecondaryColor),
    );
    return SizedBox(
      width: 64,
      height: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: hasAvatar
            ? CachedImage(
                imageUrl: _user!.avatar,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                category: CacheCategory.avatar,
                errorWidget: defaultAvatar,
              )
            : defaultAvatar,
      ),
    );
  }

  Widget _buildUserTextsAndExp() {
    final score = _user!.score;
    final levelName = LevelUtils.getLevelName(score);
    final nextExp = LevelUtils.getNextLevelExp(score);
    final progress = LevelUtils.getExpProgressPercent(score);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _user!.name,
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
                color: AppColors.primary.withOpacity(0.1),
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
        const SizedBox(height: 4),
        Text(
          _user!.intro.isNotEmpty ? _user!.intro : '暂无简介',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: context.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 12),
        // Experience Bar
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
          '经验：$score / $nextExp',
          style: TextStyle(fontSize: 12, color: context.textSecondaryColor),
        ),
      ],
    );
  }
}
