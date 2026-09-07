import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/core/utils/haptics.dart';
import 'package:komet/frontend/widgets/directional_drag_recognizer.dart';

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final VoidCallback onReply;

  const SwipeToReply({
    required this.child,
    required this.isMe,
    required this.onReply,
  });

  @override
  State<SwipeToReply> createState() => SwipeToReplyState();
}

class SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _maxDrag = 72.0;
  static const double _triggerThreshold = 56.0;

  late final AnimationController _springBack;
  double _dragX = 0.0;
  double _springFrom = 0.0;
  bool _triggered = false;
  bool _edgeBlocked = false;

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _onDragStart(DragStartDetails d) {
    if (!_android) {
      _edgeBlocked = false;
      return;
    }
    final edge = MediaQuery.paddingOf(context).left + 28;
    _edgeBlocked = d.globalPosition.dx <= edge;
  }

  @override
  void initState() {
    super.initState();
    _springBack =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addListener(() {
          final t = Curves.easeOut.transform(_springBack.value);
          setState(() => _dragX = _springFrom * (1 - t));
        });
  }

  @override
  void dispose() {
    _springBack.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_edgeBlocked) return;
    if (_springBack.isAnimating) _springBack.stop();
    var next = _dragX + d.delta.dx;
    if (next > 0) next = 0;
    if (next < -_maxDrag) next = -_maxDrag;
    final wasTriggered = _triggered;
    _triggered = next <= -_triggerThreshold;
    if (_triggered && !wasTriggered) Haptics.medium();
    setState(() => _dragX = next);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_edgeBlocked) {
      _edgeBlocked = false;
      return;
    }
    if (_triggered) widget.onReply();
    _settle();
  }

  void _onDragCancel() => _settle();

  void _settle() {
    _triggered = false;
    _springFrom = _dragX;
    _springBack.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = (-_dragX / _triggerThreshold).clamp(0.0, 1.0);
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        LeftwardDragRecognizer:
            GestureRecognizerFactoryWithHandlers<LeftwardDragRecognizer>(
              () => LeftwardDragRecognizer(debugOwner: this),
              (instance) {
                instance
                  ..onStart = _onDragStart
                  ..onUpdate = _onDragUpdate
                  ..onEnd = _onDragEnd
                  ..onCancel = _onDragCancel;
              },
            ),
      },
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            right: 16,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.6 + 0.4 * progress,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Symbols.reply, size: 20, color: cs.primary),
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_dragX, 0), child: widget.child),
        ],
      ),
    );
  }
}
