import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/services/websocket_service.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class ChatListPage extends StatefulWidget {
  final ApiService apiService;
  final Function(UserModel user) onUserTap;

  const ChatListPage({
    super.key,
    required this.apiService,
    required this.onUserTap,
  });

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _isLoading = true;
  final List<ChatContact> _contacts = [];
  StreamSubscription<List<ChatContact>>? _contactsSubscription;

  @override
  void initState() {
    super.initState();
    _initWebSocket();
  }

  @override
  void dispose() {
    _contactsSubscription?.cancel();
    super.dispose();
  }

  void _initWebSocket() {
    try {
      final ws = WebSocketService();
      if (!ws.isConnected) {
        ws.connect();
      }

      // 使用已有的联系人数据
      if (ws.currentContacts.isNotEmpty) {
        _contacts.clear();
        _contacts.addAll(ws.currentContacts);
        _loadLatestMessages();
      }

      // 监听联系人更新
      _contactsSubscription = ws.contacts.listen((contacts) {
        if (mounted) {
          _contacts.clear();
          _contacts.addAll(contacts);
          _loadLatestMessages();
        }
      });
    } catch (e) {
      debugPrint('ChatListPage WebSocket init error: $e');
    }
    
    // Fallback: if no contacts after some time, show empty or stop loading
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  /// 为每个联系人加载最新消息
  Future<void> _loadLatestMessages() async {
    final currentUser = StorageService().user;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    // 并行获取每个联系人的最新消息
    await Future.wait(_contacts.map((contact) async {
      try {
        final messages = await widget.apiService.getChatHistory(
          currentUser.userId,
          contact.userId,
        );
        if (messages.isNotEmpty) {
          // 获取最新一条消息
          final lastMsg = messages.last;
          contact.lastMessage = lastMsg.content;
          final msgTime = DateTime.tryParse(lastMsg.createdAt);
          if (msgTime != null) {
            contact.lastMessageTime = msgTime;
          }
        }
      } catch (e) {
        debugPrint('Error loading messages for ${contact.name}: $e');
      }
    }));

    // 按最新消息时间排序（最新的在前）
    _contacts.sort((a, b) {
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  UserModel _contactToUserModel(ChatContact contact) {
    return UserModel(
      userId: contact.userId,
      name: contact.name,
      email: contact.email,
      phone: '',
      avatar: contact.avatarUrl,
      score: contact.score,
      identity: contact.identity,
      intro: contact.intro ?? '',
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    
    final localTime = time.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(localTime.year, localTime.month, localTime.day);
    final diff = today.difference(messageDay).inDays;
    
    final timeStr = '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    
    if (diff == 0) {
      // 今天
      return timeStr;
    } else if (diff == 1) {
      return '昨天';
    } else if (diff < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[localTime.weekday - 1];
    } else {
      // 显示月/日
      return '${localTime.month}/${localTime.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _contacts.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: () async {
                  _initWebSocket();
                  await Future.delayed(const Duration(seconds: 1));
                },
                color: AppColors.primary,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return _buildContactItem(contact);
                  },
                ),
              );
  }

  Widget _buildContactItem(ChatContact contact) {
    final hasUnread = contact.unreadCount > 0;
    final lastMsg = contact.lastMessage ?? contact.intro ?? '';
    final timeStr = _formatTime(contact.lastMessageTime);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onUserTap(_contactToUserModel(contact)),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 头像
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.background,
                        border: Border.all(color: AppColors.divider, width: 0.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: contact.avatarUrl.isNotEmpty 
                          ? Image.network(
                              contact.avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 24, color: AppColors.textSecondary),
                            )
                          : const Icon(Icons.person, size: 24, color: AppColors.textSecondary),
                    ),
                    // 未读红点
                    if (hasUnread)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.surface, width: 1.5),
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
                          child: Center(
                            child: Text(
                              contact.unreadCount > 99 ? '99+' : '${contact.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // 名称和最新消息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contact.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeStr.isNotEmpty)
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: hasUnread ? AppColors.primary : AppColors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // 右箭头
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无私信',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '去用户主页发起私信吧',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
