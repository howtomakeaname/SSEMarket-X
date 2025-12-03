import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class AuthDesktopLayout extends StatefulWidget {
  final Widget child;
  final bool enableScroll;

  const AuthDesktopLayout({
    super.key,
    required this.child,
    this.enableScroll = true,
  });

  @override
  State<AuthDesktopLayout> createState() => _AuthDesktopLayoutState();
}

class _AuthDesktopLayoutState extends State<AuthDesktopLayout>
    with TickerProviderStateMixin {
  late final AnimationController _controller1;
  late final AnimationController _controller2;
  late final AnimationController _controller3;
  late final AnimationController _controller4;

  @override
  void initState() {
    super.initState();
    // Different durations for each circle to create organic movement
    _controller1 = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _controller2 = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);

    _controller3 = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);

    _controller4 = AnimationController(
      duration: const Duration(seconds: 4, milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    _controller4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left Branding Side
        Expanded(
          child: Container(
            color: context.backgroundColor,
            child: Stack(
              children: [
                // Top-left decorative circle
                AnimatedBuilder(
                  animation: _controller1,
                  builder: (context, child) {
                    final value = _controller1.value;
                    return Positioned(
                      top: -60 + (math.sin(value * math.pi) * 8),
                      left: -40 + (math.cos(value * math.pi) * 6),
                      child: child!,
                    );
                  },
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.05),
                    ),
                  ),
                ),
                // Top-right decorative circle
                AnimatedBuilder(
                  animation: _controller2,
                  builder: (context, child) {
                    final value = _controller2.value;
                    return Positioned(
                      top: 60 + (math.cos(value * math.pi) * 10),
                      right: -80 + (math.sin(value * math.pi) * 8),
                      child: child!,
                    );
                  },
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.04),
                    ),
                  ),
                ),
                // Bottom-left decorative circle
                AnimatedBuilder(
                  animation: _controller3,
                  builder: (context, child) {
                    final value = _controller3.value;
                    return Positioned(
                      bottom: -80 + (math.sin(value * math.pi) * 12),
                      left: 40 + (math.cos(value * math.pi) * 8),
                      child: child!,
                    );
                  },
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.04),
                    ),
                  ),
                ),
                // Bottom-right decorative circle
                AnimatedBuilder(
                  animation: _controller4,
                  builder: (context, child) {
                    final value = _controller4.value;
                    return Positioned(
                      bottom: -40 + (math.cos(value * math.pi) * 6),
                      right: -60 + (math.sin(value * math.pi) * 10),
                      child: child!,
                    );
                  },
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.06),
                    ),
                  ),
                ),
                // Main content
                Center(
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      // Calculate responsive sizes based on available width
                      final width = constraints.maxWidth;
                      final logoSize = (width * 0.22).clamp(110.0, 180.0);
                      final titleSize = (width * 0.06).clamp(30.0, 44.0);
                      final subtitleSize = (width * 0.03).clamp(17.0, 22.0);
                      
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          Image.asset(
                            'assets/images/logo.png',
                            width: logoSize,
                            height: logoSize,
                          ),
                          SizedBox(height: (width * 0.04).clamp(20.0, 40.0)),
                          // App Name
                          Text(
                            'SSE Market',
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Tagline
                          Text(
                            '软工集市',
                            style: TextStyle(
                              fontSize: subtitleSize,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right Form Side
        Expanded(
          child: Container(
            color: context.surfaceColor,
            child: widget.enableScroll
                ? Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 480),
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            widget.child,
                          ],
                        ),
                      ),
                    ),
                  )
                : widget.child,
          ),
        ),
      ],
    );
  }
}
