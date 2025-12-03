import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sse_market_x/shared/components/markdown/latex_markdown.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class TermsOfServicePage extends StatefulWidget {
  const TermsOfServicePage({super.key});

  @override
  State<TermsOfServicePage> createState() => _TermsOfServicePageState();
}

class _TermsOfServicePageState extends State<TermsOfServicePage> {
  String _content = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final content = await rootBundle.loadString('assets/legal/terms_of_service.md');
      if (mounted) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _content = '# 加载失败\n\n请稍后重试';
          _isLoading = false;
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
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '服务协议',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
      ),
      body: _isLoading
          ? const LoadingIndicator.center()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LatexMarkdown(data: _content),
              ),
            ),
    );
  }
}
