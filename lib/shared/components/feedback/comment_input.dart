import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/views/post/markdown_help_page.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/components/inputs/toolbar_icon_button.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 评论输入组件
class CommentInput extends StatefulWidget {
  final int postId;
  final ApiService apiService;
  final Future<bool> Function(String content) onSend;
  final String placeholder;

  const CommentInput({
    super.key,
    required this.postId,
    required this.apiService,
    required this.onSend,
    this.placeholder = '支持Markdown语法',
  });

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey _kaomojiButtonKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  bool _isSending = false;
  bool _showPreview = false;
  bool _isUploading = false;
  String _activeTab = 'happy';
  OverlayEntry? _kaomojiOverlay;

  // 颜文字和表情数据
  final Map<String, List<String>> _kaomojis = {
    'happy': [
      '(´∀｀)', '(￣▽￣)', '(´▽｀)', '(￣ω￣)', '(´ω｀)', '(￣∀￣)',
      '(๑´ㅂ`๑)', '(｡♥‿♥｡)', '(◕‿◕)', '(*´▽`*)', '(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧',
      '(＾◡＾)', '(◠‿◠)', '(´꒳`)', '(◡ ω ◡)', '(´｡• ᵕ •｡`)', '(◕ᴗ◕✿)',
      '(ﾉ◕ヮ◕)ﾉ', '(≧∇≦)', '(＾▽＾)', '(◉‿◉)', '(´∇｀)', '(◕‿◕)♡'
    ],
    'sad': [
      '(´；ω；｀)', '(｡•́︿•̀｡)', '(╥_╥)', '(T_T)', '(;_;)', '(ಥ﹏ಥ)',
      '(இ﹏இ`｡)', '(┳Д┳)', '(个_个)', '(´-ω-`)', '(｡•́ - •̀｡)',
      '(╯︵╰)', '(｡╯︵╰｡)', '(´°̥̥̥̥̥̥̥̥ω°̥̥̥̥̥̥̥̥｀)', '(｡•́︿•̀｡)', '(◞‸◟)',
      '(╥﹏╥)', '(ಥ_ಥ)', '(´；д；`)', '(｡•́︿•̀｡)', '(╯_╰)', '(´Д｀)'
    ],
    'angry': [
      '(╬ಠ益ಠ)', '(ಠ_ಠ)', '(¬_¬)', '(►_►)', '(҂◡_◡)', '(ꐦ°᷄д°᷅)',
      '(╯°□°）╯︵ ┻━┻', '(ノಠ益ಠ)ノ', '(눈_눈)', '(⋋▂⋌)', '(-_-メ)',
      '(｀皿´＃)', '(╯‵□′)╯︵┻━┻', '(ﾉ｀Д´)ﾉ彡┻━┻', '(ಠ益ಠ)', '(◣_◢)',
      '(╬⁽⁽ ⁰ ⁾⁾ Д ⁽⁽ ⁰ ⁾⁾)', '(ﾉ°益°)ﾉ', '(｀ε´)', '(ﾉ｀⌒´)ﾉ┫：・┻┻', '(ﾒ｀ﾛ´)/', '(ﾉ｀□´)ﾉ⌒┻━┻'
    ],
    'love': [
      '(｡♥‿♥｡)', '(´∀｀)♡', '(◍•ᴗ•◍)❤', '(｡・//ε//・｡)', '(๑˃̵ᴗ˂̵)و',
      '(✿◠‿◠)', '(⺣◡⺣)♡*', '(灬º‿º灬)♡', '(ღ˘⌣˘ღ)', '(♥ω♥*)', '(´ε｀ )',
      '(´∀｀)♡', '(◕‿◕)♡', '(｡♥‿♥｡)', '(◍•ᴗ•◍)♡', '(´｡• ω •｡`) ♡',
      '(◡ ‿ ◡)♡', '(´∀｀)♡', '(◕ᴗ◕)♡', '(◍•ᴗ•◍)❤', '(´♡‿♡`)', '(◕‿◕)♡'
    ],
    'surprise': [
      '(゜o゜;)', '(O_O)', '(⊙_⊙)', '(°ロ°)', '(◎_◎;)', '(✪ω✪)',
      '(⊙ω⊙)', '(◉_◉)', '(°△°|||)', '(☉_☉)', '(ʘᗩʘ)',
      '(⊙０⊙)', '(◉０◉)', '(°o°)', '(⊙.⊙)', '(◎０◎)', '(°□°)',
      '(⊙▽⊙)', '(◉‿◉)', '(°▽°)', '(⊙ω⊙)', '(◎_◎)', '(°０°)'
    ],
    'emoji': [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊',
      '😇', '🥰', '😍', '🤩', '😘', '😗', '☺️', '😚', '😙', '🥲', '😋', '😛',
      '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐', '🤨', '😐', '😑',
      '😶', '😏', '😒', '🙄', '😬', '🤥', '😔', '😪', '🤤', '😴', '😷', '🤒'
    ],
    'cute': [
      '(◕‿◕)', '(◡ ω ◡)', '(´｡• ᵕ •｡`)', '(◕ᴗ◕✿)', '(´꒳`)', '(◠‿◠)',
      '(｡◕‿◕｡)', '(◕‿◕)♡', '(◍•ᴗ•◍)', '(´∀｀)', '(◡‿◡)', '(◕ω◕)',
      '(◉‿◉)', '(◕‿◕)✿', '(◍•ᴗ•◍)✧*', '(◕‿◕)♪', '(◡ ‿ ◡)', '(◕‿◕)☆',
      '(◍•ᴗ•◍)♡', '(◕‿◕)♫', '(◡ ω ◡)♡', '(◕‿◕)✨', '(◍•ᴗ•◍)♪', '(◕‿◕)♬'
    ],
    'cool': [
      '(⌐■_■)', '(▀̿Ĺ̯▀̿ ̿)', '(◣_◢)', '(¬‿¬)', '(ಠ_ಠ)', '(¬_¬)',
      '(►_►)', '(◉_◉)', '(⊙_⊙)', '(◎_◎)', '(°_°)', '(-_-)',
      '(¯\\_(ツ)_/¯)', '(╯°□°）╯', '(ಠ益ಠ)', '(◣_◢)', '(⌐■_■)',
      '(▀̿Ĺ̯▀̿ ̿)', '(¬‿¬)', '(ಠ_ಠ)', '(¬_¬)', '(►_►)', '(◉_◉)', '(⊙_⊙)'
    ],
  };

  final Map<String, String> _tabLabels = {
    'happy': '开心',
    'sad': '难过',
    'angry': '愤怒',
    'love': '爱心',
    'surprise': '惊讶',
    'cute': '可爱',
    'cool': '酷炫',
    'emoji': 'Emoji',
  };

  @override
  void dispose() {
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
            painter: DashedLinePainter(),
          ),
          const SizedBox(height: 6),
          // 输入框或预览
          if (_showPreview)
            _buildPreview()
          else
            _buildEditor(),
          const SizedBox(height: 6),
          // 悬浮按钮组
          if (!_showPreview)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 颜文字按钮
                  Container(
                    key: _kaomojiButtonKey,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.divider,
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
                      color: _kaomojiOverlay != null ? AppColors.primary : AppColors.textSecondary,
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
                          ? AppColors.textSecondary.withAlpha(100)
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
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildKaomojiSelector() {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标签页
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _tabLabels.entries.map((entry) {
                    final isActive = _activeTab == entry.key;
                    return GestureDetector(
                      onTap: () {
                        setLocalState(() {
                          _activeTab = entry.key;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.background : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              // 颜文字网格
              SizedBox(
                height: 160,
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _activeTab == 'emoji' ? 6 : 4, // emoji显示6列，其他显示4列
                    childAspectRatio: _activeTab == 'emoji' ? 1.0 : 2.0, // emoji正方形，其他长方形
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _kaomojis[_activeTab]?.length ?? 0,
                  itemBuilder: (context, index) {
                    final kaomoji = _kaomojis[_activeTab]![index];
                    final isEmoji = _activeTab == 'emoji';
                    return GestureDetector(
                      onTap: () {
                        _insertKaomoji(kaomoji);
                        _hideKaomojiOverlay();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          kaomoji,
                          style: TextStyle(fontSize: isEmoji ? 20 : 14), // emoji更大
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Markdown 工具栏
  Widget _buildMarkdownToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          // Markdown 工具按钮
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
            _buildToolButton(
              icon: Icons.image,
              tooltip: '上传图片',
              onPressed: _isUploading 
                  ? () {} // 空函数而不是 null
                  : () {
                      _pickAndUploadImage();
                    },
            ),
          ],
          const Spacer(),
          // Markdown帮助
          _buildToolButton(
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
          // 预览按钮
          _buildToolButton(
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

  /// 编辑器
  Widget _buildEditor() {
    return TextField(
      controller: _controller,
      maxLines: 6,
      minLines: 3,
      onChanged: (value) {
        setState(() {}); // 更新发送按钮状态
      },
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        border: InputBorder.none, // 无边框
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
    );
  }

  /// 选择并上传图片
  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _isUploading = true;
      });
      
      final bytes = await image.readAsBytes();
      final fileName = image.name;
      
      final imageUrl = await widget.apiService.uploadPhoto(bytes, fileName);
      
      if (imageUrl != null && mounted) {
        // URL encode the image URL to handle special characters
        final encodedUrl = Uri.encodeFull(imageUrl);
        // 插入 Markdown 格式的图片链接
        final markdownImage = '![${fileName}]($encodedUrl)';
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
          ? const Text(
              '预览内容将在这里显示...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            )
          : MarkdownBody(
              data: _controller.text,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
                code: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                ),
                blockquote: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
    );
  }
}

/// 虚线分割线绘制器
class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.divider
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
