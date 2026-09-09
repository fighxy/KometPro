import 'package:flutter/material.dart';

import '../config/app_visual_style.dart';
import '../../frontend/widgets/glossy_pill.dart';
import 'komet_tokens.dart';

class KometSurface extends StatelessWidget {
  const KometSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VisualStyle>(
      valueListenable: AppVisualStyle.current,
      builder: (context, style, _) {
        final fill = color ?? KometTokens.of(context).raised;
        if (style.glossyChrome && !MediaQuery.highContrastOf(context)) {
          return GlossyPill(
            color: fill,
            borderRadius: KometTokens.cardRadius,
            padding: padding,
            depth: 2,
            child: child,
          );
        }
        return Material(
          color: fill,
          borderRadius: KometTokens.cardRadius,
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: padding, child: child),
        );
      },
    );
  }
}

class KometFocusRing extends StatefulWidget {
  const KometFocusRing({super.key, required this.child});

  final Widget child;

  @override
  State<KometFocusRing> createState() => _KometFocusRingState();
}

class _KometFocusRingState extends State<KometFocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onFocusChange: (value) => setState(() => _focused = value),
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: KometTokens.controlRadius,
        border: Border.all(
          color: _focused
              ? KometTokens.of(context).focused
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: widget.child,
    ),
  );
}
