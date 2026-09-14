import 'dart:math' as math;
import 'dart:ui';

/// Computes a stable preview frame while preserving the source aspect ratio
/// whenever that still produces a useful surface in the conversation.
Size fitMediaFrame(
  double sourceWidth,
  double sourceHeight, {
  required double maxWidth,
  required double maxHeight,
  double minSize = 100,
  double minFrameWidth = 0,
  double? minPreviewHeight,
  bool widenPortrait = false,
}) {
  final safeMaxWidth = math.max(1.0, maxWidth);
  final safeMaxHeight = math.max(1.0, maxHeight);
  final safeMinSize = math.min(minSize, math.min(safeMaxWidth, safeMaxHeight));
  final safeMinFrameWidth = minFrameWidth
      .clamp(0.0, safeMaxWidth)
      .toDouble();

  if (sourceWidth <= 0 || sourceHeight <= 0) {
    final fallback = math.min(
      math.max(
        safeMinFrameWidth,
        math.max(safeMinSize, safeMaxWidth * 0.75),
      ),
      math.min(safeMaxWidth, safeMaxHeight),
    );
    return Size(fallback, fallback);
  }

  final scale = math.min(
    1.0,
    math.min(safeMaxWidth / sourceWidth, safeMaxHeight / sourceHeight),
  );
  var width = sourceWidth * scale;
  var height = sourceHeight * scale;

  final longerSide = math.max(width, height);
  if (longerSide < safeMinSize) {
    final upscale = math.min(
      safeMinSize / longerSide,
      math.min(safeMaxWidth / width, safeMaxHeight / height),
    );
    width *= upscale;
    height *= upscale;
  }

  final previewFloor = math.min(
    minPreviewHeight ?? 0.0,
    safeMaxHeight,
  );
  if (height < previewFloor) {
    // Very wide photos need a usable click target. The image renderer crops
    // only this exceptional case to the shallow preview frame.
    width = safeMaxWidth;
    height = previewFloor;
  }

  if (width < safeMinFrameWidth) {
    final upscale = math.min(
      safeMinFrameWidth / width,
      safeMaxHeight / height,
    );
    width *= upscale;
    height *= upscale;
    width = math.max(width, safeMinFrameWidth);
  }

  if (widenPortrait &&
      sourceWidth / sourceHeight < 0.95 &&
      width < safeMaxWidth * 0.72) {
    width = safeMaxWidth;
  }

  return Size(width, height);
}
