import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';
import 'package:sse_market_x/shared/components/loading/skeleton_loader.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/components/cards/post_card.dart';
import 'package:sse_market_x/shared/components/overlays/custom_dialog.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 搜索页面
class SearchPage extends StatefulWidget {
  final ApiService apiService;
  final String partition;
  final Function(int postId)? onPostTap;

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
  List<PostModel> _hotPosts = [];
  List<String> _searchHistory = [];
  UserModel _user = UserModel.empty();
  bool _isLoading = false;
  bool _isLoadingHotPosts = false;
  bool _hasSearched = false; // 是否已执行过搜索
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 20;
  static const int _maxHotPosts = 6; // 热榜最多显示6条
  static const int _maxHistoryCount = 10; // 最多保存10条历史记录
  static const String _historyKey = 'search_history';

  final Map<String, String> _apiToDisplayPartition = {
    '院务': '院务',
    '课程交流': '课程',
    '学习交流': '学习解惑',
    '打听求助': '打听求助',
    '日常吐槽': '随想随记',
    '求职招募': '求职招募',
    '主页': '主页',
    '其他': '其他',
  };

  String get _displayPartition =>
      _apiToDisplayPartition[widget.partition] ?? widget.partition;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUser();
    _loadHotPosts();
    _loadSearchHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 添加小延迟避免键盘事件冲突
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
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
        setState(() => _user = user);
      }
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
    }
  }

  Future<void> _loadHotPosts() async {
    setState(() => _isLoadingHotPosts = true);

    try {
      final hotPosts = await widget.apiService.getHeatPosts();
      if (mounted) {
        setState(() {
          _hotPosts = hotPosts.take(_maxHotPosts).toList();
          _isLoadingHotPosts = false;
        });
      }
    } catch (e) {
      debugPrint('加载热榜帖子失败: $e');
      if (mounted) {
        setState(() => _isLoadingHotPosts = false);
      }
    }
  }

  // ===== 搜索历史相关 =====

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    if (mounted) {
      setState(() => _searchHistory = history);
    }
  }

  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, _searchHistory);
  }

  void _addToHistory(String keyword) {
    if (keyword.isEmpty) return;
    setState(() {
      _searchHistory.remove(keyword); // 移除重复项
      _searchHistory.insert(0, keyword); // 添加到开头
      if (_searchHistory.length > _maxHistoryCount) {
        _searchHistory = _searchHistory.take(_maxHistoryCount).toList();
      }
    });
    _saveSearchHistory();
  }

  Future<void> _deleteHistoryItem(String keyword) async {
    final confirm = await showCustomDialog(
      context: context,
      title: '删除记录',
      content: '确定要删除"$keyword"吗？',
      cancelText: '取消',
      confirmText: '删除',
      confirmColor: AppColors.error,
    );

    if (confirm == true && mounted) {
      setState(() => _searchHistory.remove(keyword));
      _saveSearchHistory();
    }
  }

  Future<void> _clearAllHistory() async {
    final confirm = await showCustomDialog(
      context: context,
      title: '清空历史',
      content: '确定要清空所有搜索历史吗？',
      cancelText: '取消',
      confirmText: '清空',
      confirmColor: AppColors.error,
    );

    if (confirm == true && mounted) {
      setState(() => _searchHistory.clear());
      _saveSearchHistory();
    }
  }

  // ===== 搜索相关 =====

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
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearch() {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;
    _focusNode.unfocus();
    _addToHistory(keyword);
    setState(() => _hasSearched = true);
    _loadPosts(refresh: true);
  }

  void _onHistoryTap(String keyword) {
    _searchController.text = keyword;
    _onSearch();
  }

  void _onHotPostTap(int postId) {
    if (widget.onPostTap != null) {
      widget.onPostTap!(postId);
      return;
    }

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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              isDense: true,
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, child) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: Icon(Icons.clear,
                        size: 18, color: context.textSecondaryColor),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _posts.clear();
                        _hasSearched = false;
                      });
                    },
                  );
                },
              ),
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
                style: TextStyle(fontSize: 14, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 未执行过搜索时显示历史和热榜
    if (!_hasSearched) {
      return _buildDiscoveryContent();
    }

    if (_isLoading && _posts.isEmpty) {
      return const PostListSkeleton(itemCount: 5, isDense: false);
    }

    if (_posts.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: context.textSecondaryColor),
            const SizedBox(height: 16),
            Text(
              '未找到相关内容',
              style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
            ),
          ],
        ),
      );
    }

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
            final result =
                await Navigator.of(context).push<Map<String, dynamic>?>(
              MaterialPageRoute(
                builder: (_) => PostDetailPage(
                  postId: post.id,
                  apiService: widget.apiService,
                ),
              ),
            );
            if (result != null) {
              if (result['deleted'] == true) {
                setState(() => _posts.removeWhere((p) => p.id == post.id));
              } else {
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

  /// 发现内容：搜索历史 + 热榜
  Widget _buildDiscoveryContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索历史（始终显示）
          _buildSearchHistory(),
          const SizedBox(height: 24),
          // 热榜
          _buildHotPosts(),
        ],
      ),
    );
  }

  /// 搜索历史区域
  Widget _buildSearchHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 18, color: context.textSecondaryColor),
            const SizedBox(width: 6),
            Text(
              '搜索历史',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
            const Spacer(),
            if (_searchHistory.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _clearAllHistory,
                  child: const Text(
                    '清空',
                    style: TextStyle(fontSize: 14, color: AppColors.primary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_searchHistory.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '暂无搜索历史',
                style: TextStyle(fontSize: 13, color: context.textTertiaryColor),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _searchHistory.map((keyword) {
              return GestureDetector(
                onTap: () => _onHistoryTap(keyword),
                onLongPress: () => _deleteHistoryItem(keyword),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        keyword,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _deleteHistoryItem(keyword),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  /// 热榜区域
  Widget _buildHotPosts() {
    if (_isLoadingHotPosts) {
      return const PostListSkeleton(itemCount: 3, isDense: false);
    }

    if (_hotPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    // 分成两列显示
    final leftColumn = <PostModel>[];
    final rightColumn = <PostModel>[];
    for (int i = 0; i < _hotPosts.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(_hotPosts[i]);
      } else {
        rightColumn.add(_hotPosts[i]);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_fire_department, size: 18, color: AppColors.error),
            const SizedBox(width: 6),
            Text(
              '热榜',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 两列布局
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: leftColumn.asMap().entries.map((entry) {
                  final index = entry.key * 2; // 实际排名
                  final post = entry.value;
                  return _buildHotPostItem(post, index);
                }).toList(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: rightColumn.asMap().entries.map((entry) {
                  final index = entry.key * 2 + 1; // 实际排名
                  final post = entry.value;
                  return _buildHotPostItem(post, index);
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHotPostItem(PostModel post, int index) {
    const textStyle = TextStyle(fontSize: 13, height: 1.4);
    return GestureDetector(
      onTap: () => _onHotPostTap(post.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 排名数字
            Text(
              '${index + 1}',
              style: textStyle.copyWith(
                fontWeight: FontWeight.bold,
                color: index < 3 ? AppColors.error : context.textSecondaryColor,
              ),
            ),
            const SizedBox(width: 6),
            // 标题
            Expanded(
              child: Text(
                post.title,
                style: textStyle.copyWith(
                  color: context.textPrimaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
