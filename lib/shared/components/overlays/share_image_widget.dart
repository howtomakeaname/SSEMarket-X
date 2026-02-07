import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
      decoration: const BoxDecoration(
        color: Colors.white,
        // 生成图片时使用方角，预览时通过外层 ClipRRect 添加圆角
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：Logo
          Row(
            children: [
              Image.asset(
                appLogoPath,
                width: 64, // 适当大小
                height: 64,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16), // 圆角
                    ),
                    child: Icon(
                      Icons.apps,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  );
                },
              ),
              const Spacer(),
              // 可选：添加应用名称或 slogan
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'SSE Market',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A).withOpacity(0.8),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '软工集市',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF1A1A1A).withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // 标题
          Text(
            postTitle.isNotEmpty ? postTitle : '无标题',
            style: const TextStyle(
              fontSize: 28, // 加大标题字号
              fontWeight: FontWeight.w800, // 更粗的字体
              color: Color(0xFF1A1A1A),
              height: 1.2,
              letterSpacing: -0.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          if (previewContent.isNotEmpty) ...[
            const SizedBox(height: 16),
            // 内容预览
            Text(
              previewContent,
              style: const TextStyle(
                fontSize: 17, // 适中正文字号
                color: Color(0xFF4A4A4A),
                height: 1.6,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          
          const SizedBox(height: 32),
          
          // 分割线
          Divider(color: Colors.black.withOpacity(0.06), height: 1),
          
          const SizedBox(height: 24),
          
          // 底部信息
          Row(
            children: [
              // 头像
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF2F2F7), // iOS 风格灰色背景
                ),
                clipBehavior: Clip.antiAlias,
                child: authorAvatar.isNotEmpty
                    ? CachedImage(
                        imageUrl: authorAvatar,
                        width: 44,
                        height: 44,
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
                    const SizedBox(height: 2),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF1A1A1A).withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // POST ID 标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'POST #$postId',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
