/// 评论数据模型
class CommentModel {
  final int id;
  final int authorId;
  final String authorName;
  final String authorPhone;
  final int authorScore;
  final String authorAvatar;
  final String authorIdentity;
  final String commentTime;
  final String content;
  final int likeCount;
  final bool isLiked;
  final List<SubCommentModel> subComments;
  final int? postRating; // 用户对该帖子的评分

  const CommentModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorPhone,
    required this.authorScore,
    required this.authorAvatar,
    required this.authorIdentity,
    required this.commentTime,
    required this.content,
    required this.likeCount,
    required this.isLiked,
    required this.subComments,
    this.postRating,
  });

  factory CommentModel.empty() {
    return const CommentModel(
      id: 0,
      authorId: 0,
      authorName: '',
      authorPhone: '',
      authorScore: 0,
      authorAvatar: '',
      authorIdentity: '',
      commentTime: '',
      content: '',
      likeCount: 0,
      isLiked: false,
      subComments: [],
      postRating: null,
    );
  }

  factory CommentModel.fromDynamic(dynamic raw) {
    if (raw is! Map) {
      return CommentModel.empty();
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

    List<SubCommentModel> _readSubComments() {
      final subCommentsRaw = map['SubComments'] ?? map['subComments'] ?? [];
      if (subCommentsRaw is List) {
        return subCommentsRaw
            .map((e) => SubCommentModel.fromDynamic(e))
            .toList();
      }
      return [];
    }

    return CommentModel(
      id: _readInt(['PcommentID', 'pcommentID', 'id']),
      authorId: _readInt(['AuthorID', 'authorID']),
      authorName: _readString(['Author', 'author', 'AuthorName', 'authorName']),
      authorPhone: _readString(['AuthorTelephone', 'authorTelephone']),
      authorScore: _readInt(['AuthorScore', 'authorScore']),
      authorAvatar: _readString(['AuthorAvatar', 'authorAvatar']),
      authorIdentity: _readString(['AuthorIdentity', 'authorIdentity']),
      commentTime: _readString(['CommentTime', 'commentTime']),
      content: _readString(['Content', 'content']),
      likeCount: _readInt(['LikeNum', 'likeNum']),
      isLiked: _readBool(['IsLiked', 'isLiked']),
      subComments: _readSubComments(),
      postRating: _readInt(['AuthorRating', 'authorRating', 'Rating', 'rating']) > 0 
          ? _readInt(['AuthorRating', 'authorRating', 'Rating', 'rating']) 
          : null,
    );
  }
}

/// 子评论数据模型
class SubCommentModel {
  final int id;
  final String authorName;
  final int authorId;
  final int authorScore;
  final String authorPhone;
  final String authorAvatar;
  final String authorIdentity;
  final String commentTime;
  final String content;
  final int likeCount;
  final bool isLiked;
  final String targetUserName;

  const SubCommentModel({
    required this.id,
    required this.authorName,
    required this.authorId,
    required this.authorScore,
    required this.authorPhone,
    required this.authorAvatar,
    required this.authorIdentity,
    required this.commentTime,
    required this.content,
    required this.likeCount,
    required this.isLiked,
    required this.targetUserName,
  });

  factory SubCommentModel.empty() {
    return const SubCommentModel(
      id: 0,
      authorName: '',
      authorId: 0,
      authorScore: 0,
      authorPhone: '',
      authorAvatar: '',
      authorIdentity: '',
      commentTime: '',
      content: '',
      likeCount: 0,
      isLiked: false,
      targetUserName: '',
    );
  }

  factory SubCommentModel.fromDynamic(dynamic raw) {
    if (raw is! Map) {
      return SubCommentModel.empty();
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

    return SubCommentModel(
      id: _readInt(['ccommentID', 'CcommentID', 'id']),
      authorName: _readString(['author', 'Author', 'authorName']),
      authorId: _readInt(['authorID', 'AuthorID']),
      authorScore: _readInt(['authorScore', 'AuthorScore']),
      authorPhone: _readString(['authorTelephone', 'AuthorTelephone']),
      authorAvatar: _readString(['authorAvatar', 'AuthorAvatar']),
      authorIdentity: _readString(['authorIdentity', 'AuthorIdentity']),
      commentTime: _readString(['commentTime', 'CommentTime']),
      content: _readString(['content', 'Content']),
      likeCount: _readInt(['likeNum', 'LikeNum']),
      isLiked: _readBool(['isLiked', 'IsLiked']),
      targetUserName: _readString(['userTargetName', 'UserTargetName']),
    );
  }
}
