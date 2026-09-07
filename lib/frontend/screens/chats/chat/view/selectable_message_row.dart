import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/backend/app_services.dart';
import 'package:komet/backend/modules/animoji.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/app_colors.dart';
import 'package:komet/core/config/app_message_actions_style.dart';
import 'package:komet/core/utils/haptics.dart';
import 'package:komet/frontend/widgets/message_actions_overlay.dart';
import 'package:komet/models/animoji.dart';

class SelectableMessageRow extends StatefulWidget {
  final Widget child;
  final CachedMessage message;
  final bool isMe;
  final ValueListenable<Set<String>> selectedIds;
  final Animation<double> selectionAnim;
  final bool Function() isSelectionActive;
  final VoidCallback onToggleSelection;
  final VoidCallback onEnterSelection;
  final void Function(Offset globalPosition) onStartTextSelection;
  final void Function(Offset? globalPosition) onDragTextSelection;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final bool allowCopy;
  final VoidCallback? onMarkUnread;
  final VoidCallback? onPin;
  final bool Function() isPinned;
  final Future<List<MessageReader>> Function()? loadReadBy;
  final void Function(int userId)? onReaderTap;
  final Future<List<({int id, String title})>> Function()? loadReportReasons;
  final Future<bool> Function(int reasonId)? onReport;
  final void Function(String emoji)? onReact;
  final ValueListenable<Map<String, dynamic>?>? reactions;

  const SelectableMessageRow({
    required this.child,
    required this.message,
    required this.isMe,
    required this.selectedIds,
    required this.selectionAnim,
    required this.isSelectionActive,
    required this.onToggleSelection,
    required this.onEnterSelection,
    required this.onStartTextSelection,
    required this.onDragTextSelection,
    required this.onDelete,
    this.onEdit,
    this.onReply,
    this.onForward,
    this.allowCopy = true,
    this.onMarkUnread,
    this.onPin,
    required this.isPinned,
    this.loadReadBy,
    this.onReaderTap,
    this.loadReportReasons,
    this.onReport,
    this.onReact,
    this.reactions,
  });

  @override
  State<SelectableMessageRow> createState() => SelectableMessageRowState();
}

class SelectableMessageRowState extends State<SelectableMessageRow> {
  static const double _gutterWidth = 40;

  final GlobalKey _boundaryKey = GlobalKey();
  Offset? _lastTapDown;
  Timer? _openTimer;

  bool _isPinnedNow() => widget.isPinned();

  @override
  void dispose() {
    _openTimer?.cancel();
    super.dispose();
  }

  void _openMenu() {
    final ctx = _boundaryKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;

    final origin = renderObject.localToGlobal(Offset.zero);
    final rect = origin & renderObject.size;
    final rawDpr = MediaQuery.of(ctx).devicePixelRatio;
    final dpr = rawDpr > 2.0 ? 2.0 : rawDpr;

    final ui.Image snapshot;
    try {
      snapshot = renderObject.toImageSync(pixelRatio: dpr);
    } catch (_) {
      return;
    }

    Haptics.tap();

    final controller = MessageActionsController();
    showMessageActions(
      context: ctx,
      snapshot: snapshot,
      originRect: rect,
      tapPoint: _lastTapDown ?? rect.center,
      isMe: widget.isMe,
      messageText: widget.message.text,
      copyText: widget.message.selectableText,
      controller: controller,
      style: AppMessageActionsStyle.current.value,
      interaction: MessageActionsInteraction.tap,
      editHistory: widget.message.editHistory,
      loadReadBy: widget.loadReadBy,
      onReaderTap: widget.onReaderTap,
      loadReportReasons: widget.loadReportReasons,
      onReport: widget.onReport,
      onDelete: widget.onDelete,
      onEdit: widget.onEdit,
      onReply: widget.onReply,
      onForward: widget.onForward,
      allowCopy: widget.allowCopy,
      onMarkUnread: widget.onMarkUnread,
      onPin: widget.onPin,
      isPinned: _isPinnedNow(),
      onReact: widget.onReact,
      selectedReaction: widget.reactions?.value?['yourReaction']?.toString(),
      quickReactions: _quickReactionEmojis(),
      loadReactionEmojis: () async {
        await animojiModule.ensureLoaded();
        return _animojiReactionEmojis();
      },
      onDispose: controller.dispose,
    );
  }

  List<ReactionEmoji> _quickReactionEmojis() {
    final quick = animojiModule.quickAnimojis;
    if (quick.isEmpty) {
      return AnimojiModule.fallbackReactions
          .map((e) => ReactionEmoji(emoji: e))
          .toList();
    }
    return quick.map(_toReactionEmoji).toList();
  }

  List<ReactionEmoji> _animojiReactionEmojis() {
    final list = animojiModule.animojis;
    if (list.isEmpty) {
      return AnimojiModule.fallbackReactions
          .map((e) => ReactionEmoji(emoji: e))
          .toList();
    }
    return list.map(_toReactionEmoji).toList();
  }

  ReactionEmoji _toReactionEmoji(Animoji a) => ReactionEmoji(
    emoji: a.emoji,
    animationUrl: a.lottieUrl,
    staticUrl: a.iconUrl,
  );

  void _onSecondaryTapDown(TapDownDetails details) {
    final ctx = _boundaryKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;

    final origin = renderObject.localToGlobal(Offset.zero);
    final rect = origin & renderObject.size;

    final controller = MessageActionsController();
    showMessageActions(
      context: ctx,
      originRect: rect,
      tapPoint: details.globalPosition,
      isMe: widget.isMe,
      messageText: widget.message.text,
      copyText: widget.message.selectableText,
      controller: controller,
      style: MessageActionsStyle.list,
      interaction: MessageActionsInteraction.click,
      editHistory: widget.message.editHistory,
      loadReadBy: widget.loadReadBy,
      onReaderTap: widget.onReaderTap,
      loadReportReasons: widget.loadReportReasons,
      onReport: widget.onReport,
      onDelete: widget.onDelete,
      onEdit: widget.onEdit,
      onReply: widget.onReply,
      onForward: widget.onForward,
      allowCopy: widget.allowCopy,
      onMarkUnread: widget.onMarkUnread,
      onPin: widget.onPin,
      isPinned: _isPinnedNow(),
      onDispose: controller.dispose,
    );
  }

  void _handleTap() {
    if (widget.isSelectionActive()) {
      widget.onToggleSelection();
      return;
    }
    final react = widget.onReact;
    if (react != null && (_openTimer?.isActive ?? false)) {
      _openTimer?.cancel();
      _openTimer = null;
      Haptics.tap();
      react('❤️');
      return;
    }
    _openTimer?.cancel();
    _openTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && !widget.isSelectionActive()) _openMenu();
    });
  }

  bool _textSelectionPress = false;

  void _handleLongPressMove(Offset globalPosition) {
    if (!_textSelectionPress) return;
    widget.onDragTextSelection(globalPosition);
  }

  void _handleLongPressEnd() {
    if (!_textSelectionPress) return;
    _textSelectionPress = false;
    widget.onDragTextSelection(null);
  }

  void _handleLongPressStart(Offset globalPosition) {
    _textSelectionPress = false;
    if (!widget.isSelectionActive()) {
      widget.onEnterSelection();
      return;
    }
    final selected = widget.selectedIds.value.contains(widget.message.id);
    final hasText = widget.message.selectableText != null;
    if (selected && hasText && !widget.message.isControl) {
      _textSelectionPress = true;
      widget.onStartTextSelection(globalPosition);
    } else {
      widget.onToggleSelection();
    }
  }

  Widget _buildCheckCircle(bool selected, ColorScheme cs) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? cs.primary : Colors.transparent,
        border: Border.all(
          color: selected ? cs.primary : cs.mutedText,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Symbols.check, size: 16, weight: 700, color: cs.onPrimary)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isControl) return widget.child;
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: widget.selectionAnim,
      builder: (context, _) {
        final t = Curves.easeOut.transform(
          widget.selectionAnim.value.clamp(0.0, 1.0),
        );
        return ValueListenableBuilder<Set<String>>(
          valueListenable: widget.selectedIds,
          builder: (context, selected, _) {
            final isSelected = selected.contains(widget.message.id);
            final active = selected.isNotEmpty;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _lastTapDown = d.globalPosition,
              onTap: _handleTap,
              onLongPressStart: (d) => _handleLongPressStart(d.globalPosition),
              onLongPressMoveUpdate: (d) =>
                  _handleLongPressMove(d.globalPosition),
              onLongPressEnd: (_) => _handleLongPressEnd(),
              onLongPressCancel: _handleLongPressEnd,
              onSecondaryTapDown: active ? null : _onSecondaryTapDown,
              child: ColoredBox(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.10)
                    : Colors.transparent,
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: _boundaryKey,
                      child: IgnorePointer(
                        ignoring: active,
                        child: Padding(
                          padding: EdgeInsets.only(left: _gutterWidth * t),
                          child: widget.child,
                        ),
                      ),
                    ),
                    if (t > 0)
                      Positioned(
                        left: 8,
                        bottom: 10,
                        child: Opacity(
                          opacity: t,
                          child: _buildCheckCircle(isSelected, cs),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
