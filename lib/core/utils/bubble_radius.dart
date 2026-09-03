BorderRadius computeBubbleRadius({
  required bool isMe,
  required bool isTop,
  required bool isBottom,
  required BubbleStyle style,
  required BubbleBehavior behavior,
  bool hasPhotoWithCaption = false,
  bool hasMultiplePhotosNoCaption = false,
  bool hasCommentsFooter = false,
}) {
  final isSingle = isTop && isBottom;

  late final BorderRadius radius;
  if (hasPhotoWithCaption && (isTop || isBottom)) {
    radius = BorderRadius.only(
      topLeft: _big,
      topRight: _big,
      bottomLeft: isMe ? _big : _small,
      bottomRight: _small,
    );
  } else if (hasMultiplePhotosNoCaption && isBottom) {
    radius = BorderRadius.only(
      topLeft: isMe ? _big : _small,
      topRight: _small,
      bottomLeft: isMe ? _big : _small,
      bottomRight: isMe ? _small : _big,
    );
  } else {
    final base = style == BubbleStyle.desktop ? _small : _big;
    Radius tl = base, tr = base, bl = base, br = base;

    if (behavior != BubbleBehavior.immutable && !isSingle) {
      if (isTop) {
        if (isMe) {
          br = _small;
        } else {
          bl = _small;
        }
      } else if (isBottom) {
        if (isMe) {
          tr = _small;
        } else {
          tl = _small;
        }
      } else {
        if (isMe) {
          tr = _small;
          br = _small;
        } else {
          tl = _small;
          bl = _small;
        }
      }
    }

    radius = BorderRadius.only(
      topLeft: tl,
      topRight: tr,
      bottomLeft: bl,
      bottomRight: br,
    );
  }

  if (!hasCommentsFooter) return radius;
  return BorderRadius.only(
    topLeft: radius.topLeft,
    topRight: radius.topRight,
    bottomLeft: _big,
    bottomRight: _big,
  );
}