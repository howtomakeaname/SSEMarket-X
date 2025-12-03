import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/product_model.dart';

import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
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
      final product = await widget.apiService.getProductDetail(widget.productId);
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
      ),
      body: _isLoading
          ? const LoadingIndicator.center(message: '加载中...')
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
              return CachedImage(
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
              );
            },
          ),
          // 指示器
          if (_product.photos.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _product.photos.asMap().entries.map((entry) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentImageIndex == entry.key
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      color: context.surfaceColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _product.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${_product.price}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '积分',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
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
}
