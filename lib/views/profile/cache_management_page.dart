import 'package:flutter/material.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/overlays/custom_dialog.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 缓存管理页面
class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage>
    with SingleTickerProviderStateMixin {
  final MediaCacheService _cacheService = MediaCacheService();
  List<CacheFileInfo> _cacheFiles = [];
  Map<CacheCategory, List<CacheFileInfo>> _categorizedFiles = {};
  Set<String> _selectedFiles = {};
  bool _isLoading = true;
  bool _isSelectionMode = false;
  int _totalSize = 0;
  CacheCategory? _currentCategory; // null 表示全部

  late TabController _tabController;
  final List<CacheCategory?> _tabs = [null, ...CacheCategory.values];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCacheFiles();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentCategory = _tabs[_tabController.index];
    });
  }

  Future<void> _loadCacheFiles() async {
    setState(() => _isLoading = true);

    try {
      final files = await _cacheService.getCacheFiles();
      final size = await _cacheService.getCacheSize();

      // 按分类整理
      final Map<CacheCategory, List<CacheFileInfo>> categorized = {};
      for (final cat in CacheCategory.values) {
        categorized[cat] = [];
      }
      for (final file in files) {
        categorized[file.category]!.add(file);
      }

      if (mounted) {
        setState(() {
          _cacheFiles = files;
          _categorizedFiles = categorized;
          _totalSize = size;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarHelper.show(context, '加载缓存失败');
      }
    }
  }


  List<CacheFileInfo> get _displayFiles {
    if (_currentCategory == null) return _cacheFiles;
    return _categorizedFiles[_currentCategory] ?? [];
  }

  void _toggleSelection(String fileName) {
    setState(() {
      if (_selectedFiles.contains(fileName)) {
        _selectedFiles.remove(fileName);
      } else {
        _selectedFiles.add(fileName);
      }
      _isSelectionMode = _selectedFiles.isNotEmpty;
    });
  }

  void _selectAll() {
    setState(() {
      final currentFiles = _displayFiles;
      final allSelected = currentFiles.every((f) => _selectedFiles.contains(f.fileName));
      if (allSelected) {
        for (final f in currentFiles) {
          _selectedFiles.remove(f.fileName);
        }
      } else {
        for (final f in currentFiles) {
          _selectedFiles.add(f.fileName);
        }
      }
      _isSelectionMode = _selectedFiles.isNotEmpty;
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedFiles.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedFiles.isEmpty) return;

    final count = _selectedFiles.length;
    final confirm = await showCustomDialog(
      context: context,
      title: '删除缓存',
      content: '确定要删除选中的 $count 个文件吗？',
      cancelText: '取消',
      confirmText: '删除',
      confirmColor: AppColors.error,
    );

    if (confirm == true && mounted) {
      final filesToDelete = _cacheFiles
          .where((f) => _selectedFiles.contains(f.fileName))
          .map((f) => f.file)
          .toList();

      final deletedCount = await _cacheService.deleteFiles(filesToDelete);

      if (mounted) {
        SnackBarHelper.show(context, '已删除 $deletedCount 个文件');
        _cancelSelection();
        _loadCacheFiles();
      }
    }
  }

  Future<void> _clearAllCache() async {
    final confirm = await showCustomDialog(
      context: context,
      title: '清除全部缓存',
      content: '确定要清除所有缓存吗？\n当前缓存：${_cacheService.formatCacheSize(_totalSize)}',
      cancelText: '取消',
      confirmText: '清除',
      confirmColor: AppColors.error,
    );

    if (confirm == true && mounted) {
      final success = await _cacheService.clearCache();
      if (mounted) {
        if (success) {
          SnackBarHelper.show(context, '缓存已清除');
          _loadCacheFiles();
        } else {
          SnackBarHelper.show(context, '清除失败');
        }
      }
    }
  }

  int get _selectedSize {
    return _cacheFiles
        .where((f) => _selectedFiles.contains(f.fileName))
        .fold(0, (sum, f) => sum + f.size);
  }

  int _getCategorySize(CacheCategory? category) {
    if (category == null) return _totalSize;
    return _categorizedFiles[category]?.fold<int>(0, (sum, f) => sum + f.size) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _isSelectionMode ? Icons.close : Icons.arrow_back,
            color: context.textPrimaryColor,
          ),
          onPressed:
              _isSelectionMode ? _cancelSelection : () => Navigator.pop(context),
        ),
        title: Text(
          _isSelectionMode ? '已选择 ${_selectedFiles.length} 项' : '缓存管理',
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
                _displayFiles.every((f) => _selectedFiles.contains(f.fileName))
                    ? '取消全选'
                    : '全选',
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
          ] else if (_cacheFiles.isNotEmpty) ...[
            TextButton(
              onPressed: _clearAllCache,
              child: Text(
                '清除全部',
                style: TextStyle(color: context.textSecondaryColor),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
        bottom: _cacheFiles.isNotEmpty && !_isSelectionMode
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: _buildTabBar(),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _cacheFiles.isEmpty
              ? _buildEmptyState()
              : _buildCacheContent(),
      bottomNavigationBar: _isSelectionMode ? _buildBottomBar() : null,
    );
  }


  Widget _buildTabBar() {
    return Container(
      color: context.surfaceColor,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppColors.primary,
        unselectedLabelColor: context.textSecondaryColor,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        tabAlignment: TabAlignment.start,
        tabs: _tabs.map((cat) {
          final count = cat == null
              ? _cacheFiles.length
              : (_categorizedFiles[cat]?.length ?? 0);
          final label = cat?.label ?? '全部';
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 64,
            color: context.textTertiaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无缓存',
            style: TextStyle(
              fontSize: 16,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheContent() {
    final files = _displayFiles;
    if (files.isEmpty) {
      return Center(
        child: Text(
          '该分类暂无缓存',
          style: TextStyle(
            fontSize: 14,
            color: context.textSecondaryColor,
          ),
        ),
      );
    }

    return Column(
      children: [
        // 当前分类统计
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: context.surfaceColor,
          child: Row(
            children: [
              Text(
                '${files.length} 个文件',
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondaryColor,
                ),
              ),
              const Spacer(),
              Text(
                _cacheService.formatCacheSize(_getCategorySize(_currentCategory)),
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.dividerColor),
        // 文件网格
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final fileInfo = files[index];
              final isSelected = _selectedFiles.contains(fileInfo.fileName);
              return _buildCacheItem(fileInfo, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCacheItem(CacheFileInfo fileInfo, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleSelection(fileInfo.fileName),
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelection(fileInfo.fileName);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 图片预览
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: fileInfo.isImage
                  ? Image.file(
                      fileInfo.file,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFileIcon(fileInfo),
                    )
                  : _buildFileIcon(fileInfo),
            ),
            // 选中遮罩
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            // 选中图标
            if (_isSelectionMode)
              Positioned(
                top: 4,
                right: 4,
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
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
            // 文件大小
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(7),
                  ),
                ),
                child: Text(
                  _cacheService.formatCacheSize(fileInfo.size),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(CacheFileInfo fileInfo) {
    IconData icon;
    if (fileInfo.isVideo) {
      icon = Icons.video_file_outlined;
    } else if (fileInfo.isImage) {
      icon = Icons.image_outlined;
    } else {
      icon = Icons.insert_drive_file_outlined;
    }

    return Container(
      color: context.backgroundColor,
      child: Center(
        child: Icon(icon, size: 32, color: context.textTertiaryColor),
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
              '已选择 ${_cacheService.formatCacheSize(_selectedSize)}',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _selectedFiles.isEmpty ? null : _deleteSelected,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              disabledBackgroundColor: context.dividerColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
