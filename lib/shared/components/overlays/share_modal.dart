import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:sse_market_x/shared/components/inputs/segmented_control.dart';
import 'package:sse_market_x/shared/components/overlays/share_image_widget.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 分享类型枚举
enum ShareType {
  text,
  image,
}

/// 分享弹窗组件
class ShareModal extends StatefulWidget {
  final int postId;
  final String postTitle;
  final String postContent;
  final String authorName;
  final String authorAvatar;
  final String createdAt;
  final bool isDialog; // 是否为 Dialog 模式（桌面端）

  const ShareModal({
    super.key,
    required this.postId,
    required this.postTitle,
    required this.postContent,
    required this.authorName,
    required this.authorAvatar,
    required this.createdAt,
    this.isDialog = false,
  });

  @override
  State<ShareModal> createState() => _ShareModalState();
}

class _ShareModalState extends State<ShareModal> {
  ShareType _selectedShareType = ShareType.text;
  late PageController _pageController;
  final GlobalKey _imagePreviewKey = GlobalKey();
  bool _isGeneratingImage = false;

  /// 初始给足够高以便两页都能完成布局并测高
  static const double _initialContentHeight = 520.0;
  double _contentHeight = _initialContentHeight;
  final List<double?> _pageHeights = [null, null];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _selectedShareType == ShareType.text ? 0 : 1,
    );
    _pageController.addListener(_onPageOffsetChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeights());
    // 第二页可能稍后才构建，再测一次以便滑动时能正确插值
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeights());
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageOffsetChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageOffsetChanged() {
    if (_pageHeights[0] == null || _pageHeights[1] == null) return;
    final page = _pageController.page ?? _pageController.initialPage.toDouble();
    final t = page.clamp(0.0, 1.0);
    if (mounted) {
      setState(() {
        _contentHeight = _pageHeights[0]! * (1 - t) + _pageHeights[1]! * t;
      });
    }
  }

  void _measureHeights() {
    if (!mounted) return;
    double? h0;
    double? h1;
    final box0 = _keyPage0.currentContext?.findRenderObject() as RenderBox?;
    if (box0 != null && box0.hasSize) h0 = box0.size.height;
    final box1 = _keyPage1.currentContext?.findRenderObject() as RenderBox?;
    if (box1 != null && box1.hasSize) h1 = box1.size.height;
    final bool changed = (h0 != null && _pageHeights[0] != h0) || (h1 != null && _pageHeights[1] != h1);
    if (h0 != null) _pageHeights[0] = h0;
    if (h1 != null) _pageHeights[1] = h1;
    if (!changed && h0 == null && h1 == null) return;
    final page = _pageController.page ?? _pageController.initialPage.toDouble();
    final t = page.clamp(0.0, 1.0);
    double newHeight;
    if (_pageHeights[0] != null && _pageHeights[1] != null) {
      newHeight = _pageHeights[0]! * (1 - t) + _pageHeights[1]! * t;
    } else if (_pageHeights[0] != null) {
      newHeight = _pageHeights[0]!;
    } else if (_pageHeights[1] != null) {
      newHeight = _pageHeights[1]!;
    } else {
      return;
    }
    if (mounted) setState(() => _contentHeight = newHeight);
  }

  final GlobalKey _keyPage0 = GlobalKey();
  final GlobalKey _keyPage1 = GlobalKey();

  void _goToPage(ShareType type) {
    if (_selectedShareType == type) return;
    final index = type == ShareType.text ? 0 : 1;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  /// 生成分享文本
  String _generateShareText() {
    return '打开集市APP，在搜索栏输入【${widget.postId}】以访问帖子【${widget.postTitle} - ${widget.authorName}】';
  }

  Widget _buildTextShareContent(BuildContext context, String shareText, {Key? contentKey}) {
    final column = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '分享文案',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  shareText,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.textPrimaryColor,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _copyToClipboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '复制',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
    );
    return contentKey != null
        ? SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: KeyedSubtree(key: contentKey, child: column),
          )
        : column;
  }

  Widget _buildImageShareContent(BuildContext context, {Key? contentKey}) {
    final column = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 440),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RepaintBoundary(
                key: _imagePreviewKey,
                child: ShareImageWidget(
                  appLogoPath: 'assets/images/logo.png',
                  postTitle: widget.postTitle,
                  postContent: widget.postContent,
                  authorName: widget.authorName,
                  authorAvatar: widget.authorAvatar,
                  createdAt: widget.createdAt,
                  postId: widget.postId,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isGeneratingImage ? null : _saveShareImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
              ),
              child: _isGeneratingImage
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      '生成图片',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
    );
    return contentKey != null
        ? SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: KeyedSubtree(key: contentKey, child: column),
          )
        : column;
  }

  /// 复制分享文本到剪贴板
  Future<void> _copyToClipboard() async {
    final shareText = _generateShareText();
    await Clipboard.setData(ClipboardData(text: shareText));
    if (mounted) {
      SnackBarHelper.show(context, '已复制到剪贴板');
      Navigator.of(context).pop();
    }
  }

  /// 生成并保存分享图片
  Future<void> _saveShareImage() async {
    if (_isGeneratingImage) return;

    setState(() {
      _isGeneratingImage = true;
    });

    try {
      // 等待一帧确保Widget已渲染
      await Future.delayed(const Duration(milliseconds: 200));

      // 使用RepaintBoundary捕获图片
      final RenderRepaintBoundary? boundary = _imagePreviewKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        if (mounted) {
          SnackBarHelper.show(context, '无法生成图片，请重试');
        }
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null && mounted) {
        // 保存到相册
        final result = await SaverGallery.saveImage(
          byteData.buffer.asUint8List(),
          quality: 100,
          fileName: 'sse_market_share_${DateTime.now().millisecondsSinceEpoch}.png',
          skipIfExists: false,
        );

        if (mounted) {
          if (result.isSuccess) {
            SnackBarHelper.show(context, '图片已保存到相册');
            Navigator.of(context).pop();
          } else {
            SnackBarHelper.show(context, '保存失败: ${result.errorMessage}');
          }
        }
      } else if (mounted) {
        SnackBarHelper.show(context, '生成图片失败');
      }
    } catch (e) {
      debugPrint('生成分享图片失败: $e');
      if (mounted) {
        SnackBarHelper.show(context, '生成图片失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shareText = _generateShareText();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = Container(
      decoration: BoxDecoration(
        // iOS 风格模态背景
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        borderRadius: widget.isDialog
            ? BorderRadius.circular(16)
            : const BorderRadius.vertical(top: Radius.circular(20)), // 加大圆角
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Indicator (拖动条)
          if (!widget.isDialog)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withOpacity(0.2) 
                      : Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

          // 胶囊按钮区域
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedControl<ShareType>(
                    segments: const [ShareType.text, ShareType.image],
                    selectedSegment: _selectedShareType,
                    onSegmentChanged: _goToPage,
                    labelBuilder: (type) {
                      return type == ShareType.text ? '文本' : '图片';
                    },
                  ),
                ),
                // 关闭按钮（可选，右上角小叉号，或者省略）
                if (widget.isDialog) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withOpacity(0.1) 
                            : Colors.black.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 分享内容区域：PageView 左右滑动，高度在滑动过程中随 page 偏移插值变化
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: _contentHeight,
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _selectedShareType = index == 0 ? ShareType.text : ShareType.image;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeights());
                },
                children: [
                  _buildTextShareContent(context, shareText, contentKey: _keyPage0),
                  _buildImageShareContent(context, contentKey: _keyPage1),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // 移动端底部弹出时添加底部安全区
    if (!widget.isDialog) {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;
      final backgroundColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
      
      content = Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: content,
        ),
      );
    }

    return content;
  }
}

// ... showShareModal 函数保持不变，直接复用文件末尾部分 ...
/// 显示分享弹窗
/// 移动端从底部弹出，宽屏幕设备在中间弹出
Future<void> showShareModal({
  required BuildContext context,
  required int postId,
  required String postTitle,
  required String postContent,
  required String authorName,
  required String authorAvatar,
  required String createdAt,
}) {
  final isDesktop = MediaQuery.of(context).size.width >= 600;

  if (isDesktop) {
    // 桌面端/平板：居中弹窗
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ShareModal(
            postId: postId,
            postTitle: postTitle,
            postContent: postContent,
            authorName: authorName,
            authorAvatar: authorAvatar,
            createdAt: createdAt,
            isDialog: true,
          ),
        ),
      ),
    ).then((_) {});
  } else {
    // 移动端：底部弹窗
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareModal(
        postId: postId,
        postTitle: postTitle,
        postContent: postContent,
        authorName: authorName,
        authorAvatar: authorAvatar,
        createdAt: createdAt,
        isDialog: false,
      ),
    ).then((_) {});
  }
}
