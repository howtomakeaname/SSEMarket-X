import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/notice_model.dart';
import 'package:sse_market_x/core/utils/time_utils.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/chat/chat_list_page.dart';
import 'package:sse_market_x/views/chat/chat_detail_page.dart';
import 'package:sse_market_x/core/services/websocket_service.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'dart:async';

class NoticePage extends StatefulWidget {
  final ApiService apiService;
  final Function(UserModel)? onChatTap;

  const NoticePage({
    super.key,
    required this.apiService,
    this.onChatTap,
  });

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  List<Notice> _unreadNotices = [];
  List<Notice> _readNotices = [];
  bool _isLoading = true;
  int _chatUnreadCount = 0;
  StreamSubscription<int>? _chatUnreadSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
    _initChatUnreadListener();
  }

  void _initChatUnreadListener() {
    try {
      final ws = WebSocketService();
      _chatUnreadCount = ws.totalUnreadCount;
      _chatUnreadSubscription = ws.unreadCount.listen((count) {
        if (mounted) {
          setState(() {
            _chatUnreadCount = count;
          });
        }
      });
    } catch (e) {
      debugPrint('NoticePage chat unread listener error: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _chatUnreadSubscription?.cancel();
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    final noticesToMark = List<Notice>.from(_unreadNotices);
    if (noticesToMark.isEmpty) return;

    setState(() {
      _readNotices.insertAll(0, noticesToMark);
      _unreadNotices.clear();
    });

    try {
      await Future.wait(noticesToMark.map((n) => widget.apiService.readNotice(n.noticeId)));
    } catch (e) {
      debugPrint('一键已读失败: $e');
    }
  }

  Future<void> _loadNotices({bool refresh = false}) async {
    if (!refresh) setState(() => _isLoading = true);

    try {
      final noticeNum = await widget.apiService.getNoticeNum();
      final unreadList = await widget.apiService.getNotices(requireId: 0, pageSize: noticeNum.unreadTotalNum > 0 ? noticeNum.unreadTotalNum : 20, read: 0);
      final readList = await widget.apiService.getNotices(requireId: 0, pageSize: noticeNum.readTotalNum > 0 ? noticeNum.readTotalNum : 20, read: 1);

      if (mounted) {
        setState(() {
          _unreadNotices = unreadList;
          _readNotices = readList;
        });
      }
    } catch (e) {
      debugPrint('加载通知失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用 super.build
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: Text(
          '消息',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        centerTitle: false,
        titleSpacing: 16,
      ),
      body: Column(
        children: [
          _buildTabs(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              children: [
                // 私信列表
                ChatListPage(
                  apiService: widget.apiService,
                  onUserTap: (user) {
                    if (widget.onChatTap != null) {
                      widget.onChatTap!(user);
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatDetailPage(
                            apiService: widget.apiService,
                            targetUser: user,
                            isEmbedded: false,
                          ),
                        ),
                      );
                    }
                  },
                ),
                // 未读通知
                _isLoading 
                    ? const LoadingIndicator.center(message: '加载中...')
                    : _buildNoticeList(_unreadNotices, isUnread: true),
                // 已读通知
                _isLoading
                    ? const LoadingIndicator.center(message: '加载中...')
                    : _buildNoticeList(_readNotices, isUnread: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.surfaceColor,
      child: Row(
        children: [
          _buildTabButton('私信', 0, badgeCount: _chatUnreadCount),
          const SizedBox(width: 8),
          _buildTabButton('未读通知', 1, badgeCount: _unreadNotices.length),
          const SizedBox(width: 8),
          _buildTabButton('已读通知', 2),
          const Spacer(),
          if (_currentIndex == 1 && _unreadNotices.isNotEmpty)
            GestureDetector(
              onTap: _markAllAsRead,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: context.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '一键已读',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index, {int badgeCount = 0}) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        // 点击 Tab 时直接切换到目标页，避免动画滚动经过中间页造成不必要的渲染
        _pageController.jumpToPage(index);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : context.backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.white : context.textPrimaryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (badgeCount > 0)
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
                    badgeCount > 99 ? '99+' : '$badgeCount',
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
    );
  }

  Widget _buildNoticeList(List<Notice> notices, {required bool isUnread}) {
    if (notices.isEmpty) {
      return Center(
        child: Text(isUnread ? '暂无未读通知' : '暂无已读通知', style: TextStyle(fontSize: 16, color: context.textTertiaryColor)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadNotices(refresh: true),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
        itemCount: notices.length,
        itemBuilder: (context, index) {
          final notice = notices[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.backgroundColor,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: notice.senderAvatar.isNotEmpty
                      ? Image.network(
                          notice.senderAvatar,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => SvgPicture.asset(
                            'assets/icons/default_avatar.svg',
                            fit: BoxFit.cover,
                          ),
                        )
                      : SvgPicture.asset(
                          'assets/icons/default_avatar.svg',
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            notice.senderName,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textPrimaryColor),
                          ),
                          Text(
                            notice.postId == 0
                                ? ''
                                : TimeUtils.formatNoticeTime(notice.time),
                            style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notice.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: context.textSecondaryColor, height: 1.3),
                      ),
                      if (notice.postId == 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '该评论已删除',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      ],
                      if (isUnread)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              _buildActionButton('标记已读', () async {
                                final success = await widget.apiService.readNotice(notice.noticeId);
                                if (success) _loadNotices(refresh: true);
                              }),
                              if (notice.postId > 0) const SizedBox(width: 8),
                              if (notice.postId > 0)
                                _buildActionButton('查看原帖', () async {
                                  // 先标记已读
                                  await widget.apiService.readNotice(notice.noticeId);
                                  if (!mounted) return;
                                  // 刷新列表（因为这条消息已读了）
                                  _loadNotices(refresh: true);
                                  // 跳转
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PostDetailPage(postId: notice.postId, apiService: widget.apiService),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        )
                      else if (notice.postId > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              _buildActionButton('查看原帖', () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PostDetailPage(postId: notice.postId, apiService: widget.apiService),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF4D4D),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
      ),
    );
  }
}
