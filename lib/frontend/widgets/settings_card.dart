import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_shape.dart';
import '../../core/design/komet_components.dart';
import '../../core/design/komet_tokens.dart';

class SettingsPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const SettingsPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return KometSurface(
      color: color ?? KometTokens.of(context).raised,
      padding: padding,
      child: child,
    );
  }
}

class SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return KometSurface(
      color: KometTokens.of(context).raised,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            KometFocusRing(child: children[i]),
            if (i != children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 58),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: KometTokens.of(context).divider,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  const SettingsToggleTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      duration: KometTokens.motion(context, 200),
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => onChanged(!value) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: cs.onSurfaceVariant, size: 22, weight: 400),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(value: value, onChanged: enabled ? onChanged : null),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsNavTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String label;
  final Color? tintColor;
  final VoidCallback? onTap;
  final bool isLast;

  const SettingsNavTile({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    this.tintColor,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: isLast
            ? const BorderRadius.vertical(
                bottom: Radius.circular(AppShape.card),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          child: Row(
            children: [
              leading ??
                  Icon(
                    icon,
                    color: tintColor ?? cs.onSurfaceVariant,
                    size: 22,
                    weight: 400,
                  ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: tintColor ?? cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Symbols.chevron_right,
                color: cs.outline,
                size: 20,
                weight: 400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
