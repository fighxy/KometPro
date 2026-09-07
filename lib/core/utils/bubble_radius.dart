import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/app_bubble_behavior.dart';
import '../config/app_bubble_shape.dart';

/// Visual tokens for chat bubbles (padding, radii, voice chrome).
class BubbleCss {
  static const double padX = 14;
  static const double textPadY = 10;
  static const double textGroupedPadY = 6;
  static const double voicePadY = 4;
  static const double voicePadYLoose = 6;
  static const double controlPadY = 4;
  static const double voiceCompactWidth = 240;
  static const double playSize = 32;
  static const double playWaveGap = 10;
  static const double waveTranscribeGap = 8;
  static const double durationLift = 1;
  static const double transcriptGap = 6;

  static const EdgeInsets textPad = EdgeInsets.symmetric(
    horizontal: padX,
    vertical: textPadY,
  );
  static const EdgeInsets textGroupedPad = EdgeInsets.symmetric(
    horizontal: padX,
    vertical: textGroupedPadY,
  );
  static const EdgeInsets voicePad = EdgeInsets.symmetric(
    horizontal: padX,
    vertical: voicePadY,
  );
  static const EdgeInsets voiceLoosePad = EdgeInsets.symmetric(
    horizontal: padX,
    vertical: voicePadYLoose,
  );
  static const EdgeInsets controlPad = EdgeInsets.symmetric(
    horizontal: padX,
    vertical: controlPadY,
  );

  static final Listenable styleTick = Listenable.merge([
    AppBubbleShape.current,
    AppBubbleBehavior.current,
  ]);
}

const double kBubbleBigRadius = 24;
const double kBubbleSmallRadius = 4;

const Radius _big = Radius.circular(kBubbleBigRadius);
const Radius _small = Radius.circular(kBubbleSmallRadius);

final Map<int, BorderRadius> _radiusCache = {};

int _radiusKey({
  required bool isMe,
  required bool isTop,
  required bool isBottom,
  required BubbleStyle style,
  required BubbleBehavior behavior,
}) {
  return (isMe ? 1 : 0) |
      (isTop ? 2 : 0) |
      (isBottom ? 4 : 0) |
      (style == BubbleStyle.desktop ? 8 : 0) |
      (behavior == BubbleBehavior.immutable ? 16 : 0);
}

BorderRadius computeBubbleRadius({
  required bool isMe,
  required bool isTop,
  required bool isBottom,
  required BubbleStyle style,
  required BubbleBehavior behavior,
}) {
  final key = _radiusKey(
    isMe: isMe,
    isTop: isTop,
    isBottom: isBottom,
    style: style,
    behavior: behavior,
  );
  final cached = _radiusCache[key];
  if (cached != null) return cached;

  final outer = style == BubbleStyle.desktop ? _small : _big;
  final isSingle = isTop && isBottom;

  Radius tl = outer, tr = outer, bl = outer, br = outer;

  if (behavior != BubbleBehavior.immutable && !isSingle) {
    if (isMe) {
      if (isTop) {
        br = _small;
      } else if (isBottom) {
        tr = _small;
      } else {
        tr = _small;
        br = _small;
      }
    } else {
      if (isTop) {
        bl = _small;
      } else if (isBottom) {
        tl = _small;
      } else {
        tl = _small;
        bl = _small;
      }
    }
  }

  final radius = BorderRadius.only(
    topLeft: tl,
    topRight: tr,
    bottomLeft: bl,
    bottomRight: br,
  );
  _radiusCache[key] = radius;
  return radius;
}

BorderRadius albumClipRadius(
  BorderRadius bubble, {
  required bool hasCaption,
  required bool hasContentAbove,
}) {
  return BorderRadius.only(
    topLeft: hasContentAbove ? Radius.zero : bubble.topLeft,
    topRight: hasContentAbove ? Radius.zero : bubble.topRight,
    bottomLeft: hasCaption ? Radius.zero : bubble.bottomLeft,
    bottomRight: hasCaption ? Radius.zero : bubble.bottomRight,
  );
}
