import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/views/auth/reset_password_page.dart';
import 'package:sse_market_x/shared/components/overlays/custom_dialog.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

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
  bool _isNotificationEnabled = true;
  bool _isAutoPlay = true;
  
  final MediaCacheService _cacheService = MediaCacheService();
  String _cacheSize = '计算中...';
  int _cacheFileCount = 0;
  bool _isLoadingCacheInfo = true;

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    setState(() {
      _isLoadingCacheInfo = true;
    });
    
    try {
      final size = await _cacheService.getCacheSize();
      final count = await _cacheService.getCacheFileCount();
      
      if (mounted) {
        setState(() {
          _cacheSize = _cacheService.formatCacheSize(size);
          _cacheFileCount = count;
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
            _buildSettingsGroup([
              _buildSwitchItem(
                title: '推送通知',
                subtitle: '接收新消息通知',
                value: _isNotificationEnabled,
                onChanged: (val) {
                  setState(() {
                    _isNotificationEnabled = val;
                  });
                },
              ),
            ]),
            _buildSectionTitle('媒体设置'),
            _buildSettingsGroup([
              _buildSwitchItem(
                title: '自动播放',
                subtitle: '自动播放视频和音频',
                value: _isAutoPlay,
                onChanged: (val) {
                  setState(() {
                    _isAutoPlay = val;
                  });
                },
              ),
            ]),
            _buildSectionTitle('存储设置'),
            _buildSettingsGroup([
              _buildCacheItem(),
            ]),
            _buildSectionTitle('账户设置'),
            _buildSettingsGroup([
              _buildActionItem(
                title: '重置密码',
                subtitle: '修改登录密码',
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
              ),
            ]),
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

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final widget = entry.value;
          return Column(
            children: [
              widget,
              if (index < children.length - 1)
                Divider(height: 1, color: context.dividerColor, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              'assets/icons/ic_arrow_right.svg',
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(context.dividerColor, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建缓存管理项
  Widget _buildCacheItem() {
    return InkWell(
      onTap: _showClearCacheDialog,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '清除缓存',
                    style: TextStyle(
                      fontSize: 16,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '清除图片、视频等媒体缓存',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            // 缓存大小显示
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
            const SizedBox(width: 8),
            SvgPicture.asset(
              'assets/icons/ic_arrow_right.svg',
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(context.dividerColor, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示清除缓存确认对话框
  Future<void> _showClearCacheDialog() async {
    final cacheInfo = _cacheFileCount > 0 
        ? '当前缓存：$_cacheSize（$_cacheFileCount 个文件）\n\n确定要清除所有缓存吗？'
        : '当前没有缓存数据';
    
    final confirm = await showCustomDialog(
      context: context,
      title: '清除缓存',
      content: cacheInfo,
      cancelText: '取消',
      confirmText: '清除',
      confirmColor: AppColors.error,
    );

    if (confirm == true && mounted) {
      // 显示加载状态
      setState(() {
        _isLoadingCacheInfo = true;
      });

      final success = await _cacheService.clearCache();
      
      if (mounted) {
        if (success) {
          SnackBarHelper.show(context, '缓存已清除');
        } else {
          SnackBarHelper.show(context, '清除缓存失败');
        }
        // 重新加载缓存信息
        _loadCacheInfo();
      }
    }
  }
}
