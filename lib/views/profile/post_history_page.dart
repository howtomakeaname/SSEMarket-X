import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/components/cards/post_card.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class PostHistoryPage extends StatefulWidget {
  final ApiService apiService;

  const PostHistoryPage({super.key, required this.apiService});

  @override
  State<PostHistoryPage> createState() => _PostHistoryPageState();
}

class _PostHistoryPageState extends State<PostHistoryPage> {
  final ScrollController _scrollController = ScrollController();
  List<PostModel> _posts = [];
  UserModel _user = UserModel.empty();
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUserAndHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadHistory(refresh: false);
      }
    }
  }

  Future<void> _loadUserAndHistory() async {
    try {
      final user = await widget.apiService.getUserInfo();
      if (mounted) {
        setState(() {
          _user = user;
        });
        _loadHistory(refresh: true);
      }
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
    }
  }

  Future<void> _loadHistory({required bool refresh}) async {
    if (_isLoading) return;
    if (_user.phone.isEmpty) return;

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
          partition: '主页',
          searchsort: 'history', // 使用 history 获取发帖历史
          searchinfo: '',
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
      debugPrint('加载发帖历史失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '我的发帖',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _posts.isEmpty) {
      return const LoadingIndicator.center(message: '加载中...');
    }

    if (_posts.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: context.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无发帖记录',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '快去发布你的第一篇帖子吧',
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadHistory(refresh: true),
      child: ListView.builder(
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
              // 如果帖子被删除，刷新列表
              if (result != null && result['deleted'] == true) {
                _loadHistory(refresh: true);
              } else if (result != null) {
                // 有其他变动也刷新
                _loadHistory(refresh: true);
              }
            },
            onLikeTap: () async {
              return widget.apiService.likePost(post.id, _user.phone);
            },
          );
        },
      ),
    );
  }
}
