import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart' as native;

import '../../core/config/app_native_glass.dart';

class NativeGlassScope extends InheritedWidget {
  final bool suspended;

  const NativeGlassScope({
    super.key,
    required this.suspended,
    required super.child,
  });

  static bool isSuspended(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NativeGlassScope>()
          ?.suspended ??
      false;

  @override
  bool updateShouldNotify(NativeGlassScope oldWidget) =>
      suspended != oldWidget.suspended;
}

class NativeGlassBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool useNative) builder;

  const NativeGlassBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppNativeGlass.changes,
        NativeGlassOverlays.count,
        if (route?.animation != null) route!.animation!,
        if (route?.secondaryAnimation != null) route!.secondaryAnimation!,
      ]),
      builder: (context, _) {
        final settled =
            (route?.isCurrent ?? true) &&
            (route?.animation == null || route!.animation!.isCompleted) &&
            (route?.secondaryAnimation?.value ?? 0) == 0;
        return builder(
          context,
          AppNativeGlass.enabled &&
              settled &&
              NativeGlassOverlays.count.value == 0 &&
              !MediaQuery.highContrastOf(context) &&
              !MediaQuery.disableAnimationsOf(context) &&
              !NativeGlassScope.isSuspended(context),
        );
      },
    );
  }
}

class NativeGlassSurface extends StatelessWidget {
  final bool enabled;
  final BorderRadius borderRadius;
  final Color? tint;
  final Widget fallback;
  final Widget child;

  const NativeGlassSurface({
    super.key,
    this.enabled = true,
    required this.borderRadius,
    this.tint,
    required this.fallback,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: NativeGlassBuilder(
              builder: (context, useNative) => enabled && useNative
                  ? native.LiquidGlassContainer(
                      config: native.LiquidGlassConfig(
                        shape: native.LiquidGlassEffectShape.rect,
                        cornerRadius: borderRadius.topLeft.x,
                        tint: tint,
                      ),
                      child: const SizedBox.expand(),
                    )
                  : fallback,
            ),
          ),
        ),
      ),
      ClipRRect(borderRadius: borderRadius, child: child),
    ],
  );
}

class NativeGlassTheme extends StatefulWidget {
  final Widget child;
  final bool followSystem;
  const NativeGlassTheme({
    super.key,
    required this.child,
    required this.followSystem,
  });

  @override
  State<NativeGlassTheme> createState() => _NativeGlassThemeState();
}

class _NativeGlassThemeState extends State<NativeGlassTheme> {
  static const _channel = MethodChannel('komet/native_glass');
  String? _appearance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTheme();
  }

  @override
  void didUpdateWidget(NativeGlassTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTheme();
  }

  void _syncTheme() {
    final appearance = widget.followSystem
        ? 'system'
        : Theme.of(context).brightness.name;
    if (!AppNativeGlass.supported || appearance == _appearance) return;
    _appearance = appearance;
    _syncBrightness(appearance);
  }

  Future<void> _syncBrightness(String appearance) async {
    try {
      await _channel.invokeMethod<void>('setBrightness', appearance);
    } on PlatformException catch (error) {
      debugPrint('Native glass appearance: ${error.code}');
    } on MissingPluginException {
      debugPrint('Native glass appearance channel unavailable');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class NativeGlassOverlays {
  static final count = ValueNotifier<int>(0);

  static VoidCallback suspend() {
    count.value++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      count.value--;
    };
  }
}

class NativeGlassOverlay extends StatefulWidget {
  final VoidCallback release;
  final Widget child;

  const NativeGlassOverlay({
    super.key,
    required this.release,
    required this.child,
  });

  @override
  State<NativeGlassOverlay> createState() => _NativeGlassOverlayState();
}

class _NativeGlassOverlayState extends State<NativeGlassOverlay> {
  @override
  void dispose() {
    scheduleMicrotask(widget.release);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
