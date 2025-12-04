import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/chat_message_model.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/services/websocket_service.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/inputs/emoji_picker.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class ChatDetailPage extends StatefulWidget {
  final ApiService apiService;
  final UserModel targetUser;
  final bool isEmbedded;

  const ChatDetailPage({
    super.key,
    required this.apiService,
    required this.targetUser,
    this.isEmbedded = false,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  UserModel? _currentUser;

  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _ensureWebSocketConnected();
    _loadMessages();
    _subscribeToMessages();
    _messageController.addListener(_onTextChanged);
    
    // 标记与该用户的对话为已读
    WebSocketService().markAsRead(widget.targetUser.userId);
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await widget.apiService.getUserInfo();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      debugPrint('加载当前用户信息失败: $e');
    }
  }

  void _onTextChanged() {
    setState(() {}); // 更新发送按钮状态
  }

  void _ensureWebSocketConnected() {
    final ws = WebSocketService();
    if (!ws.isConnected) {
      ws.connect();
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.removeListener(_onTextChanged);
    // 先取消焦点，避免输入法状态切换问题
    _focusNode.unfocus();
    _focusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToMessages() {
    final ws = WebSocketService();
    _messageSubscription = ws.messages.listen((data) {
      if (data is Map) {
        // Check if it's a message
        if (data.containsKey('chatMsgID') && 
            data.containsKey('content') &&
            data.containsKey('senderUserID')) {
          
          final senderId = data['senderUserID'];
          final targetId = data['targetUserID'];
          
          // Check if message belongs to this conversation
          final currentUser = StorageService().user;
          if (currentUser == null) return;

          bool isRelevant = false;
          if (senderId == widget.targetUser.userId && targetId == currentUser.userId) {
            // Message from target user to me
            isRelevant = true;
          } else if (senderId == currentUser.userId && targetId == widget.targetUser.userId) {
            // Message from me to target user (e.g. sent from another device or echoed back)
            // Usually we add our own messages locally, but if server echoes, we might duplicate.
            // If we rely on local add, we should ignore own messages from stream unless we handle ack.
            // Assuming server pushes new messages from others.
            // But wait, newSSE handles: if (data.senderUserID === current.userID) -> push to history.
            // So we should handle both. But we already add locally in _sendMessage. 
            // We should avoid duplicates if server echoes.
            // Let's assume for now we only care about incoming messages from targetUser.
            // If server broadcasts my own message back to me, I need to deduplicate or not add locally?
            // Usually local add is for immediate feedback.
            // Let's filter out my own messages for now to avoid duplication if I already added it.
            isRelevant = false; 
          }

          if (isRelevant) {
            final message = ChatMessageModel.fromJson(data as Map<String, dynamic>);
            if (mounted) {
              setState(() {
                _messages.add(message);
              });
            }
          }
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    final currentUser = StorageService().user;
    if (currentUser != null) {
      final messages = await widget.apiService.getChatHistory(
        currentUser.userId,
        widget.targetUser.userId,
      );
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// 滚动到底部（reverse 模式下是滚动到 position 0）
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    final success = WebSocketService().sendMessage(
      widget.targetUser.userId,
      text,
    );
    
    if (success) {
      final currentUser = StorageService().user;
      if (currentUser != null) {
        final newMessage = ChatMessageModel(
          chatMsgId: DateTime.now().millisecondsSinceEpoch, // Temp ID
          targetUserId: widget.targetUser.userId,
          senderUserId: currentUser.userId,
          content: text,
          unread: 1,
          createdAt: DateTime.now().toIso8601String(),
          isAnonymous: false,
        );
        
        setState(() {
          _messages.add(newMessage);
          _messageController.clear();
        });
        _scrollToBottom();
      }
    } else {
      // Fallback to HTTP or show error?
      // For now, just show error or retry logic can be added.
      // Maybe WebSocket is connecting...
      // Let's just show a snackbar or something in a real app.
      print('Failed to send message via WebSocket');
    }

    setState(() {
      _isSending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.isEmbedded
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          widget.targetUser.name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        centerTitle: false,
        titleSpacing: widget.isEmbedded ? 16 : 0,
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          '开始聊天吧',
                          style: TextStyle(color: context.textSecondaryColor),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          // reverse 模式下，index 0 是最新消息，需要反转索引
                          final reversedIndex = _messages.length - 1 - index;
                          final message = _messages[reversedIndex];
                          final isMe = message.senderUserId == StorageService().user?.userId;
                          final showTime = _shouldShowTime(reversedIndex);
                          return _buildMessageItem(message, isMe, showTime, reversedIndex);
                        },
                      ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(top: BorderSide(color: context.dividerColor)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 输入框
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 36),
                      decoration: BoxDecoration(
                        color: context.backgroundColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        maxLines: 5,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: '输入内容...',
                          hintStyle: TextStyle(color: context.textSecondaryColor, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        style: TextStyle(fontSize: 14, color: context.textPrimaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 表情选择器按钮
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: EmojiPickerButton(
                      controller: _messageController,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 发送按钮
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _messageController.text.trim().isEmpty
                            ? context.textSecondaryColor.withAlpha(100)
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: IconButton(
                        onPressed: (_isSending || _messageController.text.trim().isEmpty) 
                            ? null 
                            : _sendMessage,
                        icon: _isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, size: 18, color: Colors.white),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 判断是否需要显示时间（iMessage 风格：相隔5分钟以上显示）
  bool _shouldShowTime(int index) {
    if (index == 0) return true;
    
    final current = _messages[index];
    final previous = _messages[index - 1];
    
    final currentTime = DateTime.tryParse(current.createdAt);
    final previousTime = DateTime.tryParse(previous.createdAt);
    
    if (currentTime == null || previousTime == null) return false;
    
    // 相隔5分钟以上显示时间
    return currentTime.difference(previousTime).inMinutes >= 5;
  }

  /// 格式化时间显示（本地时间格式）
  String _formatMessageTime(String createdAt) {
    final utcTime = DateTime.tryParse(createdAt);
    if (utcTime == null) return '';
    
    // 转换为本地时间
    final time = utcTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(time.year, time.month, time.day);
    final diff = today.difference(messageDay).inDays;
    
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    
    if (diff == 0) {
      // 今天
      return timeStr;
    } else if (diff == 1) {
      return '昨天 $timeStr';
    } else if (diff < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return '${weekdays[time.weekday - 1]} $timeStr';
    } else if (time.year == now.year) {
      return '${time.month}月${time.day}日 $timeStr';
    } else {
      return '${time.year}年${time.month}月${time.day}日 $timeStr';
    }
  }

  Widget _buildMessageItem(ChatMessageModel message, bool isMe, bool showTime, int index) {
    return Column(
      children: [
        if (showTime)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _formatMessageTime(message.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondaryColor,
              ),
            ),
          ),
        _buildMessageBubble(message, isMe),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe) {
    // 计算消息气泡的最大宽度（参考微信）
    // 双方消息都不应该超过对方的起始位置
    // 对方起始位置 = 头像(32) + 间距(8) = 40
    // 消息最大宽度 = 屏幕宽度 - 左侧头像和间距(40) - 右侧头像和间距(40) = 屏幕宽度 - 80
    final double maxWidth = MediaQuery.of(context).size.width - 80;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _buildAvatar(widget.targetUser.avatar),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primary : context.backgroundColor,
                  borderRadius: BorderRadius.circular(16).copyWith(
                    topLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                    topRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                  ),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : context.textPrimaryColor,
                  ),
                ),
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            _buildAvatar(_currentUser?.avatar ?? ''),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl) {
    final defaultAvatar = SvgPicture.asset(
      'assets/icons/default_avatar.svg',
      fit: BoxFit.cover,
    );

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.backgroundColor,
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isNotEmpty
          ? CachedImage(
              imageUrl: avatarUrl,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              category: CacheCategory.avatar,
              errorWidget: defaultAvatar,
            )
          : defaultAvatar,
    );
  }
}
