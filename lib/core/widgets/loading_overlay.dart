import 'package:flutter/material.dart';

class LoadingOverlay {
  static bool _isVisible = false;

  static void show(BuildContext context) {
    if (_isVisible) return;
    _isVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: const CircularProgressIndicator(color: Colors.blueAccent),
          ),
        ),
      ),
    ).then((_) => _isVisible = false);
  }

  static void hide(BuildContext context) {
    if (_isVisible) {
      try {
        final navigator = Navigator.of(context, rootNavigator: true);
        if (navigator.canPop()) {
          navigator.pop();
        }
      } catch (e) {
        debugPrint("LoadingOverlay hide error: $e");
      }
      _isVisible = false;
    }
  }
}
