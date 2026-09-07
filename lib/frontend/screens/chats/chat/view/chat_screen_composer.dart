part of '../../chat_screen.dart';

extension _ChatComposerBuild on _ChatScreenState {
  Widget _buildComposerArea(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _selectionAnim,
          builder: (context, child) {
            final t = Curves.easeOut.transform(
              _selectionAnim.value.clamp(0.0, 1.0),
            );
            if (t == 0) return child!;
            if (t == 1) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 1 - t,
                child: Transform.translate(
                  offset: Offset(0, 48 * t),
                  child: Opacity(opacity: 1 - t, child: child),
                ),
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _attachAnim,
                builder: (context, _) {
                  if (_attachAnim.value == 0) {
                    return const SizedBox.shrink();
                  }
                  final curve = _attachAnim.status == AnimationStatus.reverse
                      ? Curves.easeIn
                      : Curves.easeOut;
                  final t = curve.transform(_attachAnim.value);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        heightFactor: t,
                        child: Opacity(
                          opacity: t,
                          child: AttachmentPanel(
                            onClose: () => _showAttachmentPanel.value = false,
                            onPickFile: _pickAndUploadFile,
                            onSendById: _sendFileById,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _stickers.anim,
                builder: (context, _) => ComposerInputBar(
                  bottomSafe: _stickers.anim.value == 0,
                  chatType: _commentsMode ? 'CHAT' : widget.chatType,
                  chrome: _effectiveChrome,
                  vignette: _chromeVignette,
                  style: AppComposerStyle.current.value,
                  background: AppComposerBackground.current.value,
                  backdropKey: _pillBackdrop,
                  attachAnim: _attachAnim,
                  replyTo: _replyTo,
                  forwardMessages: _pendingForwards,
                  myId: _myId,
                  hasText: _hasText,
                  uploadStatus: _uploadStatus,
                  messageController: _messageController,
                  messageFocusNode: _messageFocusNode,
                  voiceRec: _voiceRec,
                  note: _note,
                  onToggleStickerPanel: _toggleStickerPanel,
                  onSendText: _sendMessage,
                  onScheduleMessage: _scheduleMessage,
                  onOpenAttach: _openAttachmentSheet,
                  onOpenAttachScheduled: _openAttachmentSheetScheduled,
                  onSendHistory: _sendHistoryFile,
                  onCancelReply: _cancelReply,
                  onCancelForward: _cancelForward,
                  onPickReplyChat: _commentsMode || !_crossChatReplySupported
                      ? null
                      : () => unawaited(_pickReplyChat()),
                  formatElapsed: formatVoiceElapsed,
                  contextMenuBuilder: (ctx, state) => _formatContextMenu(
                    _messageController,
                    ctx,
                    state,
                    extraItems: _pasteMenuItems(ctx, state),
                  ),
                  onPasteMedia: ClipboardMedia.supported
                      ? _handlePasteMedia
                      : null,
                  isMuted: chat?.isMuted ?? false,
                  onToggleMute: _toggleChatMute,
                  channelSubscribed: !_previewChat,
                  channelSubscribing: _subscribing,
                  onSubscribe: _subscribeChannel,
                  showStickerButton: !_commentsMode,
                  showAttachButton: !_commentsMode,
                  forceSend: _commentsMode,
                  hintText: _commentsMode ? 'Комментарий' : 'Сообщение',
                ),
              ),
              StickerPanelView(
                stickers: _stickers,
                onStickerTap: _sendSticker,
                onEmojiTap: _insertAnimoji,
              ),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _selectionAnim,
          builder: (context, child) {
            final t = Curves.easeOut.transform(
              _selectionAnim.value.clamp(0.0, 1.0),
            );
            if (t == 0) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: t,
                child: Opacity(opacity: t, child: child),
              ),
            );
          },
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: _selectedIds,
            builder: (context, selected, _) => SelectionBottomBar(
              cs: cs,
              selected: selected,
              onReply: _replySelected,
              onForward: _forwardSelected,
              allowForward: !(chat?.forwardDisabled ?? false),
            ),
          ),
        ),
      ],
    );
    Widget wrapChrome(Widget child) {
      if (_composerFrosted) {
        if (ComposerChrome.isGlossy(AppComposerStyle.current.value)) {
          return child;
        }
        return FrostedPanel(
          sigma: AppFrost.sigma,
          tint: AppFrost.glassTint(cs),
          border: Border(top: AppFrost.hairline(cs)),
          backdropKey: _barBackdrop,
          child: child,
        );
      }
      if (_effectiveChrome != ChatChromeStyle.blur) return child;
      return FrostedPanel(
        tint: AppFrost.blurPanelTint(cs),
        border: Border(top: AppFrost.hairline(cs)),
        backdropKey: _barBackdrop,
        child: child,
      );
    }

    final base = wrapChrome(_centerChatColumn(content));
    return AnimatedBuilder(
      animation: _searchAnim,
      builder: (context, _) {
        final s = Curves.easeOut.transform(_searchAnim.value.clamp(0.0, 1.0));
        if (s == 0) return base;
        if (s >= 1) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1 - s,
            child: Opacity(
              opacity: 1 - s,
              child: IgnorePointer(child: base),
            ),
          ),
        );
      },
    );
  }
}
