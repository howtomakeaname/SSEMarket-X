import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/product_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/shared/components/loading/skeleton_loader.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/components/media/image_viewer.dart';
import 'package:sse_market_x/shared/components/overlays/custom_dialog.dart'
    show showCustomDialog;
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/chat/chat_detail_page.dart';

/// 商品详情页
class ProductDetailPage extends StatefulWidget {
  final int productId;
  final ApiService apiService;
  final bool isEmbedded;

  const ProductDetailPage({
    super.key,
    required this.productId,
    required this.apiService,
    this.isEmbedded = false,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  ProductModel _product = ProductModel.empty();
  bool _isLoading = true;
  bool _isOperating = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProductDetail();
  }

  Future<void> _loadProductDetail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final product =
          await widget.apiService.getProductDetail(widget.productId);
      if (mounted) {
        setState(() {
          _product = product;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载商品详情失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _isOwner {
    final currentUser = StorageService().user;
    return currentUser?.userId == _product.sellerId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '详情',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        actions: _isOwner && !_isLoading ? _buildOwnerActions() : null,
      ),
      body: _isLoading
          ? _buildProductDetailSkeleton()
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildImageCarousel(),
                        _buildProductInfo(),
                      ],
                    ),
                  ),
                ),
                _buildActionButtons(),
              ],
            ),
    );
  }

  List<Widget> _buildOwnerActions() {
    return [
      if (!_product.isSold)
        TextButton(
          onPressed: _isOperating ? null : _handleMarkSold,
          child: Text(
            '标记售出',
            style: TextStyle(
              fontSize: 14,
              color: _isOperating
                  ? context.textTertiaryColor
                  : AppColors.primary,
            ),
          ),
        ),
      IconButton(
        onPressed: _isOperating ? null : _handleDelete,
        icon: Icon(
          Icons.delete_outline,
          color: _isOperating ? context.textTertiaryColor : Colors.red,
        ),
      ),
    ];
  }

  Future<void> _handleMarkSold() async {
    final confirmed = await showCustomDialog(
      context: context,
      title: '确认售出',
      content: '确定要将此商品标记为已售出吗？',
      confirmText: '确定',
      cancelText: '取消',
    );

    if (confirmed != true) return;

    setState(() => _isOperating = true);

    try {
      final success = await widget.apiService.markProductSold(_product.id);
      if (mounted) {
        if (success) {
          SnackBarHelper.show(context, '已标记为售出');
          Navigator.of(context).pop(true); // 返回并通知刷新
        } else {
          SnackBarHelper.show(context, '操作失败，请重试');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.show(context, '操作失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isOperating = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showCustomDialog(
      context: context,
      title: '确认删除',
      content: '确定要删除此商品吗？此操作不可恢复！',
      confirmText: '删除',
      cancelText: '取消',
      confirmColor: Colors.red,
    );

    if (confirmed != true) return;

    setState(() => _isOperating = true);

    try {
      final success = await widget.apiService.deleteProduct(_product.id);
      if (mounted) {
        if (success) {
          SnackBarHelper.show(context, '商品已删除');
          Navigator.of(context).pop(true);
        } else {
          SnackBarHelper.show(context, '删除失败，请重试');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.show(context, '删除失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isOperating = false);
      }
    }
  }

  Widget _buildImageCarousel() {
    if (_product.photos.isEmpty) {
      return Container(
        width: double.infinity,
        height: 300,
        color: context.surfaceColor,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 64,
            color: context.textSecondaryColor,
          ),
        ),
      );
    }

    return Container(
      color: context.surfaceColor,
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: _product.photos.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openImageViewer(index),
                child: CachedImage(
                  imageUrl: _product.photos[index],
                  fit: BoxFit.cover,
                  category: CacheCategory.product,
                  errorWidget: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 48,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
              );
            },
          ),
          // 已售出遮罩
          if (_product.isSold)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '已售出',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // 指示器
          if (_product.photos.length > 1)
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _product.photos.asMap().entries.map((entry) {
                    final isActive = _currentImageIndex == entry.key;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: isActive ? 16 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isActive
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          // 点击查看提示
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, size: 14, color: Colors.white70),
                  SizedBox(width: 4),
                  Text(
                    '点击查看',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openImageViewer(int index) {
    if (_product.photos.isEmpty) return;
    ImageViewer.showMultiple(context, _product.photos, initialIndex: index);
  }

  Widget _buildProductInfo() {
    return Container(
      color: context.surfaceColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _product.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
              if (_product.isSold)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.textSecondaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '已售出',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '闲置者: ',
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondaryColor,
                ),
              ),
              Text(
                _product.sellerName,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textPrimaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '¥${_product.price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '商品描述',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _product.description,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartChat() async {
    final currentUser = StorageService().user;
    if (currentUser?.userId == _product.sellerId) {
      SnackBarHelper.show(context, '不能和自己聊天哦');
      return;
    }

    // 获取卖家用户信息
    try {
      final seller = await widget.apiService.getInfoById(_product.sellerId);
      if (seller.userId == 0) {
        if (mounted) {
          SnackBarHelper.show(context, '获取卖家信息失败');
        }
        return;
      }

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              apiService: widget.apiService,
              targetUser: seller,
              isEmbedded: false,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.show(context, '获取卖家信息失败');
      }
    }
  }

  Widget _buildActionButtons() {
    // 如果是自己的商品，不显示私聊按钮
    if (_isOwner) {
      return const SizedBox.shrink();
    }

    // 如果商品已售出，显示提示
    if (_product.isSold) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          border: Border(
            top: BorderSide(color: context.dividerColor, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: context.textSecondaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                '此商品已售出，无法进行交易',
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          top: BorderSide(color: context.dividerColor, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _handleStartChat,
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            label: const Text(
              '私聊卖家',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  /// 商品详情骨架屏
  Widget _buildProductDetailSkeleton() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 图片轮播骨架 - 显示图标而不是纯色块
                Container(
                  width: double.infinity,
                  height: 300,
                  color: context.backgroundColor,
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 80,
                      color: context.dividerColor,
                    ),
                  ),
                ),
                // 商品信息骨架
                Container(
                  color: context.surfaceColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 价格
                      SkeletonLoader(
                        width: 100,
                        height: 24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 12),
                      // 标题
                      SkeletonLoader(
                        width: double.infinity,
                        height: 18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      // 描述 - 多行
                      SkeletonLoader(
                        width: double.infinity,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      SkeletonLoader(
                        width: double.infinity,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      SkeletonLoader(
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: context.dividerColor),
                      const SizedBox(height: 16),
                      // 卖家信息
                      Row(
                        children: [
                          SkeletonLoader(
                            width: 40,
                            height: 40,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonLoader(
                                  width: 100,
                                  height: 16,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 4),
                                SkeletonLoader(
                                  width: 60,
                                  height: 12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // 底部按钮骨架
        Container(
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
          child: SkeletonLoader(
            width: double.infinity,
            height: 48,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}
