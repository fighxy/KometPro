import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/design/komet_tokens.dart';

class ShortcutGroup {
  const ShortcutGroup(this.title, this.items);

  final String title;
  final List<ShortcutHint> items;
}

class ShortcutHint {
  const ShortcutHint(this.keys, this.label);

  final List<String> keys;
  final String label;
}

class ShortcutsScreen extends StatelessWidget {
  const ShortcutsScreen({super.key});

  static bool get _meta => defaultTargetPlatform == TargetPlatform.macOS;

  static String get _mod => _meta ? '⌘' : 'Ctrl';

  static String get _shift => _meta ? '⇧' : 'Shift';

  static String get _alt => _meta ? '⌥' : 'Alt';

  static List<ShortcutGroup> get groups => [
        ShortcutGroup('Навигация', [
          ShortcutHint([_mod, 'K'], 'Командная палитра'),
          ShortcutHint([_mod, _shift, 'F'], 'Поиск по чатам'),
          ShortcutHint([_alt, '↑'], 'Предыдущий чат'),
          ShortcutHint([_alt, '↓'], 'Следующий чат'),
          ShortcutHint([_mod, 'N'], 'Новый чат'),
          ShortcutHint([_mod, 'W'], 'Закрыть чат'),
          ShortcutHint(['Esc'], 'Закрыть панель или диалог'),
        ]),
        ShortcutGroup('Переписка', [
          ShortcutHint([_mod, 'F'], 'Поиск внутри чата'),
          ShortcutHint([_mod, _shift, 'C'], 'Копировать выделенное сообщение'),
          ShortcutHint(['Enter'], 'Отправить сообщение'),
          ShortcutHint([_shift, 'Enter'], 'Перенос строки'),
        ]),
        ShortcutGroup('Звонки', [
          ShortcutHint([_mod, 'D'], 'Микрофон вкл./выкл.'),
          ShortcutHint([_mod, 'E'], 'Камера вкл./выкл.'),
          ShortcutHint([_mod, _shift, 'S'], 'Демонстрация экрана'),
          ShortcutHint([_mod, _shift, 'H'], 'Чат звонка'),
          ShortcutHint([_mod, _shift, 'P'], 'Участники'),
          ShortcutHint(['Esc'], 'Свернуть звонок'),
        ]),
        ShortcutGroup('Просмотр медиа', [
          ShortcutHint(['←'], 'Предыдущее фото'),
          ShortcutHint(['→'], 'Следующее фото'),
          ShortcutHint([_mod, 'R'], 'Повернуть'),
        ]),
        ShortcutGroup('Приложение', [
          ShortcutHint([_mod, ','], 'Настройки'),
          ShortcutHint([_mod, 'Q'], 'Выйти из приложения'),
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              group.title,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: KometTokens.of(context).raised,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final item in group.items) _ShortcutRow(hint: item),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.hint});

  final ShortcutHint hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hint.label,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          for (final key in hint.keys)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _KeyCap(label: key),
            ),
        ],
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
