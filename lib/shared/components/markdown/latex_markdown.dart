import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';
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

/// 支持 LaTeX 渲染的 Markdown 组件
class LatexMarkdown extends StatelessWidget {
  final String data;
  final bool selectable;
  final MarkdownStyleSheet? styleSheet;

  const LatexMarkdown({
    super.key,
    required this.data,
    this.selectable = false,
    this.styleSheet,
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
          color: Colors.red,
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
        generators: [latexGenerator],
        inlineSyntaxList: [LatexSyntax()],
      ),
    );
  }
}
