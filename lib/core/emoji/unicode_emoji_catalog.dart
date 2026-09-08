import '../utils/emoji_keyword_index.dart';

class UnicodeEmojiGroup {
  const UnicodeEmojiGroup({
    required this.id,
    required this.title,
    required this.iconHint,
    required this.emojis,
  });

  final String id;
  final String title;
  final String iconHint;
  final List<String> emojis;
}

class UnicodeEmojiCatalog {
  UnicodeEmojiCatalog._();

  static List<UnicodeEmojiGroup>? _groups;

  static List<UnicodeEmojiGroup> groups() {
    if (_groups != null) return _groups!;
    if (EmojiKeywordIndex.instance.all.isEmpty) return const [];
    return _groups = _build();
  }

  static List<UnicodeEmojiGroup> _build() {
    final buckets = <String, List<String>>{
      'smileys': [],
      'people': [],
      'animals': [],
      'food': [],
      'travel': [],
      'activity': [],
      'objects': [],
      'symbols': [],
      'flags': [],
    };

    for (final emoji in EmojiKeywordIndex.instance.all) {
      buckets[_bucketFor(emoji)]?.add(emoji);
    }

    const titles = <String, (String, String)>{
      'smileys': ('Смайлы', '😀'),
      'people': ('Люди', '👋'),
      'animals': ('Животные', '🐻'),
      'food': ('Еда', '🍔'),
      'travel': ('Поездки', '✈️'),
      'activity': ('Спорт', '⚽'),
      'objects': ('Предметы', '💡'),
      'symbols': ('Символы', '❤️'),
      'flags': ('Флаги', '🏳️'),
    };

    return [
      for (final id in titles.keys)
        if ((buckets[id] ?? const []).isNotEmpty)
          UnicodeEmojiGroup(
            id: id,
            title: titles[id]!.$1,
            iconHint: titles[id]!.$2,
            emojis: buckets[id]!,
          ),
    ];
  }

  static String _bucketFor(String emoji) {
    final cp = emoji.runes.isEmpty ? 0 : emoji.runes.first;
    if (cp >= 0x1F1E6 && cp <= 0x1F1FF) return 'flags';
    if (cp >= 0x1F600 && cp <= 0x1F64F) return 'smileys';
    if (cp >= 0x1F910 && cp <= 0x1F92F) return 'smileys';
    if (cp >= 0x1F970 && cp <= 0x1F97F) return 'smileys';
    if (cp >= 0x1F440 && cp <= 0x1F4FF) {
      if (cp >= 0x1F466 && cp <= 0x1F487) return 'people';
      if (cp >= 0x1F400 && cp <= 0x1F43F) return 'animals';
    }
    if (cp >= 0x1F300 && cp <= 0x1F5FF) {
      if (cp >= 0x1F345 && cp <= 0x1F37F) return 'food';
      if (cp >= 0x1F3A0 && cp <= 0x1F3FF) return 'activity';
      if (cp >= 0x1F400 && cp <= 0x1F43F) return 'animals';
      if (cp >= 0x1F466 && cp <= 0x1F9FF && cp <= 0x1F487) return 'people';
      return 'objects';
    }
    if (cp >= 0x1F680 && cp <= 0x1F6FF) return 'travel';
    if (cp >= 0x1F7E0 && cp <= 0x1F7FF) return 'symbols';
    if (cp >= 0x1F900 && cp <= 0x1F9FF) {
      if (cp >= 0x1F90C && cp <= 0x1F90F) return 'people';
      if (cp >= 0x1F918 && cp <= 0x1F91F) return 'people';
      if (cp >= 0x1F920 && cp <= 0x1F927) return 'smileys';
      if (cp >= 0x1F930 && cp <= 0x1F96B) return 'people';
      if (cp >= 0x1F980 && cp <= 0x1F9AE) return 'animals';
      if (cp >= 0x1F9B0 && cp <= 0x1F9B3) return 'people';
      if (cp >= 0x1F9C0 && cp <= 0x1F9CF) return 'food';
      if (cp >= 0x1F9D0 && cp <= 0x1F9FF) return 'people';
      return 'smileys';
    }
    if (cp >= 0x1FA70 && cp <= 0x1FAFF) return 'objects';
    if (cp >= 0x2600 && cp <= 0x26FF) return 'symbols';
    if (cp >= 0x2700 && cp <= 0x27BF) return 'symbols';
    if (cp >= 0x1F170 && cp <= 0x1F251) return 'symbols';
    return 'symbols';
  }
}
