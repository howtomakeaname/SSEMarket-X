import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/utils/annual_report_config.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 年度报告 WebView 页面
/// 统一使用 webview_flutter；与 newSSE 一致：先注入 localStorage 并 reload 一次，reload 完成后再显示界面，避免用户看到刷新闪烁
class AnnualReportPage extends StatefulWidget {
  const AnnualReportPage({super.key});

  @override
  State<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends State<AnnualReportPage> {
  static const String _url = 'https://ssemarket.cn/new/annual2025';

  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  int _loadKey = 0;
  /// 有 refreshToken 时首次 onPageFinished 会注入并 reload，此期间保持 loading，reload 完成后再显示内容
  bool _waitingForReload = false;

  @override
  void initState() {
    super.initState();
    if (!AnnualReportConfig.isWithinAccessPeriod) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SnackBarHelper.show(context, '不在活动时间内');
        Navigator.of(context).pop();
      });
      return;
    }
    _initWebView();
  }

  void _initWebView() {
    final storage = StorageService();
    final token = storage.token;
    final refreshToken = storage.refreshToken;
    final refreshTokenExpiry = storage.refreshTokenExpiry;

    _waitingForReload = refreshToken.isNotEmpty && refreshTokenExpiry > 0;

    final uri = Uri.parse(_url).replace(
      queryParameters: token.isNotEmpty ? <String, String>{'token': token} : null,
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF030712))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() { _isLoading = true; _hasError = false; });
          },
          onPageFinished: (_) async {
            if (!mounted) return;

            final escaped = _escapeJsString(refreshToken);
            final script = '''
(function(){
  var rt='$escaped';
  var exp='$refreshTokenExpiry';
  if(!sessionStorage.getItem('_authInjected')&&rt&&exp){
    localStorage.setItem('rememberMe','true');
    localStorage.setItem('refreshToken',rt);
    localStorage.setItem('refreshTokenExpiry',exp);
    sessionStorage.setItem('_authInjected','1');
    location.reload();
    return;
  }
  document.documentElement.style.colorScheme='dark';
  var m=document.querySelector('meta[name=color-scheme]');
  if(!m){m=document.createElement('meta');m.name='color-scheme';document.head.appendChild(m);}
  m.content='dark';
})();
''';
            try {
              await _controller?.runJavaScript(script);
            } catch (_) {}

            if (!mounted) return;
            // 若有 refreshToken：首次 onPageFinished 会注入并 reload，此时不关 loading；reload 完成后的第二次 onPageFinished 再关 loading 显示内容
            if (_waitingForReload) {
              setState(() => _waitingForReload = false);
              // 保持 _isLoading = true，继续显示加载层直到 reload 完成
            } else {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (_) {
            if (mounted) setState(() { _hasError = true; _isLoading = false; });
          },
        ),
      )
      ..loadRequest(uri, headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      });
  }

  static String _escapeJsString(String s) {
    return s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n').replaceAll('\r', r'\r');
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _isLoading = true;
      _loadKey++;
    });
    _initWebView();
    if (mounted) setState(() {});
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(_url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) SnackBarHelper.show(context, '无法打开链接');
    }
  }

  @override
  Widget build(BuildContext context) {
    const reportBg = Color(0xFF030712);
    const reportAccentCyan = Color(0xFF0EA5E9);

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: reportBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: reportBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: reportBg,
        appBar: AppBar(
          backgroundColor: reportBg,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Platform.isIOS ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_rounded,
              color: reportAccentCyan,
              size: Platform.isIOS ? 22 : 24,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            '年度报告',
            style: TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              if (_hasError)
                _buildErrorState(reportBg, reportAccentCyan)
              else if (_controller != null)
                WebViewWidget(key: ValueKey<int>(_loadKey), controller: _controller!),
              if (_isLoading && !_hasError)
                Container(
                  color: reportBg,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(reportAccentCyan),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '加载年度报告中…',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Color reportBg, Color reportAccentCyan) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: reportAccentCyan.withOpacity(0.8)),
            const SizedBox(height: 16),
            const Text(
              '加载年度报告出错',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('重试'),
              style: FilledButton.styleFrom(
                backgroundColor: reportAccentCyan,
                foregroundColor: reportBg,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openInBrowser,
              icon: Icon(Icons.open_in_browser_rounded, size: 18, color: reportAccentCyan),
              label: Text('在浏览器中打开', style: TextStyle(color: reportAccentCyan, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
