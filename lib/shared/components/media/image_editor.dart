import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 图片编辑器页面
/// 支持裁剪、旋转、翻转、亮度、对比度、饱和度调整
class ImageEditorPage extends StatefulWidget {
  final Uint8List imageBytes;
  final double? aspectRatio; // null 表示自由裁剪
  final bool enableCrop;
  final bool enableAdjust;

  const ImageEditorPage({
    super.key,
    required this.imageBytes,
    this.aspectRatio,
    this.enableCrop = true,
    this.enableAdjust = true,
  });

  /// 显示编辑页面并返回编辑后的图片字节
  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    double? aspectRatio,
    bool enableCrop = true,
    bool enableAdjust = true,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ImageEditorPage(
          imageBytes: imageBytes,
          aspectRatio: aspectRatio,
          enableCrop: enableCrop,
          enableAdjust: enableAdjust,
        ),
      ),
    );
  }

  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  final GlobalKey<ExtendedImageEditorState> _editorKey = GlobalKey();
  bool _isProcessing = false;

  // 当前编辑模式
  _EditMode _editMode = _EditMode.crop;

  // 调整参数
  double _brightness = 0.0;
  double _contrast = 0.0;
  double _saturation = 0.0;

  // 裁剪比例选项
  final List<_AspectRatioOption> _aspectRatioOptions = [
    _AspectRatioOption('自由', null, Icons.crop_free),
    _AspectRatioOption('1:1', 1.0, Icons.crop_square),
    _AspectRatioOption('4:3', 4.0 / 3.0, Icons.crop_landscape),
    _AspectRatioOption('3:4', 3.0 / 4.0, Icons.crop_portrait),
    _AspectRatioOption('16:9', 16.0 / 9.0, Icons.crop_16_9),
    _AspectRatioOption('9:16', 9.0 / 16.0, Icons.crop_portrait),
  ];
  int _selectedRatioIndex = 0;

  // 检查是否有任何修改
  bool get _hasChanges {
    return _brightness != 0 || _contrast != 0 || _saturation != 0;
  }

  @override
  void initState() {
    super.initState();
    if (widget.aspectRatio != null) {
      for (int i = 0; i < _aspectRatioOptions.length; i++) {
        if (_aspectRatioOptions[i].ratio == widget.aspectRatio) {
          _selectedRatioIndex = i;
          break;
        }
      }
    }
  }

  double? get _currentAspectRatio {
    if (widget.aspectRatio != null) return widget.aspectRatio;
    return _aspectRatioOptions[_selectedRatioIndex].ratio;
  }

  /// 全局重置所有修改
  void _resetAll() {
    setState(() {
      _brightness = 0;
      _contrast = 0;
      _saturation = 0;
      _selectedRatioIndex = 0;
    });
    // 重置裁剪编辑器
    _editorKey.currentState?.reset();
  }

  /// 旋转图片
  void _rotateImage() {
    _editorKey.currentState?.rotate(right: true);
  }

  /// 水平翻转
  void _flipHorizontal() {
    _editorKey.currentState?.flip();
  }

  Future<void> _processAndSave() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final state = _editorKey.currentState;
      Uint8List resultBytes = widget.imageBytes;

      // 1. 处理裁剪（包含旋转和翻转）
      if (widget.enableCrop && state != null) {
        final cropRect = state.getCropRect();
        final action = state.editAction;
        if (cropRect != null) {
          final cropped = await _cropImage(
            resultBytes,
            cropRect,
            rotateAngle: action?.rotateAngle ?? 0,
            flipHorizontal: action?.flipY ?? false,
          );
          if (cropped != null) {
            resultBytes = cropped;
          }
        }
      }

      // 2. 处理亮度/对比度/饱和度
      if (widget.enableAdjust && _hasChanges) {
        final adjusted = await _adjustImage(
          resultBytes,
          brightness: _brightness,
          contrast: _contrast,
          saturation: _saturation,
        );
        if (adjusted != null) {
          resultBytes = adjusted;
        }
      }

      if (mounted) {
        Navigator.of(context).pop(resultBytes);
      }
    } catch (e) {
      debugPrint('处理图片失败: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<Uint8List?> _cropImage(
    Uint8List imageData,
    Rect cropRect, {
    double rotateAngle = 0,
    bool flipHorizontal = false,
  }) async {
    final codec = await ui.instantiateImageCodec(imageData);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    const maxSize = 1920.0;
    double outputW = cropRect.width;
    double outputH = cropRect.height;

    if (outputW > maxSize || outputH > maxSize) {
      final scale = maxSize / (outputW > outputH ? outputW : outputH);
      outputW *= scale;
      outputH *= scale;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImageRect(
      image,
      cropRect,
      Rect.fromLTWH(0, 0, outputW, outputH),
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(outputW.toInt(), outputH.toInt());
    final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  Future<Uint8List?> _adjustImage(
    Uint8List imageData, {
    required double brightness,
    required double contrast,
    required double saturation,
  }) async {
    final codec = await ui.instantiateImageCodec(imageData);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final colorMatrix = _buildColorMatrix(brightness, contrast, saturation);
    final paint = Paint()
      ..colorFilter = ColorFilter.matrix(colorMatrix)
      ..filterQuality = FilterQuality.high;

    canvas.drawImage(image, Offset.zero, paint);

    final picture = recorder.endRecording();
    final adjustedImage = await picture.toImage(image.width, image.height);
    final byteData = await adjustedImage.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  List<double> _buildColorMatrix(double brightness, double contrast, double saturation) {
    final b = brightness * 255;
    final c = 1.0 + contrast;
    final t = (1.0 - c) / 2.0 * 255;
    final s = 1.0 + saturation;
    const lumR = 0.3086;
    const lumG = 0.6094;
    const lumB = 0.0820;
    final sr = (1 - s) * lumR;
    final sg = (1 - s) * lumG;
    final sb = (1 - s) * lumB;

    return <double>[
      c * (sr + s), c * sg, c * sb, 0, t + b,
      c * sr, c * (sg + s), c * sb, 0, t + b,
      c * sr, c * sg, c * (sb + s), 0, t + b,
      0, 0, 0, 1, 0,
    ];
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
          '编辑图片',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          // 全局重置按钮
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.white.withOpacity(0.8),
            ),
            tooltip: '重置所有',
            onPressed: _resetAll,
          ),
          TextButton(
            onPressed: _isProcessing ? null : _processAndSave,
            child: _isProcessing
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
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildEditorArea()),
          _buildBottomToolbar(bgColor),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildEditorArea() {
    if (_editMode == _EditMode.crop && widget.enableCrop) {
      return _buildCropEditor();
    } else {
      return _buildPreviewWithAdjustments();
    }
  }

  Widget _buildCropEditor() {
    return ExtendedImage.memory(
      widget.imageBytes,
      fit: BoxFit.contain,
      mode: ExtendedImageMode.editor,
      extendedImageEditorKey: _editorKey,
      initEditorConfigHandler: (state) {
        return EditorConfig(
          maxScale: 8.0,
          cropRectPadding: const EdgeInsets.all(20.0),
          hitTestSize: 20.0,
          cropAspectRatio: _currentAspectRatio,
          initCropRectType: InitCropRectType.imageRect,
          cornerColor: Colors.white,
          lineColor: Colors.white.withOpacity(0.5),
          editorMaskColorHandler: (context, pointerDown) {
            return Colors.black.withOpacity(pointerDown ? 0.5 : 0.7);
          },
        );
      },
    );
  }

  Widget _buildPreviewWithAdjustments() {
    final colorMatrix = _buildColorMatrix(_brightness, _contrast, _saturation);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(colorMatrix),
          child: Image.memory(
            widget.imageBytes,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(Color bgColor) {
    return Container(
      color: bgColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 0.5, color: Colors.white.withOpacity(0.1)),
          // 工具区域
          if (_editMode == _EditMode.crop && widget.enableCrop)
            _buildCropTools()
          else if (_editMode == _EditMode.adjust && widget.enableAdjust)
            _buildAdjustTools(),
          // 底部Tab
          if (widget.enableCrop && widget.enableAdjust) _buildModeTabs(),
        ],
      ),
    );
  }

  Widget _buildModeTabs() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _buildModeTab('裁剪', _EditMode.crop, Icons.crop)),
          Container(width: 0.5, height: 48, color: Colors.white.withOpacity(0.1)),
          Expanded(child: _buildModeTab('调整', _EditMode.adjust, Icons.tune)),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, _EditMode mode, IconData icon) {
    final isActive = _editMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _editMode = mode),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.primary : Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropTools() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // 旋转和翻转按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(Icons.rotate_right, '旋转', _rotateImage),
              const SizedBox(width: 32),
              _buildActionButton(Icons.flip, '翻转', _flipHorizontal),
            ],
          ),
          const SizedBox(height: 16),
          // 比例选择（如果没有固定比例）
          if (widget.aspectRatio == null) ...[
            Text(
              '裁剪比例',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_aspectRatioOptions.length, (index) {
                      final option = _aspectRatioOptions[index];
                      final isSelected = _selectedRatioIndex == index;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedRatioIndex = index),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            option.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '拖动调整裁剪区域',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white.withOpacity(0.8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustTools() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        children: [
          _buildSlider('亮度', Icons.brightness_6, _brightness,
              (v) => setState(() => _brightness = v)),
          const SizedBox(height: 12),
          _buildSlider('对比度', Icons.contrast, _contrast,
              (v) => setState(() => _contrast = v)),
          const SizedBox(height: 12),
          _buildSlider('饱和度', Icons.palette_outlined, _saturation,
              (v) => setState(() => _saturation = v)),
          const SizedBox(height: 16),
          // 重置调整按钮
          if (_hasChanges)
            GestureDetector(
              onTap: () => setState(() {
                _brightness = 0;
                _contrast = 0;
                _saturation = 0;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '重置调整',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlider(
      String label, IconData icon, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white.withOpacity(0.6)),
        const SizedBox(width: 10),
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white.withOpacity(0.15),
              thumbColor: Colors.white,
              overlayColor: AppColors.primary.withOpacity(0.2),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              min: -1.0,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${(value * 100).round()}',
            style: TextStyle(
              color: value != 0 ? AppColors.primary : Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: value != 0 ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

enum _EditMode { crop, adjust }

class _AspectRatioOption {
  final String label;
  final double? ratio;
  final IconData icon;

  _AspectRatioOption(this.label, this.ratio, this.icon);
}
