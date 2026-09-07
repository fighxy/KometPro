part of '../../chat_screen.dart';

extension _ChatAppBarBuild on _ChatScreenState {
  PreferredSizeWidget _buildAppBar(ColorScheme cs) {
    final glossy = AppVisualStyle.current.value.glossyChrome;
    final searchT = Curves.easeOut.transform(_searchAnim.value.clamp(0.0, 1.0));
    final height = glossy
        ? ui.lerpDouble(_glossyHeaderHeight, _glossySearchHeight, searchT)!
        : kToolbarHeight;
    final chrome = _effectiveChrome;
    final barExtent = MediaQuery.paddingOf(context).top + height;
    final fadeStop = ((barExtent - _edgeFadeHeight) / barExtent).clamp(
      0.0,
      1.0,
    );
    return AppBar(
      backgroundColor: chrome == ChatChromeStyle.color
          ? (glossy ? Colors.transparent : cs.surfaceContainerHigh)
          : Colors.transparent,
      flexibleSpace: chrome == ChatChromeStyle.blur
          ? FrostedPanel(
              tint: AppFrost.blurPanelTint(cs),
              border: Border(bottom: AppFrost.hairline(cs)),
              backdropKey: _barBackdrop,
              child: const SizedBox.expand(),
            )
          : (_chromeVignette && !glossy)
          ? IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.surface,
                      cs.surface,
                      cs.surface.withValues(alpha: 0.0),
                    ],
                    stops: [0.0, fadeStop, 1.0],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            )
          : (chrome == ChatChromeStyle.transparent && !glossy)
          ? FrostedPanel(
              sigma: AppFrost.sigma,
              tint: AppFrost.glassTint(cs),
              border: Border(bottom: AppFrost.hairline(cs)),
              backdropKey: _barBackdrop,
              child: const SizedBox.expand(),
            )
          : null,
      foregroundColor: cs.onSurface,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: cs.onSurface),
      elevation: 0,
      toolbarHeight: height,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      centerTitle: false,
      title: SizedBox(
        height: height,
        child: AnimatedBuilder(
          animation: Listenable.merge([_selectionAnim, _searchAnim]),
          builder: (context, _) {
            final t = Curves.easeOut.transform(
              _selectionAnim.value.clamp(0.0, 1.0),
            );
            final s = Curves.easeOut.transform(
              _searchAnim.value.clamp(0.0, 1.0),
            );
            return ValueListenableBuilder<Set<String>>(
              valueListenable: _selectedIds,
              builder: (context, selected, _) => Stack(
                fit: StackFit.expand,
                children: [
                  if (t < 1 && s < 1)
                    IgnorePointer(
                      ignoring: t > 0.5 || s > 0.5,
                      child: Opacity(
                        opacity: (1 - t) * (1 - s),
                        child: Transform.translate(
                          offset: Offset(0, -height * 0.4 * t),
                          child: ChatHeaderRow(
                            glossy: glossy,
                            frosted:
                                glossy && chrome == ChatChromeStyle.transparent,
                            backdropVisible: t == 0 && s == 0,
                            liquid: _liquidChrome,
                            backdropKey: _pillBackdrop,
                            cs: cs,
                            embedded: widget.embedded,
                            chatId: widget.chatId,
                            heroTag: _profileHeroTag,
                            name: _headerName(),
                            imageUrl: _headerAvatarUrl(),
                            chatType: widget.chatType,
                            isOfficial: chat?.isOfficial ?? false,
                            encrypted: _encryptionEnabled,
                            myId: _myId,
                            headerStatus: _headerStatusNotifier,
                            scheduledCount: _scheduledCount,
                            otherUnread: _otherUnread,
                            showCall:
                                !_commentsMode &&
                                widget.chatType == 'DIALOG' &&
                                widget.chatId != 0 &&
                                !_peerIsBot,
                            onClose: widget.onClose,
                            onOpenInfo: _commentsMode ? () {} : _openChatInfo,
                            onOpenScheduled: _openScheduledMessages,
                            onCall: _startCall,
                            onMenu: _commentsMode ? (_) {} : _openChatMenu,
                            onJumpDate: _commentsMode
                                ? null
                                : () => _pickSearchDate(),
                          ),
                        ),
                      ),
                    ),
                  if (t > 0)
                    IgnorePointer(
                      ignoring: t < 0.5,
                      child: Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, height * 0.4 * (1 - t)),
                          child: SelectionTopBar(
                            cs: cs,
                            selected: selected,
                            glossy: glossy,
                            copyMsgs: _copyableSelection(selected),
                            editMsg: _singleEditable(selected),
                            onClear: _clearSelection,
                            onCopy: _copySelected,
                            onEdit: _editSelected,
                            onDelete: _deleteSelected,
                          ),
                        ),
                      ),
                    ),
                  if (s > 0)
                    IgnorePointer(
                      ignoring: s < 0.5,
                      child: Opacity(
                        opacity: s,
                        child: SearchTopBar(
                          cs: cs,
                          glossy: glossy,
                          search: _search,
                          focusNode: _searchFocusNode,
                          onClose: _closeSearch,
                          onPickDate: _pickSearchDate,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
