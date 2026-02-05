import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/product_model.dart';
import 'package:sse_market_x/views/shop/product_detail_page.dart';
import 'package:sse_market_x/views/shop/create_product_page.dart';
import 'package:sse_market_x/shared/components/loading/skeleton_loader.dart';
import 'package:sse_market_x/shared/components/cards/product_card.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/core/services/browse_history_service.dart';

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
  bool _isLoading = true; // 初始化时设置为 true，避免显示空状态
  bool _isRefreshing = false;
  bool _hasLoadedOnce = false;
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadInitialProducts();
  }
  
  Future<void> _loadInitialProducts() async {
    // 尝试从缓存加载
    await _loadCachedProducts();
    
    // 后台静默刷新
    if (_hasLoadedOnce) {
      _loadProducts(silent: true);
    } else {
      _loadProducts();
    }
  }
  
  /// 从本地缓存加载商品列表
  Future<void> _loadCachedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final homeJson = prefs.getString('shop_home_products_cache');
      final historyJson = prefs.getString('shop_history_products_cache');
      
      if (homeJson != null && homeJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(homeJson);
        final cachedProducts = jsonList.map((json) => ProductModel.fromDynamic(json)).toList();
        
        if (mounted) {
          setState(() {
            _homeProducts = cachedProducts;
            _hasLoadedOnce = true;
            _isLoading = false;
          });
        }
      }
      
      if (historyJson != null && historyJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(historyJson);
        final cachedProducts = jsonList.map((json) => ProductModel.fromDynamic(json)).toList();
        
        if (mounted) {
          setState(() {
            _historyProducts = cachedProducts;
          });
        }
      }
      
      // 如果没有任何缓存，不设置 _isLoading，让后续的 _loadProducts 正常执行
    } catch (e) {
      debugPrint('加载缓存商品失败: $e');
      // 加载失败，不设置 _isLoading，让后续的 _loadProducts 正常执行
    }
  }
  
  /// 保存商品列表到本地缓存
  Future<void> _saveCachedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_homeProducts.isNotEmpty) {
        final jsonList = _homeProducts.map((p) => p.toJson()).toList();
        await prefs.setString('shop_home_products_cache', jsonEncode(jsonList));
      }
      
      if (_historyProducts.isNotEmpty) {
        final jsonList = _historyProducts.map((p) => p.toJson()).toList();
        await prefs.setString('shop_history_products_cache', jsonEncode(jsonList));
      }
    } catch (e) {
      debugPrint('保存缓存商品失败: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final homeProducts = await widget.apiService.getProducts('home');
      final historyProducts = await widget.apiService.getProducts('history');

      if (mounted) {
        setState(() {
          _homeProducts = homeProducts;
          _historyProducts = historyProducts;
          _isLoading = false;
          _isRefreshing = false;
          _hasLoadedOnce = true;
        });
        
        // 保存到缓存（仅在正常加载时）
        if (!silent) {
          _saveCachedProducts();
        }
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
    // Calculate top padding for content (StatusBar + AppBar + TabBar)
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight + 36;
    // Calculate bottom padding for content (NavBar + SafeArea)
    // Note: In IndexPage, bottom nav is overlay, so we need to add its height.
    // Standard bottom nav height is 56? IndexPage uses BottomNavigationBar (default height).
    // Plus safe area bottom.
    final bottomPadding = kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '闲置物品',
          style: TextStyle(
            color: context.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.primary),
              tooltip: '发布闲置物品',
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateProductPage(apiService: widget.apiService),
                  ),
                );
                if (result == true) {
                  _loadProducts();
                }
              },
            ),
          ),
        ],
        backgroundColor: Colors.transparent, // Important: Transparency for blur
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: context.surfaceColor.withOpacity(0.88),
                border: Border(
                  bottom: BorderSide(
                    color: context.dividerColor.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: _buildTabs(context, transparent: true), // Pass transparent flag
        ),
      ),
      body: !_hasLoadedOnce && _isLoading && !_isRefreshing
          ? Padding(
              padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
              child: const ProductGridSkeleton(itemCount: 6),
            )
          : PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              children: [
                _buildProductGrid(0, topPadding, bottomPadding),
                _buildProductGrid(1, topPadding, bottomPadding),
              ],
            ),
    );
  }

  Widget _buildTabs(BuildContext context, {bool transparent = false}) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: transparent ? Colors.transparent : context.surfaceColor, // Handle transparency
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildTabButton(context, '广场', 0),
          const SizedBox(width: 24),
          _buildTabButton(context, '我的发布', 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        _pageController.jumpToPage(index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isSelected ? AppColors.primary : context.textSecondaryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: isSelected ? 20 : 0,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(1.5),
            ),
            margin: const EdgeInsets.only(bottom: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(int index, double topPadding, double bottomPadding) {
    final products = _getProductsForIndex(index);
    
    if (products.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: context.textSecondaryColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                index == 0 ? '暂无热门商品' : '暂无我的商品',
                style: TextStyle(
                  fontSize: 16,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      edgeOffset: topPadding, // Ensure RefreshIndicator appears below header
      onRefresh: _onRefresh,
      color: AppColors.primary,
      child: GridView.builder(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: topPadding + 16,
          bottom: bottomPadding + 16,
        ),
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
            onTap: () async {
              // 添加到浏览历史（在点击时记录）
              await BrowseHistoryService().addProductHistory(
                products[itemIndex].id,
                products[itemIndex],
              );
              
              if (widget.onProductTap != null) {
                widget.onProductTap!(products[itemIndex].id);
              } else {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ProductDetailPage(
                      productId: products[itemIndex].id,
                      apiService: widget.apiService,
                    ),
                  ),
                );
                // 如果商品被删除或标记售出，刷新列表
                if (result == true) {
                  _loadProducts();
                }
              }
            },
          );
        },
      ),
    );
  }
}
