import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart' hide ImageViewer, MarkdownWidget;
import 'package:markdown_widget/markdown_widget.dart' as mw show MarkdownWidget;
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/image_viewer.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';

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

/// 图片上下文 - 用于在多图场景下共享所有图片 URL
class MarkdownImageContext extends InheritedWidget {
  final List<String> imageUrls;

  const MarkdownImageContext({
    super.key,
    required this.imageUrls,
    required super.child,
  });

  static MarkdownImageContext? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MarkdownImageContext>();
  }

  @override
  bool updateShouldNotify(MarkdownImageContext oldWidget) {
    return imageUrls != oldWidget.imageUrls;
  }
}

/// 从 Markdown 文本中提取所有图片 URL
/// 同时支持 Markdown 格式和 HTML img 标签
List<String> _extractImageUrls(String markdown) {
  final urls = <String>[];
  
  // 先将 HTML img 标签转换为 Markdown 格式
  final processedMarkdown = _convertHtmlImagesToMarkdown(markdown);
  
  // 匹配 Markdown 图片语法
  final imagePattern = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
  
  for (final match in imagePattern.allMatches(processedMarkdown)) {
    var urlPart = match.group(2) ?? '';
    // 处理带 title 的情况
    final titleMatch = RegExp(r'^(.+?)\s+"([^"]*)"$').firstMatch(urlPart);
    String url;
    if (titleMatch != null) {
      url = titleMatch.group(1)!.trim();
    } else {
      url = urlPart.trim();
    }
    // 转换为原图 URL
    final originalUrl = _encodeImageUrl(_getOriginalImageUrl(url));
    if (originalUrl.isNotEmpty) {
      urls.add(originalUrl);
    }
  }
  
  return urls;
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

/// 对图片 URL 进行编码处理
/// 处理 URL 中的中文、空格等特殊字符
String _encodeImageUrl(String url) {
  if (url.isEmpty) return url;

  // 使用正则匹配 URL 结构
  final urlPattern = RegExp(r'^(https?://[^/]+)(/.*)$');
  final match = urlPattern.firstMatch(url);

  if (match != null) {
    final baseUrl = match.group(1)!; // http://host:port
    final pathAndQuery = match.group(2)!; // /path?query

    // 分离路径和查询参数
    final queryIndex = pathAndQuery.indexOf('?');
    String path;
    String query = '';

    if (queryIndex != -1) {
      path = pathAndQuery.substring(0, queryIndex);
      query = pathAndQuery.substring(queryIndex);
    } else {
      path = pathAndQuery;
    }

    // 对路径中的每个段进行编码
    final encodedPath = path
        .split('/')
        .map((segment) {
          if (segment.isEmpty) return segment;
          // 先解码（处理已编码的情况），再重新编码
          try {
            final decoded = Uri.decodeComponent(segment);
            return Uri.encodeComponent(decoded);
          } catch (e) {
            // 如果解码失败，直接编码
            return Uri.encodeComponent(segment);
          }
        })
        .join('/');

    return '$baseUrl$encodedPath$query';
  }

  // 如果不匹配标准 URL 格式，尝试直接编码
  return Uri.encodeFull(url);
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

  /// 获取编码后的原图 URL
  String get _originalUrl => _encodeImageUrl(_getOriginalImageUrl(widget.url));

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

  /// 打开图片查看器
  void _openImageViewer(BuildContext context) {
    final imageContext = MarkdownImageContext.of(context);
    if (imageContext != null && imageContext.imageUrls.length > 1) {
      final index = imageContext.imageUrls.indexOf(_originalUrl);
      ImageViewer.showMultiple(
        context,
        imageContext.imageUrls,
        initialIndex: index >= 0 ? index : 0,
        cachedFiles: _cachedFile != null ? {_originalUrl: _cachedFile!} : null,
      );
    } else {
      ImageViewer.show(context, _originalUrl, cachedFile: _cachedFile);
    }
  }

  /// 显示图片操作菜单
  void _showImageMenu(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    if (isWideScreen) {
      // 宽屏设备使用弹窗
      _showImageDialog(context);
    } else {
      // 窄屏设备使用底部菜单
      _showImageBottomSheet(context);
    }
  }

  /// 宽屏设备的图片操作弹窗
  void _showImageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            decoration: BoxDecoration(
              color: context.surfaceColor,
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
                // 标题
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Text(
                    '图片操作',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(height: 0.5, color: context.dividerColor),
                // 查看原图
                _buildDialogButton(
                  context: context,
                  text: '查看原图',
                  onTap: () {
                    Navigator.pop(ctx);
                    _openImageViewer(context);
                  },
                ),
                Container(height: 0.5, color: context.dividerColor),
                // 复制图片链接
                _buildDialogButton(
                  context: context,
                  text: '复制图片链接',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _originalUrl));
                    Navigator.pop(ctx);
                    SnackBarHelper.show(context, '已复制图片链接');
                  },
                ),
                Container(height: 0.5, color: context.dividerColor),
                // 取消按钮
                _buildDialogButton(
                  context: context,
                  text: '取消',
                  isCancel: true,
                  isLast: true,
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 窄屏设备的底部菜单
  void _showImageBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动指示器
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: context.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 查看原图
            _buildSheetTile(
              context: context,
              icon: Icons.zoom_in,
              title: '查看原图',
              onTap: () {
                Navigator.pop(ctx);
                _openImageViewer(context);
              },
            ),
            // 复制图片链接
            _buildSheetTile(
              context: context,
              icon: Icons.link,
              title: '复制图片链接',
              onTap: () {
                Clipboard.setData(ClipboardData(text: _originalUrl));
                Navigator.pop(ctx);
                SnackBarHelper.show(context, '已复制图片链接');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 构建弹窗按钮（参考 CustomDialog 样式）
  Widget _buildDialogButton({
    required BuildContext context,
    required String text,
    required VoidCallback onTap,
    bool isCancel = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : null,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isCancel ? context.textSecondaryColor : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建底部菜单项
  Widget _buildSheetTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: context.textPrimaryColor),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(fontSize: 16, color: context.textPrimaryColor),
              ),
            ],
          ),
        ),
      ),
    );
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
      onTap: () => _openImageViewer(context),
      onLongPress: () => _showImageMenu(context),
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

/// 将 HTML img 标签转换为 Markdown 格式
/// 支持多种属性顺序：src/alt、alt/src、仅 src
String _convertHtmlImagesToMarkdown(String content) {
  // 使用单一正则匹配所有 img 标签，然后解析属性
  final imgTagPattern = RegExp(
    r'<img\s+([^>]*)/?>', 
    caseSensitive: false,
  );
  
  return content.replaceAllMapped(imgTagPattern, (match) {
    final attributes = match.group(1) ?? '';
    
    // 提取 src 属性
    final srcMatch = RegExp(r'''src=["']([^"'>]+)["']''').firstMatch(attributes);
    final src = srcMatch?.group(1) ?? '';
    
    if (src.isEmpty) return match.group(0) ?? '';
    
    // 提取 alt 属性
    final altMatch = RegExp(r'''alt=["']([^"'>]*)["']''').firstMatch(attributes);
    final alt = altMatch?.group(1) ?? '';
    
    return '![$alt]($src)';
  });
}

/// 将 HTML audio/video 标签转换为 Markdown 链接格式
/// 点击后使用系统播放器打开
/// 支持格式：
/// - <audio src="url"></audio>
/// - <audio controls><source src="url" type="audio/mpeg"></audio>
/// - <video src="url"></video>
/// - <video controls><source src="url"></video>
String _convertHtmlMediaToMarkdown(String content) {
  // 先处理带 source 子标签的 audio（优先级更高）
  // 格式: <audio controls><source src="url" type="..."></audio>
  final audioSourcePattern = RegExp(
    r'''<audio[^>]*>[\s\S]*?<source\s+[^>]*src=["']([^"']+)["'][^>]*/?>[\s\S]*?</audio>''',
    caseSensitive: false,
  );
  content = content.replaceAllMapped(audioSourcePattern, (match) {
    final src = match.group(1) ?? '';
    if (src.isEmpty) return match.group(0) ?? '';
    return '[🎵 音频播放]($src)';
  });

  // 处理带 source 子标签的 video
  // 格式: <video controls><source src="url"></video>
  final videoSourcePattern = RegExp(
    r'''<video[^>]*>[\s\S]*?<source\s+[^>]*src=["']([^"']+)["'][^>]*/?>[\s\S]*?</video>''',
    caseSensitive: false,
  );
  content = content.replaceAllMapped(videoSourcePattern, (match) {
    final src = match.group(1) ?? '';
    if (src.isEmpty) return match.group(0) ?? '';
    return '[🎬 视频播放]($src)';
  });

  // 处理直接带 src 属性的 audio
  // 格式: <audio src="url"></audio> 或 <audio src="url" />
  final audioDirectPattern = RegExp(
    r'''<audio\s+[^>]*src=["']([^"']+)["'][^>]*(?:>[\s\S]*?</audio>|/>)''',
    caseSensitive: false,
  );
  content = content.replaceAllMapped(audioDirectPattern, (match) {
    final src = match.group(1) ?? '';
    if (src.isEmpty) return match.group(0) ?? '';
    return '[🎵 音频播放]($src)';
  });

  // 处理直接带 src 属性的 video
  // 格式: <video src="url"></video> 或 <video src="url" />
  final videoDirectPattern = RegExp(
    r'''<video\s+[^>]*src=["']([^"']+)["'][^>]*(?:>[\s\S]*?</video>|/>)''',
    caseSensitive: false,
  );
  content = content.replaceAllMapped(videoDirectPattern, (match) {
    final src = match.group(1) ?? '';
    if (src.isEmpty) return match.group(0) ?? '';
    return '[🎬 视频播放]($src)';
  });

  return content;
}

/// 预处理 Markdown 文本，转换 HTML 标签并对图片 URL 进行编码
String _preprocessMarkdownImageUrls(String markdown) {
  // 第一步：将 HTML img 标签转换为 Markdown 格式
  String processedMarkdown = _convertHtmlImagesToMarkdown(markdown);
  
  // 第二步：将 HTML audio/video 标签转换为 Markdown 链接
  processedMarkdown = _convertHtmlMediaToMarkdown(processedMarkdown);
  
  // 第三步：匹配 Markdown 图片语法: ![alt](url)
  final imagePattern = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');

  return processedMarkdown.replaceAllMapped(imagePattern, (match) {
    final alt = match.group(1) ?? '';
    var urlPart = match.group(2) ?? '';

    // 检查是否有 title（以空格+"开头）
    String title = '';
    final titleMatch = RegExp(r'^(.+?)\s+"([^"]*)"$').firstMatch(urlPart);
    String url;
    if (titleMatch != null) {
      url = titleMatch.group(1)!.trim();
      title = ' "${titleMatch.group(2)}"';
    } else {
      url = urlPart.trim();
    }

    // 对 URL 进行编码
    final encodedUrl = _encodeImageUrl(url);

    return '![$alt]($encodedUrl$title)';
  });
}

/// 支持 LaTeX 渲染的 Markdown 组件
class LatexMarkdown extends StatelessWidget {
  final String data;
  final bool selectable;
  final MarkdownStyleSheet? styleSheet;
  final bool enableImageCache;
  final double fontSize; // 基础字体大小
  final bool shrinkWrap; // 紧凑模式，用于评论等场景

  const LatexMarkdown({
    super.key,
    required this.data,
    this.selectable = false,
    this.styleSheet,
    this.enableImageCache = true,
    this.fontSize = 16, // 默认 16px
    this.shrinkWrap = false, // 默认非紧凑模式
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

    // 预处理 Markdown 文本，对图片 URL 进行编码
    final processedData = _preprocessMarkdownImageUrls(data);

    final markdownConfig = config.copy(configs: [
      PConfig(textStyle: TextStyle(
        fontSize: fontSize,
        color: textPrimaryColor,
        height: 1.5,
      )),
      H1Config(style: TextStyle(
        fontSize: fontSize + 8,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
      )),
      H2Config(style: TextStyle(
        fontSize: fontSize + 4,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
      )),
      H3Config(style: TextStyle(
        fontSize: fontSize + 2,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
      )),
      CodeConfig(style: TextStyle(
        fontSize: fontSize - 2,
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
    ]);

    final generator = MarkdownGenerator(
      generators: generators,
      inlineSyntaxList: [LatexSyntax()],
      richTextBuilder: shrinkWrap ? (span) => Text.rich(span) : null,
      linesMargin: shrinkWrap ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 8),
    );

    // 提取所有图片 URL，用于多图浏览
    final imageUrls = _extractImageUrls(data);

    // 紧凑模式：使用 markdown_widget 的 MarkdownWidget 的 shrinkWrap 模式
    if (shrinkWrap) {
      return MarkdownImageContext(
        imageUrls: imageUrls,
        child: mw.MarkdownWidget(
          data: processedData,
          selectable: selectable,
          shrinkWrap: true,
          config: markdownConfig,
          markdownGenerator: generator,
        ),
      );
    }

    return MarkdownImageContext(
      imageUrls: imageUrls,
      child: MarkdownBlock(
        data: processedData,
        selectable: selectable,
        config: markdownConfig,
        generator: generator,
      ),
    );
  }
}

/// 帖子链接正则匹配模式
/// 支持 https://ssemarket.cn/new/postdetail/123 格式
final _postLinkPattern = RegExp(
  r'https?://ssemarket\.cn/new/postdetail/(\d+)',
  caseSensitive: false,
);

/// 从文本中提取所有帖子链接的 postId
List<int> extractPostIds(String content) {
  final ids = <int>[];
  for (final match in _postLinkPattern.allMatches(content)) {
    final idStr = match.group(1);
    if (idStr != null) {
      final id = int.tryParse(idStr);
      if (id != null && !ids.contains(id)) {
        ids.add(id);
      }
    }
  }
  return ids;
}

/// 帖子链接内联组件
/// 显示为可点击的帖子标题，点击后跳转到帖子详情
class _PostLinkInline extends StatefulWidget {
  final int postId;
  final ApiService apiService;

  const _PostLinkInline({
    required this.postId,
    required this.apiService,
  });

  @override
  State<_PostLinkInline> createState() => _PostLinkInlineState();
}

class _PostLinkInlineState extends State<_PostLinkInline> {
  String? _title;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadPostTitle();
  }

  Future<void> _loadPostTitle() async {
    try {
      final user = await widget.apiService.getUserInfo();
      final post = await widget.apiService.getPostDetail(widget.postId, user.phone);

      if (mounted) {
        setState(() {
          _title = post.id != 0 ? post.title : null;
          _isLoading = false;
          _hasError = post.id == 0;
        });
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

  void _navigateToPost() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          postId: widget.postId,
          apiService: widget.apiService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: context.textSecondaryColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '加载中...',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError || _title == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link_off,
              size: 14,
              color: context.textTertiaryColor,
            ),
            const SizedBox(width: 4),
            Text(
              '帖子不存在',
              style: TextStyle(
                fontSize: 14,
                color: context.textTertiaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _navigateToPost,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.article_outlined,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _title!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 带帖子链接预览的 Markdown 组件
/// 在普通 LatexMarkdown 基础上，自动解析帖子链接并替换为可点击的标题
class LatexMarkdownWithPostPreview extends StatelessWidget {
  final String data;
  final ApiService apiService;
  final bool selectable;
  final MarkdownStyleSheet? styleSheet;
  final bool enableImageCache;
  final double fontSize;
  final bool shrinkWrap;

  const LatexMarkdownWithPostPreview({
    super.key,
    required this.data,
    required this.apiService,
    this.selectable = false,
    this.styleSheet,
    this.enableImageCache = true,
    this.fontSize = 16,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    // 提取帖子链接
    final postIds = extractPostIds(data);

    // 如果没有帖子链接，直接返回普通 LatexMarkdown
    if (postIds.isEmpty) {
      return LatexMarkdown(
        data: data,
        selectable: selectable,
        styleSheet: styleSheet,
        enableImageCache: enableImageCache,
        fontSize: fontSize,
        shrinkWrap: shrinkWrap,
      );
    }

    // 将内容按帖子链接分割，交替渲染 Markdown 和帖子链接
    final widgets = <Widget>[];
    String remaining = data;

    for (final match in _postLinkPattern.allMatches(data)) {
      final beforeLink = data.substring(
        data.indexOf(remaining),
        match.start,
      );

      // 添加链接前的 Markdown 内容
      if (beforeLink.trim().isNotEmpty) {
        widgets.add(LatexMarkdown(
          data: beforeLink,
          selectable: selectable,
          styleSheet: styleSheet,
          enableImageCache: enableImageCache,
          fontSize: fontSize,
          shrinkWrap: true,
        ));
      }

      // 添加帖子链接组件
      final postIdStr = match.group(1);
      if (postIdStr != null) {
        final postId = int.tryParse(postIdStr);
        if (postId != null) {
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _PostLinkInline(
              postId: postId,
              apiService: apiService,
            ),
          ));
        }
      }

      remaining = data.substring(match.end);
    }

    // 添加最后剩余的内容
    if (remaining.trim().isNotEmpty) {
      widgets.add(LatexMarkdown(
        data: remaining,
        selectable: selectable,
        styleSheet: styleSheet,
        enableImageCache: enableImageCache,
        fontSize: fontSize,
        shrinkWrap: true,
      ));
    }

    if (shrinkWrap) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: widgets,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
