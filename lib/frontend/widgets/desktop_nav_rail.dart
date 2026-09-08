import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/desktop_density.dart';

class DesktopNavRail extends StatelessWidget {
  const DesktopNavRail({
    super.key,
    required this.index,
    required this.onSelect,
    this.onSettings,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surfaceContainerLow,
      child: SizedBox(
        width: DesktopDensity.railWidth,
        child: SafeArea(
          right: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              _RailButton(
                icon: Symbols.chat_bubble,
                selected: index == 0,
                tooltip: 'Чаты',
                onTap: () => onSelect(0),
              ),
              _RailButton(
                icon: Symbols.call,
                selected: index == 1,
                tooltip: 'Звонки',
                onTap: () => onSelect(1),
              ),
              _RailButton(
                icon: Symbols.person_pin,
                selected: index == 2,
                tooltip: 'Контакты',
                onTap: () => onSelect(2),
              ),
              const Spacer(),
              _RailButton(
                icon: Symbols.settings,
                selected: index == 3,
                tooltip: 'Настройки',
                onTap: () => onSettings?.call() ?? onSelect(3),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            hoverColor: cs.onSurface.withValues(alpha: 0.06),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 22, color: color, weight: selected ? 600 : 400),
            ),
          ),
        ),
      ),
    );
  }
}
