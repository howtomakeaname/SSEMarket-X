import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/models/product_model.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/browse_history_service.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';
import 'package:sse_market_x/views/post/score_post_detail_page.dart';
import 'package:sse_market_x/views/shop/product_detail_page.dart';
import 'package:sse_market_x/shared/components/loading/skeleton_loader.dart';
import 'package:sse_market_x/shared/components/cards/post_card.dart';
import 'package:sse_market_x/shared/components/cards/rating_card.dart';
import 'package:sse_market_x/shared/components/cards/product_card.dart';
import 'package:sse_market_x/shared/components/overlays/custom_dialog.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 浏览历史类型
enum BrowseHistoryType {
  post('帖子'),
  course('课程'),
  rating('打分'),
  product('闲置');

  final String label;
  const BrowseHistoryType(this.label);
}

class BrowseHistoryPage extends StatefulWidget {
  final ApiService apiService;

  const BrowseHistoryPage({super.key, required this.apiService});

  @override
  State<BrowseHistoryPage> createState() => _BrowseHistoryPageState();
}

class _BrowseHistoryPageState extends State<BrowseHistoryPage> {
  final BrowseHistoryService _historyService = BrowseHistoryService();
  final ScrollController _tabScrollController = ScrollController();
  final PageController _pageController = PageController();
  final Map<BrowseHistoryType, GlobalKey> _tabKeys = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<BrowseHistoryItem> _allHistory = [];
  UserModel _user = UserModel.empty();
  bool _isLoading = false;
  BrowseHistoryType _currentType = BrowseHistoryType.post;
  
  // 选择模式相关
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {}; // 使用 "id_type" 作为唯一标识
  
  // 搜索相关
  bool _isSearchMode = false;
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    // 初始化 tab keys
    for (final type in BrowseHistoryType.values) {
      _tabKeys[type] = GlobalKey();
    }
    _loadUserAndHistory();
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await widget.apiService.getUserInfo();
      final history = await _historyService.getHistory();
      
      if (mounted) {
        setState(() {
          _user = user;
          _allHistory = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载浏览历史失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<BrowseHistoryItem> get _displayHistory {
    BrowseHistoryItemType itemType;
    switch (_currentType) {
      case BrowseHistoryType.post:
        itemType = BrowseHistoryItemType.post;
        break;
      case BrowseHistoryType.course:
        itemType = BrowseHistoryItemType.course;
        break;
      case BrowseHistoryType.rating:
        itemType = BrowseHistoryItemType.rating;
        break;
      case BrowseHistoryType.product:
        itemType = BrowseHistoryItemType.product;
        break;
    }
    
    var filtered = _allHistory.where((item) => item.type == itemType).toList();
    
    // 应用搜索过滤
    if (_searchKeyword.isNotEmpty) {
      filtered = filtered.where((item) {
        if (item.type == BrowseHistoryItemType.product) {
          final product = ProductModel.fromDynamic(item.data);
          return product.name.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
                 product.description.toLowerCase().contains(_searchKeyword.toLowerCase());
        } else {
          final post = item.data as PostModel;
          return post.title.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
                 post.content.toLowerCase().contains(_searchKeyword.toLowerCase());
        }
      }).toList();
    }
    
    return filtered;
  }

  void _onTabChanged(BrowseHistoryType type) {
    final index = BrowseHistoryType.values.indexOf(type);
    _pageController.jumpToPage(index);
    setState(() {
      _currentType = type;
    });
    _scrollToTab(type);
  }

  void _onPageChanged(int index) {
    final type = BrowseHistoryType.values[index];
    setState(() {
      _currentType = type;
    });
    _scrollToTab(type);
  }

  void _scrollToTab(BrowseHistoryType type) {
    final key = _tabKeys[type];
    if (key?.currentContext != null) {
      final RenderBox renderBox = key!.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      
      // 左对齐滚动，确保选中的 tab 可见
      final targetOffset = _tabScrollController.offset + position.dx - 16; // 16 是左边距
      
      _tabScrollController.animateTo(
        targetOffset.clamp(0, _tabScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  int _getTypeCount(BrowseHistoryType type) {
    BrowseHistoryItemType itemType;
    switch (type) {
      case BrowseHistoryType.post:
        itemType = BrowseHistoryItemType.post;
        break;
      case BrowseHistoryType.course:
        itemType = BrowseHistoryItemType.course;
        break;
      case BrowseHistoryType.rating:
        itemType = BrowseHistoryItemType.rating;
        break;
      case BrowseHistoryType.product:
        itemType = BrowseHistoryItemType.product;
        break;
    }
    
    return _allHistory.where((item) => item.type == itemType).length;
  }

  String _getItemKey(BrowseHistoryItem item) {
    return '${item.id}_${item.type.name}';
  }

  void _toggleSelection(BrowseHistoryItem item) {
    // 搜索模式下不允许进入选择模式
    if (_isSearchMode) return;
    
    setState(() {
      final key = _getItemKey(item);
      if (_selectedItems.contains(key)) {
        _selectedItems.remove(key);
      } else {
        _selectedItems.add(key);
      }
      _isSelectionMode = _selectedItems.isNotEmpty;
    });
  }

  void _selectAll() {
    setState(() {
      final currentItems = _displayHistory;
      final allSelected = currentItems.every((item) => _selectedItems.contains(_getItemKey(item)));
      if (allSelected) {
        for (final item in currentItems) {
          _selectedItems.remove(_getItemKey(item));
        }
      } else {
        for (final item in currentItems) {
          _selectedItems.add(_getItemKey(item));
        }
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

  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (_isSearchMode) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        _searchKeyword = '';
        _searchFocusNode.unfocus();
      }
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchKeyword = value;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedItems.isEmpty) return;

    final count = _selectedItems.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => CustomDialog(
        title: '删除浏览记录',
        content: '确定要删除选中的 $count 条记录吗？此操作不可恢复。',
        confirmText: '删除',
        cancelText: '取消',
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );

    if (confirmed == true) {
      // 删除选中的记录
      for (final item in _allHistory) {
        if (_selectedItems.contains(_getItemKey(item))) {
          await _historyService.removeHistory(item.id, item.type);
        }
      }

      _cancelSelection();
      _loadUserAndHistory();

      if (mounted) {
        SnackBarHelper.show(context, '已删除 $count 条记录');
      }
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => CustomDialog(
        title: '清空浏览历史',
        content: '确定要清空${_currentType.label}的浏览记录吗？此操作不可恢复。',
        confirmText: '清空',
        cancelText: '取消',
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );

    if (confirmed == true) {
      BrowseHistoryItemType itemType;
      switch (_currentType) {
        case BrowseHistoryType.post:
          itemType = BrowseHistoryItemType.post;
          break;
        case BrowseHistoryType.course:
          itemType = BrowseHistoryItemType.course;
          break;
        case BrowseHistoryType.rating:
          itemType = BrowseHistoryItemType.rating;
          break;
        case BrowseHistoryType.product:
          itemType = BrowseHistoryItemType.product;
          break;
      }
      await _historyService.clearHistory(type: itemType);
      
      _loadUserAndHistory();
      
      if (mounted) {
        SnackBarHelper.show(context, '已清空浏览历史');
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
            _isSelectionMode ? Icons.close : (_isSearchMode ? Icons.arrow_back : Icons.arrow_back),
            color: context.textPrimaryColor,
          ),
          onPressed: _isSelectionMode 
              ? _cancelSelection 
              : _isSearchMode 
                  ? _toggleSearchMode 
                  : () => Navigator.of(context).pop(),
        ),
        title: _isSearchMode 
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                style: TextStyle(
                  fontSize: 16,
                  color: context.textPrimaryColor,
                ),
                decoration: InputDecoration(
                  hintText: '搜索${_currentType.label}...',
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: context.textTertiaryColor,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              )
            : Text(
                _isSelectionMode ? '已选择 ${_selectedItems.length} 项' : '浏览历史',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimaryColor,
                ),
              ),
        centerTitle: false,
        titleSpacing: _isSearchMode ? 0 : 0,
        actions: [
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: _selectAll,
              child: Text(
                _displayHistory.every((item) => _selectedItems.contains(_getItemKey(item)))
                    ? '取消全选'
                    : '全选',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ),
          ] else if (_isSearchMode) ...[
            if (_searchKeyword.isNotEmpty)
              IconButton(
                icon: Icon(Icons.clear, color: context.textSecondaryColor),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
          ] else ...[
            if (_displayHistory.isNotEmpty)
              IconButton(
                icon: Icon(Icons.search, color: context.textPrimaryColor),
                onPressed: _toggleSearchMode,
              ),
            if (_displayHistory.isNotEmpty)
              TextButton(
                onPressed: _clearHistory,
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
    if (_isLoading) {
      // 根据当前类型显示对应的骨架屏
      if (_currentType == BrowseHistoryType.product) {
        return const ProductGridSkeleton(itemCount: 6);
      } else {
        final isDense = _currentType == BrowseHistoryType.rating || 
                       _currentType == BrowseHistoryType.course;
        return PostListSkeleton(itemCount: 5, isDense: isDense);
      }
    }

    return Column(
      children: [
        // Tab 选择器（搜索模式下隐藏）
        if (!_isSelectionMode && !_isSearchMode) _buildTabSelector(),
        if (!_isSelectionMode && !_isSearchMode) Divider(height: 1, color: context.dividerColor),
        
        // 提示信息（搜索模式下隐藏）
        if (!_isSelectionMode && !_isSearchMode)
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
                    '这是一个纯本地功能，浏览历史只在本地保存',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!_isSelectionMode && !_isSearchMode) Divider(height: 1, color: context.dividerColor),
        
        // 搜索结果提示
        if (_isSearchMode && _searchKeyword.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: context.surfaceColor,
            child: Text(
              '找到 ${_displayHistory.length} 条结果',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
              ),
            ),
          ),
        if (_isSearchMode && _searchKeyword.isNotEmpty) 
          Divider(height: 1, color: context.dividerColor),
        
        // 历史列表 - 使用 PageView 支持横向滑动切换
        Expanded(
          child: _isSearchMode
              // 搜索模式下不使用 PageView
              ? (_displayHistory.isEmpty ? _buildEmptyState() : _buildHistoryList())
              : PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: BrowseHistoryType.values.length,
                  itemBuilder: (context, index) {
                    final type = BrowseHistoryType.values[index];
                    return _buildHistoryListForType(type);
                  },
                ),
        ),
      ],
    );
  }

  /// 构建指定类型的历史列表
  Widget _buildHistoryListForType(BrowseHistoryType type) {
    BrowseHistoryItemType itemType;
    switch (type) {
      case BrowseHistoryType.post:
        itemType = BrowseHistoryItemType.post;
        break;
      case BrowseHistoryType.course:
        itemType = BrowseHistoryItemType.course;
        break;
      case BrowseHistoryType.rating:
        itemType = BrowseHistoryItemType.rating;
        break;
      case BrowseHistoryType.product:
        itemType = BrowseHistoryItemType.product;
        break;
    }
    
    final history = _allHistory.where((item) => item.type == itemType).toList();
    
    if (history.isEmpty) {
      return _buildEmptyStateForType(type);
    }
    
    // 商品使用网格布局
    if (type == BrowseHistoryType.product) {
      return RefreshIndicator(
        onRefresh: _loadUserAndHistory,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: history.length,
          itemBuilder: (context, index) {
            return _buildProductHistoryItem(history[index]);
          },
        ),
      );
    }
    
    // 其他类型使用列表布局
    return RefreshIndicator(
      onRefresh: _loadUserAndHistory,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: history.length,
        itemBuilder: (context, index) {
          return _buildHistoryItem(history[index]);
        },
      ),
    );
  }

  Widget _buildEmptyStateForType(BrowseHistoryType type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: context.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无${type.label}浏览记录',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
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

  Widget _buildTabSelector() {
    return Container(
      width: double.infinity, // 占满宽度
      height: 42,
      color: context.surfaceColor, // 与 header 一致
      child: SingleChildScrollView(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.start, // 内部左对齐
          children: BrowseHistoryType.values.map((type) {
            final count = _getTypeCount(type);
            final isSelected = _currentType == type;
            
            return _HistoryTabChip(
              key: _tabKeys[type],
              label: type.label,
              count: count,
              isSelected: isSelected,
              onTap: () => _onTabChanged(type),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isSearchMode && _searchKeyword.isNotEmpty ? Icons.search_off : Icons.history,
            size: 64,
            color: context.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            _isSearchMode && _searchKeyword.isNotEmpty 
                ? '未找到匹配的${_currentType.label}'
                : '暂无${_currentType.label}浏览记录',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    // 如果当前是商品分区，使用网格布局
    if (_currentType == BrowseHistoryType.product) {
      return _buildProductGrid();
    }
    
    // 其他分区使用列表布局
    return RefreshIndicator(
      onRefresh: _loadUserAndHistory,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _displayHistory.length,
        itemBuilder: (context, index) {
          final item = _displayHistory[index];
          return _buildHistoryItem(item);
        },
      ),
    );
  }

  Widget _buildProductGrid() {
    return RefreshIndicator(
      onRefresh: _loadUserAndHistory,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: _displayHistory.length,
        itemBuilder: (context, index) {
          final item = _displayHistory[index];
          return _buildProductHistoryItem(item);
        },
      ),
    );
  }

  Widget _buildProductHistoryItem(BrowseHistoryItem item) {
    final isSelected = _selectedItems.contains(_getItemKey(item));
    final product = ProductModel.fromDynamic(item.data);
    
    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelection(item);
        }
      },
      onTap: _isSelectionMode 
          ? () => _toggleSelection(item)
          : () => _navigateToProductDetail(product),
      child: Stack(
        children: [
          ProductCard(
            product: product,
            onTap: _isSelectionMode ? null : () => _navigateToProductDetail(product),
          ),
          // 选择遮罩
          if (_isSelectionMode)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          // 勾选图标（左上角）
          if (_isSelectionMode)
            Positioned(
              top: 8,
              left: 8,
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

  Widget _buildHistoryItem(BrowseHistoryItem item) {
    final isSelected = _selectedItems.contains(_getItemKey(item));
    
    Widget cardContent;
    
    // 商品类型不应该在这里处理，已经在 _buildProductGrid 中处理
    if (item.type == BrowseHistoryItemType.product) {
      return const SizedBox.shrink();
    }
    
    {
      // 帖子类型（包括普通帖子、课程、打分）
      final post = item.data as PostModel;
      
      // 根据类型选择合适的卡片组件和样式
      Widget card;
      if (item.type == BrowseHistoryItemType.rating) {
        // 打分帖子使用 RatingCard 的紧凑模式（与打分界面一致）
        card = RatingCard(
          post: post,
          isDense: true, // 打分使用紧凑模式
          hidePartition: true, // 隐藏分区标签（用户已在对应分区标签下）
          onTap: _isSelectionMode 
              ? null // 选择模式下禁用卡片自带的点击
              : () => _navigateToPostDetail(item, post),
          onLikeTap: _isSelectionMode 
              ? null 
              : () async {
                  return widget.apiService.likePost(post.id, _user.phone);
                },
        );
      } else if (item.type == BrowseHistoryItemType.course) {
        // 课程帖子使用 PostCard 的紧凑模式（与首页课程分区一致）
        card = PostCard(
          post: post,
          isDense: true, // 课程使用紧凑模式
          hidePartition: true, // 隐藏分区标签（用户已在对应分区标签下）
          onTap: _isSelectionMode 
              ? null // 选择模式下禁用卡片自带的点击
              : () => _navigateToPostDetail(item, post),
          onLikeTap: _isSelectionMode 
              ? null 
              : () async {
                  return widget.apiService.likePost(post.id, _user.phone);
                },
        );
      } else {
        // 普通帖子使用 PostCard
        card = PostCard(
          post: post,
          hidePartition: true, // 隐藏分区标签（用户已在对应分区标签下）
          onTap: _isSelectionMode 
              ? null // 选择模式下禁用卡片自带的点击
              : () => _navigateToPostDetail(item, post),
          onLikeTap: _isSelectionMode 
              ? null 
              : () async {
                  return widget.apiService.likePost(post.id, _user.phone);
                },
        );
      }
      
      cardContent = card;
    }
    
    // 添加长按手势和选择遮罩
    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelection(item);
        }
      },
      onTap: _isSelectionMode ? () => _toggleSelection(item) : null,
      child: Stack(
        children: [
          cardContent,
          // 选择遮罩和勾选图标
          if (_isSelectionMode)
            Positioned.fill(
              child: Container(
                color: isSelected 
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.transparent,
              ),
            ),
          // 勾选图标（右上角，考虑卡片的 margin 和 padding）
          if (_isSelectionMode)
            Positioned(
              top: 18, // margin-top(6) + padding-top(12) = 18
              right: 24, // margin-right(12) + padding-right(12) = 24
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

  Future<void> _navigateToProductDetail(ProductModel product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          productId: product.id,
          apiService: widget.apiService,
        ),
      ),
    );
  }

  Future<void> _navigateToPostDetail(BrowseHistoryItem item, PostModel post) async {
    Widget detailPage;
    
    // 只有打分类型使用 ScorePostDetailPage
    if (item.type == BrowseHistoryItemType.rating) {
      detailPage = ScorePostDetailPage(
        postId: post.id,
        apiService: widget.apiService,
        initialPost: post,
      );
    } else {
      // 课程和普通帖子都使用 PostDetailPage
      detailPage = PostDetailPage(
        postId: post.id,
        apiService: widget.apiService,
        initialPost: post, // 传递初始数据
      );
    }
    
    final result = await Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute(builder: (_) => detailPage),
    );
    
    if (result != null && result['deleted'] == true) {
      await _historyService.removeHistory(post.id, item.type);
      _loadUserAndHistory();
    }
  }
}

/// 历史 Tab 标签组件
class _HistoryTabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _HistoryTabChip({
    super.key,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppColors.primary : context.textSecondaryColor,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.7)
                            : context.textTertiaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: isSelected ? 20 : 0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
