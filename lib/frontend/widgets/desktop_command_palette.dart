import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/komet_components.dart';
import '../../core/design/komet_tokens.dart';

class DesktopCommand {
  const DesktopCommand(this.label, this.icon, this.run, {this.shortcut = ''});

  final String label;
  final IconData icon;
  final VoidCallback run;
  final String shortcut;
}

Future<void> showDesktopCommandPalette(
  BuildContext context, {
  required List<DesktopCommand> commands,
}) async {
  final command = await showDialog<DesktopCommand>(
    context: context,
    builder: (_) => _CommandPalette(commands: commands),
  );
  if (context.mounted) command?.run();
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({required this.commands});

  final List<DesktopCommand> commands;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  String _query = '';
  int _selected = 0;

  List<DesktopCommand> get _matches => widget.commands
      .where((command) => command.label.toLowerCase().contains(_query))
      .toList();

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final tokens = KometTokens.of(context);
    return Dialog(
      backgroundColor: tokens.overlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KometTokens.dialog),
      ),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(KometTokens.space3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent || matches.isEmpty) {
                    return KeyEventResult.ignored;
                  }
                  final key = event.logicalKey;
                  if (key == LogicalKeyboardKey.arrowDown ||
                      key == LogicalKeyboardKey.arrowUp) {
                    setState(
                      () => _selected =
                          (_selected +
                              (key == LogicalKeyboardKey.arrowDown ? 1 : -1)) %
                          matches.length,
                    );
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Команды Komet',
                    hintText: 'Найти действие',
                    prefixIcon: Icon(Icons.search),
                    suffixText: 'Esc',
                  ),
                  onChanged: (value) => setState(() {
                    _query = value.trim().toLowerCase();
                    _selected = 0;
                  }),
                  onSubmitted: (_) {
                    if (matches.isNotEmpty) {
                      Navigator.pop(context, matches[_selected]);
                    }
                  },
                ),
              ),
              const SizedBox(height: KometTokens.space2),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (matches.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(KometTokens.space6),
                          child: Text('Команды не найдены'),
                        ),
                      for (var i = 0; i < matches.length; i++)
                        KometFocusRing(
                          child: ListTile(
                            selected: i == _selected,
                            selectedTileColor: tokens.selected,
                            selectedColor: tokens.onSelected,
                            shape: const RoundedRectangleBorder(
                              borderRadius: KometTokens.controlRadius,
                            ),
                            leading: Icon(matches[i].icon),
                            title: Text(matches[i].label),
                            trailing: Text(
                              defaultTargetPlatform == TargetPlatform.macOS
                                  ? matches[i].shortcut.replaceAll('Ctrl', '⌘')
                                  : matches[i].shortcut,
                            ),
                            onTap: () => Navigator.pop(context, matches[i]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
