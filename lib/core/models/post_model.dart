class PostModel {
  final int id;
  final String title;
  final String content;
  final String partition;
  final String authorName;
  final String authorAvatar;
  final String authorPhone;
  final String createdAt;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final int viewCount;
  final int userScore;
  final String userIdentity;
  final bool isLiked;
  final bool isSaved;
  final double rating;
  final List<int> stars;
  final int userRating;
  final int heat; // 热度值，用于热榜排名

  const PostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.partition,
    required this.authorName,
    required this.authorAvatar,
    required this.authorPhone,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.viewCount,
    required this.userScore,
    required this.userIdentity,
    this.isLiked = false,
    this.isSaved = false,
    this.rating = 0.0,
    this.stars = const [],
    this.userRating = 0,
    this.heat = 0,
  });

  /// 复制并修改点赞状态
  PostModel copyWithLike({required bool isLiked, required int likeCount}) {
    return PostModel(
      id: id,
      title: title,
      content: content,
      partition: partition,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorPhone: authorPhone,
      createdAt: createdAt,
      likeCount: likeCount,
      commentCount: commentCount,
      saveCount: saveCount,
      viewCount: viewCount,
      userScore: userScore,
      userIdentity: userIdentity,
      isLiked: isLiked,
      isSaved: isSaved,
      rating: rating,
      stars: stars,
      userRating: userRating,
      heat: heat,
    );
  }

  factory PostModel.empty() {
    return const PostModel(
      id: 0,
      title: '',
      content: '',
      partition: '',
      authorName: '',
      authorAvatar: '',
      authorPhone: '',
      createdAt: '',
      likeCount: 0,
      commentCount: 0,
      saveCount: 0,
      viewCount: 0,
      userScore: 0,
      userIdentity: '',
      isLiked: false,
      isSaved: false,
      rating: 0.0,
      stars: [],
      userRating: 0,
      heat: 0,
    );
  }

  /// 转换为 JSON Map
  Map<String, dynamic> toJson() {
    return {
      'PostID': id,
      'Title': title,
      'Content': content,
      'Partition': partition,
      'UserName': authorName,
      'UserAvatar': authorAvatar,
      'UserTelephone': authorPhone,
      'PostTime': createdAt,
      'LikeNum': likeCount,
      'CommentNum': commentCount,
      'SaveNum': saveCount,
      'Browse': viewCount,
      'UserScore': userScore,
      'UserIdentity': userIdentity,
      'IsLiked': isLiked,
      'IsSaved': isSaved,
      'Rating': rating,
      'Stars': stars,
      'UserRating': userRating,
      'Heat': heat,
    };
  }

  factory PostModel.fromDynamic(dynamic raw) {
    if (raw is! Map) {
      return PostModel.empty();
    }
    final map = raw.cast<String, dynamic>();

    int _readInt(List<String> keys) {
      for (final key in keys) {
        final v = map[key];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return 0;
    }

    String _readString(List<String> keys) {
      for (final key in keys) {
        final v = map[key];
        if (v is String) return v;
      }
      return '';
    }

    bool _readBool(List<String> keys) {
      for (final key in keys) {
        final v = map[key];
        if (v is bool) return v;
        if (v is int) return v != 0;
        if (v is String) return v.toLowerCase() == 'true' || v == '1';
      }
      return false;
    }

    List<int> _readListInt(List<String> keys) {
      for (final key in keys) {
        final v = map[key];
        if (v is List) {
          return v.map((e) {
            if (e is int) return e;
            if (e is num) return e.toInt();
            if (e is String) return int.tryParse(e) ?? 0;
            return 0;
          }).toList();
        }
      }
      return [];
    }

    double _readDouble(List<String> keys) {
      for (final key in keys) {
        final v = map[key];
        if (v is double) return v;
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
      }
      return 0.0;
    }

    return PostModel(
      id: _readInt(['PostID', 'postID', 'id']),
      title: _readString(['Title', 'title']),
      content: _readString(['Content', 'content']),
      partition: _readString(['Partition', 'partition']),
      authorName: _readString(['UserName', 'userName', 'Name']),
      authorAvatar: _readString(['UserAvatar', 'userAvatar', 'Avatar', 'avatar', 'AvatarURL', 'avatarURL']),
      authorPhone: _readString(['UserTelephone', 'userTelephone', 'Phone', 'phone']),
      createdAt: _readString(['PostTime', 'postTime', 'CreatedAt', 'createdAt', 'CreateTime']),
      likeCount: _readInt(['LikeNum', 'likeNum', 'LikeCount', 'likeCount', 'Like']),
      commentCount: _readInt(['CommentNum', 'commentNum', 'CommentCount', 'commentCount', 'Comment']),
      saveCount: _readInt(['SaveNum', 'saveNum', 'SaveCount', 'saveCount']),
      viewCount: _readInt(['Browse', 'browse', 'ViewNum', 'viewNum']),
      userScore: _readInt(['UserScore', 'userScore', 'Score']),
      userIdentity: _readString(['UserIdentity', 'userIdentity', 'Identity']),
      isLiked: _readBool(['IsLiked', 'isLiked']),
      isSaved: _readBool(['IsSaved', 'isSaved']),
      rating: _readDouble(['Rating', 'rating']),
      stars: _readListInt(['Stars', 'stars']),
      userRating: _readInt(['UserRating', 'userRating']),
      heat: _readInt(['Heat', 'heat']),
    );
  }
}
