import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 支持缓存的网络图片组件
/// 自动缓存网络图片到本地，下次加载时优先使用缓存
/// 加载完成后使用淡入效果显示
class CachedImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final Duration fadeInDuration;
  final CacheCategory category;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.category = CacheCategory.other,
  });

  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage>
    with SingleTickerProviderStateMixin {
  final MediaCacheService _cacheService = MediaCacheService();
  File? _cachedFile;
  bool _isLoading = true;
  bool _hasError = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: widget.fadeInDuration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _loadImage();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _fadeController.reset();
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

    // Web 端直接使用网络图片，不缓存
    if (kIsWeb) {
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
      _fadeController.forward();
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _cachedFile = null;
    });

    try {
      final file = await _cacheService.getOrDownload(
        widget.imageUrl,
        category: widget.category,
      );
      if (mounted) {
        setState(() {
          _cachedFile = file;
          _isLoading = false;
          _hasError = file == null;
        });
        if (file != null) {
          _fadeController.forward();
        }
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
      child = widget.placeholder ?? _buildPlaceholder(context);
    } else if (_hasError) {
      child = widget.errorWidget ?? _buildErrorWidget(context);
    } else if (kIsWeb) {
      // Web 端直接使用网络图片
      child = FadeTransition(
        opacity: _fadeAnimation,
        child: Image.network(
          widget.imageUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            return widget.errorWidget ?? _buildErrorWidget(context);
          },
        ),
      );
    } else if (_cachedFile != null) {
      child = FadeTransition(
        opacity: _fadeAnimation,
        child: Image.file(
          _cachedFile!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            return widget.errorWidget ?? _buildErrorWidget(context);
          },
        ),
      );
    } else {
      child = widget.errorWidget ?? _buildErrorWidget(context);
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

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: context.backgroundColor,
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      color: context.backgroundColor,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: context.textTertiaryColor,
          size: 24,
        ),
      ),
    );
  }
}
