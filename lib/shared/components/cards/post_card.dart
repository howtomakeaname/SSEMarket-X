import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/utils/level_utils.dart';
import 'package:sse_market_x/core/utils/time_utils.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final bool isDense;
  final bool showRating;
  final bool showContentInDense;
  final bool hidePartition;
  final Widget? topWidget;
  final VoidCallback? onTap;
  final VoidCallback? onAvatarTap;
  final Future<bool> Function()? onLikeTap;

  const PostCard({
    super.key,
    required this.post,
    this.isDense = false,
    this.showRating = false,
    this.showContentInDense = false,
    this.hidePartition = false,
    this.topWidget,
    this.onTap,
    this.onAvatarTap,
    this.onLikeTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likeCount = widget.post.likeCount;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _isLiked = widget.post.isLiked;
      _likeCount = widget.post.likeCount;
    }
  }

  Future<void> _handleLikeTap() async {
    if (widget.onLikeTap == null) return;

    // 乐观更新
    final wasLiked = _isLiked;
    final oldCount = _likeCount;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : (_likeCount - 1).clamp(0, 999999);
    });

    try {
      final success = await widget.onLikeTap!();
      if (!success && mounted) {
        // API 失败，回滚
        setState(() {
          _isLiked = wasLiked;
          _likeCount = oldCount;
        });
      }
    } catch (e) {
      // 异常回滚
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = oldCount;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        child: Padding(
          padding: widget.isDense ? const EdgeInsets.all(12) : const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.topWidget != null) ...[
                widget.topWidget!,
                const SizedBox(height: 8),
              ],
              if (!widget.isDense) ...[
                _buildHeader(),
                const SizedBox(height: 12),
              ],
              _buildContent(),
              const SizedBox(height: 12),
              _buildActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final authorName = widget.post.authorName.isNotEmpty ? widget.post.authorName : '匿名用户';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中
      children: [
        _buildAvatarWithIdentity(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    authorName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  // 等级显示
                  if (widget.post.userScore > 0 || widget.post.userScore == 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      LevelUtils.getLevelName(widget.post.userScore),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: LevelUtils.getLevelColor(widget.post.userScore),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                TimeUtils.formatRelativeTime(widget.post.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        // 移除右上角 More Icon，与鸿蒙版保持一致
        if (widget.showRating) 
          _buildRatingBadge(),
      ],
    );
  }

  Widget _buildRatingBadge() {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [context.surfaceColor.withOpacity(0.95), context.surfaceColor.withOpacity(0.9)]
              : [Colors.white.withOpacity(0.95), const Color(0xFFF8FAFC).withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.dividerColor.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              widget.post.rating.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white, 
              ),
            ),
          ),
          const SizedBox(width: 2),
          const Text(
            '★',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF4A90E2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithIdentity() {
    return GestureDetector(
      onTap: widget.onAvatarTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          children: [
            _buildAvatar(),
            // 身份标识
            if (widget.post.userIdentity == 'teacher' || widget.post.userIdentity == 'organization')
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: LevelUtils.getIdentityBackgroundColor(widget.post.userIdentity),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.backgroundColor,
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.post.authorAvatar.isNotEmpty
          ? CachedImage(
              imageUrl: widget.post.authorAvatar,
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
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.post.title.isNotEmpty) ...[
          Text(
            widget.post.title,
            style: TextStyle(
              fontSize: widget.isDense ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
              height: 1.3,
            ),
            maxLines: widget.isDense ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: widget.isDense ? 4 : 8),
        ],
        // 内容预览：非紧凑模式显示，或者紧凑模式下显式开启显示
        if (widget.post.content.isNotEmpty && (!widget.isDense || widget.showContentInDense)) ...[
          Text(
            widget.post.content,
            maxLines: widget.isDense ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
              height: 1.5,
            ),
          ),
        ],
        // 如果有 topWidget（通常包含了分区信息），则不在这里重复显示分区
        if (widget.post.partition.isNotEmpty && widget.topWidget == null && !widget.hidePartition) ...[
          SizedBox(height: widget.isDense ? 4 : 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#${widget.post.partition}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionBar() {
    // 使用 GestureDetector 包裹整个工具栏，阻止点击事件冒泡到卡片
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // 空回调，阻止事件冒泡
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 均匀分布
        children: [
          // 浏览量
          _buildMetaItem(
            'assets/icons/ic_view.svg',
            widget.post.viewCount,
          ),
          
          // 评论量
          _buildMetaItem(
            'assets/icons/ic_comment.svg',
            widget.post.commentCount,
          ),
          
          // 点赞量 - 使用本地状态实现乐观更新
          GestureDetector(
            onTap: _handleLikeTap,
            child: _buildMetaItem(
              _isLiked ? 'assets/icons/ic_like_filled.svg' : 'assets/icons/ic_like.svg',
              _likeCount,
              color: _isLiked ? Colors.red : context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String iconAsset, int count, {Color? color}) {
    final defaultColor = context.textSecondaryColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          iconAsset,
          width: 18,
          height: 18,
          colorFilter: ColorFilter.mode(
            color ?? defaultColor,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 13,
            color: color ?? defaultColor,
          ),
        ),
      ],
    );
  }
}
