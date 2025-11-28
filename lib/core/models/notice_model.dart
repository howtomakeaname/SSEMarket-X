class Notice {
  final int noticeId;
  final String receiverName;
  final String senderName;
  final String senderAvatar;
  final String type;
  final String content;
  final bool read;
  final int postId;
  final int target;
  final int pcommentId;
  final String time;

  Notice({
    required this.noticeId,
    required this.receiverName,
    required this.senderName,
    required this.senderAvatar,
    required this.type,
    required this.content,
    required this.read,
    required this.postId,
    required this.target,
    required this.pcommentId,
    required this.time,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      noticeId: json['noticeID'] ?? 0,
      receiverName: json['receiverName'] ?? '',
      senderName: json['senderName'] ?? '',
      senderAvatar: json['senderAvatar'] ?? '',
      type: json['type'] ?? '',
      content: json['content'] ?? '',
      read: json['read'] ?? false,
      postId: json['postID'] ?? 0,
      target: json['target'] ?? 0,
      pcommentId: json['pcommentID'] ?? 0,
      time: json['time'] ?? '',
    );
  }
}

class NoticeNum {
  final int totalNum;
  final int unreadTotalNum;
  final int readTotalNum;

  NoticeNum({
    required this.totalNum,
    required this.unreadTotalNum,
    required this.readTotalNum,
  });

  factory NoticeNum.fromJson(Map<String, dynamic> json) {
    return NoticeNum(
      totalNum: json['totalNum'] ?? 0,
      unreadTotalNum: json['unreadTotalNum'] ?? 0,
      readTotalNum: json['readTotalNum'] ?? 0,
    );
  }
}
