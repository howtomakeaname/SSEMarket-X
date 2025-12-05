import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/core/models/comment_model.dart';
import 'package:sse_market_x/core/utils/level_utils.dart';
import 'package:sse_market_x/core/utils/time_utils.dart';
import 'package:sse_market_x/shared/components/markdown/latex_markdown.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 评论卡片组件
class CommentCard extends StatefulWidget {
  final CommentModel comment;
  final int postId;
  final String currentUserPhone;
  final Future<bool> Function()? onLikeTap;
  final VoidCallback? onReplyTap;
  final Function(String authorName, int commentId, {int? targetCommentId, String? targetUserName})? onSubReplyTap;
  final Function(int subCommentId)? onSubLikeTap;
  final VoidCallback? onDeleteTap;
  final Function(int subCommentId)? onSubDeleteTap;
  final Function(int userId, String authorName, String authorAvatar)? onUserTap;

  const CommentCard({
    super.key,
    required this.comment,
    required this.postId,
    required this.currentUserPhone,
    this.onLikeTap,
    this.onReplyTap,
    this.onSubReplyTap,
    this.onSubLikeTap,
    this.onDeleteTap,
    this.onSubDeleteTap,
    this.onUserTap,
  });

  @override
  State<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  late bool _isLiked;
  late int _likeCount;
  bool _showSubComments = false;
  final Map<int, bool> _subCommentLikes = {};
  final Map<int, int> _subCommentLikeCounts = {};

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLiked;
    _likeCount = widget.comment.likeCount;
    
    // 初始化子评论点赞状态
    for (final subComment in widget.comment.subComments) {
      _subCommentLikes[subComment.id] = subComment.isLiked;
      _subCommentLikeCounts[subComment.id] = subComment.likeCount;
    }
  }

  @override
  void didUpdateWidget(covariant CommentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.id != widget.comment.id) {
      _isLiked = widget.comment.isLiked;
      _likeCount = widget.comment.likeCount;
      
      // 更新子评论点赞状态
      _subCommentLikes.clear();
      _subCommentLikeCounts.clear();
      for (final subComment in widget.comment.subComments) {
        _subCommentLikes[subComment.id] = subComment.isLiked;
        _subCommentLikeCounts[subComment.id] = subComment.likeCount;
      }
    }
  }

  Future<void> _handleLikeTap() async {
    if (widget.onLikeTap == null) return;

    final wasLiked = _isLiked;
    final oldCount = _likeCount;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : (_likeCount - 1).clamp(0, 999999);
    });

    try {
      final success = await widget.onLikeTap!();
      if (!success && mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = oldCount;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = oldCount;
        });
      }
    }
  }

  bool get _isOwnComment => widget.currentUserPhone == widget.comment.authorPhone;

  /// 处理子评论点赞
  Future<void> _handleSubCommentLike(int subCommentId) async {
    if (widget.onSubLikeTap == null) return;

    final wasLiked = _subCommentLikes[subCommentId] ?? false;
    final oldCount = _subCommentLikeCounts[subCommentId] ?? 0;

    setState(() {
      _subCommentLikes[subCommentId] = !wasLiked;
      _subCommentLikeCounts[subCommentId] = wasLiked ? (oldCount - 1).clamp(0, 999999) : oldCount + 1;
    });

    try {
      await widget.onSubLikeTap!(subCommentId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _subCommentLikes[subCommentId] = wasLiked;
          _subCommentLikeCounts[subCommentId] = oldCount;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserInfo(),
          const SizedBox(height: 8),
          _buildContent(),
          const SizedBox(height: 8),
          _buildActionBar(),
          if (_showSubComments && widget.comment.subComments.isNotEmpty)
            _buildSubComments(),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Row(
      children: [
        // 头像
        GestureDetector(
          onTap: () {
            if (widget.onUserTap != null) {
              widget.onUserTap!(widget.comment.authorId, widget.comment.authorName, widget.comment.authorAvatar);
            }
          },
          child: SizedBox(
            width: 32,
            height: 32,
            child: Stack(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.backgroundColor,
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.comment.authorAvatar.isNotEmpty
                    ? CachedImage(
                        imageUrl: widget.comment.authorAvatar,
                        width: 36,
                        height: 36,
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
              if (widget.comment.authorIdentity == 'teacher' ||
                  widget.comment.authorIdentity == 'organization')
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: LevelUtils.getIdentityBackgroundColor(
                          widget.comment.authorIdentity),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (widget.onUserTap != null) {
                        widget.onUserTap!(widget.comment.authorId, widget.comment.authorName, widget.comment.authorAvatar);
                      }
                    },
                    child: Text(
                      widget.comment.authorName.isNotEmpty
                          ? widget.comment.authorName
                          : '匿名用户',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),
                  if (widget.comment.authorScore >= 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      LevelUtils.getLevelName(widget.comment.authorScore),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: LevelUtils.getLevelColor(widget.comment.authorScore),
                      ),
                    ),
                  ],
                  if (widget.comment.postRating != null && widget.comment.postRating! > 0) ...[
                    const SizedBox(width: 8),
                    Row(
                      children: List.generate(5, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(
                            index < widget.comment.postRating! ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 14,
                            color: index < widget.comment.postRating! ? AppColors.ratingStar : context.textTertiaryColor,
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                TimeUtils.formatRelativeTime(widget.comment.commentTime),
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

  Widget _buildContent() {
    return LatexMarkdown(
      data: widget.comment.content,
      fontSize: 14, // 评论区使用较小字体
      shrinkWrap: true, // 紧凑模式，减少间距
      selectable: true, // 支持长按选择文字
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        // 点赞
        GestureDetector(
          onTap: _handleLikeTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                _isLiked
                    ? 'assets/icons/ic_like_filled.svg'
                    : 'assets/icons/ic_like.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  _isLiked ? Colors.red : context.textSecondaryColor,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$_likeCount',
                style: TextStyle(
                  fontSize: 12,
                  color: _isLiked ? Colors.red : context.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // 回复
        GestureDetector(
          onTap: widget.onReplyTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.reply, size: 16, color: context.textSecondaryColor),
              const SizedBox(width: 4),
              Text(
                '回复',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        // 查看回复
        if (widget.comment.subComments.isNotEmpty) ...[
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () {
              setState(() {
                _showSubComments = !_showSubComments;
              });
            },
            child: Text(
              _showSubComments
                  ? '收起回复'
                  : '查看${widget.comment.subComments.length}条回复',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
        // 删除（自己的评论）
        if (_isOwnComment) ...[
          const SizedBox(width: 16),
          GestureDetector(
            onTap: widget.onDeleteTap,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, size: 16, color: Colors.red),
                SizedBox(width: 4),
                Text(
                  '删除',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubComments() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: widget.comment.subComments.map((subComment) {
          return _buildSubCommentItem(subComment);
        }).toList(),
      ),
    );
  }

  Widget _buildSubCommentItem(SubCommentModel subComment) {
    final isOwnSubComment = widget.currentUserPhone == subComment.authorPhone;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (widget.onUserTap != null) {
                    widget.onUserTap!(subComment.authorId, subComment.authorName, subComment.authorAvatar);
                  }
                },
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Stack(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.surfaceColor,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: subComment.authorAvatar.isNotEmpty
                            ? CachedImage(
                                imageUrl: subComment.authorAvatar,
                                width: 28,
                                height: 28,
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
                      if (subComment.authorIdentity == 'teacher' ||
                          subComment.authorIdentity == 'organization')
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: LevelUtils.getIdentityBackgroundColor(
                                  subComment.authorIdentity),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  if (widget.onUserTap != null) {
                    widget.onUserTap!(subComment.authorId, subComment.authorName, subComment.authorAvatar);
                  }
                },
                child: Text(
                  subComment.authorName.isNotEmpty
                      ? subComment.authorName
                      : '匿名用户',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
              if (subComment.authorScore >= 0) ...[
                const SizedBox(width: 3),
                Text(
                  LevelUtils.getLevelName(subComment.authorScore),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: LevelUtils.getLevelColor(subComment.authorScore),
                  ),
                ),
              ],
              // 显示回复对象
              const SizedBox(width: 4),
              Text(
                '回复',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                subComment.targetUserName.isNotEmpty
                    ? subComment.targetUserName
                    : '层主',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimaryColor,
                ),
              ),
              const Spacer(),
              Text(
                TimeUtils.formatRelativeTime(subComment.commentTime),
                style: TextStyle(
                  fontSize: 11,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LatexMarkdown(
            data: subComment.content,
            fontSize: 13, // 子评论使用更小字体
            shrinkWrap: true, // 紧凑模式
            selectable: true, // 支持长按选择文字
          ),
          const SizedBox(height: 6),
          // 子评论操作栏
          Row(
            children: [
              // 点赞
              GestureDetector(
                onTap: () => _handleSubCommentLike(subComment.id),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (_subCommentLikes[subComment.id] ?? false) ? Icons.favorite : Icons.favorite_border,
                      size: 14,
                      color: (_subCommentLikes[subComment.id] ?? false) ? Colors.red : context.textSecondaryColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${_subCommentLikeCounts[subComment.id] ?? 0}',
                      style: TextStyle(
                        fontSize: 11,
                        color: (_subCommentLikes[subComment.id] ?? false) ? Colors.red : context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 回复
              GestureDetector(
                onTap: () {
                  if (widget.onSubReplyTap != null) {
                    widget.onSubReplyTap!(
                      subComment.authorName,
                      widget.comment.id,
                      targetCommentId: subComment.id,
                      targetUserName: subComment.authorName,
                    );
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.reply, size: 14, color: context.textSecondaryColor),
                    const SizedBox(width: 2),
                    Text(
                      '回复',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              // 删除（自己的子评论）
              if (isOwnSubComment) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    if (widget.onSubDeleteTap != null) {
                      widget.onSubDeleteTap!(subComment.id);
                    }
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, size: 14, color: Colors.red),
                      SizedBox(width: 2),
                      Text(
                        '删除',
                        style: TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
