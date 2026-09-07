import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/core/config/app_frost.dart';
import 'package:komet/frontend/widgets/animated_text_swap.dart';
import 'package:komet/frontend/widgets/liquid_glass.dart';
import 'package:komet/l10n/app_localizations.dart';

class PinnedMessageBanner extends StatelessWidget {
  final String? text;
  final bool isPreview;
  final VoidCallback onTap;
  final VoidCallback? onUnpin;
  final bool floating;
  final bool frosted;
  final bool liquid;
  final BorderRadius? borderRadius;
  final BackdropKey? backdropKey;

  const PinnedMessageBanner({
    required this.text,
    required this.isPreview,
    required this.onTap,
    this.onUnpin,
    this.floating = false,
    this.borderRadius,
    this.frosted = false,
    this.liquid = false,
    this.backdropKey,
  });

  BorderRadius get _radius => borderRadius ?? BorderRadius.circular(16);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Material(
      color: frosted
          ? AppFrost.glassTint(cs)
          : floating
          ? cs.surfaceContainerHigh.withValues(alpha: 0.92)
          : cs.surfaceContainerHigh,
      borderRadius: floating ? _radius : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.pinnedMessageTitle,
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    PinnedMessageText(
                      text: text,
                      isPreview: isPreview,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              if (onUnpin != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  onPressed: onUnpin,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final bottomBorder = Border(bottom: AppFrost.hairline(cs));

    if (frosted) {
      return GlassSurface(
        liquid: liquid,
        borderRadius: floating ? BorderRadius.circular(16) : BorderRadius.zero,
        frostTint: Colors.transparent,
        border: floating ? null : bottomBorder,
        backdropKey: backdropKey,
        child: content,
      );
    }

    if (!floating) {
      return DecoratedBox(
        decoration: BoxDecoration(border: bottomBorder),
        child: content,
      );
    }
    return content;
  }
}

class PinnedMessageText extends StatefulWidget {
  final String? text;
  final bool isPreview;
  final Color color;

  const PinnedMessageText({
    required this.text,
    required this.isPreview,
    required this.color,
  });

  @override
  State<PinnedMessageText> createState() => PinnedMessageTextState();
}

class PinnedMessageTextState extends State<PinnedMessageText> {
  late String? _primaryText;
  late bool _primaryIsPreview;
  late String? _secondaryText;
  late bool _secondaryIsPreview;
  bool _showSecondary = false;

  @override
  void initState() {
    super.initState();
    _primaryText = widget.text;
    _primaryIsPreview = widget.isPreview;
    _secondaryText = widget.text;
    _secondaryIsPreview = widget.isPreview;
  }

  @override
  void didUpdateWidget(covariant PinnedMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text == oldWidget.text &&
        widget.isPreview == oldWidget.isPreview) {
      return;
    }
    if (_showSecondary) {
      _primaryText = widget.text;
      _primaryIsPreview = widget.isPreview;
    } else {
      _secondaryText = widget.text;
      _secondaryIsPreview = widget.isPreview;
    }
    _showSecondary = !_showSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedTextSwap(
        showAlternate: _showSecondary,
        alternate: _buildText(context, _secondaryText, _secondaryIsPreview),
        child: _buildText(context, _primaryText, _primaryIsPreview),
      ),
    );
  }

  Widget _buildText(BuildContext context, String? text, bool isPreview) {
    final label = text == null || text.isEmpty
        ? AppLocalizations.of(context)!.msgActionsNoText
        : text;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: widget.color,
        fontSize: 14,
        fontStyle: isPreview ? FontStyle.italic : null,
      ),
    );
  }
}
