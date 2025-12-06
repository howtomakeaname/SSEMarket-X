import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/services/browse_history_service.dart';
import 'package:sse_market_x/views/post/create_post_page.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';
import 'package:sse_market_x/views/home/search_page.dart';
import 'package:sse_market_x/views/home/teacher_page.dart';
import 'package:sse_market_x/shared/components/layout/home_header.dart';
import 'package:sse_market_x/shared/components/layout/layout_config.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/components/loading/skeleton_loader.dart';
import 'package:sse_market_x/shared/components/cards/post_card.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/profile/user_profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.apiService,
    this.showHeaderAvatar = true,
    this.showHeaderAddButton = true,
    this.onPostTap,
    this.onAvatarTap,
  });

  final ApiService apiService;
  final bool showHeaderAvatar;
  final bool showHeaderAddButton;
  final Function(int postId)? onPostTap;
  final VoidCallback? onAvatarTap;

  @override
  State<HomePage> createState() => HomePageState();
}

class _PartitionState {
  List<PostModel> posts;
  int offset;
  bool hasMore;
  bool isLoading;
  bool isRefreshing;
  bool hasLoadedOnce; // 标记是否至少加载过一次
  int newPostsCount; // 后台刷新发现的新帖子数量

  _PartitionState({
    List<PostModel>? posts,
    this.offset = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.isRefreshing = false,
    this.hasLoadedOnce = false,
    this.newPostsCount = 0,
  }) : posts = posts ?? <PostModel>[];
}

class HomePageState extends State<HomePage> {
  static const int _pageSize = 10;

  /// 显示名称分区列表
  /// 院务 -> 院务
  /// 教师 -> 课程专区（特殊处理，使用独立页面）
  /// 课程 -> 课程交流
  /// 学习解惑 -> 学习交流
  /// 打听求助 -> 打听求助
  /// 随想随记 -> 日常吐槽
  /// 求职招募 -> 求职招募
  /// 杂项 -> 主页
  /// 其他 -> 其他
  final List<String> _displayPartitions = <String>[
    '主页',
    '院务',
    '教师',
    '课程',
    '学习解惑',
    '打听求助',
    '随想随记',
    '求职招募',
    '其他',
  ];

  /// 显示名称 -> API 名称
  final Map<String, String> _displayToApiPartition = <String, String>{
    '主页': '主页',
    '院务': '院务',
    '教师': '课程专区',
    '课程': '课程交流',
    '学习解惑': '学习交流',
    '打听求助': '打听求助',
    '随想随记': '日常吐槽',
    '求职招募': '求职招募',
    '其他': '其他',
  };

  /// API 名称 -> 分区状态
  final Map<String, _PartitionState> _partitionStates = <String, _PartitionState>{};

  /// 当前选中的显示名称分区
  int _currentPartitionIndex = 0;
  String _searchText = '';

  UserModel _user = UserModel.empty();
  bool _loadingUser = false;

  final PageController _pageController = PageController();
  final ScrollController _tabScrollController = ScrollController();
  final Map<String, GlobalKey> _tabKeys = {};
  
  String get _currentDisplayPartition => _displayPartitions[_currentPartitionIndex];

  @override
  void initState() {
    super.initState();
    for (final entry in _displayToApiPartition.entries) {
      _partitionStates[entry.value] = _PartitionState();
    }
    // 初始化每个 tab 的 GlobalKey
    for (final p in _displayPartitions) {
      _tabKeys[p] = GlobalKey();
    }
    _loadUserAndInitialPosts();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    await _fetchPosts(refresh: true);
  }

  /// 静默后台刷新（不清空列表，检测新内容）
  Future<void> silentRefresh() async {
    await _fetchPosts(refresh: true, silent: true);
  }

  /// 从本地缓存加载帖子列表
  Future<void> _loadCachedPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'posts_cache_${_currentApiPartition}';
      final cachedJson = prefs.getString(cacheKey);
      
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(cachedJson);
        final cachedPosts = jsonList.map((json) => PostModel.fromDynamic(json)).toList();
        
        if (cachedPosts.isNotEmpty && mounted) {
          setState(() {
            _partitionStates[_currentApiPartition] = _PartitionState(
              posts: cachedPosts,
              offset: cachedPosts.length,
              hasMore: true,
              isLoading: false,
              isRefreshing: false,
              hasLoadedOnce: true,
              newPostsCount: 0,
            );
          });
          return; // 成功加载缓存，直接返回
        }
      }
      
      // 没有缓存或加载失败，标记需要显示骨架屏
      if (mounted) {
        setState(() {
          _loadingUser = true;
        });
      }
    } catch (e) {
      debugPrint('加载缓存帖子失败: $e');
      // 加载失败，标记需要显示骨架屏
      if (mounted) {
        setState(() {
          _loadingUser = true;
        });
      }
    }
  }
  
  /// 保存帖子列表到本地缓存
  Future<void> _saveCachedPosts(List<PostModel> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'posts_cache_${_currentApiPartition}';
      final jsonList = posts.map((post) => post.toJson()).toList();
      await prefs.setString(cacheKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('保存缓存帖子失败: $e');
    }
  }

  Future<void> _loadUserAndInitialPosts() async {
    // 1. 先从 StorageService 获取缓存的用户数据（即时显示）
    final storageService = StorageService();
    if (storageService.isLoggedIn && storageService.user != null) {
      if (!mounted) return;
      setState(() {
        _user = storageService.user!;
        _loadingUser = false; // 有用户缓存，先不显示加载状态
      });
      
      // 2. 尝试从本地缓存加载帖子列表（同步判断，异步加载）
      await _loadCachedPosts();
      
      // 3. 后台静默刷新最新帖子（如果有缓存数据）
      if (_currentState.hasLoadedOnce) {
        _fetchPosts(refresh: true, silent: true);
      } else {
        // 没有缓存，正常加载
        _fetchPosts(refresh: true);
      }
    } else {
      // 没有用户缓存，显示加载状态
      setState(() {
        _loadingUser = true;
      });
      _fetchPosts(refresh: true);
    }
  }
  


  String get _currentApiPartition =>
      _displayToApiPartition[_currentDisplayPartition] ?? _currentDisplayPartition;

  _PartitionState get _currentState =>
      _partitionStates[_currentApiPartition] ?? _PartitionState();

  Future<void> _fetchPosts({required bool refresh, bool silent = false}) async {
    final state = _currentState;
    if (state.isLoading) return;

    // 静默刷新：不清空列表，不显示加载状态
    final newState = _PartitionState(
      posts: (refresh && !silent) ? <PostModel>[] : state.posts,
      offset: refresh ? 0 : state.offset,
      hasMore: state.hasMore,
      isLoading: !silent, // 静默刷新时不显示加载状态
      isRefreshing: refresh && !silent,
      hasLoadedOnce: state.hasLoadedOnce,
      newPostsCount: state.newPostsCount,
    );
    
    if (!silent) {
      setState(() {
        _partitionStates[_currentApiPartition] = newState;
      });
    }

    try {
      final params = GetPostsParams(
        limit: _pageSize,
        offset: newState.offset,
        partition: _currentApiPartition,
        searchsort: 'home',
        searchinfo: _searchText,
        userTelephone: _user.phone,
        tag: '',
      );

      final list = await widget.apiService.getPosts(params);
      
      // 静默刷新：比较新旧数据，计算新帖子数量
      int newCount = 0;
      List<PostModel> finalPosts;
      
      if (silent && refresh && state.posts.isNotEmpty) {
        // 静默刷新模式：不立即更新列表，只记录新帖子数量
        final existingIds = state.posts.map((p) => p.id).toSet();
        newCount = list.where((p) => !existingIds.contains(p.id)).length;
        finalPosts = state.posts; // 保持原列表
      } else {
        // 正常刷新或加载更多
        finalPosts = refresh ? list : <PostModel>[...newState.posts, ...list];
        newCount = 0;
      }

      final updated = _PartitionState(
        posts: finalPosts,
        offset: refresh ? list.length : newState.offset + list.length,
        hasMore: list.length == _pageSize,
        isLoading: false,
        isRefreshing: false,
        hasLoadedOnce: true,
        newPostsCount: newCount,
      );

      if (!mounted) return;
      setState(() {
        _partitionStates[_currentApiPartition] = updated;
      });
      
      // 保存到缓存（仅在正常刷新时）
      if (!silent && refresh) {
        _saveCachedPosts(finalPosts);
      }
    } finally {
      if (mounted && !silent) {
        final st = _partitionStates[_currentApiPartition] ?? _PartitionState();
        _partitionStates[_currentApiPartition] = _PartitionState(
          posts: st.posts,
          offset: st.offset,
          hasMore: st.hasMore,
          isLoading: false,
          isRefreshing: false,
          hasLoadedOnce: st.hasLoadedOnce,
          newPostsCount: st.newPostsCount,
        );
      }
    }
  }


  void _onPartitionTap(String partition) {
    final index = _displayPartitions.indexOf(partition);
    if (index == -1 || index == _currentPartitionIndex) return;
    // 点击分区标签时直接切换到目标页，避免动画滚动经过中间页造成不必要的渲染
    _pageController.jumpToPage(index);
  }
  
  void _onPageChanged(int index) {
    setState(() {
      _currentPartitionIndex = index;
    });
    _scrollToTab(_displayPartitions[index]);
    
    // 加载当前分区数据
    if (_currentState.posts.isEmpty && !_currentState.isLoading) {
      _fetchPosts(refresh: true);
    }
  }

  /// 滚动 Tab 栏到指定分区
  void _scrollToTab(String partition) {
    final key = _tabKeys[partition];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3, // 让选中的 tab 靠左一点显示
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _displayPartitions.length,
            itemBuilder: (context, index) {
              final partition = _displayPartitions[index];
              
              // 教师分区使用独立页面
              if (partition == '教师') {
                final layoutConfig = LayoutConfig.of(context);
                final onPostTap = layoutConfig?.onPostTap ?? widget.onPostTap;
                return TeacherPage(
                  apiService: widget.apiService,
                  onPostTap: onPostTap,
                );
              }
              
              final apiPartition = _displayToApiPartition[partition] ?? partition;
              final state = _partitionStates[apiPartition] ?? _PartitionState();
              return _buildPostList(state, partition);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostList(_PartitionState state, String partition) {
    final isDense = partition == '课程';
    final apiPartition = _displayToApiPartition[partition] ?? partition; // 获取 API 分区名
    final layoutConfig = LayoutConfig.of(context);
    final onPostTap = layoutConfig?.onPostTap ?? widget.onPostTap;

    // 只在首次加载且列表为空时显示骨架屏
    // 如果已经加载过（hasLoadedOnce），即使列表为空也不显示骨架屏（可能是真的没有数据）
    if (!state.hasLoadedOnce && (_loadingUser || state.isLoading) && state.posts.isEmpty) {
      return _buildSkeletonLoader(isDense);
    }

    return Container(
      color: context.backgroundColor, // Use consistent background color
      child: RefreshIndicator(
        onRefresh: () => _fetchPosts(refresh: true),
        color: AppColors.primary,
        backgroundColor: context.surfaceColor,
        child: Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.posts.length + 1,
              itemBuilder: (context, index) {
                // 检查是否需要加载更多
                if (index == state.posts.length) {
                  if (state.hasMore && !state.isLoading) {
                    Future.microtask(() => _fetchPosts(refresh: false));
                  }
                  
                  // 底部提示
                  if (state.isLoading && !state.isRefreshing) {
                    return _buildLoadMoreIndicator();
                  }
                  if (!state.hasMore && state.posts.isNotEmpty) {
                    return _buildNoMoreData();
                  }
                  return const SizedBox.shrink();
                }

                final post = state.posts[index];
                return PostCard(
                  post: post,
                  isDense: isDense,
                  onAvatarTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfilePage(
                          apiService: widget.apiService,
                          userId: 0,
                          userPhone: post.authorPhone,
                        ),
                      ),
                    );
                  },
                  onTap: () async {
                      // 添加到浏览历史（在点击时记录）
                      final postWithPartition = PostModel(
                        id: post.id,
                        title: post.title,
                        content: post.content,
                        partition: apiPartition, // 使用 API 分区名
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
                      
                      if (onPostTap != null) {
                        onPostTap(post.id);
                        return;
                      }
                      final result = await Navigator.of(context).push<Map<String, dynamic>?>(
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(
                            postId: post.id,
                            apiService: widget.apiService,
                            initialPost: post, // 传递初始数据，优化加载体验
                          ),
                        ),
                      );
                      // 处理返回的数据
                      if (result != null) {
                        if (result['deleted'] == true) {
                          // 删除帖子：从列表中移除
                          setState(() {
                            state.posts.removeWhere((p) => p.id == post.id);
                          });
                        } else {
                          // 更新点赞状态
                          final newIsLiked = result['isLiked'] as bool?;
                          final newLikeCount = result['likeCount'] as int?;
                          if (newIsLiked != null && newLikeCount != null) {
                            final idx = state.posts.indexWhere((p) => p.id == post.id);
                            if (idx != -1) {
                              setState(() {
                                state.posts[idx] = state.posts[idx].copyWithLike(
                                  isLiked: newIsLiked,
                                  likeCount: newLikeCount,
                                );
                              });
                            }
                          }
                        }
                      }
                    },
                    onLikeTap: () async {
                      return await widget.apiService.likePost(post.id, _user.phone);
                    },
                  );
              },
            ),
          // 下拉刷新时顶部显示 Loading
          if (state.isRefreshing && state.posts.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildRefreshingIndicator(),
            ),
          // 新帖子提示条
          if (state.newPostsCount > 0)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: _buildNewPostsIndicator(state.newPostsCount),
            ),
        ],
      ),
        ),
    );
  }

  /// 骨架屏加载器（初始加载/切换分区）
  Widget _buildSkeletonLoader(bool isDense) {
    return PostListSkeleton(itemCount: 5, isDense: isDense);
  }

  /// 下拉刷新时顶部指示器（移除，使用系统自带的刷新指示器）
  Widget _buildRefreshingIndicator() {
    // 不再显示额外的刷新指示器，RefreshIndicator 已经提供了视觉反馈
    return const SizedBox.shrink();
  }

  /// 加载更多指示器
  Widget _buildLoadMoreIndicator() {
    return const Center(
      child: LoadingRow(message: '加载更多...', size: 16),
    );
  }

  /// 没有更多数据提示
  Widget _buildNoMoreData() {
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
  
  /// 新帖子提示条
  Widget _buildNewPostsIndicator(int count) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 点击后刷新列表
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

  Widget _buildHeader(BuildContext context) {
    final layoutConfig = LayoutConfig.of(context);
    final onPostTap = layoutConfig?.onPostTap ?? widget.onPostTap;
    final showAvatar = layoutConfig != null ? !layoutConfig.isDesktop : widget.showHeaderAvatar;
    final showAddButton = layoutConfig != null ? !layoutConfig.isDesktop : widget.showHeaderAddButton;

    return HomeHeader(
      user: _user,
      showAvatar: showAvatar,
      showAddButton: showAddButton,
      currentPartition: _currentDisplayPartition,
      displayPartitions: _displayPartitions,
      tabScrollController: _tabScrollController,
      tabKeys: _tabKeys,
      onPartitionTap: _onPartitionTap,
      onAvatarTap: widget.onAvatarTap,
      onSearchTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SearchPage(
              apiService: widget.apiService,
              partition: _displayToApiPartition[_currentDisplayPartition] ?? '主页',
              onPostTap: onPostTap, // 传递三栏布局的回调
            ),
          ),
        );
      },
      onAddPostTap: () async {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CreatePostPage(apiService: widget.apiService),
          ),
        );
        // 如果发布成功，刷新当前分区
        if (result == true) {
          _fetchPosts(refresh: true);
        }
      },
    );
  }
}
