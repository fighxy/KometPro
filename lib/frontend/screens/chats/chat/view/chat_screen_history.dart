part of '../../chat_screen.dart';

extension _ChatHistoryLoad on _ChatScreenState {
  Future<void> _fastPreloadCache() async {
    final p = await AppDatabase.loadActiveProfile();
    if (!mounted) return;
    _myId = p?.id ?? 0;
    if (p != null && p.id != 0) {
      final myName = [
        p.firstName,
        p.lastName,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
      if (myName.isNotEmpty) ContactCache.put(p.id, myName);
      ContactCache.putAvatar(p.id, p.baseUrl);
    }
    if (_commentsMode) return;
    _restoreDraft();
    unawaited(_loadPeerKind());
    unawaited(_loadWallpaper());
    unawaited(_loadEncryption());
    unawaited(_refreshBadge());

    try {
      final chatRows = await _deps.chats.getChat(_myId, widget.chatId);
      if (!mounted) return;
      if (chatRows.isNotEmpty) {
        final channelSubscribed =
            widget.chatType != 'CHANNEL' ||
            await AppDatabase.isChatInList(_myId, widget.chatId);
        if (!mounted) return;
        setState(() {
          chat = chatRows.first;
          if (widget.chatType == 'CHANNEL') {
            _previewChat = !channelSubscribed;
          }
        });
        _bumpMessages();
        _seedPresenceFromChat();
        _recomputeHeaderStatus();
        _syncOtherReadTime();
      }
    } catch (_) {}

    _resolveUnreadAnchor();

    final cached = MessageSessionCache.get(_myId, widget.chatId);
    if (cached != null && cached.messages.isNotEmpty) {
      setState(() {
        _messages = List<CachedMessage>.of(cached.messages);
        _deferredIds.clear();
        _hasMoreHistory = !cached.reachedStart;
        _messagesRev.value++;
      });
      _mergePendingMedia();
      _syncReactionNotifiersFromMessages();
      _requestCommentCounts();
      _revealOrHoldInitial();
      return;
    }

    final firstRows = await AppDatabase.loadMessages(
      _myId,
      widget.chatId,
      limit: 20,
      onlyVisible: !KometSettings.viewDeleted.value,
    );
    if (!mounted) return;
    if (firstRows.isNotEmpty) {
      final first = firstRows.reversed
          .map((r) => CachedMessage.fromDbRow(r))
          .toList();
      setState(() {
        _messages = first;
        _deferredIds.clear();
        _messagesRev.value++;
      });
      _mergePendingMedia();
      _requestCommentCounts();
      _revealOrHoldInitial();
    }
  }

  void _resolveUnreadAnchor() {
    final c = chat;
    _readMarkTime = c?.participants[_myId] ?? 0;
    if (c == null || c.unreadCount <= 0) {
      _unreadAnchorTime = null;
    } else {
      final myMark = c.participants[_myId] ?? 0;
      _unreadAnchorTime = myMark > 0 ? myMark : null;
    }
    _awaitingPosition = c != null && c.unreadCount > 0;
  }

  void _resolveCountBasedAnchor() {
    final c = chat;
    if (c == null || c.unreadCount <= 0 || _messages.isEmpty) return;
    final unread = c.unreadCount;
    if (_messages.length > unread) {
      _unreadAnchorTime = _messages[_messages.length - unread - 1].time;
    } else if (!_hasMoreHistory) {
      _unreadAnchorTime = _messages.first.time - 1;
    }
  }

  void _revealOrHoldInitial() {
    if (_awaitingPosition && !_canPositionNow()) return;
    setState(() {
      _isLoading = false;
      _onLoadingFinished();
    });
  }

  bool _canPositionNow() {
    if (_unreadAnchorTime == null) _resolveCountBasedAnchor();
    final ua = _unreadAnchorTime;
    if (ua == null) return false;
    final firstUnread = _messages.indexWhere((m) => m.time > ua);
    if (firstUnread == -1) return _newestMessageLoaded();
    return firstUnread > 0 || !_hasMoreHistory;
  }

  bool _newestMessageLoaded() {
    if (_messages.isEmpty) return false;
    final serverLast = chat?.lastMsgTime ?? 0;
    return _messages.last.time >= serverLast;
  }

  void _onFirstFrameRendered(Duration _) {
    if (!mounted) return;
    if (widget.embedded) {
      _routeSettle.settleNow();
    } else {
      _routeSettle.bind(context);
    }
    _routeSettle.run(_kickoffHistory);
  }

  void _kickoffHistory() {
    _animojiHold.value = false;
    if (_historyKickedOff) return;
    _historyKickedOff = true;
    _shimmerStartTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted || !_isLoading) return;
      _shimmerController.repeat();
    });
    unawaited(_loadHistory().then((_) => _sendPendingBotStart()));
  }

  bool get _isRouteCurrent {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  Future<void> _sendPendingBotStart() async {
    final payload = widget.botStartPayload;
    if (payload == null || _botStartRequested || !mounted) return;
    _botStartRequested = true;
    await _sendBotStart(payload);
  }

  Future<void> _sendBotStart(String startPayload) async {
    if (_myId == 0) {
      final profile = await AppDatabase.loadActiveProfile();
      if (!mounted) return;
      _myId = profile?.id ?? 0;
    }
    try {
      final sent = await _chatController.sendBotStart(
        startPayload,
      );
      if (!mounted) return;
      if (sent == null) {
        showCustomNotification(context, 'Не удалось запустить бота');
        return;
      }
      await _persistOutgoing(
        CachedMessage.fromPushPayload(_myId, widget.chatId, sent),
      );
    } catch (_) {
      if (mounted) showCustomNotification(context, 'Не удалось запустить бота');
    }
  }

  void _onLoadingFinished() {
    _shimmerStartTimer?.cancel();
    _shimmerStartTimer = null;
    _applyInitialPositioning();
  }

  void _recordScrollPixels() {
    if (!_scrollController.hasClients) return;
    if (_initialPositionDone &&
        _scrollController.position.userScrollDirection !=
            ScrollDirection.idle) {
      _userDidScroll = true;
      _pinnedMessageId = null;
    }
  }

  double _unreadAnchorAlignment() {
    final listBox = _listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || listBox.size.height <= 0) {
      return _unreadAnchorFallbackAlignment;
    }
    final separator =
        _unreadSeparatorKey.currentContext?.size?.height ??
        _unreadSeparatorHeight;
    final glossy = AppVisualStyle.current.value.glossyChrome;
    final chromeBottom = _effectiveChrome == ChatChromeStyle.color
        ? 0.0
        : MediaQuery.paddingOf(context).top +
              (glossy ? _glossyHeaderHeight : kToolbarHeight) +
              _pinnedBannerHeight.value;
    final desiredTop = chromeBottom + separator + _unreadSeparatorInset;
    return (desiredTop / listBox.size.height).clamp(0.0, 0.5);
  }

  void _positionToMessage(String messageId) {
    _pinnedMessageId = messageId;
    _jumpCacheExtent.value = _jumpCacheExtentPx;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pinnedAlignment = _unreadAnchorAlignment();
      _scrollToLoadedMessage(
        messageId,
        alignment: _pinnedAlignment,
        highlight: false,
        notifyIfMissing: false,
        onSettled: () {
          if (!mounted) return;
          setState(_markPositioned);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _jumpCacheExtent.value = null;
            _reapplyPinIfNeeded();
          });
        },
      );
    });
  }

  void _reapplyPinIfNeeded() {
    final id = _pinnedMessageId;
    if (id == null || _userDidScroll || !_scrollController.hasClients) return;
    _holdReadMarker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pinnedMessageId != id || _userDidScroll) {
        _releaseReadMarker();
        return;
      }
      _alignLoadedMessage(
        id,
        _pinnedAlignment,
        0,
        onSettled: _releaseReadMarker,
      );
    });
  }

  void _applyInitialPositioning() {
    if (_initialPositionDone) {
      if (_shimmerController.isAnimating) _shimmerController.stop();
      _scheduleReadMarker();
      return;
    }
    if (_positioningInFlight) return;
    if (_commentsMode) {
      _initialPositionDone = true;
      _markPositioned();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
      return;
    }
    if (_messages.isEmpty) {
      if (!_hasMoreHistory) _markPositioned();
      return;
    }

    final c = chat;
    if (c != null && c.unreadCount > 0) {
      if (_unreadAnchorTime == null) _resolveCountBasedAnchor();
      final ua = _unreadAnchorTime;
      if (ua == null) {
        if (_hasMoreHistory) {
          _positioningInFlight = true;
          unawaited(_loadUntilUnreadReady());
        } else {
          _markPositioned();
        }
        return;
      }
      final firstUnread = _messages.indexWhere((m) => m.time > ua);
      if (firstUnread == -1) {
        _markPositioned();
        return;
      }
      if (firstUnread > 0 || !_hasMoreHistory) {
        _initialPositionDone = true;
        _positionToMessage(_messages[firstUnread].id);
      } else {
        _positioningInFlight = true;
        unawaited(_loadUntilUnreadReady());
      }
      return;
    }

    _markPositioned();
  }

  void _markPositioned() {
    _positioningInFlight = false;
    _initialPositionDone = true;
    _awaitingPosition = false;
    _isLoading = false;
    if (_shimmerController.isAnimating) _shimmerController.stop();
    _scheduleReadMarker();
    _maybeRunInitialTarget();
  }

  void _maybeRunInitialTarget() {
    if (_initialTargetHandled || widget.initialMessageId == null) return;
    _initialTargetHandled = true;
    _beginTargetNavigation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_navigateToInitialMessage());
    });
  }

  void _beginTargetNavigation() {
    _navigatingToTarget = true;
    _jumpCacheExtent.value = _jumpCacheExtentPx;
    _goToMessageSettleTimer?.cancel();
    if (!_shimmerController.isAnimating) _shimmerController.repeat();
  }

  void _finishTargetNavigation() {
    _goToMessageSettleTimer?.cancel();
    if (!mounted) {
      _navigatingToTarget = false;
      return;
    }
    if (_navigatingToTarget) {
      setState(() => _navigatingToTarget = false);
    }
    if (_shimmerController.isAnimating) _shimmerController.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumpCacheExtent.value = null;
    });
  }

  void _openChatInfo({ChatInfoTab? initialTab}) {
    final navigator = Navigator.of(context);
    final chatRoute = ModalRoute.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatInfoScreen(
          chatId: widget.chatId,
          name: _headerName(),
          imageUrl: _headerAvatarUrl(),
          chatType: widget.chatType,
          heroTag: _profileHeroTag,
          initialTab: initialTab,
          openedFromChat: true,
          onJumpToMessage: (chatRoute == null || widget.embedded)
              ? null
              : (messageId, time) {
                  navigator.popUntil((r) => r == chatRoute);
                  _requestGoToMessage(messageId, time);
                },
        ),
      ),
    );
  }

  void _forwardMessageById(String messageId) {
    final message = _messages.where((m) => m.id == messageId).firstOrNull;
    if (message == null) {
      showCustomNotification(context, 'Сообщение не загружено');
      return;
    }
    unawaited(_forwardMessages([message]));
  }

  void _requestGoToMessage(String id, int time) {
    if (!mounted) return;
    setState(_beginTargetNavigation);
    _goToMessageSettleTimer = Timer(const Duration(milliseconds: 340), () {
      if (mounted) unawaited(_runGoToMessage(id, time));
    });
  }

  Future<void> _loadUntilUnreadReady() async {
    await _walkHistoryBack(
      reached: () {
        if (_unreadAnchorTime == null) _resolveCountBasedAnchor();
        final ua = _unreadAnchorTime;
        return ua != null && _messages.indexWhere((m) => m.time > ua) > 0;
      },
      maxPages: 15,
    );
    if (!mounted) return;
    if (_unreadAnchorTime == null) _resolveCountBasedAnchor();
    final ua = _unreadAnchorTime;
    final idx = ua == null ? -1 : _messages.indexWhere((m) => m.time > ua);
    _positioningInFlight = false;
    _initialPositionDone = true;
    if (idx >= 0) {
      _positionToMessage(_messages[idx].id);
    } else {
      setState(_markPositioned);
    }
  }

  void _scheduleReadMarker() => _readMarker.schedule();

  void _holdReadMarker() => _readMarker.hold();

  void _releaseReadMarker() => _readMarker.release();

  void _updateReadMarker() {
    if (_commentsMode) return;
    if (!mounted || _myId == 0 || _messages.isEmpty) return;
    if (_awaitingPosition || !_initialPositionDone) return;
    if (_readMarker.held) return;
    if (!_scrollController.hasClients) return;
    final listBox = _listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox) return;
    final viewportBottom = listBox.size.height;
    if (viewportBottom <= 0) return;

    CachedMessage? candidate;
    int topIndex = -1;
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      final ctx = _messageKeys[m.id]?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
      final bottom = top + box.size.height;
      if (bottom <= 0 || top >= viewportBottom) continue;
      candidate ??= m;
      topIndex = i;
    }
    if (candidate == null) return;

    final atBottom = candidate.id == _messages.last.id;

    if (_unreadAnchorTime != null &&
        _userDidScroll &&
        _unreadSeparatorScrolledPast(
          atBottom,
          topIndex,
          listBox,
          viewportBottom,
        )) {
      _unreadAnchorTime = null;
      _bumpMessages();
    }

    if (candidate.time <= _readMarkTime) return;
    _readMarkTime = candidate.time;
    final remaining = _messages
        .where((m) => m.time > _readMarkTime && m.senderId != _myId)
        .length;
    unawaited(
      _deps.chats.markReadUpTo(
        _deps.api,
        _myId,
        widget.chatId,
        candidate.id,
        candidate.time,
        remaining: remaining,
      ),
    );
  }

  bool _unreadSeparatorScrolledPast(
    bool atBottom,
    int topIndex,
    RenderBox listBox,
    double viewportBottom,
  ) {
    if (atBottom) return true;
    final ua = _unreadAnchorTime;
    if (ua == null) return false;
    final firstUnread = _messages.indexWhere((m) => m.time > ua);
    if (firstUnread == -1) return true;
    if (topIndex >= 0 && topIndex > firstUnread) return true;
    final box = _messageKeys[_messages[firstUnread].id]?.currentContext
        ?.findRenderObject();
    if (box is RenderBox && box.attached) {
      final top = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
      if (top <= 0) return true;
    }
    return false;
  }

  Future<void> _markMessageUnread(CachedMessage message) async {
    final unread = await _deps.chats.markUnread(
      _deps.api,
      _myId,
      widget.chatId,
      message.time,
    );
    if (!mounted) return;
    if (unread == null) {
      showCustomNotification(context, 'Не удалось пометить непрочитанным');
      return;
    }
    Navigator.of(context).pop();
  }

  bool _canShowReadBy(CachedMessage message) {
    if (message.isControl || message.deleted) return false;
    if (int.tryParse(message.id) == null) return false;
    final type = chat?.type ?? widget.chatType;
    return type == 'CHAT' || type == 'GROUP';
  }

  Future<List<MessageReader>> _loadReadBy(CachedMessage message) async {
    final marks = await _deps.chats.getReadMarks(_deps.api, _myId, widget.chatId);
    final reactions = await _deps.messages.getDetailedReactions(
      widget.chatId,
      message.id,
    );

    final readerIds = <int>{
      ...marks.entries.where((e) => e.value >= message.time).map((e) => e.key),
      ...reactions.keys,
    }..removeAll({_myId, message.senderId});
    if (readerIds.isEmpty || !mounted) return const [];

    await _deps.messages.ensureContactNames(readerIds);
    await _deps.animoji.ensureLoaded();
    if (!mounted) return const [];

    final animojiByEmoji = {
      for (final animoji in _deps.animoji.animojis)
        EmojiKeywordIndex.normalize(animoji.emoji): animoji,
    };
    final unknownName = AppLocalizations.of(
      context,
    )!.msgActionsReadByUnknownUser;

    final readers = readerIds.map((id) {
      final emoji = reactions[id];
      final animoji = emoji == null
          ? null
          : animojiByEmoji[EmojiKeywordIndex.normalize(emoji)];
      final name = ContactCache.get(id);
      return MessageReader(
        id: id,
        name: name == null || name.isEmpty ? unknownName : name,
        avatarUrl: ContactCache.getAvatar(id),
        reaction: emoji == null
            ? null
            : ReactionEmoji(
                emoji: emoji,
                animationUrl: animoji?.lottieUrl,
                staticUrl: animoji?.iconUrl,
              ),
      );
    }).toList();

    readers.sort((a, b) {
      final aReacted = a.reaction != null;
      final bReacted = b.reaction != null;
      if (aReacted != bReacted) return aReacted ? -1 : 1;
      return (marks[b.id] ?? 0).compareTo(marks[a.id] ?? 0);
    });
    return readers;
  }

  bool _canPinMessage(CachedMessage message) {
    if (message.isControl) return false;
    if (int.tryParse(message.id) == null) return false;
    return chat?.canPinMessages(_myId) ?? false;
  }

  Future<void> _togglePinMessage(CachedMessage message) async {
    final messageId = int.tryParse(message.id);
    if (messageId == null) return;
    final previousChat = chat;
    final willUnpin = chat?.pinnedMsgId == messageId;
    if (willUnpin) {
      _applyPinnedMessageLocally();
    } else {
      final preview = _pinnedPreviewFor(message);
      _applyPinnedMessageLocally(
        messageId: messageId,
        text: preview.text,
        time: message.time,
        isPreview: preview.isPreview,
      );
    }
    final error = await _deps.chats.setPinnedMessage(
      _deps.api,
      chatId: widget.chatId,
      messageId: willUnpin ? null : messageId,
      notify: !willUnpin,
    );
    if (!mounted) return;
    if (error != null) {
      if (previousChat != null) setState(() => chat = previousChat);
      showCustomNotification(context, error);
      return;
    }
    showCustomNotification(
      context,
      willUnpin ? 'Сообщение откреплено' : 'Сообщение закреплено',
    );
  }

  Future<void> _unpinCurrentMessage() async {
    final previousChat = chat;
    _applyPinnedMessageLocally();
    final error = await _deps.chats.setPinnedMessage(
      _deps.api,
      chatId: widget.chatId,
      messageId: null,
      notify: false,
    );
    if (!mounted) return;
    if (error != null) {
      if (previousChat != null) setState(() => chat = previousChat);
      showCustomNotification(context, error);
      return;
    }
    showCustomNotification(context, 'Сообщение откреплено');
  }

  ({String? text, bool isPreview}) _pinnedPreviewFor(CachedMessage message) {
    final payload = message.payload;
    if (payload != null) return pinnedMessagePreview(payload);
    return pinnedMessagePreview({
      'text': message.text,
      'attaches':
          message.attachments?.map((a) => a.toMap()).toList() ?? const [],
    });
  }

  void _applyPinnedMessageLocally({
    int? messageId,
    String? text,
    int? time,
    bool isPreview = false,
  }) {
    final current = chat;
    if (current == null) return;
    setState(() {
      chat = current.copyWith(
        pinnedMsgId: messageId,
        pinnedMsgText: text,
        pinnedMsgTime: time,
        pinnedMsgIsPreview: isPreview,
      );
    });
  }

  void _jumpToPinnedMessage() {
    final id = chat?.pinnedMsgId;
    if (id == null) return;
    final messageId = id.toString();
    if (_messages.any((m) => m.id == messageId)) {
      _scrollToLoadedMessage(messageId);
      return;
    }
    setState(_beginTargetNavigation);
    unawaited(_runGoToMessage(messageId, chat?.pinnedMsgTime ?? 0));
  }

  void _onChatsBump() {
    unawaited(_reloadChatMeta());
    if (_badgeRefreshing) {
      _badgeRefreshQueued = true;
      return;
    }
    unawaited(_runBadgeRefresh());
  }

  Future<void> _reloadChatMeta() async {
    if (_myId == 0) return;
    final rows = await _deps.chats.getChat(_myId, widget.chatId);
    if (!mounted || rows.isEmpty) return;
    final fresh = rows.first;
    final current = chat;
    if (current != null &&
        current.pinnedMsgId == fresh.pinnedMsgId &&
        current.pinnedMsgText == fresh.pinnedMsgText &&
        current.pinnedMsgTime == fresh.pinnedMsgTime &&
        current.pinnedMsgIsPreview == fresh.pinnedMsgIsPreview &&
        current.owner == fresh.owner &&
        current.options.length == fresh.options.length &&
        current.options.containsAll(fresh.options) &&
        current.admins.length == fresh.admins.length &&
        current.admins.containsAll(fresh.admins)) {
      return;
    }
    setState(() => chat = fresh);
  }

  Future<void> _runBadgeRefresh() async {
    _badgeRefreshing = true;
    try {
      await _refreshBadge();
    } finally {
      _badgeRefreshing = false;
      if (_badgeRefreshQueued && mounted) {
        _badgeRefreshQueued = false;
        unawaited(_runBadgeRefresh());
      }
    }
  }

  Future<void> _refreshBadge() async {
    if (_myId == 0) return;
    final total = await AppDatabase.sumUnread(
      _myId,
      excludeChatId: widget.chatId,
      excludeChatIds: ArchivedChatsStore.instance.archivedChatIds(_myId),
    );
    if (mounted) _otherUnread.value = total;
  }

  Future<void> _loadHistory() async {
    if (_myId == 0) {
      final activeProfile = await AppDatabase.loadActiveProfile();
      if (!mounted) return;
      _myId = activeProfile?.id ?? 0;
    }
    if (_commentsMode) {
      await _loadCommentsHistory();
      return;
    }
    if (widget.chatType == 'DIALOG') {
      unawaited(_loadOtherPresence());
    }
    unawaited(_refreshScheduledCount());
    await _chatController.loadRemainingHistory(
      onApplyMerged: _applyMergedMessages,
      onLoadingFinished: () {
        setState(() {
          _isLoading = false;
          _onLoadingFinished();
        });
      },
      onPreview: () => _previewChat = true,
      onSenderNames: () {
        _loadForwardedSenderNames();
        _loadGroupSenderNames();
      },
    );
  }

  void _maybeLoadMoreHistory() {
    if (!_scrollController.hasClients) return;
    if (_historyAutoloadSuppressed) return;
    if (_isLoading) return;
    if (_commentsMode) {
      if (_commentsLoadingMore || !_commentsHasMore || _messages.isEmpty) {
        return;
      }
      final pos = _scrollController.position;
      if (pos.pixels - pos.minScrollExtent <= _historyPrefetchExtent) {
        unawaited(_loadMoreComments());
      }
      return;
    }
    _maybeFillGap();
    if (_isLoadingMore || !_hasMoreHistory) return;
    if (_messages.isEmpty) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    if (pos.maxScrollExtent - pos.pixels <= _historyPrefetchExtent) {
      unawaited(_loadMoreHistory());
    }
  }

  void _maybeFillGap() {
    final controller = _chatController;
    if (!controller.hasGap || controller.loadingGap) return;
    final oldestRendered = _oldestRenderedMessageTime();
    for (final gap in controller.gaps) {
      if (!ChatController.gapFillLeavesViewportInPlace(gap, oldestRendered)) {
        continue;
      }
      unawaited(_fillGapForward(gap));
      return;
    }
  }

  int? _oldestRenderedMessageTime() {
    for (final message in _messages) {
      final box = _messageKeys[message.id]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached) return message.time;
    }
    return null;
  }

  Future<void> _fillGapForward(HistoryGap gap) async {
    String? anchorId;
    double? anchorAt;
    double? anchorAlignment;
    final added = await _chatController.fillGapForward(
      gap,
      beforeApply: () {
        final id = _viewportAnchorId();
        anchorId = id;
        if (id == null) return;
        anchorAt = _messageContentOffset(id);
        anchorAlignment = _messageAlignmentInList(id);
      },
    );
    if (!mounted || added == 0) return;

    _syncReactionNotifiersFromMessages();
    _holdReadMarker();
    _bumpMessages();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      _releaseReadMarker();
      return;
    }

    final id = anchorId;
    final at = anchorAt;
    final alignment = anchorAlignment;
    if (id != null && at != null && !_restoreContentOffset(id, at)) {
      _historyAutoloadSuppressCount++;
      _alignLoadedMessage(
        id,
        alignment ?? 0,
        0,
        epoch: _userGestureEpoch,
        onSettled: () {
          _historyAutoloadSuppressCount--;
          _releaseReadMarker();
        },
      );
    } else {
      _releaseReadMarker();
    }
    _loadForwardedSenderNames();
    _loadGroupSenderNames();
  }

  int get _visibleMessageCount {
    if (_deferredIds.isEmpty) return _messages.length;
    var visible = _messages.length;
    while (visible > 0 && _deferredIds.contains(_messages[visible - 1].id)) {
      visible--;
    }
    return visible;
  }

  void _flushDeferredMessages() {
    if (_deferredIds.isEmpty) return;
    _deferredIds.clear();
    _bumpMessages();
  }

  String? _viewportAnchorId() {
    final listBox = _listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || !listBox.attached) return null;
    final height = listBox.size.height;
    String? newest;
    for (final message in _messages) {
      final box = _messageKeys[message.id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final dy = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
      if (dy >= 0 && dy <= height) newest = message.id;
    }
    return newest;
  }

  double? _messageOffsetInList(String messageId) {
    final listBox = _listKey.currentContext?.findRenderObject();
    final box = _keyForMessage(messageId).currentContext?.findRenderObject();
    if (listBox is! RenderBox || box is! RenderBox || !box.attached) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: listBox).dy;
  }

  double? _messageContentOffset(String messageId) {
    if (!_scrollController.hasClients) return null;
    final dy = _messageOffsetInList(messageId);
    if (dy == null) return null;
    return dy - _scrollController.position.pixels;
  }

  double? _messageAlignmentInList(String messageId) {
    final listBox = _listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || listBox.size.height <= 0) return null;
    final dy = _messageOffsetInList(messageId);
    if (dy == null) return null;
    return (dy / listBox.size.height).clamp(0.0, 1.0);
  }

  bool _restoreContentOffset(String messageId, double before) {
    if (!_scrollController.hasClients) return false;
    final after = _messageContentOffset(messageId);
    if (after == null) return false;
    final delta = before - after;
    if (delta.abs() <= 0.5) return true;
    final pos = _scrollController.position;
    final target = (pos.pixels + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if ((target - pos.pixels).abs() <= 0.5) return true;
    _scrollController.jumpTo(target);
    return true;
  }

  Future<void> _loadMessageWindow(String messageId, int targetTime) async {
    if (targetTime <= 0) {
      await _walkHistoryBack(
        reached: () => _messages.any((m) => m.id == messageId),
        maxPages: 10,
      );
      return;
    }

    _historyAutoloadSuppressCount++;
    try {
      await _chatController.loadMessageWindow(
        targetId: messageId,
        targetTime: targetTime,
      );
    } finally {
      _historyAutoloadSuppressCount--;
    }
    if (!mounted) return;
    _syncReactionNotifiersFromMessages();
    _bumpMessages();
    _loadForwardedSenderNames();
    _loadGroupSenderNames();
  }

  Future<void> _walkHistoryBack({
    required bool Function() reached,
    required int maxPages,
    int targetTime = 0,
  }) async {
    if (reached()) return;
    _historyAutoloadSuppressCount++;
    try {
      var page = 0;
      while (mounted &&
          page < maxPages &&
          _hasMoreHistory &&
          !reached() &&
          (_messages.isEmpty || _messages.first.time > targetTime)) {
        page++;
        final before = _messages.isEmpty ? 0 : _messages.first.time;
        await _loadMoreHistory(
          resolveSenderNames: false,
          pageSize: ChatController.historyWalkPageSize,
          persist: false,
        );
        if (!mounted) return;
        final after = _messages.isEmpty ? 0 : _messages.first.time;
        if (after == before) break;
      }
    } finally {
      _historyAutoloadSuppressCount--;
    }
    if (!mounted) return;
    _chatController.persistSessionCache();
    _loadForwardedSenderNames();
    _loadGroupSenderNames();
  }

  Future<void> _loadMoreHistory({
    bool resolveSenderNames = true,
    int? pageSize,
    bool persist = true,
  }) async {
    await _chatController.loadMoreHistory(
      pageSize: pageSize,
      persist: persist,
      onLoadingStarted: _bumpMessages,
      onLoaded: (added) {
        if (added > 0) _syncReactionNotifiersFromMessages();
        _bumpMessages();
        if (resolveSenderNames) {
          _loadForwardedSenderNames();
          _loadGroupSenderNames();
        }
      },
      onError: (_) {
        if (mounted) {
          _isLoadingMore = false;
          _bumpMessages();
        }
      },
    );
  }

  void _applyMergedMessages(
    List<CachedMessage> decodedDesc, {
    bool markLoaded = false,
  }) {
    final anchor = _captureViewportAnchor();
    final changed = _chatController.mergeMessages(decodedDesc);
    _requestCommentCounts();

    if (!changed && !markLoaded) return;

    setState(() {
      if (markLoaded) {
        _isLoading = false;
        _onLoadingFinished();
      }
    });
    if (changed) {
      _syncReactionNotifiersFromMessages();
      _pruneReactionNotifiers();
      _chatController.persistSessionCache();
      _restoreViewportAfterMerge(anchor);
      _reapplyPinIfNeeded();
    }
  }

  ({String id, double at, double alignment})? _captureViewportAnchor() {
    if (_pinnedMessageId != null && !_userDidScroll) return null;
    if (!_scrollController.hasClients || _isNearBottom()) return null;
    final id = _viewportAnchorId();
    if (id == null) return null;
    final at = _messageContentOffset(id);
    final alignment = _messageAlignmentInList(id);
    if (at == null || alignment == null) return null;
    return (id: id, at: at, alignment: alignment);
  }

  void _restoreViewportAfterMerge(
    ({String id, double at, double alignment})? anchor,
  ) {
    _holdReadMarker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || anchor == null) {
        _releaseReadMarker();
        return;
      }
      if (_restoreContentOffset(anchor.id, anchor.at)) {
        _releaseReadMarker();
        return;
      }
      _historyAutoloadSuppressCount++;
      _alignLoadedMessage(
        anchor.id,
        anchor.alignment,
        0,
        epoch: _userGestureEpoch,
        onSettled: () {
          _historyAutoloadSuppressCount--;
          _releaseReadMarker();
        },
      );
    });
  }

  void _requestCommentCounts() {
    if (_commentsMode) return;
    if ((chat?.type ?? widget.chatType) != 'CHANNEL') return;
    final pending = <String>[];
    for (final m in _messages) {
      if (m.isControl) continue;
      if (_commentCountsRequested.contains(m.id)) continue;
      _commentCountsRequested.add(m.id);
      pending.add(m.id);
    }
    if (pending.isEmpty) return;
    unawaited(
      _deps.comments.fetchInfo(
        accountId: _myId,
        chatId: widget.chatId,
        postIds: pending,
      ),
    );
  }

  void _onCommentsInfo(Map<String, CommentsInfo> info) {
    if (!mounted) return;
    var changed = false;
    for (final m in _messages) {
      final count = info[m.id]?.totalCount;
      if (count == null) continue;
      if (_commentCounts[m.id] != count) {
        _commentCounts[m.id] = count;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  String _commentsLabelFor(String postId) {
    final l10n = AppLocalizations.of(context)!;
    final count = _commentCounts[postId];
    if (count == null || count == 0) return l10n.commentsWrite;
    return l10n.commentsCount(count);
  }

  void _openComments(CachedMessage post) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: widget.chatId,
              name: widget.name,
              imageUrl: widget.imageUrl,
              chatType: 'CHANNEL',
              commentPostId: post.id,
              postMessage: _stripInlineKeyboard(post),
            ),
          ),
        )
        .then((_) => _refreshCommentCount(post.id));
  }

  void _refreshCommentCount(String postId) {
    if (!mounted) return;
    _commentCountsRequested.remove(postId);
    _requestCommentCounts();
  }

  CachedMessage _stripInlineKeyboard(CachedMessage post) {
    final attaches = post.attachments;
    if (attaches == null || attaches.isEmpty) return post;
    final filtered = attaches
        .where((a) => a.type != AttachmentType.inlineKeyboard)
        .toList();
    if (filtered.length == attaches.length) return post;
    return post.copyWith(attachments: filtered);
  }

  Future<void> _loadCommentsHistory() async {
    final post = widget.postMessage;
    final loaded = await _deps.comments.fetchHistory(
      _myId,
      widget.chatId,
      widget.commentPostId!,
      fromTime: post?.time ?? DateTime.now().millisecondsSinceEpoch,
      forward: 30,
      backward: 0,
    );
    if (!mounted) return;
    final comments = [...loaded]..sort((a, b) => a.time.compareTo(b.time));
    _messages = post != null ? [post, ...comments] : comments;
    _deferredIds.clear();
    _commentsHasMore = comments.isNotEmpty;
    _syncReactionNotifiersFromMessages();
    unawaited(_resolveCommentNames(comments));
    _bumpMessages();
    setState(() {
      _isLoading = false;
      _onLoadingFinished();
    });
  }

  Future<void> _loadMoreComments() async {
    if (_commentsLoadingMore || !_commentsHasMore || _messages.isEmpty) return;
    _commentsLoadingMore = true;
    final newest = _messages.last;
    try {
      final more = await _deps.comments.fetchHistory(
        _myId,
        widget.chatId,
        widget.commentPostId!,
        fromTime: newest.time,
        forward: 30,
        backward: 0,
      );
      if (!mounted) return;
      final existing = _messages.map((m) => m.id).toSet();
      final fresh = more.where((c) => !existing.contains(c.id)).toList();
      if (fresh.isEmpty) {
        _commentsHasMore = false;
      } else {
        _messages = [..._messages, ...fresh]
          ..sort((a, b) => a.time.compareTo(b.time));
        _syncReactionNotifiersFromMessages();
        unawaited(_resolveCommentNames(fresh));
        _bumpMessages();
      }
    } finally {
      _commentsLoadingMore = false;
    }
  }

  void _onLiveComment(CommentAddedEvent event) {
    if (!mounted) return;
    final comment = event.comment;
    if (comment.senderId == _myId) return;
    if (_messages.any((m) => m.id == comment.id)) return;
    final nearBottom = _isNearListBottom();
    if (!nearBottom) _deferredIds.add(comment.id);
    _messages.add(comment);
    _syncReactionNotifiersFromMessages();
    _bumpMessages();
    unawaited(_resolveCommentNames([comment]));
    if (nearBottom) {
      _scrollToBottom();
    } else {
      _noteMissedMessage();
    }
  }

  bool _isNearListBottom() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <= _historyPrefetchExtent;
  }

  Future<void> _resolveCommentNames(List<CachedMessage> list) async {
    final ids = list
        .map((m) => m.senderId)
        .where((id) => id != 0 && ContactCache.get(id) == null)
        .toSet();
    if (ids.isEmpty) return;
    final resolved = await _deps.messages.ensureContactNames(ids);
    if (resolved && mounted) _bumpMessages();
  }

  void _syncReactionNotifiersFromMessages() {
    for (final m in _messages) {
      if (_reactionNotifiers.containsKey(m.id)) continue;
      final info = m.payload?['reactionInfo'];
      _reactionNotifiers[m.id] = ValueNotifier(
        info is Map ? Map<String, dynamic>.from(info) : null,
      );
    }
  }
}
