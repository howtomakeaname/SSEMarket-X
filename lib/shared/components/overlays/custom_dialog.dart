import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 自定义确认弹窗组件
class CustomDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? cancelText;
  final String? confirmText;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final Color? confirmColor;

  const CustomDialog({
    super.key,
    required this.title,
    required this.content,
    this.cancelText,
    this.confirmText,
    this.onCancel,
    this.onConfirm,
    this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400, // 限制最大宽度
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题区域
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // 内容区域
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Text(
                  content,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // 分割线
              Container(
                height: 0.5,
                color: AppColors.divider,
              ),
              // 按钮区域
              Row(
                children: [
                  // 取消按钮
                  if (cancelText != null)
                    Expanded(
                      child: _DialogButton(
                        text: cancelText!,
                        onPressed: onCancel ?? () => Navigator.of(context).pop(false),
                        isCancel: true,
                      ),
                    ),
                  // 分割线
                  if (cancelText != null && confirmText != null)
                    Container(
                      width: 0.5,
                      height: 52,
                      color: AppColors.divider,
                    ),
                  // 确认按钮
                  if (confirmText != null)
                    Expanded(
                      child: _DialogButton(
                        text: confirmText!,
                        onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
                        color: confirmColor ?? AppColors.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹窗按钮组件
class _DialogButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final bool isCancel;

  const _DialogButton({
    required this.text,
    required this.onPressed,
    this.color,
    this.isCancel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.only(
          bottomLeft: isCancel ? const Radius.circular(16) : Radius.zero,
          bottomRight: !isCancel ? const Radius.circular(16) : Radius.zero,
        ),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color ?? AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 显示自定义确认弹窗
Future<bool?> showCustomDialog({
  required BuildContext context,
  required String title,
  required String content,
  String cancelText = '取消',
  String confirmText = '确定',
  Color? confirmColor,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => CustomDialog(
      title: title,
      content: content,
      cancelText: cancelText,
      confirmText: confirmText,
      confirmColor: confirmColor,
    ),
  );
}
