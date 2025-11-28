import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/components/overlays/custom_toast.dart';

class SnackBarHelper {
  static void show(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    CustomToast.show(
      context, 
      message, 
      duration: duration ?? const Duration(seconds: 2),
    );
  }
}
