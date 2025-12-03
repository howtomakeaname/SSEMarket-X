import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';

/// 全屏图片查看器
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
        barrierColor: Colors.black87,
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

class _ImageViewerState extends State<ImageViewer> {
  final TransformationController _transformController = TransformationController();
  final MediaCacheService _cacheService = MediaCacheService();
  File? _file;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    if (widget.cachedFile != null) {
      setState(() {
        _file = widget.cachedFile;
        _isLoading = false;
      });
      return;
    }

    final file = await _cacheService.getOrDownload(
      widget.imageUrl,
      category: CacheCategory.post,
    );
    if (mounted) {
      setState(() {
        _file = file;
        _isLoading = false;
      });
    }
  }

  void _onDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      _transformController.value = Matrix4.identity()..scale(2.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // 图片
            Center(
              child: GestureDetector(
                onDoubleTap: _onDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : _file != null
                          ? Image.file(_file!, fit: BoxFit.contain)
                          : const Icon(Icons.broken_image, color: Colors.white, size: 48),
                ),
              ),
            ),
            // 关闭按钮
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
