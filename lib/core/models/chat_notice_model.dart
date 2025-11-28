class ChatNoticeModel {
  final int userId;
  final String email;
  final String name;
  final String avatarUrl;
  final String identity;
  final int score;
  final int unRead;

  ChatNoticeModel({
    required this.userId,
    required this.email,
    required this.name,
    required this.avatarUrl,
    required this.identity,
    required this.score,
    required this.unRead,
  });

  factory ChatNoticeModel.fromJson(Map<String, dynamic> json) {
    return ChatNoticeModel(
      userId: json['userID'] ?? 0,
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatarURL'] ?? '',
      identity: json['identity'] ?? '',
      score: json['score'] ?? 0,
      unRead: json['unRead'] ?? 0,
    );
  }

  static ChatNoticeModel empty() {
    return ChatNoticeModel(
      userId: 0,
      email: '',
      name: '',
      avatarUrl: '',
      identity: '',
      score: 0,
      unRead: 0,
    );
  }
}
