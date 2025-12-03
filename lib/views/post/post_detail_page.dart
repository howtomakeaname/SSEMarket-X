import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/comment_model.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/utils/level_utils.dart';
import 'package:sse_market_x/core/utils/time_utils.dart';
import 'package:sse_market_x/shared/components/cards/comment_card.dart';
import 'package:sse_market_x/shared/components/feedback/comment_input.dart';
import 'package:sse_market_x/shared/components/markdown/latex_markdown.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/components/overlays/reply_modal.dart';
import 'package:sse_market_x/shared/components/overlays/custom_dialog.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/profile/user_profile_page.dart';

class PostDetailPage extends StatefulWidget {
  final int postId;
  final ApiService apiService;
  final bool isEmbedded;
  final PostModel? previewPost;
  final Widget? extraContent; // Displayed below content
  final Widget? topContent;   // Displayed above content (below title)
  final Future<bool> Function(String content)? onSendComment; // Custom comment send handler
  final String postType; // 'post' or 'rating'

  const PostDetailPage({
    super.key,
    required this.postId,
    required this.apiService,
    this.isEmbedded = false,
    this.previewPost,
    this.extraContent,
    this.topContent,
    this.onSendComment,
    this.postType = 'post',
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> with SingleTickerProviderStateMixin {
  PostModel _post = PostModel.empty();
  UserModel _user = UserModel.empty();
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isCommentsLoading = false;
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isSaved = false;
  bool _hasChanges = false; // 标记是否有变化需要刷新上一页

  // 滚动监听相关
  final ScrollController _scrollController = ScrollController();
  bool _showPostTitle = false;

  /// 是否是自己的帖子
  bool get _isOwnPost => _user.phone.isNotEmpty && _user.phone == _post.authorPhone;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPostDetail();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PostDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update preview content when previewPost changes
    if (widget.previewPost != null && widget.previewPost != oldWidget.previewPost) {
      setState(() {
        _post = widget.previewPost!;
      });
    }
  }

  void _onScroll() {
    const threshold = 100.0; // 滚动超过100时显示帖子标题
    final shouldShowTitle = _scrollController.offset > threshold;
    
    if (_showPostTitle != shouldShowTitle) {
      setState(() {
        _showPostTitle = shouldShowTitle;
      });
    }
  }

  Future<void> _loadPostDetail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.previewPost != null) {
        // Preview mode - use provided post data
        final user = await widget.apiService.getUserInfo();
        
        if (!mounted) return;
        
        setState(() {
          _user = user;
          _post = widget.previewPost!;
          _isLiked = false;
          _likeCount = 0;
          _isSaved = false;
          _isLoading = false;
        });
        
        // Don't load comments in preview mode
        return;
      }
      
      // Normal mode - fetch from API
      final user = await widget.apiService.getUserInfo();
      final post = await widget.apiService.getPostDetail(widget.postId, user.phone);

      if (!mounted) return;

      setState(() {
        _user = user;
        _post = post;
        _isLiked = post.isLiked;
        _likeCount = post.likeCount;
        _isSaved = post.isSaved;
        _isLoading = false;
      });

      // 加载评论
      _loadComments();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadComments() async {
    if (_user.phone.isEmpty) return;

    setState(() {
      _isCommentsLoading = true;
    });

    try {
      final comments = await widget.apiService.getComments(
        widget.postId, 
        _user.phone, 
        postType: widget.postType,
      );
      if (!mounted) return;

      setState(() {
        _comments = comments.reversed.toList(); // 参考原项目，反转评论列表
        _isCommentsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCommentsLoading = false;
      });
    }
  }

  Future<void> _onLikeTap() async {
    if (_isLoading) return;

    // 乐观更新 UI
    final wasLiked = _isLiked;
    final oldCount = _likeCount;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : (_likeCount - 1).clamp(0, double.infinity).toInt();
    });

    try {
      final success = await widget.apiService.likePost(_post.id, _user.phone);

      if (success) {
        _hasChanges = true; // 标记有变化
      } else if (mounted) {
        // 回滚
        setState(() {
          _isLiked = wasLiked;
          _likeCount = oldCount;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // 回滚
      setState(() {
        _isLiked = wasLiked;
        _likeCount = oldCount;
      });
    }
  }

  /// 收藏/取消收藏
  Future<void> _onSavePost() async {
    try {
      final success = await widget.apiService.savePost(_post.id, _user.phone);
      if (success && mounted) {
        setState(() {
          _isSaved = !_isSaved;
        });
        SnackBarHelper.show(context, _isSaved ? '已收藏' : '已取消收藏');
      }
    } catch (e) {
      debugPrint('收藏失败: $e');
    }
  }

  /// 删除帖子
  Future<void> _onDeletePost() async {
    // 显示确认对话框
    final confirm = await showCustomDialog(
      context: context,
      title: '确认删除',
      content: '确定要删除这个帖子吗？此操作不可撤销。',
      cancelText: '取消',
      confirmText: '删除',
      confirmColor: AppColors.error,
    );

    if (confirm != true) return;

    try {
      final success = await widget.apiService.deletePost(_post.id);
      if (success && mounted) {
        SnackBarHelper.show(context, '已删除');
        Navigator.of(context).pop({'deleted': true}); // 返回删除标记
      } else if (mounted) {
        SnackBarHelper.show(context, '删除失败');
      }
    } catch (e) {
      debugPrint('删除失败: $e');
      if (mounted) {
        SnackBarHelper.show(context, '删除失败');
      }
    }
  }

  void _onBack() {
    // 返回变化的数据：是否删除、点赞状态、点赞数
    if (_hasChanges) {
      Navigator.of(context).pop({
        'deleted': false,
        'isLiked': _isLiked,
        'likeCount': _likeCount,
        'isSaved': _isSaved,
      });
    } else {
      Navigator.of(context).pop(null);
    }
  }

  void _onUserTap(int userId, String userName, String userAvatar) {
    // Navigate to UserProfilePage
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          apiService: widget.apiService,
          userId: userId,
          isEmbedded: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _onBack();
        }
      },
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          backgroundColor: context.surfaceColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: widget.previewPost == null ? IconButton(
            icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
            onPressed: _onBack,
          ) : null,
          centerTitle: false,
        titleSpacing: widget.previewPost == null ? 0 : 16,
        title: widget.previewPost != null 
          ? Text(
              '预览',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimaryColor,
              ),
            )
          : Stack(
          alignment: Alignment.centerLeft,
          children: [
            AnimatedOpacity(
              opacity: _showPostTitle ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                '详情',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimaryColor,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _showPostTitle ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                _post.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: widget.previewPost == null
            ? [
                if (_isOwnPost)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: _onDeletePost,
                  ),
                // 打分帖子不显示收藏按钮
                if (widget.postType != 'rating')
                  IconButton(
                    icon: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: context.textPrimaryColor,
                    ),
                    onPressed: _onSavePost,
                  ),
                const SizedBox(width: 8), // Add right padding
              ]
            : null,
      ),
      body: _isLoading
          ? const LoadingIndicator.center(message: '加载中...')
          : RefreshIndicator(
              onRefresh: _loadPostDetail,
              color: AppColors.primary,
              backgroundColor: context.surfaceColor,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // 帖子内容区
                    Container(
                      color: context.surfaceColor,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildUserInfo(),
                          const SizedBox(height: 16),
                          _buildTitle(),
                          if (widget.topContent != null) ...[
                            const SizedBox(height: 16),
                            widget.topContent!,
                          ],
                          const SizedBox(height: 12),
                          _buildContent(),
                          if (widget.extraContent != null) ...[
                            const SizedBox(height: 16),
                            widget.extraContent!,
                          ],
                          if (widget.previewPost == null) ...[
                            const SizedBox(height: 16),
                            _buildActionBar(),
                          ],
                        ],
                      ),
                    ),
                    // 评论区 (不在预览模式下显示)
                    if (widget.previewPost == null)
                      _buildCommentSection(),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Row(
      children: [
        // 头像
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UserProfilePage(
                  apiService: widget.apiService,
                  userId: 0,
                  userPhone: _post.authorPhone,
                  isEmbedded: false,
                ),
              ),
            );
          },
          child: SizedBox(
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
                child: _post.authorAvatar.isNotEmpty
                    ? Image.network(
                        _post.authorAvatar,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return SvgPicture.asset(
                            'assets/icons/default_avatar.svg',
                            fit: BoxFit.cover,
                          );
                        },
                      )
                    : SvgPicture.asset(
                        'assets/icons/default_avatar.svg',
                        fit: BoxFit.cover,
                      ),
              ),
              // 身份标识
              if (_post.userIdentity == 'teacher' || _post.userIdentity == 'organization')
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: LevelUtils.getIdentityBackgroundColor(_post.userIdentity),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserProfilePage(
                            apiService: widget.apiService,
                            userId: 0,
                            userPhone: _post.authorPhone,
                            isEmbedded: false,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      _post.authorName.isNotEmpty ? _post.authorName : '匿名用户',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),
                  if (_post.userScore > 0 || _post.userScore == 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      LevelUtils.getLevelName(_post.userScore),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: LevelUtils.getLevelColor(_post.userScore),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                TimeUtils.formatRelativeTime(_post.createdAt),
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

  Widget _buildTitle() {
    if (_post.title.isEmpty) return const SizedBox.shrink();

    return Text(
      _post.title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: context.textPrimaryColor,
        height: 1.3,
      ),
    );
  }

  Widget _buildContent() {
    if (_post.content.isEmpty) return const SizedBox.shrink();

    return LatexMarkdown(
      data: _post.content,
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMetaItem('assets/icons/ic_view.svg', _post.viewCount),
          _buildMetaItem('assets/icons/ic_comment.svg', _post.commentCount),
          GestureDetector(
            onTap: _onLikeTap,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          iconAsset,
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            color ?? context.textSecondaryColor,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 14,
            color: color ?? context.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCommentSection() {
    return Container(
      color: context.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 评论标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                Text(
                  '回复',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_comments.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          // 评论输入框 (不在预览模式下显示)
          if (widget.previewPost == null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: CommentInput(
                postId: widget.postId,
                apiService: widget.apiService,
                onSend: (content) async {
                  bool success;
                  if (widget.onSendComment != null) {
                    success = await widget.onSendComment!(content);
                  } else {
                    success = await widget.apiService.sendComment(
                      content,
                      widget.postId,
                      _user.phone,
                    );
                  }
                  
                  if (success) {
                    _loadComments();
                  }
                  return success;
                },
              ),
            ),
          ],
          // 评论列表 (不在预览模式下显示)
          if (widget.previewPost == null) ...[
            if (_comments.isNotEmpty) const SizedBox(height: 12),
            if (_isCommentsLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_comments.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '暂无评论',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: _comments.map((comment) {
                  return CommentCard(
                    comment: comment,
                    postId: widget.postId,
                    currentUserPhone: _user.phone,
                    onLikeTap: () async {
                      return await widget.apiService.likeComment(comment.id, _user.phone);
                    },
                    onReplyTap: () {
                      _showReplyModal(comment.authorName, comment.id);
                    },
                    onSubReplyTap: (authorName, commentId, {targetCommentId, targetUserName}) {
                      _showReplyModal(authorName, commentId, targetCommentId: targetCommentId, targetUserName: targetUserName);
                    },
                    onSubLikeTap: (subCommentId) async {
                      return await widget.apiService.likeSubComment(subCommentId, _user.phone);
                    },
                    onSubDeleteTap: (subCommentId) async {
                      final confirm = await showCustomDialog(
                        context: context,
                        title: '确认删除',
                        content: '确定要删除这条回复吗？',
                        cancelText: '取消',
                        confirmText: '删除',
                        confirmColor: AppColors.error,
                      );

                      if (confirm == true) {
                        final success = await widget.apiService.deleteSubComment(subCommentId);
                        if (success) {
                          _loadComments();
                          if (mounted) {
                            SnackBarHelper.show(context, '已删除');
                          }
                        } else if (mounted) {
                          SnackBarHelper.show(context, '删除失败');
                        }
                      }
                    },
                    onDeleteTap: () async {
                      final confirm = await showCustomDialog(
                        context: context,
                        title: '确认删除',
                        content: '确定要删除这条评论吗？',
                        cancelText: '取消',
                        confirmText: '删除',
                        confirmColor: AppColors.error,
                      );

                      if (confirm == true) {
                        final success = await widget.apiService.deleteComment(comment.id);
                        if (success) {
                          _loadComments();
                          if (mounted) {
                            SnackBarHelper.show(context, '已删除');
                          }
                        } else if (mounted) {
                          SnackBarHelper.show(context, '删除失败');
                        }
                      }
                    },
                    onUserTap: (userId, userName, userAvatar) {
                      _onUserTap(userId, userName, userAvatar);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 48), // 底部安全区
        ],
      ),
    );
  }

  /// 显示回复弹窗
  void _showReplyModal(String replyToName, int? parentCommentId, {int? targetCommentId, String? targetUserName}) {
    showDialog(
      context: context,
      builder: (context) => ReplyModal(
        postId: widget.postId,
        apiService: widget.apiService,
        replyToName: replyToName,
        parentCommentId: parentCommentId,
        targetCommentId: targetCommentId,
        targetUserName: targetUserName,
      ),
    ).then((result) {
      if (result == true) {
        // 回复成功，刷新评论列表
        _loadComments();
      }
    });
  }
}
