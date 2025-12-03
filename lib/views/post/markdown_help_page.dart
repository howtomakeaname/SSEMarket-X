import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// Markdown语法帮助页面
class MarkdownHelpPage extends StatefulWidget {
  const MarkdownHelpPage({super.key});

  @override
  State<MarkdownHelpPage> createState() => _MarkdownHelpPageState();
}

class _MarkdownHelpPageState extends State<MarkdownHelpPage> {
  final TextEditingController _practiceController = TextEditingController();
  bool _showPreview = false;

  final List<_SyntaxItem> _syntaxItems = [
    _SyntaxItem(
      title: '标题',
      syntax: '# 一级标题\n## 二级标题\n### 三级标题',
      example: '# 一级标题\n## 二级标题\n### 三级标题',
    ),
    _SyntaxItem(
      title: '文本样式',
      syntax: '**粗体** *斜体* ~~删除线~~',
      example: '**粗体** *斜体* ~~删除线~~',
    ),
    _SyntaxItem(
      title: '列表',
      syntax: '- 无序列表项\n- 另一个列表项\n\n1. 有序列表项\n2. 另一个有序项',
      example: '- 无序列表项\n- 另一个列表项\n\n1. 有序列表项\n2. 另一个有序项',
    ),
    _SyntaxItem(
      title: '链接和图片',
      syntax: '[链接文本](https://example.com)\n![图片描述](图片URL)',
      example: '[链接文本](https://example.com)',
    ),
    _SyntaxItem(
      title: '代码',
      syntax: '`行内代码`\n\n```\n代码块\n```',
      example: '`行内代码`\n\n```\n代码块\n```',
    ),
    _SyntaxItem(
      title: '引用',
      syntax: '> 这是一个引用\n> 可以多行',
      example: '> 这是一个引用\n> 可以多行',
    ),
    _SyntaxItem(
      title: '表格',
      syntax: '| 列1 | 列2 |\n|-----|-----|\n| 内容1 | 内容2 |',
      example: '| 列1 | 列2 |\n|-----|-----|\n| 内容1 | 内容2 |',
    ),
  ];

  @override
  void dispose() {
    _practiceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Markdown语法帮助',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        titleSpacing: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 语法指南
            _buildSyntaxGuide(),
            const SizedBox(height: 16),
            // 练习区域
            _buildPracticeSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSyntaxGuide() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '常用语法',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          ..._syntaxItems.map((item) => _buildSyntaxItem(item)),
        ],
      ),
    );
  }

  Widget _buildSyntaxItem(_SyntaxItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '语法:',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.backgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.syntax,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: context.textPrimaryColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '效果:',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.backgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: MarkdownBody(
              data: item.example,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 14, color: context.textPrimaryColor),
                h1: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimaryColor),
                h2: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimaryColor),
                h3: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimaryColor),
                code: TextStyle(
                  fontSize: 12,
                  backgroundColor: context.backgroundColor,
                  color: AppColors.primary,
                ),
                blockquote: TextStyle(fontSize: 14, color: context.textSecondaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '练习区域',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          // 操作按钮
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  _practiceController.clear();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.backgroundColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '清空',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showPreview = !_showPreview;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.backgroundColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _showPreview ? '编辑' : '预览',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_showPreview)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _practiceController.text.trim().isEmpty
                  ? Center(
                      child: Text(
                        '请输入Markdown内容进行预览',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    )
                  : MarkdownBody(
                      data: _practiceController.text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(fontSize: 14, color: context.textPrimaryColor),
                      ),
                    ),
            )
          else
            TextField(
              controller: _practiceController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: '在这里输入Markdown语法进行练习...',
                hintStyle: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: context.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: TextStyle(
                fontSize: 14,
                color: context.textPrimaryColor,
              ),
              onChanged: (_) => setState(() {}),
            ),
        ],
      ),
    );
  }
}

class _SyntaxItem {
  final String title;
  final String syntax;
  final String example;

  _SyntaxItem({
    required this.title,
    required this.syntax,
    required this.example,
  });
}
