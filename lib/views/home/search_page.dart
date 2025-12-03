import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/components/cards/post_card.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 搜索页面
class SearchPage extends StatefulWidget {
  final ApiService apiService;
  final String partition;
  final Function(int postId)? onPostTap; // 三栏布局下的点击回调

  const SearchPage({
    super.key,
    required this.apiService,
    required this.partition,
    this.onPostTap,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<PostModel> _posts = [];
  List<PostModel> _hotPosts = []; // 热榜帖子
  UserModel _user = UserModel.empty();
  bool _isLoading = false;
  bool _isLoadingHotPosts = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 20;

  /// API 名称 -> 显示名称
  final Map<String, String> _apiToDisplayPartition = {
    '院务': '院务',
    '课程交流': '课程',
    '学习交流': '学习解惑',
    '打听求助': '打听求助',
    '日常吐槽': '随想随记',
    '求职招募': '求职招募',
    '主页': '杂项',
    '其他': '其他',
  };

  /// 获取当前分区显示名称
  String get _displayPartition => _apiToDisplayPartition[widget.partition] ?? widget.partition;


  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUser();
    _loadHotPosts(); // 加载热榜帖子
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final user = await widget.apiService.getUserInfo();
      if (mounted) {
        setState(() {
          _user = user;
        });
      }
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
    }
  }

  Future<void> _loadHotPosts() async {
    setState(() {
      _isLoadingHotPosts = true;
    });

    try {
      final hotPosts = await widget.apiService.getHeatPosts();
      if (mounted) {
        setState(() {
          _hotPosts = hotPosts;
          _isLoadingHotPosts = false;
        });
      }
    } catch (e) {
      debugPrint('加载热榜帖子失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingHotPosts = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadPosts(refresh: false);
      }
    }
  }

  Future<void> _loadPosts({required bool refresh}) async {
    if (_isLoading) return;
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _offset = 0;
        _posts = [];
      }
    });

    try {
      final posts = await widget.apiService.getPosts(
        GetPostsParams(
          limit: _pageSize,
          offset: _offset,
          partition: widget.partition,
          searchsort: 'home',
          searchinfo: _searchController.text.trim(),
          userTelephone: _user.phone,
          tag: '',
        ),
      );

      if (!mounted) return;

      setState(() {
        if (refresh) {
          _posts = posts;
        } else {
          _posts.addAll(posts);
        }
        _offset += posts.length;
        _hasMore = posts.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('搜索失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearch() {
    if (_searchController.text.trim().isEmpty) return;
    _focusNode.unfocus();
    _loadPosts(refresh: true);
  }

  void _onHotPostTap(int postId) {
    // 如果有 onPostTap 回调（三栏布局），则使用回调
    if (widget.onPostTap != null) {
      widget.onPostTap!(postId);
      return;
    }
    
    // 否则 push 新页面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          postId: postId,
          apiService: widget.apiService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Container(
          height: 36,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: '在$_displayPartition分区内搜索',
              hintStyle: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              isDense: true,
            ),
            style: TextStyle(fontSize: 14, color: context.textPrimaryColor),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _onSearch(),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _onSearch,
              child: const Text(
                '搜索',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 如果还没有搜索，显示热榜帖子
    if (_posts.isEmpty && !_isLoading && _searchController.text.isEmpty) {
      return _buildHotPosts();
    }

    // 加载中
    if (_isLoading && _posts.isEmpty) {
      return const LoadingIndicator.center(message: '搜索中...');
    }

    // 无结果
    if (_posts.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: context.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              '未找到"${_searchController.text}"相关内容',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    // 搜索结果列表
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8),
      itemCount: _posts.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _posts.length) {
          return const LoadingRow();
        }
        final post = _posts[index];
        return PostCard(
          post: post,
          onTap: () async {
            final result = await Navigator.of(context).push<Map<String, dynamic>?>(
              MaterialPageRoute(
                builder: (_) => PostDetailPage(
                  postId: post.id,
                  apiService: widget.apiService,
                ),
              ),
            );
            // 处理返回的数据
            if (result != null) {
              if (result['deleted'] == true) {
                // 删除帖子：从列表中移除
                setState(() {
                  _posts.removeWhere((p) => p.id == post.id);
                });
              } else {
                // 更新点赞状态
                final newIsLiked = result['isLiked'] as bool?;
                final newLikeCount = result['likeCount'] as int?;
                if (newIsLiked != null && newLikeCount != null) {
                  final idx = _posts.indexWhere((p) => p.id == post.id);
                  if (idx != -1) {
                    setState(() {
                      _posts[idx] = _posts[idx].copyWithLike(
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
            return widget.apiService.likePost(post.id, _user.phone);
          },
        );
      },
    );
  }

  Widget _buildHotPosts() {
    if (_isLoadingHotPosts) {
      return const LoadingIndicator.center(message: '加载中...');
    }

    if (_hotPosts.isEmpty) {
      return Center(
        child: Text(
          '暂无热榜数据',
          style: TextStyle(
            fontSize: 16,
            color: context.textSecondaryColor,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '热榜',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimaryColor,
                ),
              ),
              const Spacer(),
              Text(
                '${_hotPosts.length} 条热门',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textTertiaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 热榜帖子列表
          ...List.generate(_hotPosts.length, (index) {
            final post = _hotPosts[index];
            return GestureDetector(
              onTap: () => _onHotPostTap(post.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // 排名
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: index < 3 ? AppColors.error : context.textSecondaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 帖子信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: context.textPrimaryColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
