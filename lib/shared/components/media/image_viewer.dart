import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';

/// 全屏图片查看器 - 支持多图浏览和原图分辨率查看
class ImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final Map<String, File>? cachedFiles; // URL -> File 映射

  const ImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.cachedFiles,
  });

  /// 显示单张图片
  static void show(BuildContext context, String imageUrl, {File? cachedFile}) {
    showMultiple(
      context,
      [imageUrl],
      initialIndex: 0,
      cachedFiles: cachedFile != null ? {imageUrl: cachedFile} : null,
    );
  }

  /// 显示多张图片
  static void showMultiple(
    BuildContext context,
    List<String> imageUrls, {
    int initialIndex = 0,
    Map<String, File>? cachedFiles,
  }) {
    if (imageUrls.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ImageViewer(
            imageUrls: imageUrls,
            initialIndex: initialIndex.clamp(0, imageUrls.length - 1),
            cachedFiles: cachedFiles,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  
  // 每个页面的状态
  final Map<int, _ImagePageState> _pageStates = {};
  
  // 淡入淡出动画
  double _opacity = 1.0;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // 不需要 dispose _pageStates，因为它们由 _ImagePage 子组件自己管理
    _pageStates.clear();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _jumpToPage(int index) async {
    if (_isTransitioning || index == _currentIndex) return;
    _isTransitioning = true;
    
    // 淡出
    setState(() => _opacity = 0.0);
    await Future.delayed(const Duration(milliseconds: 150));
    
    if (!mounted) return;
    
    // 跳转
    _pageController.jumpToPage(index);
    
    // 淡入
    setState(() => _opacity = 1.0);
    await Future.delayed(const Duration(milliseconds: 150));
    
    _isTransitioning = false;
  }

  @override
  Widget build(BuildContext context) {
    final imageCount = widget.imageUrls.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 图片区域 - PageView
          AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 150),
            child: PageView.builder(
              controller: _pageController,
              itemCount: imageCount,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return _ImagePage(
                  key: ValueKey(widget.imageUrls[index]),
                  imageUrl: widget.imageUrls[index],
                  cachedFile: widget.cachedFiles?[widget.imageUrls[index]],
                  onTap: () => Navigator.of(context).pop(),
                  onStateCreated: (state) => _pageStates[index] = state,
                );
              },
            ),
          ),
          // 顶部信息栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(context),
          ),
          // 底部指示器和提示
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(context, imageCount),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final currentState = _pageStates[_currentIndex];
    final imageSize = currentState?.imageSize;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 图片尺寸信息
          if (imageSize != null)
            Text(
              '${imageSize.width.toInt()} × ${imageSize.height.toInt()}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            )
          else
            const SizedBox(),
          // 关闭按钮
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, int imageCount) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 16,
        right: 16,
        top: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图片指示器（多图时显示）
          if (imageCount > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(imageCount, (index) {
                  final isActive = _currentIndex == index;
                  return GestureDetector(
                    onTap: () => _jumpToPage(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        width: isActive ? 16 : 8,
                        height: 8,
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
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 底部提示
          Text(
            imageCount > 1
                ? '左右滑动切换 · 双击放大 · 点击关闭'
                : '双击放大 · 捏合缩放 · 点击关闭',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 单个图片页面的状态管理
class _ImagePageState {
  final TransformationController transformController;
  final AnimationController animController;
  Size? imageSize;
  double currentScale = 1.0;

  _ImagePageState({
    required this.transformController,
    required this.animController,
  });

  void dispose() {
    transformController.dispose();
    animController.dispose();
  }
}

/// 单个图片页面
class _ImagePage extends StatefulWidget {
  final String imageUrl;
  final File? cachedFile;
  final VoidCallback onTap;
  final Function(_ImagePageState) onStateCreated;

  const _ImagePage({
    super.key,
    required this.imageUrl,
    this.cachedFile,
    required this.onTap,
    required this.onStateCreated,
  });

  @override
  State<_ImagePage> createState() => _ImagePageStateWidget();
}

class _ImagePageStateWidget extends State<_ImagePage> with SingleTickerProviderStateMixin {
  final MediaCacheService _cacheService = MediaCacheService();
  late TransformationController _transformController;
  late AnimationController _animController;
  late _ImagePageState _state;
  
  File? _file;
  bool _isLoading = true;
  Size? _imageSize;
  double _currentScale = 1.0;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _state = _ImagePageState(
      transformController: _transformController,
      animController: _animController,
    );
    widget.onStateCreated(_state);
    _loadImage();
  }

  @override
  void dispose() {
    _transformController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    File? file = widget.cachedFile;
    file ??= await _cacheService.getOrDownload(
      widget.imageUrl,
      category: CacheCategory.post,
    );

    if (file != null && mounted) {
      // 获取图片原始尺寸
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final imageSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );

      setState(() {
        _file = file;
        _imageSize = imageSize;
        _state.imageSize = imageSize;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  double get _maxScale {
    if (_imageSize == null) return 10.0;
    final screenSize = MediaQuery.of(context).size;
    final widthRatio = _imageSize!.width / screenSize.width;
    final heightRatio = _imageSize!.height / screenSize.height;
    return (widthRatio > heightRatio ? widthRatio : heightRatio).clamp(4.0, 20.0);
  }

  void _onDoubleTapDown(TapDownDetails details) {
    final position = details.localPosition;
    final endMatrix = _currentScale > 1.0
        ? Matrix4.identity()
        : _matrixZoomTo(position, 2.5);

    _animateToMatrix(endMatrix);
  }

  Matrix4 _matrixZoomTo(Offset focalPoint, double scale) {
    final x = -focalPoint.dx * (scale - 1);
    final y = -focalPoint.dy * (scale - 1);
    return Matrix4.identity()
      ..translate(x, y)
      ..scale(scale);
  }

  void _animateToMatrix(Matrix4 end) {
    _animation = Matrix4Tween(
      begin: _transformController.value,
      end: end,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animation!.addListener(() {
      _transformController.value = _animation!.value;
    });

    _animController.forward(from: 0);
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    _currentScale = _transformController.value.getMaxScaleOnAxis();
    _state.currentScale = _currentScale;
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _currentScale = _transformController.value.getMaxScaleOnAxis();
    _state.currentScale = _currentScale;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: _onDoubleTapDown,
      onDoubleTap: () {},
      child: Container(
        color: Colors.transparent,
        width: screenSize.width,
        height: screenSize.height,
        child: InteractiveViewer(
          transformationController: _transformController,
          onInteractionUpdate: _onInteractionUpdate,
          onInteractionEnd: _onInteractionEnd,
          minScale: 0.5,
          maxScale: _maxScale,
          child: Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : _file != null
                    ? Image.file(
                        _file!,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      )
                    : const Icon(Icons.broken_image, color: Colors.white, size: 48),
          ),
        ),
      ),
    );
  }
}
