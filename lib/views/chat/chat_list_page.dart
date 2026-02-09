import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/services/websocket_service.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class ChatListPage extends StatefulWidget {
  final ApiService apiService;
  final Function(UserModel user) onUserTap;
  final EdgeInsetsGeometry? contentPadding;

  const ChatListPage({
    super.key,
    required this.apiService,
    required this.onUserTap,
    this.contentPadding,
  });

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  final List<ChatContact> _contacts = [];
  StreamSubscription<List<ChatContact>>? _contactsSubscription;

  @override
  bool get wantKeepAlive => true;

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
      if (ws.currentContacts.isNotEmpty && !_hasLoadedOnce) {
        _contacts.clear();
        _contacts.addAll(ws.currentContacts);
        _loadLatestMessages();
      } else if (_hasLoadedOnce) {
        // 已经加载过，只更新数据不重新排序
        _updateContactsWithoutReorder(ws.currentContacts);
      }

      // 监听联系人更新
      _contactsSubscription = ws.contacts.listen((contacts) {
        if (mounted) {
          if (!_hasLoadedOnce) {
            _contacts.clear();
            _contacts.addAll(contacts);
            _loadLatestMessages();
          } else {
            // 已经加载过，只更新数据不重新排序
            _updateContactsWithoutReorder(contacts);
          }
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

  /// 更新联系人数据但不重新排序
  void _updateContactsWithoutReorder(List<ChatContact> newContacts) {
    // 更新现有联系人的数据（未读数等）
    for (final newContact in newContacts) {
      final index = _contacts.indexWhere((c) => c.userId == newContact.userId);
      if (index != -1) {
        _contacts[index].unreadCount = newContact.unreadCount;
        _contacts[index].lastMessage = newContact.lastMessage ?? _contacts[index].lastMessage;
        if (newContact.lastMessageTime != null) {
          _contacts[index].lastMessageTime = newContact.lastMessageTime;
        }
      } else {
        // 新联系人，添加到列表开头
        _contacts.insert(0, newContact);
      }
    }
    if (mounted) {
      setState(() {});
    }
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

    // 只在首次加载时排序
    if (!_hasLoadedOnce) {
      _contacts.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });
      _hasLoadedOnce = true;
    }

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
    super.build(context); // 必须调用 super.build
    
    // Default padding if not provided. Default includes bottom 60 for tabbar
    final padding = widget.contentPadding ?? const EdgeInsets.fromLTRB(16, 12, 16, 60);

    // 直接显示内容，不显示 loading 状态
    // 如果正在加载且没有联系人，显示空状态
    return _contacts.isEmpty
        ? Padding(
             padding: EdgeInsets.only(top: padding.resolve(TextDirection.ltr).top), 
             child: _buildEmptyState(context)
          )
        : RefreshIndicator(
             edgeOffset: padding.resolve(TextDirection.ltr).top,
             onRefresh: () async {
                  _initWebSocket();
                  await Future.delayed(const Duration(seconds: 1));
                },
                color: AppColors.primary,
                child: ListView.builder(
                  padding: padding,
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return _buildContactItem(context, contact);
                  },
                ),
              );
  }

  Widget _buildContactItem(BuildContext context, ChatContact contact) {
    final hasUnread = contact.unreadCount > 0;
    final lastMsg = contact.lastMessage ?? contact.intro ?? '';
    final timeStr = _formatTime(contact.lastMessageTime);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.surfaceColor,
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
                    Builder(builder: (context) {
                      final defaultAvatar = SvgPicture.asset(
                        'assets/icons/default_avatar.svg',
                        fit: BoxFit.cover,
                      );
                      return Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.backgroundColor,
                          border: Border.all(color: context.dividerColor, width: 0.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: contact.avatarUrl.isNotEmpty
                            ? CachedImage(
                                imageUrl: contact.avatarUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                category: CacheCategory.avatar,
                                errorWidget: defaultAvatar,
                              )
                            : defaultAvatar,
                      );
                    }),
                    // 未读红点
                    if (hasUnread)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                          child: Center(
                            child: Text(
                              contact.unreadCount > 99 ? '99+' : '${contact.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
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
                                color: context.textPrimaryColor,
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
                                color: hasUnread ? AppColors.primary : context.textTertiaryColor,
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
                          color: hasUnread ? context.textPrimaryColor : context.textSecondaryColor,
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
                  color: context.textTertiaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: context.textTertiaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无私信',
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '去用户主页发起私信吧',
            style: TextStyle(
              color: context.textTertiaryColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
