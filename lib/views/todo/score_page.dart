import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/views/post/score_post_detail_page.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/components/cards/rating_card.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/core/services/storage_service.dart';

import 'package:sse_market_x/shared/components/layout/layout_config.dart';

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
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasMore = true;
  int _offset = 0;
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
    await _fetchPosts(refresh: true);
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

  Future<void> _fetchPosts({required bool refresh}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _isRefreshing = true;
        _offset = 0;
      }
    });

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

      setState(() {
        if (refresh) {
          _posts = list;
        } else {
          _posts.addAll(list);
        }
        _offset += list.length;
        _hasMore = list.length == _pageSize;
      });
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
        title: const Text(
          '打分',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0, // 防止滚动时改变背景色
        centerTitle: false, // 标题居左
        automaticallyImplyLeading: false,
      ),
      backgroundColor: AppColors.background, // Use consistent background color
      body: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _posts.isEmpty) {
      return const LoadingIndicator.center(message: '加载中...');
    }

    if (!_isLoading && _posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '暂无打分数据',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
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
      // backgroundColor: AppColors.surface, // 下拉不必改变背景色，使用默认即可
      child: ListView.builder(
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
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          
          // No more data footer
          if (!_hasMore && _posts.isNotEmpty) {
             return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '已经到底啦',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            );
          }
          
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
