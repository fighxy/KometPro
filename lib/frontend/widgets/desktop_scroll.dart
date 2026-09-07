import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Scrollbar + mouse/trackpad drag on desktop only.
/// Mobile keeps the platform default (no persistent thumb).
class DesktopScroll extends StatelessWidget {
  const DesktopScroll({
    super.key,
    required this.child,
    this.controller,
  });

  final Widget child;
  final ScrollController? controller;

  static bool get isDesktop {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  static ScrollBehavior behaviorOf(BuildContext context) {
    return ScrollConfiguration.of(context).copyWith(
      dragDevices: {
        ...ScrollConfiguration.of(context).dragDevices,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      },
      scrollbars: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final configured = ScrollConfiguration(
      behavior: behaviorOf(context),
      child: child,
    );
    if (!isDesktop) return configured;
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      child: configured,
    );
  }
}
