import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/models/product_model.dart';

/// 浏览历史项类型
enum BrowseHistoryItemType {
  post,    // 普通帖子
  course,  // 课程帖子
  rating,  // 评分帖子
  product, // 闲置商品
}

/// 浏览历史项
class BrowseHistoryItem {
  final int id;
  final BrowseHistoryItemType type;
  final dynamic data; // PostModel 或其他数据
  final DateTime timestamp;

  BrowseHistoryItem({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'data': _dataToJson(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  dynamic _dataToJson() {
    if (data is PostModel) {
      final post = data as PostModel;
      return {
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
      };
    }
    // 对于 ProductModel，直接返回原始数据（已经是 Map 格式）
    return data;
  }

  factory BrowseHistoryItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = BrowseHistoryItemType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => BrowseHistoryItemType.post,
    );

    dynamic data;
    if (type == BrowseHistoryItemType.post ||
        type == BrowseHistoryItemType.course ||
        type == BrowseHistoryItemType.rating) {
      data = PostModel.fromDynamic(json['data']);
    } else if (type == BrowseHistoryItemType.product) {
      // 商品数据需要导入 ProductModel 才能解析，这里先保存原始数据
      data = json['data'];
    } else {
      data = json['data'];
    }

    return BrowseHistoryItem(
      id: json['id'] as int,
      type: type,
      data: data,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// 浏览历史服务 - 纯本地功能
class BrowseHistoryService {
  static final BrowseHistoryService _instance = BrowseHistoryService._internal();
  factory BrowseHistoryService() => _instance;
  BrowseHistoryService._internal();

  static const String _keyBrowseHistory = 'browse_history_v2'; // 更新版本
  static const int _maxHistoryCount = 200; // 最多保存200条记录

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  /// 添加帖子浏览记录（自动根据 partition 判断类型）
  Future<void> addPostHistory(PostModel post, {bool isRating = false, bool isCourse = false}) async {
    BrowseHistoryItemType type;
    
    // 根据 partition 自动判断类型
    // 课程交流 -> 课程分区
    // 打分 -> 打分分区
    // 其他 -> 普通帖子分区
    if (post.partition == '打分') {
      type = BrowseHistoryItemType.rating;
    } else if (post.partition == '课程交流' || post.partition == '课程') {
      type = BrowseHistoryItemType.course;
    } else {
      type = BrowseHistoryItemType.post;
    }

    final item = BrowseHistoryItem(
      id: post.id,
      type: type,
      data: post,
      timestamp: DateTime.now(),
    );

    await _addHistoryItem(item);
  }

  /// 添加商品浏览记录
  Future<void> addProductHistory(int productId, ProductModel product) async {
    // 将 ProductModel 转换为 Map 以便序列化
    final productMap = {
      'ProductID': product.id,
      'SellerID': product.sellerId,
      'SellerName': product.sellerName,
      'Price': product.price,
      'Name': product.name,
      'Description': product.description,
      'Photos': product.photos,
      'IsSold': product.isSold,
      'IsAnonymous': product.isAnonymous,
    };
    
    final item = BrowseHistoryItem(
      id: productId,
      type: BrowseHistoryItemType.product,
      data: productMap,
      timestamp: DateTime.now(),
    );

    await _addHistoryItem(item);
  }

  /// 内部方法：添加历史项
  Future<void> _addHistoryItem(BrowseHistoryItem item) async {
    await init();
    
    final historyList = await getHistory();
    
    // 移除已存在的相同项（避免重复）
    historyList.removeWhere((h) => h.id == item.id && h.type == item.type);
    
    // 添加到列表开头
    historyList.insert(0, item);
    
    // 限制最大数量
    if (historyList.length > _maxHistoryCount) {
      historyList.removeRange(_maxHistoryCount, historyList.length);
    }
    
    // 保存到本地
    await _saveHistory(historyList);
  }

  /// 获取浏览历史
  Future<List<BrowseHistoryItem>> getHistory({BrowseHistoryItemType? type}) async {
    await init();
    
    final jsonString = _prefs.getString(_keyBrowseHistory);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final items = jsonList.map((json) => BrowseHistoryItem.fromJson(json)).toList();
      
      if (type != null) {
        return items.where((item) => item.type == type).toList();
      }
      return items;
    } catch (e) {
      return [];
    }
  }

  /// 清空浏览历史
  Future<void> clearHistory({BrowseHistoryItemType? type}) async {
    await init();
    
    if (type == null) {
      await _prefs.remove(_keyBrowseHistory);
    } else {
      final historyList = await getHistory();
      final filtered = historyList.where((item) => item.type != type).toList();
      await _saveHistory(filtered);
    }
  }

  /// 删除单条记录
  Future<void> removeHistory(int id, BrowseHistoryItemType type) async {
    await init();
    
    final historyList = await getHistory();
    historyList.removeWhere((item) => item.id == id && item.type == type);
    await _saveHistory(historyList);
  }

  /// 保存历史记录
  Future<void> _saveHistory(List<BrowseHistoryItem> historyList) async {
    final jsonList = historyList.map((item) => item.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _prefs.setString(_keyBrowseHistory, jsonString);
  }

  /// 兼容旧版本：添加帖子历史（保持向后兼容）
  @Deprecated('Use addPostHistory instead')
  Future<void> addHistory(PostModel post) async {
    await addPostHistory(post);
  }
}
