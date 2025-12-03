import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';

/// 支持缓存的网络图片组件
/// 自动缓存网络图片到本地，下次加载时优先使用缓存
class CachedImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  final MediaCacheService _cacheService = MediaCacheService();
  File? _cachedFile;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _cachedFile = null;
    });

    try {
      final file = await _cacheService.getOrDownload(widget.imageUrl);
      if (mounted) {
        setState(() {
          _cachedFile = file;
          _isLoading = false;
          _hasError = file == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_isLoading) {
      child = widget.placeholder ?? _buildPlaceholder();
    } else if (_hasError || _cachedFile == null) {
      child = widget.errorWidget ?? _buildErrorWidget();
    } else {
      child = Image.file(
        _cachedFile!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          return widget.errorWidget ?? _buildErrorWidget();
        },
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: child,
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: child,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}
