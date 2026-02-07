import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/views/post/markdown_help_page.dart';
import 'package:sse_market_x/shared/components/markdown/latex_markdown.dart';
import 'package:sse_market_x/shared/components/media/image_editor.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/components/inputs/toolbar_icon_button.dart';
import 'package:sse_market_x/shared/components/inputs/emoji_picker.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 评论输入组件
class CommentInput extends StatefulWidget {
  final int postId;
  final ApiService apiService;
  final Future<bool> Function(String content) onSend;
  final String placeholder;
  final bool autoFocus;
  /// 当输入框失去焦点时回调，参数为当前文本（已 trim），可用于弹窗在键盘收起且内容为空时关闭
  final void Function(String currentText)? onUnfocus;

  const CommentInput({
    super.key,
    required this.postId,
    required this.apiService,
    required this.onSend,
    this.placeholder = '支持Markdown语法',
    this.autoFocus = false,
    this.onUnfocus,
  });

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _kaomojiButtonKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  bool _isSending = false;
  bool _showPreview = false;
  bool _isUploading = false;
  OverlayEntry? _kaomojiOverlay;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && widget.onUnfocus != null) {
      widget.onUnfocus!(_controller.text.trim());
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _hideKaomojiOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _showKaomojiOverlay() {
    _hideKaomojiOverlay();
    
    final RenderBox? renderBox = _kaomojiButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final position = renderBox.localToGlobal(Offset.zero);
    
    _kaomojiOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 点击外部关闭
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideKaomojiOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // 颜文字选择器
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).size.height - position.dy + 8,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: _buildKaomojiSelector(),
            ),
          ),
        ],
      ),
    );
    
    Overlay.of(context).insert(_kaomojiOverlay!);
  }

  void _hideKaomojiOverlay() {
    _kaomojiOverlay?.remove();
    _kaomojiOverlay = null;
  }

  void _toggleKaomoji() {
    if (_kaomojiOverlay != null) {
      _hideKaomojiOverlay();
    } else {
      _showKaomojiOverlay();
    }
  }

  Future<void> _handleSend() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      SnackBarHelper.show(context, '请输入评论内容');
      return;
    }

    if (content.length > 1000) {
      SnackBarHelper.show(context, '评论内容不能超过1000个字符');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final success = await widget.onSend(content);
      if (success && mounted) {
        _controller.clear();
        _hideKaomojiOverlay();
        SnackBarHelper.show(context, '评论发布成功');
      } else if (mounted) {
        SnackBarHelper.show(context, '评论发布失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _insertKaomoji(String kaomoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    
    // 如果没有有效的选择位置，追加到末尾
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    
    final newText = text.replaceRange(start, end, kaomoji);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + kaomoji.length,
      ),
    );
  }

  /// 插入 Markdown 语法
  void _insertMarkdown(String prefix, String suffix, {String placeholder = ''}) {
    final text = _controller.text;
    final selection = _controller.selection;
    
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    
    String selectedText = '';
    if (start != end) {
      selectedText = text.substring(start, end);
    } else if (placeholder.isNotEmpty) {
      selectedText = placeholder;
    }
    
    final newText = text.replaceRange(start, end, '$prefix$selectedText$suffix');
    final newCursorPos = start + prefix.length + selectedText.length;
    
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Markdown 工具栏
          _buildMarkdownToolbar(),
          const SizedBox(height: 6),
          // 虚线分割线
          CustomPaint(
            size: const Size(double.infinity, 1),
            painter: DashedLinePainter(color: context.dividerColor),
          ),
          const SizedBox(height: 6),
          // 输入框或预览
          if (_showPreview)
            _buildPreview()
          else
            _buildEditor(),
          const SizedBox(height: 6),
          // 底部按钮组
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左侧：帮助和预览按钮
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Markdown帮助按钮
                    _buildBottomIconButton(
                    icon: Icons.help_outline,
                    tooltip: 'Markdown帮助',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MarkdownHelpPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // 预览按钮
                  _buildBottomIconButton(
                    icon: _showPreview ? Icons.edit : Icons.visibility,
                    tooltip: _showPreview ? '编辑' : '预览',
                    onPressed: () {
                      setState(() {
                        _showPreview = !_showPreview;
                      });
                    },
                    isActive: _showPreview,
                  ),
                ],
              ),
              // 右侧：颜文字和发送按钮
              if (!_showPreview)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 颜文字按钮
                    Container(
                      key: _kaomojiButtonKey,
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.dividerColor,
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _toggleKaomoji,
                        icon: const Icon(Icons.emoji_emotions_outlined, size: 16),
                        color: _kaomojiOverlay != null ? AppColors.primary : context.textSecondaryColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 发送按钮
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _controller.text.trim().isEmpty 
                            ? context.textSecondaryColor.withAlpha(100)
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: (_isSending || _controller.text.trim().isEmpty) ? null : _handleSend,
                        icon: _isSending 
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, size: 14),
                        color: Colors.white,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildKaomojiSelector() {
    return EmojiSelectorPanel(
      onEmojiSelected: (emoji) {
        _insertKaomoji(emoji);
        _hideKaomojiOverlay();
      },
    );
  }

  /// Markdown 工具栏
  Widget _buildMarkdownToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：Markdown 格式按钮
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_showPreview) ...[
                _buildToolButton(
                  icon: Icons.format_bold,
                  tooltip: '粗体：**粗体文字**',
                  onPressed: () => _insertMarkdown('**', '**', placeholder: '粗体文字'),
                ),
                _buildToolButton(
                  icon: Icons.format_italic,
                  tooltip: '斜体：*斜体文字*',
                  onPressed: () => _insertMarkdown('*', '*', placeholder: '斜体文字'),
                ),
                _buildToolButton(
                  icon: Icons.format_list_bulleted,
                  tooltip: '列表：- 列表项',
                  onPressed: () => _insertMarkdown('\n- ', '\n', placeholder: '列表项'),
                ),
                _buildToolButton(
                  icon: Icons.code,
                  tooltip: '代码：`代码`',
                  onPressed: () => _insertMarkdown('`', '`', placeholder: '代码'),
                ),
                _buildToolButton(
                  icon: Icons.format_quote,
                  tooltip: '引用：> 引用内容',
                  onPressed: () => _insertMarkdown('\n> ', '\n', placeholder: '引用内容'),
                ),
              ],
            ],
          ),
          // 右侧：上传图片按钮
          if (!_showPreview)
            _buildToolButton(
              icon: _isUploading ? Icons.hourglass_empty : Icons.image,
              tooltip: '上传图片',
              onPressed: _isUploading ? () {} : _pickAndUploadImage,
            ),
        ],
      ),
    );
  }

  /// 工具按钮
  Widget _buildToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return ToolbarIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      isActive: isActive,
    );
  }

  /// 底部图标按钮（左下角帮助和预览按钮）
  Widget _buildBottomIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.dividerColor,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          color: isActive ? AppColors.primary : context.textSecondaryColor,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
    );
  }

  /// 编辑器
  Widget _buildEditor() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: widget.autoFocus,
      maxLines: 6,
      minLines: 3,
      onChanged: (value) {
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: TextStyle(
          color: context.textSecondaryColor,
          fontSize: 14,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      style: TextStyle(
        fontSize: 14,
        color: context.textPrimaryColor,
        height: 1.5,
      ),
    );
  }

  /// 选择并上传图片
  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (image == null) return;

      final imageBytes = await image.readAsBytes();
      
      if (!mounted) return;
      
      // 打开图片编辑器
      final editedBytes = await ImageEditorPage.show(
        context,
        imageBytes: imageBytes,
        enableCrop: true,
        enableAdjust: true,
      );
      
      if (editedBytes == null || !mounted) return;

      setState(() {
        _isUploading = true;
      });
      
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageUrl = await widget.apiService.uploadPhoto(editedBytes, fileName);
      
      if (imageUrl != null && mounted) {
        // URL encode the image URL to handle special characters
        final encodedUrl = Uri.encodeFull(imageUrl);
        // 插入 Markdown 格式的图片链接
        final markdownImage = '![$fileName]($encodedUrl)';
        final currentText = _controller.text;
        final selection = _controller.selection;
        final cursorPos = selection.baseOffset >= 0 ? selection.baseOffset : currentText.length;
        
        final newText = currentText.substring(0, cursorPos) + 
                       markdownImage + 
                       currentText.substring(cursorPos);
        
        _controller.text = newText;
        // 移动光标到插入内容之后
        _controller.selection = TextSelection.collapsed(
          offset: cursorPos + markdownImage.length,
        );
        
        SnackBarHelper.show(context, '图片上传成功');
      } else if (mounted) {
        SnackBarHelper.show(context, '图片上传失败');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.show(context, '图片上传失败');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  /// 预览
  Widget _buildPreview() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: _controller.text.trim().isEmpty
          ? Text(
              '预览内容将在这里显示...',
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 14,
              ),
            )
          : MarkdownBody(
              data: _controller.text,
              styleSheet: getAdaptiveMarkdownStyleSheet(context).copyWith(
                p: TextStyle(
                  fontSize: 14,
                  color: context.textPrimaryColor,
                  height: 1.5,
                ),
                code: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  backgroundColor: context.backgroundColor,
                ),
              ),
            ),
    );
  }
}

/// 虚线分割线绘制器
class DashedLinePainter extends CustomPainter {
  final Color? color;
  
  DashedLinePainter({this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color ?? const Color(0xFFE0E0E0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
