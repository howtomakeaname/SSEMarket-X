import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/services/websocket_service.dart';
import 'package:sse_market_x/core/services/blur_effect_service.dart';
import 'package:sse_market_x/core/services/desktop_layout_preference_service.dart';
import 'package:sse_market_x/views/post/create_post_page.dart';
import 'package:sse_market_x/views/home/home_page.dart';
import 'package:sse_market_x/views/profile/my_page.dart';
import 'package:sse_market_x/views/notice/notice_page.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';
import 'package:sse_market_x/views/shop/product_detail_page.dart';
import 'package:sse_market_x/views/todo/score_page.dart';
import 'package:sse_market_x/shared/components/cards/post_preview_card.dart';
import 'package:sse_market_x/shared/components/layout/layout_config.dart';
import 'package:sse_market_x/shared/components/layout/side_menu.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/shop/shop_page.dart';
// import 'package:sse_market_x/views/chat/chat_list_page.dart'; // Removed
import 'package:sse_market_x/views/chat/chat_detail_page.dart';

import 'package:sse_market_x/views/post/score_post_detail_page.dart';
import 'package:sse_market_x/core/services/notice_service.dart';

// Detail panel content types
enum DetailContentType {
  placeholder,
  postDetail,
  scorePostDetail,
  postPreview,
  productDetail,
  chatDetail
}

class IndexPage extends StatefulWidget {
  const IndexPage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _DetailNavigatorObserver extends NavigatorObserver {
  final Function(bool isInitialRoute) onRouteChanged;

  _DetailNavigatorObserver({required this.onRouteChanged});

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    // Check if we're back to the initial route
    if (previousRoute != null && previousRoute.isFirst) {
      onRouteChanged(true);
    }
  }
}

class _IndexPageState extends State<IndexPage> {
  int _currentIndex = 0;
  int? _selectedPostId; // For desktop 3-column layout
  PostModel? _selectedPost; // Store selected post model for init data
  int?
      _currentDetailPostId; // Track current post in detail panel (Legacy, can be removed but kept for compatibility if needed)
  int? _currentDetailProductId; // Track current product in detail panel
  UserModel? _selectedChatUser; // Track selected user for chat detail

  final DesktopLayoutPreferenceService _layoutPrefService =
      DesktopLayoutPreferenceService();

  static const double _splitterWidth = 6;
  static const double _minMiddleWidth = 420;
  static const double _minDetailWidth = 360;
  double? _middleColumnWidth;
  double? _sideMenuWidthValue;
  static const double _minSideMenuWidth = 220;
  static const double _maxSideMenuWidth = 420;

  DetailContentType _detailContentType = DetailContentType.placeholder;

  // Preview state - 使用 ValueNotifier 实现实时更新
  final ValueNotifier<Map<String, dynamic>> _previewDataNotifier =
      ValueNotifier({});
  bool _isShowingPreview = false;

  // 未读消息数（用于移动端底部 tab 小红点）
  int _unreadCount = 0;
  int _noticeUnreadCount = 0;
  StreamSubscription<int>? _unreadSubscription;
  StreamSubscription<int>? _noticeUnreadSubscription;

  // Keys for nested navigators to maintain state per tab
  final Map<int, GlobalKey<NavigatorState>> _navigatorKeys = {
    0: GlobalKey<NavigatorState>(),
    1: GlobalKey<NavigatorState>(),
    2: GlobalKey<NavigatorState>(),
    3: GlobalKey<NavigatorState>(),
    4: GlobalKey<NavigatorState>(),
    5: GlobalKey<NavigatorState>(),
    6: GlobalKey<NavigatorState>(),
  };

  // Key for detail panel navigator in 3-column layout
  final GlobalKey<NavigatorState> _detailNavigatorKey =
      GlobalKey<NavigatorState>();

  // Key for HomePage to access its state
  final GlobalKey<HomePageState> _homePageKey = GlobalKey<HomePageState>();

  @override
  void initState() {
    super.initState();
    _sideMenuWidthValue = _layoutPrefService.sideWidth;
    _middleColumnWidth = _layoutPrefService.middleWidth;
    _layoutPrefService.sideWidthNotifier
        .addListener(_handleSideWidthPreferenceChanged);
    _layoutPrefService.middleWidthNotifier
        .addListener(_handleMiddleWidthPreferenceChanged);
    // 初始化 WebSocket 连接，以便获取未读消息数
    _initWebSocket();
    // 初始化未读消息监听
    _initUnreadListener();
    // 刷新用户信息
    _refreshUserInfo();
  }

  @override
  void dispose() {
    _layoutPrefService.sideWidthNotifier
        .removeListener(_handleSideWidthPreferenceChanged);
    _layoutPrefService.middleWidthNotifier
        .removeListener(_handleMiddleWidthPreferenceChanged);
    _unreadSubscription?.cancel();
    _noticeUnreadSubscription?.cancel();
    super.dispose();
  }

  void _handleSideWidthPreferenceChanged() {
    if (!mounted) return;
    setState(() {
      _sideMenuWidthValue = _layoutPrefService.sideWidth;
    });
  }

  void _handleMiddleWidthPreferenceChanged() {
    if (!mounted) return;
    setState(() {
      _middleColumnWidth = _layoutPrefService.middleWidth;
    });
  }

  void _initWebSocket() {
    if (StorageService().isLoggedIn) {
      final ws = WebSocketService();
      if (!ws.isConnected) {
        ws.connect();
      }
    }
  }

  /// 初始化未读消息监听（私信）
  void _initUnreadListener() {
    try {
      final ws = WebSocketService();
      // 私信未读数
      _unreadCount = ws.totalUnreadCount;
      _unreadSubscription = ws.unreadCount.listen((count) {
        if (mounted) {
          setState(() {
            _unreadCount = count;
          });
        }
      });
    } catch (e) {
      debugPrint('IndexPage unread listener error: $e');
    }
    // 获取通知未读数
    _fetchNoticeUnreadCount();
  }

  /// 获取通知未读数
  Future<void> _fetchNoticeUnreadCount() async {
    try {
      final noticeNum = await widget.apiService.getNoticeNum();
      final noticeService = NoticeService();
      noticeService.updateUnreadCount(noticeNum.unreadTotalNum);

      // 监听通知未读数变化
      _noticeUnreadSubscription?.cancel();
      _noticeUnreadSubscription = noticeService.unreadCount.listen((count) {
        if (mounted) {
          setState(() {
            _noticeUnreadCount = count;
          });
        }
      });

      if (mounted) {
        setState(() {
          _noticeUnreadCount = noticeNum.unreadTotalNum;
        });
      }
    } catch (e) {
      debugPrint('IndexPage fetch notice count error: $e');
    }
  }

  /// 刷新用户信息并更新到 StorageService
  Future<void> _refreshUserInfo() async {
    if (!StorageService().isLoggedIn) return;

    try {
      // 获取基本用户信息
      final basicUser = await widget.apiService.getUserInfo();
      UserModel detailedUser = basicUser;

      // 如果有手机号，获取详细信息（包含 score 和 intro）
      if (basicUser.phone.isNotEmpty) {
        try {
          final detailed =
              await widget.apiService.getDetailedUserInfo(basicUser.phone);
          // 合并详细信息到基本信息
          detailedUser = basicUser.copyWith(
            score: detailed.score,
            intro: detailed.intro,
          );
        } catch (e) {
          debugPrint('获取详细用户信息失败: $e');
          // 如果获取详细信息失败，仍然使用基本信息
        }
      }

      final storage = StorageService();
      // 更新用户信息，保持当前 token 和 rememberMe 状态
      await storage.setUser(
        detailedUser,
        storage.token,
        rememberMe: storage.rememberMe,
      );
    } catch (e) {
      debugPrint('刷新用户信息失败: $e');
    }
  }

  /// Convert mobile bottom nav index to unified tab index
  /// Mobile: [0:Home, 1:Score, 2:Shop, 3:Message, 4:Profile]
  /// Unified: [0:Home, 1:CreatePost, 2:Score, 3:Shop, 4:Message, 5:Unused, 6:Profile]
  int _getMobileTabIndex(int mobileIndex) {
    if (mobileIndex == 0) return 0; // Home
    if (mobileIndex == 4) return 6; // Profile
    return mobileIndex + 1; // Score(1->2), Shop(2->3), Message(3->4)
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use 1000 as breakpoint for 3-column layout
        if (constraints.maxWidth >= 1000) {
          return _buildDesktopLayout(isThreeColumn: true);
        }
        // Use 600 as breakpoint for 2-column layout (Tablet/Desktop)
        else if (constraints.maxWidth >= 600) {
          return _buildDesktopLayout(isThreeColumn: false);
        }
        // Mobile layout
        else {
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      extendBody: true,
      body: IndexedStack(
        // Remove SafeArea to allow content behind/under
        index: _currentIndex,
        children: [
          _buildBodyForTab(0, isDesktop: false, isThreeColumn: false), // 首页
          _buildBodyForTab(2, isDesktop: false, isThreeColumn: false), // 打分
          _buildBodyForTab(3, isDesktop: false, isThreeColumn: false), // 闲置
          _buildBodyForTab(4, isDesktop: false, isThreeColumn: false), // 消息
          _buildBodyForTab(6, isDesktop: false, isThreeColumn: false), // 我的
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: BlurEffectService().enabledNotifier,
        builder: (context, isBlurEnabled, child) {
          Widget navContent = Container(
            decoration: BoxDecoration(
              color: isBlurEnabled
                  ? context.blurBackgroundColor.withOpacity(0.82)
                  : context.surfaceColor,
              border: Border(
                top: BorderSide(color: context.dividerColor, width: 0.5),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent, // Transparent for blur
              selectedItemColor: AppColors.primary,
              unselectedItemColor: context.textSecondaryColor,
              elevation: 0,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              iconSize: 24,
              items: [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SvgPicture.asset(
                      'assets/icons/home_normal.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  activeIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SvgPicture.asset(
                      'assets/icons/home_selected.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  label: '首页',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SvgPicture.asset(
                      'assets/icons/todo_normal_new.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  activeIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SvgPicture.asset(
                      'assets/icons/todo_selected_new.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  label: '打分',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SvgPicture.asset(
                      'assets/icons/shop_normal.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  activeIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SvgPicture.asset(
                      'assets/icons/shop_selected.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  label: '闲置',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildMessageIcon(isSelected: false),
                  ),
                  activeIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildMessageIcon(isSelected: true),
                  ),
                  label: '消息',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SvgPicture.asset(
                      'assets/icons/profile_normal.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  activeIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SvgPicture.asset(
                      'assets/icons/profile_selected.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  label: '我的',
                ),
              ],
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
                // 切换到首页时触发静默后台刷新
                if (index == 0) {
                  _homePageKey.currentState?.silentRefresh();
                }
                // 切换到消息页时刷新通知未读数
                if (index == 3) {
                  _fetchNoticeUnreadCount();
                }
              },
            ),
          );

          if (isBlurEnabled) {
            return ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: navContent,
              ),
            );
          } else {
            return navContent;
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout({required bool isThreeColumn}) {
    return LayoutConfig(
      isDesktop: true,
      isThreeColumn: isThreeColumn,
      onPostTap: isThreeColumn
          ? (postId, {isScorePost = false, post}) => _navigateToPostDetail(
              postId,
              isScorePost: isScorePost,
              post: post)
          : null,
      child: Scaffold(
        backgroundColor: context.surfaceColor,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final desiredSideWidth = _sideMenuWidthValue ??
                DesktopLayoutPreferenceService.defaultSideWidth;
            final desiredMiddleWidth = _middleColumnWidth ??
                DesktopLayoutPreferenceService.defaultMiddleWidth;

            if (isThreeColumn) {
              double sideWidth = desiredSideWidth;
              double middleWidth = desiredMiddleWidth;

              final maxSideWidth = totalWidth -
                  (2 * _splitterWidth) -
                  _minMiddleWidth -
                  _minDetailWidth;
              final effectiveMaxSide = maxSideWidth < _minSideMenuWidth
                  ? _minSideMenuWidth
                  : (maxSideWidth > _maxSideMenuWidth
                      ? _maxSideMenuWidth
                      : maxSideWidth);
              sideWidth = sideWidth.clamp(_minSideMenuWidth, effectiveMaxSide);

              final rawMaxMiddle = totalWidth -
                  sideWidth -
                  (2 * _splitterWidth) -
                  _minDetailWidth;
              final effectiveMaxMiddle = rawMaxMiddle < _minMiddleWidth
                  ? _minMiddleWidth
                  : rawMaxMiddle;
              middleWidth =
                  middleWidth.clamp(_minMiddleWidth, effectiveMaxMiddle);

              double detailWidth =
                  totalWidth - sideWidth - middleWidth - (2 * _splitterWidth);
              if (detailWidth < _minDetailWidth) {
                final deficit = _minDetailWidth - detailWidth;
                final reducibleFromMiddle = middleWidth - _minMiddleWidth;
                final reduceFromMiddle = reducibleFromMiddle >= deficit
                    ? deficit
                    : reducibleFromMiddle;
                middleWidth -= reduceFromMiddle;
                detailWidth += reduceFromMiddle;

                if (detailWidth < _minDetailWidth) {
                  final remaining = _minDetailWidth - detailWidth;
                  final reducibleFromSide = sideWidth - _minSideMenuWidth;
                  final reduceFromSide = reducibleFromSide >= remaining
                      ? remaining
                      : reducibleFromSide;
                  sideWidth -= reduceFromSide;
                  detailWidth += reduceFromSide;

                  if (detailWidth < _minDetailWidth) {
                    detailWidth = _minDetailWidth;
                  }
                }
              }

              final maxMiddleWidth = totalWidth -
                  sideWidth -
                  (2 * _splitterWidth) -
                  _minDetailWidth;

              return Row(
                children: [
                  SizedBox(
                    width: sideWidth,
                    child: SideMenu(
                      apiService: widget.apiService,
                      selectedIndex: _currentIndex,
                      onItemTap: (index) {
                        setState(() {
                          _currentIndex = index;
                          _detailNavigatorKey.currentState
                              ?.popUntil((route) => route.isFirst);
                          _detailContentType = DetailContentType.placeholder;
                        });
                      },
                      onAvatarTap: () {
                        setState(() {
                          _currentIndex = 6;
                          _detailNavigatorKey.currentState
                              ?.popUntil((route) => route.isFirst);
                          _detailContentType = DetailContentType.placeholder;
                        });
                      },
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          final proposed = (_sideMenuWidthValue ?? sideWidth) +
                              details.delta.dx;
                          final upperBound = effectiveMaxSide;
                          double newSide = proposed;
                          if (upperBound < _minSideMenuWidth) {
                            newSide = _minSideMenuWidth;
                          } else {
                            if (newSide < _minSideMenuWidth)
                              newSide = _minSideMenuWidth;
                            if (newSide > upperBound) newSide = upperBound;
                          }
                          _sideMenuWidthValue = newSide;

                          final double middleUpper = totalWidth -
                              newSide -
                              (2 * _splitterWidth) -
                              _minDetailWidth;
                          if (_middleColumnWidth != null) {
                            double newMiddle = _middleColumnWidth!;
                            if (middleUpper < _minMiddleWidth) {
                              newMiddle = _minMiddleWidth;
                            } else if (newMiddle > middleUpper) {
                              newMiddle = middleUpper;
                            }
                            _middleColumnWidth = newMiddle;
                          }
                        });
                      },
                      onHorizontalDragEnd: (_) {
                        if (_sideMenuWidthValue != null) {
                          unawaited(_layoutPrefService
                              .setSideWidth(_sideMenuWidthValue!));
                        }
                        if (_middleColumnWidth != null) {
                          unawaited(_layoutPrefService
                              .setMiddleWidth(_middleColumnWidth!));
                        }
                      },
                      child: Container(
                        width: _splitterWidth,
                        height: double.infinity,
                        color: context.surfaceColor,
                        child: Center(
                          child: Container(
                            width: 2,
                            height: 40,
                            decoration: BoxDecoration(
                              color: context.dividerColor.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: middleWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                            right: BorderSide(
                                color: context.dividerColor, width: 1)),
                      ),
                      child: IndexedStack(
                        index: _currentIndex,
                        children: List.generate(7, (index) {
                          return Navigator(
                            key: _navigatorKeys[index],
                            onGenerateRoute: (settings) {
                              return MaterialPageRoute(
                                builder: (_) => _buildBodyForTab(index,
                                    isDesktop: true,
                                    isThreeColumn: isThreeColumn),
                              );
                            },
                          );
                        }),
                      ),
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          final proposed = (_middleColumnWidth ?? middleWidth) +
                              details.delta.dx;
                          final upperBound = maxMiddleWidth < _minMiddleWidth
                              ? _minMiddleWidth
                              : maxMiddleWidth;
                          double newMiddle = proposed;
                          if (upperBound < _minMiddleWidth) {
                            newMiddle = _minMiddleWidth;
                          } else {
                            if (newMiddle < _minMiddleWidth)
                              newMiddle = _minMiddleWidth;
                            if (newMiddle > upperBound) newMiddle = upperBound;
                          }
                          _middleColumnWidth = newMiddle;
                        });
                      },
                      onHorizontalDragEnd: (_) {
                        if (_middleColumnWidth != null) {
                          unawaited(_layoutPrefService
                              .setMiddleWidth(_middleColumnWidth!));
                        }
                      },
                      child: Container(
                        width: _splitterWidth,
                        height: double.infinity,
                        color: context.surfaceColor,
                        child: Center(
                          child: Container(
                            width: 2,
                            height: 40,
                            decoration: BoxDecoration(
                              color: context.dividerColor.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildDetailPanel(),
                  ),
                ],
              );
            }

            double sideWidth =
                desiredSideWidth.clamp(_minSideMenuWidth, _maxSideMenuWidth);
            final double minContentWidth = 600;
            double maxSideForTwoColumn = totalWidth - minContentWidth;
            if (maxSideForTwoColumn < _minSideMenuWidth) {
              maxSideForTwoColumn = _minSideMenuWidth;
            }
            if (sideWidth > maxSideForTwoColumn) {
              sideWidth = maxSideForTwoColumn;
            }

            return Row(
              children: [
                SizedBox(
                  width: sideWidth,
                  child: SideMenu(
                    apiService: widget.apiService,
                    selectedIndex: _currentIndex,
                    onItemTap: (index) {
                      setState(() {
                        _currentIndex = index;
                        _detailNavigatorKey.currentState
                            ?.popUntil((route) => route.isFirst);
                        _detailContentType = DetailContentType.placeholder;
                      });
                    },
                    onAvatarTap: () {
                      setState(() {
                        _currentIndex = 6;
                        _detailNavigatorKey.currentState
                            ?.popUntil((route) => route.isFirst);
                        _detailContentType = DetailContentType.placeholder;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(
                              color: context.dividerColor, width: 1)),
                    ),
                    child: IndexedStack(
                      index: _currentIndex,
                      children: List.generate(7, (index) {
                        return Navigator(
                          key: _navigatorKeys[index],
                          onGenerateRoute: (settings) {
                            return MaterialPageRoute(
                              builder: (_) => _buildBodyForTab(index,
                                  isDesktop: true,
                                  isThreeColumn: isThreeColumn),
                            );
                          },
                        );
                      }),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBodyForTab(int index,
      {required bool isDesktop, required bool isThreeColumn}) {
    switch (index) {
      case 0:
        return HomePage(
          key: _homePageKey,
          apiService: widget.apiService,
          showHeaderAvatar: !isDesktop,
          showHeaderAddButton: !isDesktop,
          onAvatarTap: () {
            if (!isDesktop) {
              // 在移动端：头像点击等同于点击底部导航栏的“我的”tab
              setState(() {
                _currentIndex = 4; // 底部 "我的" 的 index
              });
            }
          },
          onPostTap: isThreeColumn
              ? (postId) => _navigateToPostDetail(postId, isScorePost: false)
              : null,
        );
      case 1:
        return CreatePostPage(
          apiService: widget.apiService,
          isEmbedded: true,
          isActive: _currentIndex == 1,
          onPreviewUpdate: isThreeColumn ? _updatePostPreview : null,
          onPostSuccess: () {
            setState(() {
              _currentIndex = 0;
            });
            // Wait for frame to ensure HomePage is built before refreshing
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _homePageKey.currentState?.refresh();
            });
          },
        );
      case 2:
        return ScorePage(apiService: widget.apiService);
      case 3:
        return ShopPage(
          apiService: widget.apiService,
          onProductTap: isThreeColumn
              ? (productId) => _updateProductDetail(productId)
              : null,
        );
      case 4:
        // Message Page (includes Chat and Notice)
        return NoticePage(
          apiService: widget.apiService,
          onChatTap:
              isThreeColumn ? (user) => _navigateToChatDetail(user) : null,
        );
      case 5:
        // Unused (previously Chat)
        return const SizedBox();
      case 6:
        return MyPage(apiService: widget.apiService);
      default:
        return _buildTabPlaceholder('首页');
    }
  }

  Widget _buildDetailPanel() {
    return Navigator(
      key: _detailNavigatorKey,
      observers: [
        _DetailNavigatorObserver(
          onRouteChanged: (isInitialRoute) {
            if (isInitialRoute) {
              setState(() {
                _selectedPostId = null;
                _currentDetailPostId = null;
                _currentDetailProductId = null;
                _selectedChatUser = null;
                _detailContentType = DetailContentType.placeholder;
                _isShowingPreview = false; // Reset preview flag
              });
            }
          },
        ),
      ],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          // Fix: Always use placeholder for the root route to prevent it from
          // changing into a detail page when state updates.
          builder: (_) => _buildPlaceholderContent(),
        );
      },
    );
  }

  Widget _buildDetailPanelContent() {
    switch (_detailContentType) {
      case DetailContentType.placeholder:
        return _buildPlaceholderContent();
      case DetailContentType.postDetail:
        if (_selectedPostId == null) {
          return _buildPlaceholderContent();
        }
        return PostDetailPage(
          postId: _selectedPostId!,
          apiService: widget.apiService,
          isEmbedded: true,
        );
      case DetailContentType.scorePostDetail:
        if (_selectedPostId == null) {
          return _buildPlaceholderContent();
        }
        return ScorePostDetailPage(
          postId: _selectedPostId!,
          apiService: widget.apiService,
          initialPost: _selectedPost,
        );
      case DetailContentType.postPreview:
        // 预览现在通过 navigator push 方式显示，这里返回 placeholder
        return _buildPlaceholderContent();
      case DetailContentType.productDetail:
        return _buildProductDetail();
      case DetailContentType.chatDetail:
        if (_selectedChatUser == null) {
          return _buildPlaceholderContent();
        }
        return ChatDetailPage(
          apiService: widget.apiService,
          targetUser: _selectedChatUser!,
          isEmbedded: true,
        );
    }
  }

  Widget _buildPlaceholderContent() {
    String message;
    IconData icon;

    switch (_currentIndex) {
      case 0:
        message = '选择一个帖子查看详情';
        icon = Icons.article_outlined;
        break;
      case 1:
        message = '预览窗口';
        icon = Icons.article_outlined;
        break;
      case 2:
        message = '选择一个帖子查看详情';
        icon = Icons.grade_outlined;
        break;
      case 3:
        message = '选择一个商品查看详情';
        icon = Icons.shopping_bag_outlined;
        break;
      case 4:
        message = '查看通知';
        icon = Icons.notifications_outlined;
        break;
      case 5:
        message = '选择一个联系人开始聊天';
        icon = Icons.chat_bubble_outline;
        break;
      case 6:
        message = '个人中心';
        icon = Icons.person_outline;
        break;
      default:
        message = '选择内容以查看';
        icon = Icons.article_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: context.dividerColor),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: context.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetail() {
    final productId = _currentDetailProductId;
    if (productId == null) {
      return _buildPlaceholderContent();
    }

    return ProductDetailPage(
      productId: productId,
      apiService: widget.apiService,
      isEmbedded: true,
    );
  }

  void _navigateToChatDetail(UserModel user) {
    setState(() {
      _selectedChatUser = user;
      _detailContentType = DetailContentType.chatDetail;
    });

    _detailNavigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          apiService: widget.apiService,
          targetUser: user,
          isEmbedded: true,
        ),
      ),
    );
  }

  void _navigateToPostDetail(int postId,
      {bool isScorePost = false, PostModel? post}) {
    // Check if the same post is already displayed and content type matches
    final expectedType = isScorePost
        ? DetailContentType.scorePostDetail
        : DetailContentType.postDetail;

    if (_selectedPostId == postId && _detailContentType == expectedType) {
      return; // Don't push if same post is already displayed
    }

    setState(() {
      _selectedPostId = postId;
      _selectedPost = post;
      _detailContentType = expectedType;
    });

    // Push new post detail page to the navigator
    _detailNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => _buildDetailPanelContent(),
      ),
    );
  }

  void _updatePostPreview(String title, String content) {
    final user = StorageService().user;
    if (user == null) return;

    // 更新预览数据，触发 ValueNotifier 通知
    _previewDataNotifier.value = {
      'title': title,
      'content': content,
      'user': user,
    };

    if (!_isShowingPreview) {
      _isShowingPreview = true;
      // Push preview page wrapper to navigator
      _detailNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => _buildPostPreviewPage(),
        ),
      );
    }
  }

  /// 构建帖子预览页面（使用 PostPreviewCard 组件）
  Widget _buildPostPreviewPage() {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Text(
          '预览',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: _previewDataNotifier,
          builder: (context, data, child) {
            final user = data['user'] as UserModel?;
            if (user == null) return _buildPlaceholderContent();
            return PostPreviewCard(
              title: data['title'] ?? '',
              content: data['content'] ?? '',
              user: user,
            );
          },
        ),
      ),
    );
  }

  void _updateProductDetail(int productId) {
    // Check if the same product is already displayed
    if (_currentDetailProductId == productId) {
      return;
    }

    // Update current product ID
    _currentDetailProductId = productId;

    // Push product detail page to navigator
    _detailNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          productId: productId,
          apiService: widget.apiService,
          isEmbedded: true,
        ),
      ),
    );
  }

  Widget _buildTabPlaceholder(String title) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: context.surfaceColor,
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 22,
            color: context.textPrimaryColor,
          ),
        ),
      ),
    );
  }

  /// 构建消息图标（带未读小红点）
  Widget _buildMessageIcon({required bool isSelected}) {
    final totalUnread = _unreadCount + _noticeUnreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SvgPicture.asset(
          isSelected
              ? 'assets/icons/notice_selected.svg'
              : 'assets/icons/notice_normal.svg',
          width: 24,
          height: 24,
        ),
        if (totalUnread > 0)
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
                  totalUnread > 99 ? '99+' : '$totalUnread',
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
    );
  }
}
