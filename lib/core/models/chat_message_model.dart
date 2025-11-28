class ChatMessageModel {
  final int chatMsgId;
  final int targetUserId;
  final int senderUserId;
  final String content;
  final int unread;
  final String createdAt;
  final bool isAnonymous;

  ChatMessageModel({
    required this.chatMsgId,
    required this.targetUserId,
    required this.senderUserId,
    required this.content,
    required this.unread,
    required this.createdAt,
    required this.isAnonymous,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      chatMsgId: json['chatMsgID'] ?? 0,
      targetUserId: json['targetUserID'] ?? 0,
      senderUserId: json['senderUserID'] ?? 0,
      content: json['content'] ?? '',
      unread: json['unread'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      isAnonymous: json['isAnonymous'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatMsgID': chatMsgId,
      'targetUserID': targetUserId,
      'senderUserID': senderUserId,
      'content': content,
      'unread': unread,
      'createdAt': createdAt,
      'isAnonymous': isAnonymous,
    };
  }
}
