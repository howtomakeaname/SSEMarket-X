import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PrivacyPolicyModal extends StatefulWidget {
  final VoidCallback? onAccept;
  final VoidCallback? onReject; // In Flutter modal, usually we just close it or pop.

  const PrivacyPolicyModal({
    super.key,
    this.onAccept,
    this.onReject,
  });

  static void show(BuildContext context, {VoidCallback? onAccept}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PrivacyPolicyModal(
        onAccept: onAccept,
      ),
    );
  }

  @override
  State<PrivacyPolicyModal> createState() => _PrivacyPolicyModalState();
}

class _PrivacyPolicyModalState extends State<PrivacyPolicyModal> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isWebviewSupported = true;
  static const String _url =
      'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1803216654725832128';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    try {
      // 简单的平台检测，实际 webview_flutter 内部会处理
      // 如果在不支持的平台上运行（如 macOS 桌面版且未配置），可能会抛出异常
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(_url));
    } catch (e) {
      debugPrint('WebView initialization failed: $e');
      if (mounted) {
        setState(() {
          _isWebviewSupported = false;
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(_url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        SnackBarHelper.show(context, '无法打开链接');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 拖动条
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: context.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Text(
                  '隐私政策',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '请仔细阅读并同意我们的隐私政策',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.dividerColor),
          // WebView
          Expanded(
            child: Stack(
              children: [
                if (_hasError || !_isWebviewSupported)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: context.textSecondaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '无法加载内容',
                          style: TextStyle(color: context.textSecondaryColor),
                        ),
                        const SizedBox(height: 8),
                        if (_isWebviewSupported)
                          ElevatedButton(
                            onPressed: () {
                              _controller?.reload();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('重试'),
                          ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _openInBrowser,
                          child: const Text('在浏览器中打开'),
                        ),
                      ],
                    ),
                  )
                else if (_controller != null)
                  WebViewWidget(controller: _controller!),
                if (_isLoading && !_hasError && _isWebviewSupported)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
          // 底部按钮
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(top: BorderSide(color: context.dividerColor)),
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (widget.onAccept != null) {
                    widget.onAccept!();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  '同意并继续',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
