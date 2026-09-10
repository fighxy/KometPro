import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/telegram_album_layout.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/photo_bubble.dart';

AlbumMediaSize _s(double w, double h) => AlbumMediaSize(w, h);

void _assertPacked(AlbumLayout layout) {
  expect(layout.tiles, isNotEmpty);
  expect(layout.width, greaterThan(0));
  expect(layout.height, greaterThan(0));
  for (var i = 0; i < layout.tiles.length; i++) {
    final a = layout.tiles[i];
    expect(a.width, greaterThan(1));
    expect(a.height, greaterThan(1));
    expect(a.left, greaterThanOrEqualTo(-0.01));
    expect(a.top, greaterThanOrEqualTo(-0.01));
    expect(a.left + a.width, lessThanOrEqualTo(layout.width + 0.05));
    expect(a.top + a.height, lessThanOrEqualTo(layout.height + 0.05));
    for (var j = i + 1; j < layout.tiles.length; j++) {
      final b = layout.tiles[j];
      final overlapW =
          (a.left + a.width).clamp(b.left, b.left + b.width) -
          a.left.clamp(b.left, b.left + b.width);
      final overlapH =
          (a.top + a.height).clamp(b.top, b.top + b.height) -
          a.top.clamp(b.top, b.top + b.height);
      expect(overlapW * overlapH, lessThan(0.5));
    }
  }
}

void main() {
  group('photo content width', () {
    test('keeps photo-only messages compact', () {
      expect(
        PhotoBubble.minimumContentWidth(
          captionLength: 0,
          hasReactions: false,
          hasComments: false,
          isDesktop: true,
          maxWidth: 400,
        ),
        0,
      );
    });

    test('uses readable desktop widths for captions and footers', () {
      expect(
        PhotoBubble.minimumContentWidth(
          captionLength: 30,
          hasReactions: false,
          hasComments: false,
          isDesktop: true,
          maxWidth: 400,
        ),
        340,
      );
      expect(
        PhotoBubble.minimumContentWidth(
          captionLength: 80,
          hasReactions: false,
          hasComments: false,
          isDesktop: true,
          maxWidth: 400,
        ),
        400,
      );
      expect(
        PhotoBubble.minimumContentWidth(
          captionLength: 30,
          hasReactions: true,
          hasComments: true,
          isDesktop: true,
          maxWidth: 400,
        ),
        360,
      );
    });

    test('uses one safe mobile minimum for content cards', () {
      expect(
        PhotoBubble.minimumContentWidth(
          captionLength: 1,
          hasReactions: false,
          hasComments: false,
          isDesktop: false,
          maxWidth: 360,
        ),
        320,
      );
      expect(
        PhotoBubble.minimumContentWidth(
          captionLength: 0,
          hasReactions: false,
          hasComments: true,
          isDesktop: false,
          maxWidth: 360,
        ),
        320,
      );
    });

    test('long mobile captions use the available chat width', () {
      expect(
        PhotoBubble.minimumContentWidth(
          captionLength: 80,
          hasReactions: true,
          hasComments: true,
          isDesktop: false,
          maxWidth: 344,
        ),
        344,
      );
    });
  });

  test('single photo keeps its aspect inside the max box', () {
    final layout = layoutTelegramAlbum([_s(1920, 1080)], maxWidth: 280);
    expect(layout.tiles, hasLength(1));
    expect(layout.width / layout.height, closeTo(16 / 9, 0.01));
    expect(layout.width, lessThanOrEqualTo(280));
  });

  test('portrait photo keeps a wide frame for side blur', () {
    final layout = layoutTelegramAlbum([_s(900, 1600)], maxWidth: 280);
    expect(layout.width, closeTo(280, 0.5));
    expect(layout.height, greaterThan(200));
    expect(layout.width / layout.height, greaterThan(0.7));
  });

  test('panorama keeps a usable preview height', () {
    final layout = layoutTelegramAlbum([_s(4000, 200)], maxWidth: 280);
    expect(layout.width, closeTo(280, 0.1));
    expect(layout.height, closeTo(100, 0.1));
    _assertPacked(layout);
  });

  test('tiny photo grows to a useful click target', () {
    final layout = layoutTelegramAlbum([_s(20, 20)], maxWidth: 280);
    expect(layout.width, closeTo(100, 0.1));
    expect(layout.height, closeTo(100, 0.1));
    _assertPacked(layout);
  });

  test('caption can request a readable single-photo width', () {
    final layout = layoutTelegramAlbum(
      [_s(180, 120)],
      maxWidth: 400,
      minSingleWidth: 360,
    );
    expect(layout.width, closeTo(360, 0.1));
    expect(layout.height, closeTo(240, 0.1));
    _assertPacked(layout);
  });

  test('caption width is capped by a narrow parent', () {
    final layout = layoutTelegramAlbum(
      [_s(180, 120)],
      maxWidth: 260,
      minSingleWidth: 360,
    );
    expect(layout.width, closeTo(260, 0.1));
    expect(layout.height, lessThanOrEqualTo(260 * 1.15));
    _assertPacked(layout);
  });

  test('single photo never exceeds a narrow parent width', () {
    final layout = layoutTelegramAlbum([_s(1920, 1080)], maxWidth: 96);
    expect(layout.width, lessThanOrEqualTo(96));
    expect(layout.height, lessThanOrEqualTo(96 * 1.15));
    _assertPacked(layout);
  });

  test('two similar landscapes stack like Telegram', () {
    final layout = layoutTelegramAlbum(
      [_s(1600, 900), _s(1920, 1080)],
      maxWidth: 280,
    );
    expect(layout.tiles, hasLength(2));
    expect(layout.tiles[0].left, 0);
    expect(layout.tiles[1].left, 0);
    expect(layout.tiles[1].top, greaterThan(layout.tiles[0].height));
    _assertPacked(layout);
  });

  test('two portraits sit side by side', () {
    final layout = layoutTelegramAlbum(
      [_s(900, 1600), _s(800, 1400)],
      maxWidth: 280,
    );
    expect(layout.tiles[0].top, 0);
    expect(layout.tiles[1].top, 0);
    expect(layout.tiles[1].left, greaterThan(layout.tiles[0].width));
    _assertPacked(layout);
  });

  test('three items with a tall first photo use a left column', () {
    final layout = layoutTelegramAlbum(
      [_s(800, 1600), _s(1200, 800), _s(1200, 900)],
      maxWidth: 280,
    );
    expect(layout.tiles[0].left, 0);
    expect(layout.tiles[1].left, greaterThan(layout.tiles[0].width));
    expect(layout.tiles[2].left, greaterThan(layout.tiles[0].width));
    expect(layout.tiles[2].top, greaterThan(layout.tiles[1].top));
    _assertPacked(layout);
  });

  test('three landscapes put the first photo on top', () {
    final layout = layoutTelegramAlbum(
      [_s(1600, 900), _s(1200, 800), _s(1400, 900)],
      maxWidth: 280,
    );
    expect(layout.tiles[0].width, closeTo(layout.width, 0.5));
    expect(layout.tiles[1].top, greaterThan(layout.tiles[0].height));
    expect(layout.tiles[2].top, greaterThan(layout.tiles[0].height));
    _assertPacked(layout);
  });

  test('four squares make a 2x2 grid', () {
    final layout = layoutTelegramAlbum(
      [_s(800, 800), _s(800, 800), _s(800, 800), _s(800, 800)],
      maxWidth: 280,
    );
    expect(layout.tiles, hasLength(4));
    expect(layout.height, closeTo(layout.width, 2));
    _assertPacked(layout);
  });

  test('eight landscapes stay two per row so tiles stay large', () {
    final layout = layoutTelegramAlbum(
      List.generate(8, (_) => _s(1600, 900)),
      maxWidth: 280,
    );
    expect(layout.tiles, hasLength(8));
    final rowCounts = <double, int>{};
    for (final tile in layout.tiles) {
      final key = (tile.top * 10).round() / 10;
      rowCounts[key] = (rowCounts[key] ?? 0) + 1;
      expect(tile.height, greaterThanOrEqualTo(70));
    }
    expect(rowCounts.values.every((count) => count <= 2), isTrue);
    _assertPacked(layout);
  });

  test('six photos all stay visible without a +N tile', () {
    final layout = layoutTelegramAlbum(
      List.generate(6, (_) => _s(1200, 900)),
      maxWidth: 280,
    );
    expect(layout.tiles, hasLength(6));
    _assertPacked(layout);
  });

  test('ten photos pack into a telegram mosaic', () {
    final layout = layoutTelegramAlbum(
      [
        _s(1600, 900),
        _s(900, 1600),
        _s(1200, 1200),
        _s(1800, 1000),
        _s(800, 1200),
        _s(1400, 900),
        _s(1000, 1400),
        _s(1600, 1100),
        _s(900, 900),
        _s(1300, 800),
      ],
      maxWidth: 280,
    );
    expect(layout.tiles, hasLength(10));
    _assertPacked(layout);
  });
}
