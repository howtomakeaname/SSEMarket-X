import 'package:flutter/material.dart';
import 'package:sse_market_x/core/utils/time_utils.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 分享图片Widget
class ShareImageWidget extends StatelessWidget {
  final String appLogoPath;
  final String postTitle;
  final String postContent;
  final String authorName;
  final String authorAvatar;
  final String createdAt;
  final int postId;

  const ShareImageWidget({
    super.key,
    required this.appLogoPath,
    required this.postTitle,
    required this.postContent,
    required this.authorName,
    required this.authorAvatar,
    required this.createdAt,
    required this.postId,
  });

  /// 截取内容的前部分文字（去除markdown格式）
  String _getPreviewContent(String content) {
    // 移除markdown格式标记
    String text = content
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '') // 移除图片
        .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '') // 移除链接
        .replaceAll(RegExp(r'#{1,6}\s+'), '') // 移除标题标记
        .replaceAllMapped(RegExp(r'\*\*.*?\*\*'), (match) => match.group(0)!.replaceAll('**', '')) // 移除粗体标记但保留文字
        .replaceAllMapped(RegExp(r'\*.*?\*'), (match) => match.group(0)!.replaceAll('*', '')) // 移除斜体标记但保留文字
        .replaceAllMapped(RegExp(r'`.*?`'), (match) => match.group(0)!.replaceAll('`', '')) // 移除代码标记但保留文字
        .replaceAll(RegExp(r'\n+'), ' ') // 将换行符替换为空格
        .trim();

    // 限制长度
    const maxLength = 200;
    if (text.length > maxLength) {
      text = '${text.substring(0, maxLength)}...';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final previewContent = _getPreviewContent(postContent);
    final formattedTime = TimeUtils.formatRelativeTime(createdAt);
    final authorDisplayName = authorName.isNotEmpty ? authorName : '匿名用户';

    return Container(
      width: 600,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：Logo和标题区域
          Container(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Image.asset(
                  appLogoPath,
                  width: 72,
                  height: 72,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.apps,
                        color: AppColors.primary,
                        size: 40,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // 帖子标题
                Text(
                  postTitle.isNotEmpty ? postTitle : '无标题',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 中间：帖子内容
          if (previewContent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
              child: Text(
                previewContent,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF4A4A4A),
                  height: 1.6,
                ),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // 底部：发帖人信息和POST ID
          Container(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // 头像
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE0E0E0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: authorAvatar.isNotEmpty
                      ? CachedImage(
                          imageUrl: authorAvatar,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          category: CacheCategory.avatar,
                          errorWidget: const Icon(
                            Icons.person,
                            size: 24,
                            color: Color(0xFF999999),
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 24,
                          color: Color(0xFF999999),
                        ),
                ),
                const SizedBox(width: 12),
                // 发帖人信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorDisplayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            formattedTime,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF999999),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 2,
                            height: 2,
                            decoration: const BoxDecoration(
                              color: Color(0xFF999999),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'POST #$postId',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
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
