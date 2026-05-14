import 'dart:io';
import 'package:flutter/material.dart';

/// Wrapper widget implementing "press back twice to exit" pattern.
///
/// First back press → shows snackbar warning
/// Second back press within [duration] → exits the app
class DoubleBackToExit extends StatefulWidget {
  final Widget child;
  final String message;
  final Duration duration;
  final Future<void> Function()? onExit;

  const DoubleBackToExit({
    super.key,
    required this.child,
    this.onExit,
    this.message = 'კიდევ ერთხელ დააჭირე გასვლისთვის',
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends State<DoubleBackToExit> {
  DateTime? _lastBackPress;

  bool _isReadyToExit() {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > widget.duration) {
      _lastBackPress = now;
      return false;
    }
    return true;
  }

  void _showSnackBar() {
    // Clear any existing snackbars to avoid stacking
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.message),
        duration: widget.duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_isReadyToExit()) {
          try {
            await widget.onExit?.call();
          } catch (_) {}
          exit(0);
        } else {
          _showSnackBar();
        }
      },
      child: widget.child,
    );
  }
}
