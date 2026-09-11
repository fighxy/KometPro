import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// System color-emoji faces so Outfit/Inter do not swallow glyphs.
const List<String> kEmojiFontFallback = [
  'Apple Color Emoji',
  'Segoe UI Emoji',
  'Noto Color Emoji',
  'Android Emoji',
];

String? get platformEmojiFont => switch (defaultTargetPlatform) {
  TargetPlatform.windows => 'Segoe UI Emoji',
  TargetPlatform.macOS || TargetPlatform.iOS => 'Apple Color Emoji',
  TargetPlatform.android || TargetPlatform.linux => 'Noto Color Emoji',
  _ => null,
};

TextStyle emojiTextStyle({double size = 24}) => TextStyle(
  fontFamily: platformEmojiFont,
  fontFamilyFallback: kEmojiFontFallback,
  fontSize: size,
  height: 1,
);

extension EmojiTextStyle on TextStyle {
  TextStyle withEmojiFallback() {
    final existing = fontFamilyFallback;
    if (existing != null &&
        kEmojiFontFallback.every(existing.contains)) {
      return this;
    }
    return copyWith(
      fontFamilyFallback: [
        if (existing != null) ...existing,
        for (final family in kEmojiFontFallback)
          if (existing == null || !existing.contains(family)) family,
      ],
    );
  }
}
