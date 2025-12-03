import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class FeedbackPage extends StatefulWidget {
  final ApiService apiService;

  const FeedbackPage({
    super.key,
    required this.apiService,
  });

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _contentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      SnackBarHelper.show(context, '请输入反馈内容');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await widget.apiService.submitFeedback(content);
      if (mounted) {
        if (success) {
          SnackBarHelper.show(context, '反馈提交成功，感谢您的建议！');
          Navigator.of(context).pop();
        } else {
          SnackBarHelper.show(context, '提交失败，请稍后重试');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.show(context, '网络错误，请检查连接');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '反馈',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitFeedback,
            child: Text(
              '提交',
              style: TextStyle(
                fontSize: 16,
                color: _isSubmitting ? context.textSecondaryColor : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请在下方输入您的反馈信息',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: '请在此输入反馈...',
                    hintStyle: TextStyle(
                      color: context.textTertiaryColor,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    color: context.textPrimaryColor,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 底部留白，避免贴底太近
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
