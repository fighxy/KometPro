import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/media_frame_size.dart';

void main() {
  test('landscape video keeps its aspect ratio inside the frame', () {
    final size = fitMediaFrame(1920, 1080, maxWidth: 280, maxHeight: 280);
    expect(size.width, closeTo(280, 0.1));
    expect(size.width / size.height, closeTo(16 / 9, 0.01));
  });

  test('portrait photo uses a wide frame for blurred side fill', () {
    final size = fitMediaFrame(
      900,
      1600,
      maxWidth: 280,
      maxHeight: 280,
      minFrameWidth: 240,
      widenPortrait: true,
    );
    expect(size.width, 280);
    expect(size.height, lessThanOrEqualTo(280));
  });

  test('panorama retains a usable preview height', () {
    final size = fitMediaFrame(
      4000,
      200,
      maxWidth: 280,
      maxHeight: 280,
      minPreviewHeight: 100,
    );
    expect(size.height, 100);
    expect(size.width, 280);
  });
}
