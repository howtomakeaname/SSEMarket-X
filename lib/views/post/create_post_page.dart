import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/views/post/markdown_help_page.dart';
import 'package:sse_market_x/shared/components/markdown/latex_markdown.dart';
import 'package:sse_market_x/shared/components/media/image_editor.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/components/inputs/toolbar_icon_button.dart';
import 'package:sse_market_x/shared/components/overlays/custom_dialog.dart';
import 'package:sse_market_x/shared/components/inputs/custom_dropdown.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 创建帖子页面
class CreatePostPage extends StatefulWidget {
  final ApiService apiService;
  final bool isEmbedded;
  final bool isActive;
  final Function(String title, String content)? onPreviewUpdate;
  final VoidCallback? onPostSuccess;
  /// 是否从打分页面进入，用于默认选中“打分”分区并跳过草稿加载
  final bool fromRatingPage;

  const CreatePostPage({
    super.key,
    required this.apiService,
    this.isEmbedded = false,
    this.isActive = true,
    this.onPreviewUpdate,
    this.onPostSuccess,
    this.fromRatingPage = false,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  bool _isSubmitting = false;
  bool _showPreview = false;
  bool _isUploading = false;
  String _selectedPartition = '主页';
  Timer? _debounce;
  bool _draftLoaded = false;
  
  final ImagePicker _imagePicker = ImagePicker();

  UserModel _user = UserModel.empty();

  /// 显示名称分区列表
  final List<String> _displayPartitions = [
    '主页',
    '院务',
    '课程',
    '学习解惑',
    '打听求助',
    '随想随记',
    '求职招募',
    '打分',
    '其他',
  ];

  /// 显示名称 -> API 名称
  final Map<String, String> _displayToApiPartition = {
    '主页': '主页',
    '院务': '院务',
    '课程': '课程交流',
    '学习解惑': '学习交流',
    '打听求助': '打听求助',
    '随想随记': '日常吐槽',
    '求职招募': '求职招募',
    '打分': '打分',
    '其他': '其他',
  };

  @override
  void initState() {
    super.initState();
    _loadUser();

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    // 如果从打分页面进入：默认选中“打分”，且不加载草稿
    if (widget.fromRatingPage) {
      _selectedPartition = '打分';
      _draftLoaded = true; // 标记为已处理，避免后续 didUpdateWidget 再次加载
    } else {
      // 仅在普通入口且已激活时加载草稿
      if (widget.isActive) {
        _loadDraft();
        _draftLoaded = true;
        // Initial preview update
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updatePreview();
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant CreatePostPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Load draft when becoming active for the first time
    if (!widget.fromRatingPage) {
      if (widget.isActive && !oldWidget.isActive && !_draftLoaded) {
        _loadDraft();
        _draftLoaded = true;
        // Trigger initial preview
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updatePreview();
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
    _titleController.dispose();
    _contentController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final user = await widget.apiService.getUserInfo();
      if (mounted) {
        setState(() {
          _user = user;
        });
      }
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
    }
  }

  void _insertMarkdown(String prefix, String suffix, {String? placeholder}) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    
    if (selection.start < 0) {
      final insertText = placeholder ?? '';
      final newText = text + prefix + insertText + suffix;
      _contentController.text = newText;
      if (placeholder != null) {
        // 选中示例文字
        _contentController.selection = TextSelection(
          baseOffset: text.length + prefix.length,
          extentOffset: text.length + prefix.length + insertText.length,
        );
      } else {
        _contentController.selection = TextSelection.collapsed(offset: newText.length - suffix.length);
      }
      return;
    }

    final start = selection.start;
    final end = selection.end;
    
    final selectedText = text.substring(start, end);
    final insertText = selectedText.isNotEmpty ? selectedText : (placeholder ?? '');
    final newText = text.substring(0, start) + prefix + insertText + suffix + text.substring(end);
    
    _contentController.text = newText;
    if (insertText.isNotEmpty) {
      _contentController.selection = TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + insertText.length,
      );
    } else {
      _contentController.selection = TextSelection.collapsed(offset: start + prefix.length);
    }
    _onTextChanged();
  }

  Future<void> _onSubmit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // 验证输入
    if (title.isEmpty) {
      _showMessage('请输入标题');
      return;
    }

    if (title.length > 100) {
      _showMessage('标题不能超过100个字符');
      return;
    }

    if (content.isEmpty) {
      _showMessage('请输入内容');
      return;
    }

    if (content.length > 5000) {
      _showMessage('内容不能超过5000个字符');
      return;
    }

    if (_user.phone.isEmpty) {
      _showMessage('用户信息获取失败，请重新登录');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final apiPartition = _displayToApiPartition[_selectedPartition] ?? '主页';
      final success = await widget.apiService.createPost(
        title,
        content,
        apiPartition,
        _user.phone,
      );

      if (success && mounted) {
        _showMessage('发布成功');
        _clearDraft();
        
        if (widget.isEmbedded) {
          if (widget.onPostSuccess != null) {
            widget.onPostSuccess!();
          }
          // Reset form
          _titleController.clear();
          _contentController.clear();
          setState(() {
            _selectedPartition = '主页';
          });
        } else {
          Navigator.of(context).pop(true);
        }
      } else if (mounted) {
        _showMessage('发布失败，请重试');
      }
    } catch (e) {
      debugPrint('发布失败: $e');
      if (mounted) {
        _showMessage('发布失败，请检查网络连接');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    SnackBarHelper.show(context, message);
  }

  void _onTextChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _saveDraft();
      _updatePreview();
    });
  }

  void _updatePreview() {
    if (widget.onPreviewUpdate != null) {
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();
      widget.onPreviewUpdate!(title, content);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
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
        final currentText = _contentController.text;
        final selection = _contentController.selection;
        final cursorPos = selection.baseOffset >= 0 ? selection.baseOffset : currentText.length;
        
        final newText = currentText.substring(0, cursorPos) + 
                       markdownImage + 
                       currentText.substring(cursorPos);
        
        _contentController.text = newText;
        // 移动光标到插入内容之后
        _contentController.selection = TextSelection.collapsed(
          offset: cursorPos + markdownImage.length,
        );
        
        _showMessage('图片上传成功');
      } else if (mounted) {
        _showMessage('图片上传失败');
      }
    } catch (e) {
      debugPrint('选择或上传图片失败: $e');
      if (mounted) {
        _showMessage('图片上传失败');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft_title', _titleController.text);
    await prefs.setString('draft_content', _contentController.text);
    await prefs.setString('draft_partition', _selectedPartition);
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('draft_title');
    await prefs.remove('draft_content');
    await prefs.remove('draft_partition');
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('draft_title');
    final content = prefs.getString('draft_content');
    final partition = prefs.getString('draft_partition');

    if (title != null || content != null || partition != null) {
      final load = await showCustomDialog(
        context: context,
        title: '加载草稿',
        content: '检测到有未提交的草稿，是否加载？',
        cancelText: '新建',
        confirmText: '加载',
      );

      if (load == true && mounted) {
        setState(() {
          _titleController.text = title ?? '';
          _contentController.text = content ?? '';
          _selectedPartition = partition ?? '主页';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: widget.isEmbedded ? null : AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '新建帖子',
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
            onPressed: _isSubmitting ? null : _onSubmit,
            child: Text(
              '提交',
              style: TextStyle(
                fontSize: 16,
                color: _isSubmitting ? context.textSecondaryColor : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8), // Add right padding
        ],
      ),
      body: Column(
        children: [
          // Custom header for embedded mode
          if (widget.isEmbedded)
            Container(
              color: context.surfaceColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '新建',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSubmitting ? null : _onSubmit,
                    child: Text(
                      '提交',
                      style: TextStyle(
                        fontSize: 16,
                        color: _isSubmitting ? context.textSecondaryColor : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Main content - 邮件编写风格
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildUnifiedComposer(),
            ),
          ),
        ],
      ),
    );
  }

  /// 统一的编写器（邮件风格）
  Widget _buildUnifiedComposer() {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 标题输入
          _buildTitleInput(),
          // 虚线分隔线
          _buildDashedDivider(),
          // 分区选择
          _buildPartitionSelector(),
          // 虚线分隔线
          _buildDashedDivider(),
          // 内容输入区
          _buildContentInput(),
        ],
      ),
    );
  }

  /// 虚线分隔线
  Widget _buildDashedDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, 1),
            painter: DashedLinePainter(color: context.dividerColor),
          );
        },
      ),
    );
  }

  /// 标题输入
  Widget _buildTitleInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '标题',
              style: TextStyle(
                fontSize: 15,
                color: context.textSecondaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: '请输入标题',
                hintStyle: TextStyle(
                  color: context.textTertiaryColor,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 16,
                color: context.textPrimaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 分区选择器
  Widget _buildPartitionSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // 与标题区域一致
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12), // 与标题区域保持一致
            child: Text(
              '分区',
              style: TextStyle(
                fontSize: 15,
                color: context.textSecondaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: CustomDropdown<String>(
                value: _selectedPartition,
                items: _displayPartitions,
                itemBuilder: (partition) => partition,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPartition = value;
                    });
                    _onTextChanged();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 内容输入区
  Widget _buildContentInput() {
    return Column(
      children: [
        // 工具栏
        _buildToolbar(),
        // 内容输入/预览
        if (_showPreview)
          _buildPreview()
        else
          _buildEditor(),
      ],
    );
  }

  /// 工具栏
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Markdown 工具按钮
          if (!_showPreview) ...[
            ToolbarIconButton(
              icon: Icons.title,
              tooltip: '标题：## 二级标题',
              onPressed: () => _insertMarkdown('\n## ', '\n', placeholder: '二级标题'),
            ),
            ToolbarIconButton(
              icon: Icons.format_bold,
              tooltip: '粗体：**粗体文字**',
              onPressed: () => _insertMarkdown('**', '**', placeholder: '粗体文字'),
            ),
            ToolbarIconButton(
              icon: Icons.format_italic,
              tooltip: '斜体：*斜体文字*',
              onPressed: () => _insertMarkdown('*', '*', placeholder: '斜体文字'),
            ),
            ToolbarIconButton(
              icon: Icons.format_list_bulleted,
              tooltip: '无序列表：- 列表项',
              onPressed: () => _insertMarkdown('\n- ', '\n', placeholder: '列表项'),
            ),
            ToolbarIconButton(
              icon: Icons.code,
              tooltip: '代码：`代码`',
              onPressed: () => _insertMarkdown('`', '`', placeholder: '代码'),
            ),
            ToolbarIconButton(
              icon: Icons.format_quote,
              tooltip: '引用：> 引用内容',
              onPressed: () => _insertMarkdown('\n> ', '\n', placeholder: '引用内容'),
            ),
            ToolbarIconButton(
              icon: Icons.image,
              tooltip: '上传图片',
              onPressed: _isUploading ? null : _pickAndUploadImage,
            ),
          ],
          const Spacer(),
          // Markdown 帮助
          ToolbarIconButton(
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
          // 预览按钮（与评论输入区统一为 icon 按钮样式）
          if (widget.onPreviewUpdate == null)
            ToolbarIconButton(
              icon: _showPreview ? Icons.edit : Icons.visibility,
              tooltip: _showPreview ? '编辑' : '预览',
              isActive: _showPreview,
              onPressed: () {
                setState(() {
                  _showPreview = !_showPreview;
                });
              },
            ),
        ],
      ),
    );
  }

  /// 编辑器
  Widget _buildEditor() {
    return TextField(
      controller: _contentController,
      maxLines: null,
      minLines: 20, // 增加初始高度
      decoration: InputDecoration(
        hintText: '请输入内容，支持 Markdown 格式...',
        hintStyle: TextStyle(
          color: context.textSecondaryColor,
          fontSize: 15,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      ),
      style: TextStyle(
        fontSize: 15,
        color: context.textPrimaryColor,
        height: 1.5,
      ),
    );
  }

  /// 预览
  Widget _buildPreview() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 400), // 增加预览最小高度
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: _contentController.text.trim().isEmpty
          ? Center(
              child: Text(
                '暂无内容预览',
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondaryColor,
                ),
              ),
            )
          : LatexMarkdown(
              data: _contentController.text,
            ),
    );
  }
}

/// 虚线绘制器
class DashedLinePainter extends CustomPainter {
  final Color color;
  
  DashedLinePainter({this.color = const Color(0xFFE0E0E0)});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

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
  bool shouldRepaint(covariant DashedLinePainter oldDelegate) => oldDelegate.color != color;
}
