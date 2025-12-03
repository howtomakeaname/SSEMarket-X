import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart' hide ImageViewer;
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/image_viewer.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 获取适配深色模式的 MarkdownStyleSheet
MarkdownStyleSheet getAdaptiveMarkdownStyleSheet(BuildContext context) {
  final textPrimaryColor = context.textPrimaryColor;
  final textSecondaryColor = context.textSecondaryColor;
  final backgroundColor = context.backgroundColor;
  final surfaceColor = context.surfaceColor;

  return MarkdownStyleSheet(
    p: TextStyle(fontSize: 16, color: textPrimaryColor, height: 1.5),
    h1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimaryColor),
    h2: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimaryColor),
    h3: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimaryColor),
    h4: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimaryColor),
    h5: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimaryColor),
    h6: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimaryColor),
    em: TextStyle(fontStyle: FontStyle.italic, color: textPrimaryColor),
    strong: TextStyle(fontWeight: FontWeight.bold, color: textPrimaryColor),
    del: TextStyle(decoration: TextDecoration.lineThrough, color: textSecondaryColor),
    blockquote: TextStyle(fontSize: 16, color: textSecondaryColor, fontStyle: FontStyle.italic),
    img: const TextStyle(),
    checkbox: TextStyle(color: AppColors.primary),
    listBullet: TextStyle(fontSize: 16, color: textPrimaryColor),
    tableHead: TextStyle(fontWeight: FontWeight.bold, color: textPrimaryColor),
    tableBody: TextStyle(color: textPrimaryColor),
    code: TextStyle(
      fontSize: 14,
      color: AppColors.primary,
      backgroundColor: backgroundColor,
      fontFamily: 'monospace',
    ),
    codeblockDecoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
    ),
    blockquoteDecoration: BoxDecoration(
      color: surfaceColor,
      border: const Border(
        left: BorderSide(color: AppColors.primary, width: 4),
      ),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.dividerColor, width: 1)),
    ),
    a: const TextStyle(color: AppColors.primary, decoration: TextDecoration.none),
  );
}

// 1. Custom tag
const _latexTag = 'latex';

// 2. Custom SpanNode generator
SpanNodeGeneratorWithTag latexGenerator = SpanNodeGeneratorWithTag(
  tag: _latexTag,
  generator: (e, config, visitor) =>
      LatexNode(e.attributes, e.textContent, config),
);

// 3. Custom SpanNode
class LatexNode extends SpanNode {
  final Map<String, String> attributes;
  final String textContent;
  final MarkdownConfig config;

  LatexNode(this.attributes, this.textContent, this.config);

  @override
  InlineSpan build() {
    final content = attributes['content'] ?? '';
    final isInline = attributes['isInline'] == 'true';
    final style = parentStyle ?? config.p.textStyle;

    if (content.isEmpty) return TextSpan(style: style, text: textContent);

    final latex = Math.tex(
      content,
      mathStyle: MathStyle.text,
      textStyle: style,
      textScaleFactor: 1,
      onErrorFallback: (error) {
        return Text(
          textContent,
          style: style.copyWith(color: Colors.red),
        );
      },
    );

    return WidgetSpan(
      child: !isInline
          ? Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: latex),
            )
          : latex,
    );
  }
}

// 4. Custom Syntax
class LatexSyntax extends m.InlineSyntax {
  LatexSyntax() : super(r'(\$\$[\s\S]+?\$\$)|(\$[^\$\n]+?\$)');

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final input = match.input;
    final matchValue = input.substring(match.start, match.end);
    String content = '';
    bool isInline = true;
    const blockSyntax = '\$\$';
    const inlineSyntax = '\$';

    if (matchValue.startsWith(blockSyntax) &&
        matchValue.endsWith(blockSyntax) &&
        (matchValue != blockSyntax)) {
      content = matchValue.substring(2, matchValue.length - 2);
      isInline = false;
    } else if (matchValue.startsWith(inlineSyntax) &&
        matchValue.endsWith(inlineSyntax) &&
        matchValue != inlineSyntax) {
      content = matchValue.substring(1, matchValue.length - 1);
    }

    m.Element el = m.Element.text(_latexTag, matchValue);
    el.attributes['content'] = content;
    el.attributes['isInline'] = '$isInline';
    parser.addNode(el);
    return true;
  }
}

/// 自定义图片节点生成器 - 支持缓存和点击放大
class CachedImageNode extends SpanNode {
  final String url;
  final String alt;
  final MarkdownConfig config;

  CachedImageNode(this.url, this.alt, this.config);

  @override
  InlineSpan build() {
    return WidgetSpan(
      child: _CachedMarkdownImage(url: url, alt: alt),
    );
  }
}

/// 将缩略图 URL 转换为原图 URL
/// 服务端存储了两个版本：resized（200x200缩略图）和 uploads（原图）
String _getOriginalImageUrl(String url) {
  return url.replaceAll('/resized/', '/uploads/');
}

/// 缓存的 Markdown 图片组件
class _CachedMarkdownImage extends StatefulWidget {
  final String url;
  final String alt;

  const _CachedMarkdownImage({required this.url, required this.alt});

  @override
  State<_CachedMarkdownImage> createState() => _CachedMarkdownImageState();
}

class _CachedMarkdownImageState extends State<_CachedMarkdownImage>
    with SingleTickerProviderStateMixin {
  final MediaCacheService _cacheService = MediaCacheService();
  File? _cachedFile;
  bool _isLoading = true;
  bool _hasError = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  /// 获取原图 URL
  String get _originalUrl => _getOriginalImageUrl(widget.url);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _loadImage();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    if (widget.url.isEmpty) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    try {
      // 使用原图 URL 下载
      final file = await _cacheService.getOrDownload(
        _originalUrl,
        category: CacheCategory.post,
      );
      if (mounted) {
        setState(() {
          _cachedFile = file;
          _isLoading = false;
          _hasError = file == null;
        });
        if (file != null) {
          _fadeController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: context.backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    if (_hasError || _cachedFile == null) {
      return Container(
        height: 120,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: context.backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: context.textTertiaryColor, size: 32),
              const SizedBox(height: 8),
              Text(
                '图片加载失败',
                style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => ImageViewer.show(context, _originalUrl, cachedFile: _cachedFile),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Image.file(
              _cachedFile!,
              fit: BoxFit.fitWidth, // 保持宽度适配，不压缩高度
              width: double.infinity,
              filterQuality: FilterQuality.high, // 高质量渲染
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: context.backgroundColor,
                child: Center(
                  child: Icon(Icons.broken_image_outlined, color: context.textTertiaryColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 自定义图片节点生成器
SpanNodeGeneratorWithTag cachedImageGenerator = SpanNodeGeneratorWithTag(
  tag: 'img',
  generator: (e, config, visitor) {
    final url = e.attributes['src'] ?? '';
    final alt = e.attributes['alt'] ?? '';
    return CachedImageNode(url, alt, config);
  },
);

/// 支持 LaTeX 渲染的 Markdown 组件
class LatexMarkdown extends StatelessWidget {
  final String data;
  final bool selectable;
  final MarkdownStyleSheet? styleSheet;
  final bool enableImageCache;

  const LatexMarkdown({
    super.key,
    required this.data,
    this.selectable = false,
    this.styleSheet,
    this.enableImageCache = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final config = isDark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;

    final textPrimaryColor = context.textPrimaryColor;
    final textSecondaryColor = context.textSecondaryColor;
    final backgroundColor = context.backgroundColor;

    final generators = <SpanNodeGeneratorWithTag>[latexGenerator];
    if (enableImageCache) {
      generators.add(cachedImageGenerator);
    }

    return MarkdownBlock(
      data: data,
      selectable: selectable,
      config: config.copy(configs: [
        PConfig(textStyle: TextStyle(
          fontSize: 16,
          color: textPrimaryColor,
          height: 1.5,
        )),
        H1Config(style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        )),
        H2Config(style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        )),
        H3Config(style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        )),
        CodeConfig(style: TextStyle(
          fontSize: 14,
          color: AppColors.primary,
          backgroundColor: backgroundColor,
        )),
        PreConfig(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        BlockquoteConfig(
          sideColor: AppColors.primary,
          textColor: textSecondaryColor,
        ),
        const LinkConfig(style: TextStyle(
          color: AppColors.primary,
          decoration: TextDecoration.none,
        )),
      ]),
      generator: MarkdownGenerator(
        generators: generators,
        inlineSyntaxList: [LatexSyntax()],
      ),
    );
  }
}
