import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/core/utils/level_utils.dart';
import 'package:sse_market_x/shared/components/markdown/latex_markdown.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 帖子预览卡片组件
/// 用于新建帖子时的预览展示，支持在窄屏预览模式和三栏视图中复用
class PostPreviewCard extends StatelessWidget {
  final String title;
  final String content;
  final UserModel user;
  final String? timeText;

  const PostPreviewCard({
    super.key,
    required this.title,
    required this.content,
    required this.user,
    this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.surfaceColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户信息
          _buildUserInfo(context),
          const SizedBox(height: 16),
          // 标题
          if (title.isNotEmpty)
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.textPrimaryColor,
                height: 1.3,
              ),
            ),
          if (title.isNotEmpty) const SizedBox(height: 12),
          // 内容
          if (content.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  '暂无内容预览',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondaryColor,
                  ),
                ),
              ),
            )
          else
            LatexMarkdown(data: content),
        ],
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context) {
    return Row(
      children: [
        // 头像
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.backgroundColor,
                ),
                clipBehavior: Clip.antiAlias,
                child: user.avatar.isNotEmpty
                    ? CachedImage(
                        imageUrl: user.avatar,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        category: CacheCategory.avatar,
                        errorWidget: SvgPicture.asset(
                          'assets/icons/default_avatar.svg',
                          fit: BoxFit.cover,
                        ),
                      )
                    : SvgPicture.asset(
                        'assets/icons/default_avatar.svg',
                        fit: BoxFit.cover,
                      ),
              ),
              // 身份标识
              if (user.identity == 'teacher' || user.identity == 'organization')
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: LevelUtils.getIdentityBackgroundColor(user.identity),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    user.name.isNotEmpty ? user.name : '匿名用户',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  if (user.score >= 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      LevelUtils.getLevelName(user.score),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: LevelUtils.getLevelColor(user.score),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                timeText ?? '刚刚',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
