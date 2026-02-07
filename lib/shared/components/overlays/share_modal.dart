import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 分享弹窗组件
class ShareModal extends StatelessWidget {
  final int postId;
  final String postTitle;
  final String authorName;
  final bool isDialog; // 是否为 Dialog 模式（桌面端）

  const ShareModal({
    super.key,
    required this.postId,
    required this.postTitle,
    required this.authorName,
    this.isDialog = false,
  });

  /// 生成分享文本
  String _generateShareText() {
    return '打开集市APP，在搜索栏输入【$postId】以访问帖子【$postTitle - $authorName】';
  }

  /// 复制分享文本到剪贴板
  Future<void> _copyToClipboard(BuildContext context) async {
    final shareText = _generateShareText();
    await Clipboard.setData(ClipboardData(text: shareText));
    if (context.mounted) {
      SnackBarHelper.show(context, '已复制到剪贴板');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shareText = _generateShareText();

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        // 如果是 Dialog 模式，四周圆角；否则只有顶部圆角
        borderRadius: isDialog
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
                    onPressed: () => _copyToClipboard(context),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 显示分享弹窗
/// 移动端从底部弹出，宽屏幕设备在中间弹出
Future<void> showShareModal({
  required BuildContext context,
  required int postId,
  required String postTitle,
  required String authorName,
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
          constraints: const BoxConstraints(maxWidth: 500),
          child: ShareModal(
            postId: postId,
            postTitle: postTitle,
            authorName: authorName,
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
        authorName: authorName,
        isDialog: false,
      ),
    ).then((_) {});
  }
}
