import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/watch_later_service.dart';
import 'package:sse_market_x/shared/components/cards/post_card.dart';
import 'package:sse_market_x/shared/components/loading/skeleton_loader.dart';
import 'package:sse_market_x/shared/components/overlays/custom_dialog.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';

/// 稍后再看页面
class WatchLaterPage extends StatefulWidget {
  final ApiService apiService;

  const WatchLaterPage({super.key, required this.apiService});

  @override
  State<WatchLaterPage> createState() => _WatchLaterPageState();
}

class _WatchLaterPageState extends State<WatchLaterPage> {
  final WatchLaterService _watchLaterService = WatchLaterService();
  
  List<WatchLaterItem> _items = [];
  UserModel _user = UserModel.empty();
  bool _isLoading = false;
  
  // 选择模式相关
  bool _isSelectionMode = false;
  final Set<int> _selectedItems = {}; // 使用 postId 作为唯一标识

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await widget.apiService.getUserInfo();
      final items = await _watchLaterService.getItems();
      
      if (mounted) {
        setState(() {
          _user = user;
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSelection(int postId) {
    setState(() {
      if (_selectedItems.contains(postId)) {
        _selectedItems.remove(postId);
      } else {
        _selectedItems.add(postId);
      }
      _isSelectionMode = _selectedItems.isNotEmpty;
    });
  }

  void _selectAll() {
    setState(() {
      final allSelected = _items.every((item) => _selectedItems.contains(item.postId));
      if (allSelected) {
        _selectedItems.clear();
      } else {
        _selectedItems.addAll(_items.map((item) => item.postId));
      }
      _isSelectionMode = _selectedItems.isNotEmpty;
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedItems.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedItems.isEmpty) return;

    final count = _selectedItems.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => CustomDialog(
        title: '删除记录',
        content: '确定要删除选中的 $count 条记录吗？',
        confirmText: '删除',
        cancelText: '取消',
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );

    if (confirmed == true) {
      await _watchLaterService.removeItems(_selectedItems.toList());
      _cancelSelection();
      _loadData();

      if (mounted) {
        SnackBarHelper.show(context, '已删除 $count 条记录');
      }
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => CustomDialog(
        title: '清空稍后再看',
        content: '确定要清空所有稍后再看的帖子吗？此操作不可恢复。',
        confirmText: '清空',
        cancelText: '取消',
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );

    if (confirmed == true) {
      await _watchLaterService.clearAll();
      _loadData();
      
      if (mounted) {
        SnackBarHelper.show(context, '已清空');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            _isSelectionMode ? Icons.close : Icons.arrow_back,
            color: context.textPrimaryColor,
          ),
          onPressed: _isSelectionMode ? _cancelSelection : () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isSelectionMode ? '已选择 ${_selectedItems.length} 项' : '稍后再看',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: _selectAll,
              child: Text(
                _items.every((item) => _selectedItems.contains(item.postId))
                    ? '取消全选'
                    : '全选',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ),
          ] else if (_items.isNotEmpty) ...[
            TextButton(
              onPressed: _clearAll,
              child: Text(
                '清空',
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _isSelectionMode ? _buildBottomBar() : null,
    );
  }

  Widget _buildBody() {
    // 加载时只显示骨架屏，不显示其他内容
    if (_isLoading) {
      return const PostListSkeleton(itemCount: 5, isDense: false);
    }

    // 加载完成后显示完整内容
    return Column(
      children: [
        // 提示信息
        if (!_isSelectionMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: context.surfaceColor,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: context.textTertiaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '这是一个纯本地功能，记录只在本地保存',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!_isSelectionMode) Divider(height: 1, color: context.dividerColor),
        
        // 列表内容
        Expanded(
          child: _items.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: _items.length + _getOlderSectionCount(),
                    itemBuilder: (context, index) {
                      return _buildItem(index);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  int _getOlderSectionCount() {
    // 检查是否需要显示"更早添加的帖子"分隔线
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].addedAt.isBefore(sevenDaysAgo)) {
        return 1; // 需要显示一个分隔线
      }
    }
    return 0;
  }

  Widget _buildItem(int index) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    // 检查是否需要在此位置显示分隔线
    int actualIndex = index;
    bool showDivider = false;
    
    if (_getOlderSectionCount() > 0) {
      for (int i = 0; i < _items.length; i++) {
        if (_items[i].addedAt.isBefore(sevenDaysAgo)) {
          if (index == i) {
            showDivider = true;
            break;
          } else if (index > i) {
            actualIndex = index - 1;
          }
          break;
        }
      }
    }
    
    if (showDivider) {
      return _buildOlderDivider();
    }
    
    if (actualIndex >= _items.length) {
      return const SizedBox.shrink();
    }
    
    final item = _items[actualIndex];
    return _buildPostItem(item);
  }

  Widget _buildOlderDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: context.dividerColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '以下为更早添加的帖子',
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiaryColor,
              ),
            ),
          ),
          Expanded(child: Divider(color: context.dividerColor)),
        ],
      ),
    );
  }

  Widget _buildPostItem(WatchLaterItem item) {
    final isSelected = _selectedItems.contains(item.postId);
    final addedTime = _formatAddedTime(item.addedAt);
    
    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelection(item.postId);
        }
      },
      onTap: _isSelectionMode ? () => _toggleSelection(item.postId) : null,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PostCard(
                post: item.post,
                hidePartition: true,
                onTap: _isSelectionMode 
                    ? null 
                    : () => _navigateToPostDetail(item.post),
                onLikeTap: _isSelectionMode 
                    ? null 
                    : () async {
                        return await widget.apiService.likePost(item.post.id, _user.phone);
                      },
              ),
              // 添加时间提示 - 优化样式
              Container(
                margin: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.backgroundColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: context.textTertiaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      addedTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 选择遮罩和勾选图标
          if (_isSelectionMode)
            Positioned.fill(
              child: Container(
                color: isSelected 
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.transparent,
              ),
            ),
          if (_isSelectionMode)
            Positioned(
              top: 18,
              right: 24,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : context.surfaceColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : context.dividerColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  String _formatAddedTime(DateTime addedAt) {
    final now = DateTime.now();
    final difference = now.difference(addedAt);
    
    if (difference.inMinutes < 1) {
      return '刚刚添加';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前添加';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前添加';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前添加';
    } else {
      return '${addedAt.month}月${addedAt.day}日添加';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.watch_later_outlined,
            size: 64,
            color: context.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无稍后再看的帖子',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在帖子详情页点击"稍后再看"按钮即可添加',
            style: TextStyle(
              fontSize: 12,
              color: context.textTertiaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(top: BorderSide(color: context.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '已选择 ${_selectedItems.length} 项',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
              ),
            ),
          ),
          GestureDetector(
            onTap: _selectedItems.isEmpty ? null : _deleteSelected,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _selectedItems.isEmpty
                    ? context.dividerColor
                    : AppColors.error,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '删除',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _selectedItems.isEmpty
                      ? context.textTertiaryColor
                      : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToPostDetail(PostModel post) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          postId: post.id,
          apiService: widget.apiService,
          initialPost: post, // 传递初始数据
        ),
      ),
    );
    
    // 如果帖子被删除，从列表中移除
    if (result != null && result['deleted'] == true) {
      await _watchLaterService.removeItem(post.id);
      _loadData();
    }
  }
}
