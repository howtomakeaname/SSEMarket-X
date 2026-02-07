import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  final GlobalKey _imagePreviewKey = GlobalKey();
  bool _isGeneratingImage = false;

  /// 生成分享文本
  String _generateShareText() {
    return '打开集市APP，在搜索栏输入【${widget.postId}】以访问帖子【${widget.postTitle} - ${widget.authorName}】';
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
        // 复制图片数据到剪贴板（某些平台可能不支持，但先尝试）
        // 注意：Flutter的Clipboard目前不支持直接复制图片
        // 这里我们提示用户图片已准备好，实际保存需要平台特定实现
        SnackBarHelper.show(context, '分享图片已生成（请使用系统分享功能）');
        
        // TODO: 可以在这里添加保存到相册的功能，需要添加image_gallery_saver包
        // 或者使用share_plus包来分享图片
        
        Navigator.of(context).pop();
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

    Widget content = Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        // 如果是 Dialog 模式，四周圆角；否则只有顶部圆角
        borderRadius: widget.isDialog
            ? BorderRadius.circular(16)
            : const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '分享帖子',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 分享内容区域
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 胶囊按钮切换
                Center(
                  child: SegmentedControl<ShareType>(
                    segments: const [ShareType.text, ShareType.image],
                    selectedSegment: _selectedShareType,
                    onSegmentChanged: (type) {
                      setState(() {
                        _selectedShareType = type;
                      });
                    },
                    labelBuilder: (type) {
                      return type == ShareType.text ? '文本' : '图片';
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // 根据选择的类型显示不同内容
                if (_selectedShareType == ShareType.text) ...[
                  Text(
                    '分享内容：',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.dividerColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: SelectableText(
                      shareText,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textPrimaryColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 复制按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _copyToClipboard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '复制分享内容',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // 图片预览
                  RepaintBoundary(
                    key: _imagePreviewKey,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 400),
                      decoration: BoxDecoration(
                        color: context.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: context.dividerColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SingleChildScrollView(
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
                  ),
                  const SizedBox(height: 16),
                  // 生成并保存按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isGeneratingImage ? null : _saveShareImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isGeneratingImage
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              '生成并保存图片',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    // 移动端底部弹出时，添加底部安全区
    if (!widget.isDialog) {
      content = SafeArea(
        top: false,
        child: content,
      );
    }

    return content;
  }
}

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
