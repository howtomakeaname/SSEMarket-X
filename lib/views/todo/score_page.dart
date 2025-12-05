import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/services/browse_history_service.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/shared/components/cards/rating_card.dart';
import 'package:sse_market_x/shared/components/layout/layout_config.dart';
import 'package:sse_market_x/shared/components/loading/skeleton_loader.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/post/create_post_page.dart';
import 'package:sse_market_x/views/post/score_post_detail_page.dart';

class ScorePage extends StatefulWidget {
  const ScorePage({
    super.key,
    required this.apiService,
    this.onPostTap,
  });

  final ApiService apiService;
  final Function(int postId)? onPostTap;

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  List<PostModel> _posts = [];
  bool _isLoading = true; // 初始化时设置为 true，避免显示空状态
  bool _isRefreshing = false;
  bool _hasMore = true;
  bool _hasLoadedOnce = false;
  int _offset = 0;
  int _newPostsCount = 0;
  static const int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialPosts();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPosts() async {
    // 尝试从缓存加载
    await _loadCachedPosts();
    
    // 后台静默刷新或首次加载
    if (_hasLoadedOnce) {
      _fetchPosts(refresh: true, silent: true);
    } else {
      // 首次加载，强制执行
      _fetchPosts(refresh: true, forceLoad: true);
    }
  }
  
  /// 从本地缓存加载帖子列表
  Future<void> _loadCachedPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('score_posts_cache');
      
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(cachedJson);
        final cachedPosts = jsonList.map((json) => PostModel.fromDynamic(json)).toList();
        
        if (cachedPosts.isNotEmpty && mounted) {
          setState(() {
            _posts = cachedPosts;
            _offset = cachedPosts.length;
            _hasLoadedOnce = true;
            _isLoading = false;
          });
          return;
        }
      }
      
      // 没有缓存，不设置 _isLoading，让后续的 _fetchPosts 正常执行
    } catch (e) {
      debugPrint('加载缓存打分帖子失败: $e');
      // 加载失败，不设置 _isLoading，让后续的 _fetchPosts 正常执行
    }
  }
  
  /// 保存帖子列表到本地缓存
  Future<void> _saveCachedPosts(List<PostModel> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = posts.map((post) => post.toJson()).toList();
      await prefs.setString('score_posts_cache', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('保存缓存打分帖子失败: $e');
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (maxScroll - current < 200) {
      if (!_isLoading && _hasMore) {
        _fetchPosts(refresh: false);
      }
    }
  }

  Future<void> _fetchPosts({required bool refresh, bool silent = false, bool forceLoad = false}) async {
    // 如果正在加载且不是静默模式且不是强制加载，则跳过
    if (_isLoading && !silent && !forceLoad) return;

    if (!silent) {
      setState(() {
        _isLoading = true;
        if (refresh) {
          _isRefreshing = true;
          _offset = 0;
        }
      });
    }

    try {
      final userPhone = StorageService().user?.phone ?? '';
      final params = GetPostsParams(
        limit: _pageSize,
        offset: _offset,
        partition: '打分',
        searchsort: 'rating',
        searchinfo: '',
        userTelephone: userPhone,
        tag: '',
      );

      final list = await widget.apiService.getPosts(params);

      if (!mounted) return;

      // 静默刷新：比较新旧数据
      int newCount = 0;
      List<PostModel> finalPosts;
      
      if (silent && refresh && _posts.isNotEmpty) {
        final existingIds = _posts.map((p) => p.id).toSet();
        newCount = list.where((p) => !existingIds.contains(p.id)).length;
        finalPosts = _posts;
      } else {
        finalPosts = refresh ? list : [..._posts, ...list];
        newCount = 0;
      }

      setState(() {
        _posts = finalPosts;
        _offset = refresh ? list.length : _offset + list.length;
        _hasMore = list.length == _pageSize;
        _hasLoadedOnce = true;
        _newPostsCount = newCount;
      });
      
      // 保存到缓存（仅在正常刷新时）
      if (!silent && refresh) {
        _saveCachedPosts(finalPosts);
      }
    } catch (e) {
      debugPrint('Fetch posts error: $e');
      if (mounted) {
        SnackBarHelper.show(context, '加载失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '打分',
          style: TextStyle(
            color: context.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.primary),
              tooltip: '发布打分帖子',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreatePostPage(
                      apiService: widget.apiService,
                      fromRatingPage: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        backgroundColor: context.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: context.backgroundColor,
      body: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasLoadedOnce && _isLoading && _posts.isEmpty) {
      return const PostListSkeleton(itemCount: 5, isDense: true);
    }

    if (!_isLoading && _posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '暂无打分数据',
              style: TextStyle(color: context.textSecondaryColor, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchPosts(refresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('刷新重试'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchPosts(refresh: true),
      color: AppColors.primary,
      child: Stack(
        children: [
          ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _posts.length + 1,
        itemBuilder: (context, index) {
          if (index < _posts.length) {
            final post = _posts[index];
            return RatingCard(
              post: post,
              isDense: true,
              onTap: () async {
                // 添加到浏览历史（在点击时记录）
                // 确保 partition 字段是"打分"
                final postWithPartition = PostModel(
                  id: post.id,
                  title: post.title,
                  content: post.content,
                  partition: '打分', // 明确设置为"打分"
                  authorName: post.authorName,
                  authorAvatar: post.authorAvatar,
                  authorPhone: post.authorPhone,
                  createdAt: post.createdAt,
                  likeCount: post.likeCount,
                  commentCount: post.commentCount,
                  saveCount: post.saveCount,
                  viewCount: post.viewCount,
                  userScore: post.userScore,
                  userIdentity: post.userIdentity,
                  isLiked: post.isLiked,
                  isSaved: post.isSaved,
                  rating: post.rating,
                  stars: post.stars,
                  userRating: post.userRating,
                  heat: post.heat,
                );
                BrowseHistoryService().addPostHistory(postWithPartition);
                
                final layoutConfig = LayoutConfig.of(context);
                final onPostTap = layoutConfig?.onPostTap;
                
                if (onPostTap != null) {
                  // 多栏模式下，直接调用回调
                  onPostTap(post.id, isScorePost: true);
                  return;
                }

                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ScorePostDetailPage(
                      postId: post.id,
                      apiService: widget.apiService,
                      initialPost: post,
                    ),
                  ),
                );
                // 返回后刷新列表
                _fetchPosts(refresh: true);
              },
              onLikeTap: () async {
                final userPhone = StorageService().user?.phone ?? '';
                return await widget.apiService.likePost(post.id, userPhone);
              },
            );
          }
          
          // Loading footer
          if (_isLoading && !_isRefreshing) {
            return const LoadingRow(message: '加载更多...', size: 16);
          }
          
          // No more data footer
          if (!_hasMore && _posts.isNotEmpty) {
             return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '已经到底啦',
                  style: TextStyle(fontSize: 12, color: context.textSecondaryColor),
                ),
              ),
            );
          }
          
          return const SizedBox.shrink();
        },
      ),
          // 新帖子提示条
          if (_newPostsCount > 0)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: _buildNewPostsIndicator(_newPostsCount),
            ),
        ],
      ),
    );
  }
  
  /// 新帖子提示条
  Widget _buildNewPostsIndicator(int count) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _fetchPosts(refresh: true);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fiber_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '$count 条新内容',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.touch_app_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
