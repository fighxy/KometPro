part of '../../chat_screen.dart';

extension _ChatTranscriptBuild on _ChatScreenState {
  Widget _buildDateSeparatorWidget(
    BuildContext context,
    DateTime date, {
    Key? key,
    bool floating = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(vertical: floating ? 2 : 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateLabel(date),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontStyle: floating ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnreadSeparatorWidget(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    return Padding(
      key: _unreadSeparatorKey,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Непрочитанные сообщения',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPinnedAndPill() {
    return ValueListenableBuilder<PlaybackKind?>(
      valueListenable: MediaPlayback.instance.primary,
      builder: (context, kind, _) {
        final merged = kind != null;
        final banner = _buildPinnedBanner(
          floating: true,
          borderRadius: merged
              ? const BorderRadius.vertical(top: Radius.circular(16))
              : null,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?banner,
            MediaPlaybackPill(
              onlyChatId: widget.chatId,
              borderRadius: banner == null
                  ? BorderRadius.circular(16)
                  : const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
          ],
        );
      },
    );
  }

  Widget? _buildPinnedBanner({
    required bool floating,
    BorderRadius? borderRadius,
  }) {
    final pinned = chat;
    if (pinned == null || !pinned.hasPinnedMessage) return null;
    return PinnedMessageBanner(
      text: pinned.pinnedMsgText,
      isPreview: pinned.pinnedMsgIsPreview,
      floating: floating,
      borderRadius: borderRadius,
      frosted: _effectiveChrome == ChatChromeStyle.transparent,
      liquid: _liquidChrome,
      backdropKey: _pillBackdrop,
      onTap: _jumpToPinnedMessage,
      onUnpin: pinned.canPinMessages(_myId)
          ? () => unawaited(_unpinCurrentMessage())
          : null,
    );
  }

  Widget _buildColorBody() {
    final cs = Theme.of(context).colorScheme;
    final banner = _buildPinnedBanner(floating: false);
    final frosted = _composerFrosted;
    final composer = MeasureSize(
      onHeight: (value) => _composerHeight.value = value,
      child: _buildComposerArea(context),
    );
    return Column(
      children: [
        ?banner,
        MediaPlaybackPill(
          onlyChatId: widget.chatId,
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          borderRadius: BorderRadius.circular(16),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_wallpaper != null)
                Positioned.fill(
                  child: ChatWallpaperView(wallpaper: _wallpaper!),
                ),
              Positioned.fill(child: _buildMessagesArea()),
              ValueListenableBuilder<double>(
                valueListenable: _composerHeight,
                builder: (context, height, _) => Positioned(
                  left: 0,
                  right: 0,
                  bottom: frosted ? height : 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MentionPanelView(mentionPanel: _mentionPanel),
                      CommandPanelView(commandPanel: _commandPanel),
                    ],
                  ),
                ),
              ),
              VideoNoteRecordingLayer(controller: _note),
              if (frosted)
                Positioned(left: 0, right: 0, bottom: 0, child: composer),
              SearchOverlay(
                cs: cs,
                searchAnim: _searchAnim,
                search: _search,
                onOpenResult: _openSearchResult,
                senderName: _searchSenderName,
                senderAvatar: _searchSenderAvatar,
              ),
            ],
          ),
        ),
        if (!frosted) composer,
      ],
    );
  }

  double _pinnedBannerTop() {
    final glossy = AppVisualStyle.current.value.glossyChrome;
    return MediaQuery.paddingOf(context).top +
        (glossy ? _glossyHeaderHeight : kToolbarHeight) -
        _pinnedBannerLift;
  }

  Widget _buildUnderlapBody() {
    final cs = Theme.of(context).colorScheme;
    final vignette = _chromeVignette;
    final bannerTop = _pinnedBannerTop();
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_wallpaper != null)
          Positioned.fill(child: ChatWallpaperView(wallpaper: _wallpaper!)),
        Positioned.fill(child: _buildMessagesArea()),
        SearchOverlay(
          cs: cs,
          searchAnim: _searchAnim,
          search: _search,
          onOpenResult: _openSearchResult,
          senderName: _searchSenderName,
          senderAvatar: _searchSenderAvatar,
        ),
        if (vignette) ...[
          if (AppVisualStyle.current.value.glossyChrome)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildEdgeVignette(cs, top: true),
            ),
          ValueListenableBuilder<double>(
            valueListenable: _composerHeight,
            builder: (context, height, _) => _composerPaintsSurface
                ? Positioned(
                    left: 0,
                    right: 0,
                    bottom: height,
                    child: _buildEdgeFade(cs),
                  )
                : Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildEdgeVignette(cs, top: false, height: height),
                  ),
          ),
        ],
        Positioned(
          top: bannerTop,
          left: 8,
          right: 8,
          child: MeasureSize(
            onHeight: (value) => _pinnedBannerHeight.value = value,
            child: _buildPinnedAndPill(),
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: _composerHeight,
          builder: (context, height, _) => Positioned(
            left: 0,
            right: 0,
            bottom: height,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MentionPanelView(mentionPanel: _mentionPanel),
                CommandPanelView(commandPanel: _commandPanel),
              ],
            ),
          ),
        ),
        VideoNoteRecordingLayer(controller: _note),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Builder(
            builder: (context) => MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: MeasureSize(
                onHeight: (value) => _composerHeight.value = value,
                child: _buildComposerArea(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEdgeFade(ColorScheme cs) {
    return IgnorePointer(
      child: Container(
        height: _edgeFadeHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [cs.surface, cs.surface.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeVignette(
    ColorScheme cs, {
    required bool top,
    double? height,
  }) {
    final double resolved;
    if (height != null) {
      resolved = height;
    } else {
      final glossy = AppVisualStyle.current.value.glossyChrome;
      resolved =
          MediaQuery.paddingOf(context).top +
          (glossy ? _glossyHeaderHeight : kToolbarHeight);
    }
    return IgnorePointer(
      child: Container(
        height: resolved,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [cs.surface, cs.surface.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesArea() {
    final showShimmer = _messages.isEmpty
        ? _isLoading
        : (_awaitingPosition || _navigatingToTarget);
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: showShimmer ? 0.0 : 1.0,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _userGestureEpoch++;
              } else if (notification is ScrollEndNotification) {
                _readMarker.flush();
              }
              return false;
            },
            child: _buildMessagesList(),
          ),
        ),
        if (showShimmer)
          Positioned.fill(child: ShimmerLoading(shimmer: _shimmerController)),
      ],
    );
  }

  Widget _buildMessagesList() =>
      _messageListWidget ??= _ChatMessageList(this, key: _messageListKey);

  EdgeInsets _messagesListPadding(BuildContext context, {double inset = 0}) {
    if (AppChatChrome.current.value == ChatChromeStyle.color) {
      return EdgeInsets.fromLTRB(inset, 8, inset, 8);
    }
    final topInset = MediaQuery.paddingOf(context).top;
    return EdgeInsets.fromLTRB(inset, topInset + 8, inset, 8);
  }

  Widget _centerChatColumn(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = ChatLayout.horizontalInset(constraints.maxWidth);
        if (inset <= 0) return child;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: child,
        );
      },
    );
  }

  double _floatingDateTop(double pinnedHeight) {
    if (AppChatChrome.current.value == ChatChromeStyle.color) {
      final glossy = AppVisualStyle.current.value.glossyChrome;
      return glossy ? 2 : 4;
    }
    if (chat?.hasPinnedMessage == true && pinnedHeight > 0) {
      return _pinnedBannerTop() + pinnedHeight + 2;
    }
    return _pinnedBannerTop() + 2;
  }

  Widget _buildLoadMoreIndicator() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: SmallSpinner(size: 22, color: cs.onSurfaceVariant)),
    );
  }

  Widget _buildMessagesListContent() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final items = _buildCombinedItems();
    final visibleCount = _visibleMessageCount;

    return Stack(
      key: _listKey,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: AppCacheExtent.current,
          builder: (context, userCacheExtent, _) =>
              ValueListenableBuilder<double?>(
                valueListenable: _jumpCacheExtent,
                builder: (context, jumpExtent, _) {
                  final cacheExtent =
                      jumpExtent != null && jumpExtent < userCacheExtent
                      ? jumpExtent
                      : userCacheExtent;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final inset = ChatLayout.horizontalInset(
                        constraints.maxWidth,
                      );
                      return DesktopScroll(
                        controller: _scrollController,
                        child: CustomScrollView(
                    controller: _scrollController,
                    reverse: true,
                    scrollCacheExtent: ScrollCacheExtent.pixels(cacheExtent),
                    slivers: [
                      SliverPadding(
                        padding: _messagesListPadding(context, inset: inset),
                        sliver: SliverList(
                          key: ValueKey(_listEpoch),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index == 0) {
                                return ValueListenableBuilder<double>(
                                  valueListenable: _composerHeight,
                                  builder: (context, height, _) => SizedBox(
                                    height: (_composerUnderlap ? height : 0) +
                                        (height < 8
                                            ? MediaQuery.paddingOf(context)
                                                .bottom
                                            : 0),
                                  ),
                                );
                              }
                              if (index > items.length) {
                                return _buildLoadMoreIndicator();
                              }
                              final item = items[items.length - index];

                              if (item is DateSeparatorItem) {
                                return _buildDateSeparatorWidget(
                                  context,
                                  item.date,
                                  key: item.key,
                                );
                              }

                              if (item is UnreadSeparatorItem) {
                                return _buildUnreadSeparatorWidget(context);
                              }

                              final msgItem = item as ChatListMessageItem;
                              final message = msgItem.message;
                              final msgIndex = msgItem.index;
                              final isMe = message.senderId == _myId;
                              final prevMessage = msgIndex > 0
                                  ? _messages[msgIndex - 1]
                                  : null;
                              final nextMessage = msgIndex < visibleCount - 1
                                  ? _messages[msgIndex + 1]
                                  : null;

                              final bool isChannelPost =
                                  !_commentsMode &&
                                  (chat?.type ?? widget.chatType) ==
                                      'CHANNEL' &&
                                  !message.isControl;
                              final bool isCommentedPost =
                                  _commentsMode &&
                                  message.id == widget.commentPostId;

                              final bubble = MessageBubble(
                                message: message,
                                isMe: isMe,
                                myId: _myId,
                                prevMessage: prevMessage,
                                nextMessage: nextMessage,
                                chatType: _commentsMode
                                    ? 'CHAT'
                                    : (chat?.type ?? 'CHAT'),
                                chatId: widget.chatId,
                                photoActions: _photoActions,
                                overrideStatus: _effectiveStatus(message),
                                otherReadTime: _otherReadTime,
                                reactionsListenable: _reactionNotifierFor(
                                  message,
                                ),
                                reactionAnimation: _reactionAnimation,
                                uploadProgress: _photoProgressFor(message),
                                onReplyTap: (id) =>
                                    _jumpToMessage(id, fromId: message.id),
                                onAvatarTap: _openSenderProfile,
                                onForwardedSourceTap: _openForwardedSource,
                                onStickerTap: _openStickerPack,
                                onReactionTap: message.isControl
                                    ? null
                                    : (emoji) =>
                                          _reactToMessage(message, emoji),
                                peerName: widget.name,
                                peerAvatarUrl: widget.imageUrl,
                                senderNameOverride: isCommentedPost
                                    ? widget.name
                                    : null,
                                senderAvatarOverride: isCommentedPost
                                    ? widget.imageUrl
                                    : null,
                                senderRole: isCommentedPost
                                    ? null
                                    : _senderRoleLabel(message.senderId),
                                textSelection: _textSelection,
                                textSelectionDrag: _textSelectionDrag,
                                onExitTextSelection: _exitTextSelection,
                                commentsLabel: isChannelPost
                                    ? _commentsLabelFor(message.id)
                                    : null,
                                onCommentsTap: isChannelPost
                                    ? () => _openComments(message)
                                    : null,
                              );

                              final canReport = !isMe && !message.isControl;
                              final reportTypeId = _complaintTypeId(
                                chat?.type ?? widget.chatType,
                              );

                              final pressable = SelectableMessageRow(
                                message: message,
                                isMe: isMe,
                                selectedIds: _selectedIds,
                                selectionAnim: _selectionAnim,
                                isSelectionActive: () => _selectionMode,
                                onToggleSelection: () =>
                                    _toggleSelection(message),
                                onEnterSelection: () =>
                                    _enterSelection(message),
                                onStartTextSelection: (pos) =>
                                    _startTextSelection(message, pos),
                                onDragTextSelection: (pos) =>
                                    _textSelectionDrag.value = pos,
                                onDelete: () =>
                                    _confirmDeleteMessage(message.id, isMe),
                                onEdit: _canEditMessage(message)
                                    ? () => _startEditMessage(message)
                                    : null,
                                onReply: message.isControl
                                    ? null
                                    : () => _startReply(message),
                                onForward:
                                    message.isControl ||
                                        (chat?.forwardDisabled ?? false)
                                    ? null
                                    : () => _forwardMessages([message]),
                                allowCopy: !(chat?.copyDisabled ?? false),
                                onMarkUnread: message.isControl
                                    ? null
                                    : () => _markMessageUnread(message),
                                onPin: _canPinMessage(message)
                                    ? () => _togglePinMessage(message)
                                    : null,
                                isPinned: () =>
                                    chat?.pinnedMsgId ==
                                    int.tryParse(message.id),
                                loadReadBy: _canShowReadBy(message)
                                    ? () => _loadReadBy(message)
                                    : null,
                                onReaderTap: _openSenderProfile,
                                loadReportReasons: canReport
                                    ? () => _loadReportReasons(reportTypeId)
                                    : null,
                                onReport: canReport
                                    ? (reasonId) => _reportMessage(
                                        message,
                                        reportTypeId,
                                        reasonId,
                                      )
                                    : null,
                                onReact: message.isControl
                                    ? null
                                    : (emoji) =>
                                          _reactToMessage(message, emoji),
                                reactions: _reactionNotifierFor(message),
                                child: bubble,
                              );

                              final isChannel =
                                  (chat?.type ?? widget.chatType) == 'CHANNEL';
                              final swipeable = (message.isControl || isChannel)
                                  ? pressable
                                  : SwipeToReply(
                                      isMe: isMe,
                                      onReply: () => _startReply(message),
                                      child: pressable,
                                    );

                              final Widget child;
                              if (_deletingIds.contains(message.id)) {
                                child = DeletingMessageAnimation(
                                  key: ValueKey('del_${message.id}'),
                                  onComplete: () => _finalizeDelete(message.id),
                                  child: IgnorePointer(child: swipeable),
                                );
                              } else if (message.id == _lastSentId) {
                                child = SentMessageAnimation(
                                  key: ValueKey('anim_${message.id}'),
                                  onComplete: () {
                                    if (mounted) {
                                      _lastSentId = null;
                                      _bumpMessages();
                                    }
                                  },
                                  child: swipeable,
                                );
                              } else {
                                child = swipeable;
                              }

                              final highlightable =
                                  ValueListenableBuilder<String?>(
                                    valueListenable: _highlightMessageId,
                                    builder: (context, hl, c) =>
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          color: hl == message.id
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.12)
                                              : Colors.transparent,
                                          child: c,
                                        ),
                                    child: child,
                                  );

                              final builtItem = RepaintBoundary(
                                key: ValueKey('msg_${message.id}'),
                                child: KeyedSubtree(
                                  key: _keyForMessage(message.id),
                                  child: highlightable,
                                ),
                              );
                              return message.id == _prank.bubbleId
                                  ? KeyedSubtree(
                                      key: _prank.bubbleKey,
                                      child: builtItem,
                                    )
                                  : builtItem;
                            },
                            childCount:
                                items.length + 1 + (_isLoadingMore ? 1 : 0),
                            addRepaintBoundaries: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                      );
                    },
                  );
                },
              ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: _pinnedBannerHeight,
          builder: (context, pinnedHeight, child) => Positioned(
            top: _floatingDateTop(pinnedHeight),
            left: 0,
            right: 0,
            child: child!,
          ),
          child: IgnorePointer(
            child: ValueListenableBuilder<DateTime?>(
              valueListenable: _floatingDate,
              builder: (context, date, _) {
                if (date == null) return const SizedBox.shrink();
                return AnimatedBuilder(
                  animation: _floatingDateCurved,
                  builder: (context, child) {
                    final t = _floatingDateCurved.value;
                    return Opacity(
                      opacity: t,
                      child: Transform.scale(
                        scale: 0.82 + 0.18 * t,
                        child: child,
                      ),
                    );
                  },
                  child: _buildDateSeparatorWidget(
                    context,
                    date,
                    floating: true,
                  ),
                );
              },
            ),
          ),
        ),
        _buildScrollDownButton(),
      ],
    );
  }

  Widget _buildScrollDownButton() {
    final cs = Theme.of(context).colorScheme;
    final frosted = _effectiveChrome == ChatChromeStyle.transparent;
    return ValueListenableBuilder<double>(
      valueListenable: _composerHeight,
      builder: (context, height, child) => Positioned(
        right: _materialComposer
            ? (_materialIconSlot - _scrollDownSize) / 2
            : 16,
        bottom: (_composerUnderlap ? height : 0) +
            12 +
            (height < 8 ? MediaQuery.paddingOf(context).bottom : 0),
        child: child!,
      ),
      child: AnimatedBuilder(
        animation: _scrollDownCurved,
        builder: (context, child) {
          final t = _scrollDownCurved.value;
          if (t == 0) return const SizedBox.shrink();
          final backdropVisible = t >= 1;
          return Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.82 + 0.18 * t,
              child: SizedBox(
                width: _scrollDownSize,
                height: _scrollDownSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: GlossyPill(
                        color: frosted || _liquidChrome
                            ? AppFrost.glassTint(cs)
                            : null,
                        blurSigma: frosted && !_liquidChrome && backdropVisible
                            ? AppFrost.sigma
                            : null,
                        liquid: _liquidChrome,
                        backdropKey: _pillBackdrop,
                        elevated: true,
                        onTap: _onScrollDownTap,
                        child: child!,
                      ),
                    ),
                    Positioned(
                      top: -5,
                      right: -3,
                      child: ValueListenableBuilder<int>(
                        valueListenable: _newMessageCount,
                        builder: (context, count, _) => count <= 0
                            ? const SizedBox.shrink()
                            : AnimatedValueSwap<int>(
                                value: count > 99 ? 100 : count,
                                alignment: Alignment.centerRight,
                                builder: (context, value) =>
                                    _unreadBadge(cs, value),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        child: Center(
          child: Icon(
            Symbols.keyboard_arrow_down,
            color: cs.onSurface,
            weight: 500,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _unreadBadge(ColorScheme cs, int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 21),
      height: 21,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
