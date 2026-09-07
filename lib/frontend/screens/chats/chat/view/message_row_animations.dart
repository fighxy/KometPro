import 'package:flutter/material.dart';

class DeletingMessageAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback onComplete;

  const DeletingMessageAnimation({
    super.key,
    required this.child,
    required this.onComplete,
  });

  @override
  State<DeletingMessageAnimation> createState() =>
      DeletingMessageAnimationState();
}

class DeletingMessageAnimationState extends State<DeletingMessageAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<double> _collapse;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _opacity = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6)));
    _scale = Tween<double>(
      begin: 1,
      end: 0.82,
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6)));
    _collapse = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 1.0, curve: Curves.easeInOut),
      ),
    );
    _ctrl.forward().whenComplete(() {
      if (_fired) return;
      _fired = true;
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _collapse,
      alignment: AlignmentDirectional.centerStart,
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

class SentMessageAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback onComplete;

  const SentMessageAnimation({
    super.key,
    required this.child,
    required this.onComplete,
  });

  @override
  State<SentMessageAnimation> createState() => SentMessageAnimationState();
}

class SentMessageAnimationState extends State<SentMessageAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(
      begin: 16,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
