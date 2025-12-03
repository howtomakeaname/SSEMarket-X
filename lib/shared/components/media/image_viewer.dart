import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';

/// 全屏图片查看器 - 支持原图分辨率查看
class ImageViewer extends StatefulWidget {
  final String imageUrl;
  final File? cachedFile;

  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.cachedFile,
  });

  /// 显示图片查看器
  static void show(BuildContext context, String imageUrl, {File? cachedFile}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ImageViewer(imageUrl: imageUrl, cachedFile: cachedFile);
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

class _ImageViewerState extends State<ImageViewer> with SingleTickerProviderStateMixin {
  final TransformationController _transformController = TransformationController();
  final MediaCacheService _cacheService = MediaCacheService();
  File? _file;
  bool _isLoading = true;
  Size? _imageSize;
  double _currentScale = 1.0;

  late AnimationController _animController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
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
    if (file == null) {
      file = await _cacheService.getOrDownload(
        widget.imageUrl,
        category: CacheCategory.post,
      );
    }

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
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // 计算可以放大到原图分辨率的最大倍数
  double get _maxScale {
    if (_imageSize == null) return 10.0;
    final screenSize = MediaQuery.of(context).size;
    final widthRatio = _imageSize!.width / screenSize.width;
    final heightRatio = _imageSize!.height / screenSize.height;
    // 允许放大到原图分辨率，最少 4 倍，最多 20 倍
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
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _currentScale = _transformController.value.getMaxScaleOnAxis();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 图片区域
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            onDoubleTapDown: _onDoubleTapDown,
            onDoubleTap: () {}, // 需要空实现才能触发 onDoubleTapDown
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
          ),
          // 顶部信息栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 8,
              ),
              decoration: BoxDecoration(
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
                  if (_imageSize != null)
                    Text(
                      '${_imageSize!.width.toInt()} × ${_imageSize!.height.toInt()}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    )
                  else
                    const SizedBox(),
                  // 关闭按钮
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
          // 底部提示
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '双击放大 · 捏合缩放 · 点击关闭',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
