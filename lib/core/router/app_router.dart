import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/views/auth/login_page.dart';
import 'package:sse_market_x/views/index_page.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: StorageService().userNotifier,
  redirect: (BuildContext context, GoRouterState state) {
    final bool isLoggedIn = StorageService().isLoggedIn;
    final bool isLoggingIn = state.matchedLocation == '/login';

    if (!isLoggedIn) {
      // Allow access to login page
      if (isLoggingIn) return null;
      
      // Redirect to login page for other routes, saving connection
      // We use uri.toString() to capture query params as well
      return '/login?redirect=${Uri.encodeComponent(state.uri.toString())}';
    }

    // If logged in and trying to access login, redirect to home or previous page
    if (isLoggingIn) {
      // Check if there is a redirect param
      final redirect = state.uri.queryParameters['redirect'];
      if(redirect != null && redirect.isNotEmpty) {
         return redirect;
      }
      return '/';
    }

    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginPage();
      },
    ),
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return IndexPage(apiService: ApiService());
      },
    ),
    GoRoute(
      path: '/new',
      redirect: (BuildContext context, GoRouterState state) => '/',
    ),
    GoRoute(
      path: '/new/postdetail/:id',
      redirect: (BuildContext context, GoRouterState state) {
        final id = state.pathParameters['id'];
        return id == null ? '/' : '/postdetail/$id';
      },
    ),
    GoRoute(
      path: '/postdetail/:id',
      builder: (BuildContext context, GoRouterState state) {
        final idStr = state.pathParameters['id'];
        final int? id = int.tryParse(idStr ?? '');
        if (id == null) {
          // Handle invalid ID, redirect to home
          return IndexPage(apiService: ApiService());
        }
        return PostDetailPage(
          postId: id,
          apiService: ApiService(),
        );
      },
    ),
  ],
);
