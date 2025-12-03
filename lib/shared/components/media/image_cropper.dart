import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 图片裁剪页面
/// 使用 extended_image 库实现，支持移动端和桌面端
class ImageCropperPage extends StatefulWidget {
  final Uint8List imageBytes;
  final double aspectRatio;

  const ImageCropperPage({
    super.key,
    required this.imageBytes,
    this.aspectRatio = 1.0,
  });

  /// 显示裁剪页面并返回裁剪后的图片字节
  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    double aspectRatio = 1.0,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ImageCropperPage(
          imageBytes: imageBytes,
          aspectRatio: aspectRatio,
        ),
      ),
    );
  }

  @override
  State<ImageCropperPage> createState() => _ImageCropperPageState();
}

class _ImageCropperPageState extends State<ImageCropperPage> {
  final GlobalKey<ExtendedImageEditorState> _editorKey = GlobalKey();
  bool _isCropping = false;

  Future<void> _cropAndSave() async {
    if (_isCropping) return;

    final state = _editorKey.currentState;
    if (state == null) return;

    setState(() => _isCropping = true);

    try {
      // 获取裁剪区域和编辑动作
      final cropRect = state.getCropRect();
      final action = state.editAction;
      final img = state.rawImageData;

      if (cropRect == null) {
        setState(() => _isCropping = false);
        return;
      }

      // 使用 dart:ui 进行裁剪
      final result = await _cropImage(
        img,
        cropRect: cropRect,
        flipHorizontal: action?.flipY ?? false,
        rotateAngle: action?.rotateAngle ?? 0,
      );

      if (result != null && mounted) {
        Navigator.of(context).pop(result);
      } else if (mounted) {
        setState(() => _isCropping = false);
      }
    } catch (e) {
      debugPrint('裁剪失败: $e');
      if (mounted) {
        setState(() => _isCropping = false);
      }
    }
  }

  /// 使用 dart:ui 裁剪图片
  Future<Uint8List?> _cropImage(
    Uint8List imageData, {
    required Rect cropRect,
    bool flipHorizontal = false,
    double rotateAngle = 0,
  }) async {
    // 解码图片
    final codec = await ui.instantiateImageCodec(imageData);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // 计算输出尺寸（限制最大尺寸）
    const maxSize = 1024.0;
    double outputW = cropRect.width;
    double outputH = cropRect.height;
    
    if (outputW > maxSize || outputH > maxSize) {
      final scale = maxSize / (outputW > outputH ? outputW : outputH);
      outputW *= scale;
      outputH *= scale;
    }

    // 创建画布
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 应用变换
    canvas.save();
    
    // 如果有旋转，需要调整裁剪区域
    if (rotateAngle != 0 || flipHorizontal) {
      // 简化处理：直接裁剪原图区域
      canvas.drawImageRect(
        image,
        cropRect,
        Rect.fromLTWH(0, 0, outputW, outputH),
        Paint()..filterQuality = FilterQuality.high,
      );
    } else {
      canvas.drawImageRect(
        image,
        cropRect,
        Rect.fromLTWH(0, 0, outputW, outputH),
        Paint()..filterQuality = FilterQuality.high,
      );
    }
    
    canvas.restore();

    // 生成图片
    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(outputW.toInt(), outputH.toInt());
    final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '裁剪图片',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isCropping ? null : _cropAndSave,
            child: _isCropping
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    '完成',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ExtendedImage.memory(
              widget.imageBytes,
              fit: BoxFit.contain,
              mode: ExtendedImageMode.editor,
              extendedImageEditorKey: _editorKey,
              initEditorConfigHandler: (state) {
                return EditorConfig(
                  maxScale: 8.0,
                  cropRectPadding: const EdgeInsets.all(20.0),
                  hitTestSize: 20.0,
                  cropAspectRatio: widget.aspectRatio,
                  initCropRectType: InitCropRectType.imageRect,
                  cropLayerPainter: _CircleCropLayerPainter(
                    isCircle: widget.aspectRatio == 1.0,
                  ),
                  cornerColor: Colors.white,
                  lineColor: Colors.white.withOpacity(0.5),
                  editorMaskColorHandler: (context, pointerDown) {
                    return Colors.black.withOpacity(pointerDown ? 0.5 : 0.7);
                  },
                );
              },
            ),
          ),
          // 底部提示
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              '拖动调整位置 · 双指缩放',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// 自定义裁剪图层绘制器（支持圆形）
class _CircleCropLayerPainter extends EditorCropLayerPainter {
  final bool isCircle;

  _CircleCropLayerPainter({this.isCircle = false});

  @override
  void paintCorners(
    Canvas canvas,
    Size size,
    ExtendedImageCropLayerPainter bindValue,
  ) {
    if (isCircle) {
      // 圆形裁剪不绘制角落
      return;
    }
    super.paintCorners(canvas, size, bindValue);
  }

  @override
  void paintMask(
    Canvas canvas,
    Size size,
    ExtendedImageCropLayerPainter bindValue,
  ) {
    final rect = bindValue.cropRect;
    final maskColor = bindValue.maskColor;

    // 绘制遮罩
    final paint = Paint()..color = maskColor;
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (isCircle) {
      // 圆形镂空
      path.addOval(rect);
    } else {
      path.addRect(rect);
    }

    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // 绘制边框
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (isCircle) {
      canvas.drawOval(rect, borderPaint);
    } else {
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  void paintLines(
    Canvas canvas,
    Size size,
    ExtendedImageCropLayerPainter bindValue,
  ) {
    if (isCircle) {
      // 圆形裁剪不绘制网格线
      return;
    }
    super.paintLines(canvas, size, bindValue);
  }
}
