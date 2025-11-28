import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/product_model.dart';
import 'package:sse_market_x/views/shop/product_detail_page.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/components/cards/product_card.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 闲置物品页面
class ShopPage extends StatefulWidget {
  final ApiService apiService;
  final Function(int productId)? onProductTap;

  const ShopPage({
    super.key,
    required this.apiService,
    this.onProductTap,
  });

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  List<ProductModel> _homeProducts = [];
  List<ProductModel> _historyProducts = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final homeProducts = await widget.apiService.getProducts('home');
      final historyProducts = await widget.apiService.getProducts('history');

      if (mounted) {
        setState(() {
          _homeProducts = homeProducts;
          _historyProducts = historyProducts;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('加载商品失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    await _loadProducts();
  }

  List<ProductModel> _getProductsForIndex(int index) =>
      index == 0 ? _homeProducts : _historyProducts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // 顶部标题栏
          _buildHeader(),
          // Tab 切换
          _buildTabs(),
          // 商品列表 - 支持左右滑动
          Expanded(
            child: _isLoading && !_isRefreshing
                ? const LoadingIndicator.center(message: '加载中...')
                : PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    children: [
                      _buildProductGrid(0),
                      _buildProductGrid(1),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.surface,
      child: Row(
        children: [
          const Text(
            '闲置物品',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          // 发布按钮（暂时隐藏）
          // IconButton(
          //   icon: const Icon(Icons.add, color: AppColors.primary),
          //   onPressed: () {},
          // ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(
        children: [
          _buildTabButton('热门', 0),
          const SizedBox(width: 8),
          _buildTabButton('我的', 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        // 点击 Tab 时直接切换到目标页，避免动画滚动经过中间页造成不必要的渲染
        _pageController.jumpToPage(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid(int index) {
    final products = _getProductsForIndex(index);
    
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              index == 0 ? '暂无热门商品' : '暂无我的商品',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: products.length,
        itemBuilder: (context, itemIndex) {
          return ProductCard(
            product: products[itemIndex],
            onTap: () {
              if (widget.onProductTap != null) {
                widget.onProductTap!(products[itemIndex].id);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductDetailPage(
                      productId: products[itemIndex].id,
                      apiService: widget.apiService,
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
