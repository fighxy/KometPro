import 'package:flutter/material.dart';
import 'package:komet/core/config/app_frost.dart';
import 'package:komet/frontend/widgets/liquid_glass.dart';

class FrostedPanel extends StatelessWidget {
  final Color tint;
  final Border? border;
  final double sigma;
  final BackdropKey? backdropKey;
  final Widget child;

  FrostedPanel({
    required this.tint,
    this.border,
    double? sigma,
    this.backdropKey,
    required this.child,
  }) : sigma = sigma ?? AppFrost.panelSigma;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GlassSurface(
            frostTint: tint,
            frostSigma: sigma,
            border: border,
            backdropKey: backdropKey,
            child: const SizedBox.expand(),
          ),
        ),
        child,
      ],
    );
  }
}

class MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<double> onHeight;

  const MeasureSize({required this.onHeight, required this.child});

  @override
  State<MeasureSize> createState() => MeasureSizeState();
}

class MeasureSizeState extends State<MeasureSize> {
  final GlobalKey _key = GlobalKey();
  double _last = -1;

  void _report() {
    if (!mounted) return;
    final height = _key.currentContext?.size?.height;
    if (height == null) return;
    if ((height - _last).abs() > 0.5) {
      _last = height;
      widget.onHeight(height);
    }
  }

  void _scheduleReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  Widget build(BuildContext context) {
    _scheduleReport();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _scheduleReport();
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: SizedBox(key: _key, child: widget.child),
      ),
    );
  }
}

