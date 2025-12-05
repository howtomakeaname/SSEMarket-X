import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/services/browse_history_service.dart';
import 'package:sse_market_x/shared/components/cards/post_card.dart';
import 'package:sse_market_x/shared/components/inputs/teacher_dropdown.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/components/loading/skeleton_loader.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';

/// 教师分区页面
class TeacherPage extends StatefulWidget {
  final ApiService apiService;
  final Function(int postId)? onPostTap;

  const TeacherPage({
    super.key,
    required this.apiService,
    this.onPostTap,
  });

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  static const int _pageSize = 10;

  List<Map<String, dynamic>> _teachers = [];
  String? _selectedTeacher;
  List<PostModel> _posts = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingTeachers = true;
  UserModel _user = UserModel.empty();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 加载用户信息
    final storageService = StorageService();
    if (storageService.isLoggedIn && storageService.user != null) {
      _user = storageService.user!;
    }

    // 加载教师列表
    setState(() => _isLoadingTeachers = true);
    try {
      final teachers = await widget.apiService.getTeachers();
      if (mounted) {
        setState(() {
          _teachers = teachers;
          _isLoadingTeachers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTeachers = false);
      }
    }

    // 加载帖子列表
    _fetchPosts(refresh: true);
  }

  Future<void> _fetchPosts({required bool refresh}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _posts = [];
        _offset = 0;
        _hasMore = true;
      }
    });

    try {
      final params = GetPostsParams(
        limit: _pageSize,
        offset: refresh ? 0 : _offset,
        partition: '课程专区',
        searchsort: 'home',
        searchinfo: '',
        userTelephone: _user.phone,
        tag: _selectedTeacher ?? '',
      );

      final list = await widget.apiService.getPosts(params);

      if (mounted) {
        setState(() {
          if (refresh) {
            _posts = list;
          } else {
            _posts.addAll(list);
          }
          _offset = _posts.length;
          _hasMore = list.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onTeacherChanged(String? teacher) {
    setState(() {
      _selectedTeacher = teacher;
    });
    _fetchPosts(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(child: _buildPostList()),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final options = [
      const TeacherOption(value: null, label: '全部教师'),
      ..._teachers.map((t) => TeacherOption(
            value: t['Name'] as String?,
            label: t['Name'] as String? ?? '',
            count: t['Num'] as int?,
          )),
    ];

    return Container(
      color: context.surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(
            '筛选',
            style: TextStyle(
              fontSize: 13,
              color: context.textTertiaryColor,
            ),
          ),
          const SizedBox(width: 8),
          if (_isLoadingTeachers)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.textTertiaryColor,
              ),
            )
          else
            TeacherDropdown(
              options: options,
              value: _selectedTeacher,
              hint: '全部教师',
              showCount: true,
              onChanged: _onTeacherChanged,
            ),
        ],
      ),
    );
  }

  Widget _buildPostList() {
    // 首次加载显示骨架屏
    if (_isLoading && _posts.isEmpty) {
      return const PostListSkeleton(itemCount: 5, isDense: true);
    }

    if (_posts.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    return Container(
      color: context.backgroundColor,
      child: RefreshIndicator(
        onRefresh: () => _fetchPosts(refresh: true),
        color: AppColors.primary,
        backgroundColor: context.surfaceColor,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _posts.length + 1,
          itemBuilder: (context, index) {
            if (index == _posts.length) {
              if (_hasMore && !_isLoading) {
                Future.microtask(() => _fetchPosts(refresh: false));
              }

              if (_isLoading) {
                return const Center(
                  child: LoadingRow(message: '加载更多...', size: 16),
                );
              }
              if (!_hasMore && _posts.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      '已经到底啦',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }

            final post = _posts[index];
            return PostCard(
              post: post,
              isDense: true,
              onTap: () => _navigateToPostDetail(post),
              onLikeTap: () async {
                return await widget.apiService.likePost(post.id, _user.phone);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: context.textTertiaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedTeacher != null ? '该教师暂无帖子' : '暂无帖子',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToPostDetail(PostModel post) async {
    // 添加到浏览历史
    final postWithPartition = PostModel(
      id: post.id,
      title: post.title,
      content: post.content,
      partition: '课程专区',
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
    BrowseHistoryService().addPostHistory(postWithPartition, isCourse: true);

    if (widget.onPostTap != null) {
      widget.onPostTap!(post.id);
      return;
    }

    final result = await Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          postId: post.id,
          apiService: widget.apiService,
          initialPost: post,
        ),
      ),
    );

    if (result != null) {
      if (result['deleted'] == true) {
        setState(() {
          _posts.removeWhere((p) => p.id == post.id);
        });
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
  }
}
