import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:sse_market_x/views/profile/user_profile_page.dart';

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

class _TeacherPageState extends State<TeacherPage>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 10;
  static const String _cacheKey = 'posts_cache_teacher';
  static const String _teachersCacheKey = 'teachers_cache';

  List<Map<String, dynamic>> _teachers = [];
  String? _selectedTeacher;
  List<PostModel> _posts = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingTeachers = true;
  bool _hasLoadedOnce = false;
  UserModel _user = UserModel.empty();

  @override
  bool get wantKeepAlive => true;

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

    // 先尝试从缓存加载教师列表
    await _loadCachedTeachers();

    // 后台刷新教师列表
    _fetchTeachers();

    // 尝试从缓存加载帖子
    await _loadCachedPosts();

    // 后台刷新或正常加载
    if (_hasLoadedOnce) {
      _fetchPosts(refresh: true, silent: true);
    } else {
      _fetchPosts(refresh: true);
    }
  }

  /// 从缓存加载教师列表
  Future<void> _loadCachedTeachers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_teachersCacheKey);

      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(cachedJson);
        final cachedTeachers = jsonList
            .map((json) => Map<String, dynamic>.from(json as Map))
            .toList();

        if (cachedTeachers.isNotEmpty && mounted) {
          setState(() {
            _teachers = cachedTeachers;
            _isLoadingTeachers = false;
          });
        }
      }
    } catch (e) {
      debugPrint('加载教师列表缓存失败: $e');
    }
  }

  /// 保存教师列表到缓存
  Future<void> _saveCachedTeachers(List<Map<String, dynamic>> teachers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_teachersCacheKey, jsonEncode(teachers));
    } catch (e) {
      debugPrint('保存教师列表缓存失败: $e');
    }
  }

  /// 从 API 获取教师列表
  Future<void> _fetchTeachers() async {
    try {
      final teachers = await widget.apiService.getTeachers();
      if (mounted) {
        setState(() {
          _teachers = teachers;
          _isLoadingTeachers = false;
        });
        // 保存到缓存
        _saveCachedTeachers(teachers);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTeachers = false);
      }
    }
  }

  /// 从本地缓存加载帖子列表
  Future<void> _loadCachedPosts() async {
    // 只有在未选择教师时才使用缓存
    if (_selectedTeacher != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);

      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(cachedJson);
        final cachedPosts =
            jsonList.map((json) => PostModel.fromDynamic(json)).toList();

        if (cachedPosts.isNotEmpty && mounted) {
          setState(() {
            _posts = cachedPosts;
            _offset = cachedPosts.length;
            _hasMore = true;
            _hasLoadedOnce = true;
          });
        }
      }
    } catch (e) {
      debugPrint('加载教师分区缓存失败: $e');
    }
  }

  /// 保存帖子列表到本地缓存
  Future<void> _saveCachedPosts(List<PostModel> posts) async {
    // 只有在未选择教师时才保存缓存
    if (_selectedTeacher != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = posts.map((post) => post.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('保存教师分区缓存失败: $e');
    }
  }

  Future<void> _fetchPosts({required bool refresh, bool silent = false}) async {
    if (_isLoading && !silent) return;

    if (!silent) {
      setState(() {
        _isLoading = true;
        if (refresh) {
          _posts = [];
          _offset = 0;
          _hasMore = true;
        }
      });
    }

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
          _hasLoadedOnce = true;
        });

        // 保存到缓存（仅在正常刷新时）
        if (!silent && refresh) {
          _saveCachedPosts(_posts);
        }
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
      _hasLoadedOnce = false; // 切换教师时重置缓存状态
    });
    _fetchPosts(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用 super.build
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

    // 只有在没有教师数据且正在加载时才显示 loading
    final showLoading = _teachers.isEmpty && _isLoadingTeachers;

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
          if (showLoading)
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
              onChanged: _onTeacherChanged,
            ),
        ],
      ),
    );
  }

  Widget _buildPostList() {
    // 显示骨架屏的条件：
    // 1. 正在加载中且列表为空
    // 2. 还没加载过且列表为空（首次进入）
    // 3. 正在加载教师列表（说明刚进入页面）
    if (_posts.isEmpty && (_isLoading || !_hasLoadedOnce || _isLoadingTeachers)) {
      return const PostListSkeleton(itemCount: 5, isDense: false);
    }

    // 只有在加载完成后且列表为空时才显示空状态
    if (_posts.isEmpty && !_isLoading && _hasLoadedOnce) {
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
