import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sse_market_x/core/models/post_model.dart';

/// 稍后再看项
class WatchLaterItem {
  final int postId;
  final PostModel post;
  final DateTime addedAt;

  WatchLaterItem({
    required this.postId,
    required this.post,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'post': {
        'PostID': post.id,
        'Title': post.title,
        'Content': post.content,
        'Partition': post.partition,
        'UserName': post.authorName,
        'UserAvatar': post.authorAvatar,
        'UserTelephone': post.authorPhone,
        'PostTime': post.createdAt,
        'LikeNum': post.likeCount,
        'CommentNum': post.commentCount,
        'SaveNum': post.saveCount,
        'Browse': post.viewCount,
        'UserScore': post.userScore,
        'UserIdentity': post.userIdentity,
        'IsLiked': post.isLiked,
        'IsSaved': post.isSaved,
        'Rating': post.rating,
        'Stars': post.stars,
        'UserRating': post.userRating,
        'Heat': post.heat,
      },
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory WatchLaterItem.fromJson(Map<String, dynamic> json) {
    return WatchLaterItem(
      postId: json['postId'] as int,
      post: PostModel.fromDynamic(json['post']),
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }
}

/// 稍后再看服务 - 纯本地功能
class WatchLaterService {
  static final WatchLaterService _instance = WatchLaterService._internal();
  factory WatchLaterService() => _instance;
  WatchLaterService._internal();

  static const String _keyWatchLater = 'watch_later_v1';
  static const int _maxItemCount = 100; // 最多保存100条

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  /// 添加到稍后再看
  Future<bool> addPost(PostModel post) async {
    await init();

    final items = await getItems();

    // 检查是否已存在
    if (items.any((item) => item.postId == post.id)) {
      return false; // 已存在
    }

    // 添加到列表开头
    final newItem = WatchLaterItem(
      postId: post.id,
      post: post,
      addedAt: DateTime.now(),
    );
    items.insert(0, newItem);

    // 限制最大数量
    if (items.length > _maxItemCount) {
      items.removeRange(_maxItemCount, items.length);
    }

    await _saveItems(items);
    return true;
  }

  /// 获取所有稍后再看项
  Future<List<WatchLaterItem>> getItems() async {
    await init();

    final jsonString = _prefs.getString(_keyWatchLater);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => WatchLaterItem.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 检查帖子是否已添加
  Future<bool> hasPost(int postId) async {
    final items = await getItems();
    return items.any((item) => item.postId == postId);
  }

  /// 删除单个项
  Future<void> removeItem(int postId) async {
    await init();

    final items = await getItems();
    items.removeWhere((item) => item.postId == postId);
    await _saveItems(items);
  }

  /// 删除多个项
  Future<void> removeItems(List<int> postIds) async {
    await init();

    final items = await getItems();
    items.removeWhere((item) => postIds.contains(item.postId));
    await _saveItems(items);
  }

  /// 清空所有
  Future<void> clearAll() async {
    await init();
    await _prefs.remove(_keyWatchLater);
  }

  /// 保存项列表
  Future<void> _saveItems(List<WatchLaterItem> items) async {
    final jsonList = items.map((item) => item.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _prefs.setString(_keyWatchLater, jsonString);
  }
}
