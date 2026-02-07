import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/comment_model.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/core/services/watch_later_service.dart';
import 'package:sse_market_x/core/services/blur_effect_service.dart';
import 'package:sse_market_x/core/utils/level_utils.dart';
import 'package:sse_market_x/core/utils/time_utils.dart';
import 'package:sse_market_x/shared/components/cards/comment_card.dart';
import 'package:sse_market_x/shared/components/feedback/comment_input.dart';
import 'package:sse_market_x/shared/components/loading/skeleton_loader.dart';
import 'package:sse_market_x/shared/components/markdown/latex_markdown.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/components/overlays/custom_dialog.dart';
import 'package:sse_market_x/shared/components/overlays/reply_modal.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/profile/user_profile_page.dart';

class PostDetailPage extends StatefulWidget {
  final int postId;
  final ApiService apiService;
  final bool isEmbedded;
  final PostModel? previewPost; // 预览模式或初始数据
  final PostModel? initialPost; // 从列表传递的初始数据（用于优化加载体验）
  final Widget? extraContent; // Displayed below content
  final Widget? topContent; // Displayed above content (below title)
  final Future<bool> Function(String content)?
      onSendComment; // Custom comment send handler
  final String postType; // 'post' or 'rating'

  const PostDetailPage({
    super.key,
    required this.postId,
    required this.apiService,
    this.isEmbedded = false,
    this.previewPost,
    this.initialPost,
    this.extraContent,
    this.topContent,
    this.onSendComment,
    this.postType = 'post',
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage>
    with SingleTickerProviderStateMixin {
  late PostModel _post;
  UserModel _user = UserModel.empty();
  List<CommentModel> _comments = [];
  late bool _isLoading;
  bool _isCommentsLoading = false;
  late bool _isLiked;
  late int _likeCount;
  late bool _isSaved;
  bool _hasChanges = false; // 标记是否有变化需要刷新上一页
  bool _isInWatchLater = false; // 是否已添加到稍后再看
  bool _isWatchLaterEnabled = false; // 稍后再看功能是否启用
  final GlobalKey _commentSectionKey = GlobalKey();

  // 滚动监听相关
  final ScrollController _scrollController = ScrollController();
  bool _showPostTitle = false;
  final WatchLaterService _watchLaterService = WatchLaterService();

  /// 是否是自己的帖子
  bool get _isOwnPost =>
      _user.phone.isNotEmpty && _user.phone == _post.authorPhone;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // 初始化状态 - 如果有初始数据，直接使用；否则显示 loading
    if (widget.initialPost != null) {
      _post = widget.initialPost!;
      _isLiked = widget.initialPost!.isLiked;
      _likeCount = widget.initialPost!.likeCount;
      _isSaved = widget.initialPost!.isSaved;
      _isLoading = false; // 有初始数据时不显示 loading
      _isCommentsLoading = true; // 评论正在加载，显示骨架屏
    } else {
      _post = PostModel.empty();
      _isLiked = false;
      _likeCount = 0;
      _isSaved = false;
      _isLoading = true; // 没有初始数据时显示 loading
      _isCommentsLoading = false; // 整个页面都在 loading，不需要单独显示评论 loading
    }

    _loadPostDetail();
  }

  Widget _buildBottomBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: BlurEffectService().enabledNotifier,
      builder: (context, isBlurEnabled, _) {
        final commentLabel = '${_post.commentCount}';

        final barContent = Container(
          decoration: BoxDecoration(
            color: isBlurEnabled
                ? context.blurBackgroundColor.withOpacity(0.82)
                : context.surfaceColor,
            border: Border(
              top: BorderSide(
                color:
                    context.dividerColor.withOpacity(isBlurEnabled ? 0.3 : 0.2),
                width: 0.5,
              ),
            ),
            boxShadow: isBlurEnabled
                ? null
                : [
                    BoxShadow(
                      color:
                          Colors.black.withOpacity(context.isDark ? 0.4 : 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _isLoading ? null : _openReplyComposer,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: context.backgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.dividerColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '说点什么…',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 0),
                _buildBottomAction(
                  icon: SvgPicture.asset(
                    _isLiked
                        ? 'assets/icons/ic_like_filled.svg'
                        : 'assets/icons/ic_like.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      _isLiked ? Colors.red : context.textSecondaryColor,
                      BlendMode.srcIn,
                    ),
                  ),
                  text: '$_likeCount',
                  textColor: _isLiked ? Colors.red : null,
                  onTap: _isLoading ? null : _onLikeTap,
                ),
                const SizedBox(width: 0),
                _buildBottomAction(
                  icon: Icon(
                    _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    size: 22,
                    color: _isSaved
                        ? AppColors.primary
                        : context.textSecondaryColor,
                  ),
                  text: _isSaved ? '已收藏' : '收藏',
                  textColor: _isSaved ? AppColors.primary : null,
                  onTap: _isLoading ? null : _onSavePost,
                ),
                const SizedBox(width: 0),
                _buildBottomAction(
                  icon: SvgPicture.asset(
                    'assets/icons/ic_comment.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      context.textSecondaryColor,
                      BlendMode.srcIn,
                    ),
                  ),
                  text: commentLabel,
                  onTap: _isLoading ? null : _scrollToComments,
                ),
              ],
            ),
          ),
        );

        if (isBlurEnabled) {
          return ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: barContent,
            ),
          );
        }

        return barContent;
      },
    );
  }

  Widget _buildBottomAction({
    required Widget icon,
    required String text,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: textColor ??
                    (enabled
                        ? context.textSecondaryColor
                        : context.textTertiaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openReplyComposer() {
    if (widget.previewPost != null) return;
    final replyToName = _post.authorName.isNotEmpty ? _post.authorName : '楼主';
    _showReplyModal(replyToName, null);
  }

  void _scrollToComments() {
    if (widget.previewPost != null) return;
    if (!_scrollController.hasClients) return;

    final sectionContext = _commentSectionKey.currentContext;
    if (sectionContext == null) return;

    final box = sectionContext.findRenderObject() as RenderBox?;
    if (box == null) return;

    final offset = box.localToGlobal(Offset.zero);
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    final target = (_scrollController.offset + offset.dy - topPadding - 16)
        .clamp(0.0, _scrollController.position.maxScrollExtent);

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
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
    if (widget.previewPost != null &&
        widget.previewPost != oldWidget.previewPost) {
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
    // 如果没有初始数据，显示 loading
    if (widget.initialPost == null) {
      setState(() {
        _isLoading = true;
      });
    }

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

      // 如果有初始数据，先更新用户信息，不重新获取帖子详情
      if (widget.initialPost != null && mounted) {
        setState(() {
          _user = user;
          // 保持使用初始数据，不覆盖
        });
      }

      final post =
          await widget.apiService.getPostDetail(widget.postId, user.phone);

      if (!mounted) return;

      // 检查稍后再看功能是否启用
      final isWatchLaterEnabled = await _watchLaterService.isEnabled();

      // 如果启用了，检查是否已添加到稍后再看
      bool isInWatchLater = false;
      if (isWatchLaterEnabled) {
        isInWatchLater = await _watchLaterService.hasPost(widget.postId);
      }

      setState(() {
        _user = user;
        _post = post;
        _isLiked = post.isLiked;
        _likeCount = post.likeCount;
        _isSaved = post.isSaved;
        _isWatchLaterEnabled = isWatchLaterEnabled;
        _isInWatchLater = isInWatchLater;
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
      _likeCount = _isLiked
          ? _likeCount + 1
          : (_likeCount - 1).clamp(0, double.infinity).toInt();
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
          _hasChanges = true;
        });
        SnackBarHelper.show(context, _isSaved ? '已收藏' : '已取消收藏');
      }
    } catch (e) {
      debugPrint('收藏失败: $e');
    }
  }

  /// 添加到稍后再看
  Future<void> _onAddToWatchLater() async {
    try {
      final added = await _watchLaterService.addPost(_post);
      if (added && mounted) {
        setState(() {
          _isInWatchLater = true;
        });
        // 显示提示
        if (mounted) {
          SnackBarHelper.show(
            context,
            '已添加到稍后再看，可在"我的"页面查看',
          );
        }
      } else if (!added && mounted) {
        SnackBarHelper.show(context, '该帖子已在稍后再看列表中');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.show(context, '添加失败');
      }
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
    // 检查是否可以返回，如果不能（如深层链接直接打开），则跳转到首页
    if (!Navigator.of(context).canPop()) {
      context.go('/');
      return;
    }

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
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _onBack();
        }
      },
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor:
              Colors.transparent, // Important: Transparency for blur
          flexibleSpace: ValueListenableBuilder<bool>(
            valueListenable: BlurEffectService().enabledNotifier,
            builder: (context, isBlurEnabled, _) {
              Widget content = Container(
                decoration: BoxDecoration(
                  color: isBlurEnabled
                      ? context.blurBackgroundColor.withOpacity(0.82)
                      : context.surfaceColor,
                  border: Border(
                    bottom: BorderSide(
                      color: context.dividerColor.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                ),
              );

              if (isBlurEnabled) {
                return ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: content,
                  ),
                );
              } else {
                return content;
              }
            },
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leading: widget.previewPost == null
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
                  onPressed: _onBack,
                )
              : null,
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
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.ease,
                    );
                  },
                  child: Stack(
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
                ),
          actions: widget.previewPost == null
              ? [
                  if (_isOwnPost)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.error),
                      onPressed: _onDeletePost,
                    ),
                  // 打分帖子不显示收藏和稍后再看按钮
                  if (widget.postType != 'rating') ...[
                    IconButton(
                      icon: Icon(
                        _isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: context.textPrimaryColor,
                      ),
                      onPressed: _onSavePost,
                    ),
                    // 只在启用了稍后再看功能时显示按钮
                    if (_isWatchLaterEnabled)
                      IconButton(
                        icon: Icon(
                          _isInWatchLater
                              ? Icons.watch_later
                              : Icons.watch_later_outlined,
                          color: _isInWatchLater
                              ? AppColors.primary
                              : context.textPrimaryColor,
                        ),
                        onPressed: _onAddToWatchLater,
                        tooltip: '稍后再看',
                      ),
                  ],
                  const SizedBox(width: 8), // Add right padding
                ]
              : null,
        ),
        body: _isLoading
            ? _buildDetailSkeleton(topPadding)
            : RefreshIndicator(
                onRefresh: _loadPostDetail,
                edgeOffset: topPadding,
                color: AppColors.primary,
                backgroundColor: context.surfaceColor,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: topPadding,
                    bottom: widget.previewPost == null ? 120 : 32,
                  ),
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
                      if (widget.previewPost == null) _buildCommentSection(),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar:
            widget.previewPost == null ? _buildBottomBar() : null,
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
                      ? CachedImage(
                          imageUrl: _post.authorAvatar,
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
                if (_post.userIdentity == 'teacher' ||
                    _post.userIdentity == 'organization')
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: LevelUtils.getIdentityBackgroundColor(
                            _post.userIdentity),
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

    return LatexMarkdownWithPostPreview(
      data: _post.content,
      apiService: widget.apiService,
      selectable: true, // 支持长按选择文字
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
              _isLiked
                  ? 'assets/icons/ic_like_filled.svg'
                  : 'assets/icons/ic_like.svg',
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
      key: _commentSectionKey,
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
              decoration: BoxDecoration(
                color: context.surfaceColor,
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
              // 使用骨架屏代替 loading 指示器
              const CommentListSkeleton(itemCount: 3)
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
              // 使用 ListView.builder 实现懒加载，优化性能
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 0), // 移除左右内边距，使评论卡片占满
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  return CommentCard(
                    comment: comment,
                    postId: widget.postId,
                    currentUserPhone: _user.phone,
                    onLikeTap: () async {
                      return await widget.apiService
                          .likeComment(comment.id, _user.phone);
                    },
                    onReplyTap: () {
                      _showReplyModal(comment.authorName, comment.id);
                    },
                    onSubReplyTap: (authorName, commentId,
                        {targetCommentId, targetUserName}) {
                      _showReplyModal(authorName, commentId,
                          targetCommentId: targetCommentId,
                          targetUserName: targetUserName);
                    },
                    onSubLikeTap: (subCommentId) async {
                      return await widget.apiService
                          .likeSubComment(subCommentId, _user.phone);
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
                        final success = await widget.apiService
                            .deleteSubComment(subCommentId);
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
                        final success =
                            await widget.apiService.deleteComment(comment.id);
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
                },
              ),
          ],
          const SizedBox(height: 48), // 底部安全区
        ],
      ),
    );
  }

  /// 显示回复弹窗
  void _showReplyModal(String replyToName, int? parentCommentId,
      {int? targetCommentId, String? targetUserName}) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    if (isDesktop) {
      // 桌面端/平板：居中弹窗
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ReplyModal(
              postId: widget.postId,
              apiService: widget.apiService,
              replyToName: replyToName,
              parentCommentId: parentCommentId,
              targetCommentId: targetCommentId,
              targetUserName: targetUserName,
              isDialog: true, // 标记为弹窗模式
            ),
          ),
        ),
      ).then((result) {
        if (result == true) {
          _loadComments();
        }
      });
    } else {
      // 移动端：底部弹窗
      showModalBottomSheet(
        context: context,
        isScrollControlled: true, // 允许全屏高度
        backgroundColor: Colors.transparent,
        builder: (context) => Padding(
          // 确保输入框被键盘顶起
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ReplyModal(
            postId: widget.postId,
            apiService: widget.apiService,
            replyToName: replyToName,
            parentCommentId: parentCommentId,
            targetCommentId: targetCommentId,
            targetUserName: targetUserName,
          ),
        ),
      ).then((result) {
        if (result == true) {
          // 回复成功，刷新评论列表
          _loadComments();
        }
      });
    }
  }

  /// 详情页骨架屏
  Widget _buildDetailSkeleton(double topPadding) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: topPadding, bottom: 120),
      child: Container(
        color: context.surfaceColor,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息骨架
            Row(
              children: [
                SkeletonLoader(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.circular(20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(
                        width: 120,
                        height: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      SkeletonLoader(
                        width: 80,
                        height: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 标题骨架 - 两行
            SkeletonLoader(
              width: double.infinity,
              height: 20,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            SkeletonLoader(
              width: MediaQuery.of(context).size.width * 0.7,
              height: 20,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            // 内容骨架 - 多行
            ...List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SkeletonLoader(
                  width: index == 3
                      ? MediaQuery.of(context).size.width * 0.5
                      : double.infinity,
                  height: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
            const SizedBox(height: 16),
            // 操作栏骨架
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: context.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SkeletonLoader(
                        width: 20,
                        height: 20,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(width: 6),
                      SkeletonLoader(
                        width: 30,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
