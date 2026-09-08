import 'package:flutter/painting.dart';

/// System color-emoji faces so Outfit/Inter do not swallow glyphs.
const List<String> kEmojiFontFallback = [
  'Apple Color Emoji',
  'Segoe UI Emoji',
  'Noto Color Emoji',
  'Android Emoji',
];

extension EmojiTextStyle on TextStyle {
  TextStyle withEmojiFallback() {
    final existing = fontFamilyFallback;
    if (existing != null &&
        existing.length >= kEmojiFontFallback.length &&
        existing.take(kEmojiFontFallback.length).toList().join() ==
            kEmojiFontFallback.join()) {
      return this;
    }
    return copyWith(
      fontFamilyFallback: [
        ...kEmojiFontFallback,
        if (existing != null) ...existing,
      ],
    );
  }
}
