import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/shared/components/feedback/comment_input.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 回复弹窗组件
class ReplyModal extends StatefulWidget {
  final int postId;
  final ApiService apiService;
  final String replyToName;
  final int? parentCommentId; // 主评论ID
  final int? targetCommentId; // 目标评论ID（子评论回复时使用）
  final String? targetUserName; // 目标用户名（子评论回复时使用）
  final bool isDialog; // 是否为 Dialog 模式（桌面端）

  const ReplyModal({
    super.key,
    required this.postId,
    required this.apiService,
    required this.replyToName,
    this.parentCommentId,
    this.targetCommentId,
    this.targetUserName,
    this.isDialog = false,
  });

  @override
  State<ReplyModal> createState() => _ReplyModalState();
}

class _ReplyModalState extends State<ReplyModal> {
  @override
  Widget build(BuildContext context) {
    return Container(
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
                  '回复 ${widget.replyToName}',
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
          // 回复输入区域
          CommentInput(
            postId: widget.postId,
            apiService: widget.apiService,
            placeholder: '回复 ${widget.replyToName}...',
            autoFocus: true, // 弹窗中自动聚焦
            onSend: (content) async {
              return await _handleReply(content);
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _handleReply(String content) async {
    try {
      final storage = StorageService();
      final user = storage.user;
      if (user == null) return false;

      bool success;
      
      if (widget.parentCommentId != null) {
        // 回复评论（子评论）
        success = await widget.apiService.sendSubComment(
          content: content,
          postId: widget.postId,
          parentCommentId: widget.parentCommentId!,
          targetCommentId: widget.targetCommentId,
          targetUserName: widget.targetUserName,
        );
      } else {
        // 直接回复帖子（主评论）
        success = await widget.apiService.sendComment(
          content,
          widget.postId,
          user.phone,
        );
      }

      if (success && mounted) {
        Navigator.of(context).pop(true); // 返回成功标识
      }
      
      return success;
    } catch (e) {
      return false;
    }
  }
}
