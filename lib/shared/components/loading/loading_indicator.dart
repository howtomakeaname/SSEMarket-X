import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 统一的加载指示器组件
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final double strokeWidth;
  final bool showMessage;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 24,
    this.strokeWidth = 2,
    this.showMessage = true,
  });

  /// 居中加载指示器（用于页面初始加载、切换分区等）
  const LoadingIndicator.center({
    super.key,
    this.message = '加载中...',
    this.size = 24,
    this.strokeWidth = 2,
    this.showMessage = true,
  });

  /// 小型加载指示器（用于加载更多）
  const LoadingIndicator.small({
    super.key,
    this.message = '加载更多...',
    this.size = 16,
    this.strokeWidth = 2,
    this.showMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              color: AppColors.primary,
            ),
          ),
          if (showMessage && message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 行内加载指示器（用于刷新、加载更多等）
class LoadingRow extends StatelessWidget {
  final String message;
  final double size;
  final double strokeWidth;

  const LoadingRow({
    super.key,
    this.message = '加载中...',
    this.size = 16,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
