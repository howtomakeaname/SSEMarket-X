import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/views/auth/reset_password_page.dart';
import 'package:sse_market_x/views/profile/cache_management_page.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/shared/components/lists/settings_list_item.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';

class SettingsPage extends StatefulWidget {
  final ApiService apiService;
  final String? userEmail;

  const SettingsPage({
    super.key,
    required this.apiService,
    this.userEmail,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // bool _isNotificationEnabled = true; // TODO: 推送通知功能待实现
  bool _isEmailNotificationEnabled = false;
  bool _isAutoPlay = true;
  
  final MediaCacheService _cacheService = MediaCacheService();
  String _cacheSize = '计算中...';
  bool _isLoadingCacheInfo = true;

  @override
  void initState() {
    super.initState();
    // Web 端不需要加载缓存信息
    if (!kIsWeb) {
      _loadCacheInfo();
    }
    _loadEmailPushStatus();
  }

  Future<void> _loadCacheInfo() async {
    setState(() {
      _isLoadingCacheInfo = true;
    });
    
    try {
      final size = await _cacheService.getCacheSize();
      
      if (mounted) {
        setState(() {
          _cacheSize = _cacheService.formatCacheSize(size);
          _isLoadingCacheInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cacheSize = '获取失败';
          _isLoadingCacheInfo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '设置',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('通知设置'),
            SettingsListGroup(
              children: [
                // TODO: 推送通知功能待实现
                // SettingsListItem(
                //   title: '推送通知',
                //   subtitle: '接收新消息通知',
                //   type: SettingsListItemType.toggle,
                //   switchValue: _isNotificationEnabled,
                //   onSwitchChanged: (val) {
                //     setState(() {
                //       _isNotificationEnabled = val;
                //     });
                //   },
                //   isFirst: true,
                // ),
                SettingsListItem(
                  title: '邮箱通知',
                  subtitle: '接收回复、私信等的邮箱通知',
                  type: SettingsListItemType.toggle,
                  switchValue: _isEmailNotificationEnabled,
                  onSwitchChanged: (val) {
                    _toggleEmailNotification(val);
                  },
                  isFirst: true,
                  isLast: true,
                ),
              ],
            ),
            _buildSectionTitle('媒体设置'),
            SettingsListGroup(
              children: [
                SettingsListItem(
                  title: '自动播放',
                  subtitle: '自动播放视频和音频',
                  type: SettingsListItemType.toggle,
                  switchValue: _isAutoPlay,
                  onSwitchChanged: (val) {
                    setState(() {
                      _isAutoPlay = val;
                    });
                  },
                  isFirst: true,
                  isLast: true,
                ),
              ],
            ),
            // Web 端不显示存储设置
            if (!kIsWeb) ...[
              _buildSectionTitle('存储设置'),
              SettingsListGroup(
                children: [
                  SettingsListItem(
                    title: '缓存管理',
                    subtitle: '查看和清理图片、视频等媒体缓存',
                    type: SettingsListItemType.custom,
                    onTap: _openCacheManagement,
                    trailing: _buildCacheTrailing(),
                    isFirst: true,
                    isLast: true,
                  ),
                ],
              ),
            ],
            _buildSectionTitle('账户设置'),
            SettingsListGroup(
              children: [
                SettingsListItem(
                  title: '重置密码',
                  subtitle: '修改登录密码',
                  type: SettingsListItemType.navigation,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ResetPasswordPage(
                          apiService: widget.apiService,
                          initialEmail: widget.userEmail,
                        ),
                      ),
                    );
                  },
                  isFirst: true,
                  isLast: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: context.textSecondaryColor,
        ),
      ),
    );
  }

  /// 构建缓存尾部组件
  Widget _buildCacheTrailing() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoadingCacheInfo)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.textSecondaryColor,
            ),
          )
        else
          Text(
            _cacheSize,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),
      ],
    );
  }

  /// 打开缓存管理页面
  Future<void> _openCacheManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CacheManagementPage(),
      ),
    );
    // 返回后刷新缓存信息
    _loadCacheInfo();
  }

  /// 加载邮箱推送状态
  Future<void> _loadEmailPushStatus() async {
    try {
      final userInfo = await widget.apiService.getUserInfo();
      final detailedInfo = await widget.apiService.getDetailedUserInfo(userInfo.phone);
      
      if (mounted) {
        setState(() {
          _isEmailNotificationEnabled = detailedInfo.emailPush;
        });
      }
    } catch (e) {
      // 加载失败，保持默认值
    }
  }

  /// 切换邮箱通知
  Future<void> _toggleEmailNotification(bool value) async {
    try {
      final userInfo = await widget.apiService.getUserInfo();
      
      if (userInfo.userId == 0) {
        if (mounted) {
          SnackBarHelper.show(context, '用户信息获取失败');
        }
        return;
      }
      
      final success = await widget.apiService.updateEmailPush(userInfo.userId);
      
      if (mounted) {
        if (success) {
          setState(() {
            _isEmailNotificationEnabled = value;
          });
          
          SnackBarHelper.show(
            context,
            value ? '邮箱通知已开启' : '邮箱通知已关闭',
          );
        } else {
          SnackBarHelper.show(
            context,
            '操作失败，请稍后重试',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.show(
          context,
          '操作失败，请稍后重试',
        );
      }
    }
  }
}
