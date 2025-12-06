import 'dart:async';

/// 通知服务 - 管理通知未读数状态
class NoticeService {
  static final NoticeService _instance = NoticeService._internal();
  factory NoticeService() => _instance;
  NoticeService._internal();

  final _unreadCountController = StreamController<int>.broadcast();
  int _unreadCount = 0;

  /// 未读数变化流
  Stream<int> get unreadCount => _unreadCountController.stream;

  /// 当前未读数
  int get currentUnreadCount => _unreadCount;

  /// 更新未读数
  void updateUnreadCount(int count) {
    if (_unreadCount != count) {
      _unreadCount = count;
      _unreadCountController.add(_unreadCount);
    }
  }

  /// 减少未读数（标记已读时调用）
  void decreaseUnreadCount([int count = 1]) {
    _unreadCount = (_unreadCount - count).clamp(0, double.infinity).toInt();
    _unreadCountController.add(_unreadCount);
  }

  /// 清空未读数（一键已读时调用）
  void clearUnreadCount() {
    if (_unreadCount != 0) {
      _unreadCount = 0;
      _unreadCountController.add(_unreadCount);
    }
  }

  /// 释放资源
  void dispose() {
    _unreadCountController.close();
  }
}
