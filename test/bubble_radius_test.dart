import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/app_bubble_behavior.dart';
import 'package:komet/core/config/app_bubble_shape.dart';
import 'package:komet/core/utils/bubble_radius.dart';

void main() {
  test('comments footer uses the same 24pt corners as the bubble top', () {
    final radius = computeBubbleRadius(
      isMe: false,
      isTop: true,
      isBottom: true,
      style: BubbleStyle.ios,
      behavior: BubbleBehavior.grouped,
      hasPhotoWithCaption: true,
      hasCommentsFooter: true,
    );

    expect(radius.topLeft, const Radius.circular(kBubbleBigRadius));
    expect(radius.topRight, const Radius.circular(kBubbleBigRadius));
    expect(radius.bottomLeft, const Radius.circular(kBubbleBigRadius));
    expect(radius.bottomRight, const Radius.circular(kBubbleBigRadius));
  });

  test('photo+caption without comments keeps the incoming tail', () {
    final radius = computeBubbleRadius(
      isMe: false,
      isTop: true,
      isBottom: true,
      style: BubbleStyle.ios,
      behavior: BubbleBehavior.grouped,
      hasPhotoWithCaption: true,
    );

    expect(radius.bottomLeft, const Radius.circular(kBubbleSmallRadius));
    expect(radius.bottomRight, const Radius.circular(kBubbleSmallRadius));
  });
}
