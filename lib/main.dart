import 'package:flutter/material.dart';

import 'package:flutter_web_plugins/url_strategy.dart'; // Import for web URL strategy
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/core/services/blur_effect_service.dart';
import 'package:sse_market_x/core/services/desktop_layout_preference_service.dart';
import 'package:sse_market_x/core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // Use path URL strategy for web
  await StorageService().init();
  await MediaCacheService().init();
  await BlurEffectService().init();
  await DesktopLayoutPreferenceService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SSE Market',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // 跟随系统设置
      routerConfig: appRouter,
      builder: (context, child) {
        // 限制系统字体缩放范围，避免 UI 布局异常
        final mediaQuery = MediaQuery.of(context);
        final scale = mediaQuery.textScaler.scale(1.0).clamp(0.85, 1.15);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        );
      },
    );
  }
}

