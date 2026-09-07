part of '../../chat_screen.dart';

extension _ChatNavigation on _ChatScreenState {
  void _scrollToBottom() {
    _flushDeferredMessages();
    _returnStack.clear();
    _newMessageCount.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final runway = pos.viewportDimension;
      final teleport = pos.pixels > runway * _scrollDownTeleportFactor;
      if (teleport) {
        _pinnedMessageId = null;
        _listEpoch++;
        _jumpCacheExtent.value = _jumpCacheExtentPx;
        _bumpMessages();
        _scrollController.jumpTo(runway);
      }
      unawaited(
        _scrollController
            .animateTo(
              pos.minScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            )
            .whenComplete(() {
              if (!teleport) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _jumpCacheExtent.value = null;
              });
            }),
      );
    });
  }

  void _updateScrollDownVisible() {
    if (!_scrollController.hasClients) {
      _setScrollDownVisible(_newMessageCount.value > 0);
      return;
    }
    final pos = _scrollController.position;
    final atBottom = _isNearBottom();
    if (_returnStack.isNotEmpty &&
        atBottom &&
        pos.userScrollDirection != ScrollDirection.idle) {
      _returnStack.clear();
    }
    if (atBottom && (_newMessageCount.value > 0 || _deferredIds.isNotEmpty)) {
      _clearNewMessageCountSoon();
    }
    final reveal = math.min(
      _scrollDownRevealExtent,
      pos.viewportDimension * _scrollDownRevealFactor,
    );
    _setScrollDownVisible(
      pos.pixels >= reveal ||
          _returnStack.isNotEmpty ||
          _newMessageCount.value > 0,
    );
  }

  void _setScrollDownVisible(bool show) {
    if (show == _scrollDownVisible) return;
    _scrollDownVisible = show;
    if (show) {
      _scrollDownAnimController.forward();
    } else {
      _scrollDownAnimController.reverse();
    }
  }

  void _noteMissedMessage() {
    _newMessageCount.value++;
    _updateScrollDownVisible();
  }

  void _clearNewMessageCountSoon() {
    if (_clearCountScheduled) return;
    _clearCountScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clearCountScheduled = false;
      if (!mounted || !_isNearBottom()) return;
      _flushDeferredMessages();
      _newMessageCount.value = 0;
      _updateScrollDownVisible();
    });
  }

  void _pushReturnAnchor(String messageId) {
    if (!_scrollController.hasClients) return;
    final listBox = _listKey.currentContext?.findRenderObject();
    final dy = _messageOffsetInList(messageId);
    final viewportH = listBox is RenderBox ? listBox.size.height : 0.0;
    final alignment = viewportH > 0 && dy != null
        ? (dy / viewportH).clamp(0.0, 1.0)
        : 0.5;
    _returnStack.add((
      id: messageId,
      pixels: _scrollController.position.pixels,
      alignment: alignment.toDouble(),
    ));
    if (!_scrollDownVisible) {
      _scrollDownVisible = true;
      _scrollDownAnimController.forward();
    }
  }

  void _onScrollDownTap() {
    if (_returningToAnchor || _navigatingToTarget) return;
    if (!_scrollController.hasClients) {
      _scrollToBottom();
      return;
    }
    final pixels = _scrollController.position.pixels;
    while (_returnStack.isNotEmpty) {
      final anchor = _returnStack.removeLast();
      if (anchor.pixels < pixels && _messages.any((m) => m.id == anchor.id)) {
        _returningToAnchor = true;
        unawaited(
          _returnToAnchor(
            anchor,
          ).whenComplete(() => _returningToAnchor = false),
        );
        return;
      }
    }
    _scrollToBottom();
  }

  Future<void> _returnToAnchor(
    ({String id, double pixels, double alignment}) anchor,
  ) async {
    final pos = _scrollController.position;
    final runway = pos.viewportDimension;
    final target = anchor.pixels.clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    final distance = (pos.pixels - target).abs();
    final far = distance > runway * _scrollDownTeleportFactor;

    if (!far) {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
      await _scrollToMessagePrecise(anchor.id, alignment: anchor.alignment);
      return;
    }

    _jumpCacheExtent.value = _jumpCacheExtentPx;
    if (target + runway < distance) {
      _listEpoch++;
      _bumpMessages();
      _scrollController.jumpTo(target + runway);
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
    }
    await _scrollToMessagePrecise(anchor.id, alignment: anchor.alignment);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumpCacheExtent.value = null;
    });
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <= 120;
  }

  void _startReply(CachedMessage message) {
    _cancelForward();
    _replyTo.value = message;
    _replySourceChatId = null;
    _messageFocusNode.requestFocus();
  }

  void _cancelReply() {
    _replyTo.value = null;
    _replySourceChatId = null;
  }

  Future<void> _pickReplyChat() async {
    final reply = _replyTo.value;
    if (reply == null) return;
    if (reply.id.startsWith('temp_')) {
      showCustomNotification(context, 'Сообщение ещё не отправлено');
      return;
    }

    final sourceChatId = _replySourceChatId ?? widget.chatId;
    final target = await openForwardScreen(context: context);
    if (target == null || !mounted) return;

    if (target.chatId == widget.chatId) {
      _replySourceChatId = sourceChatId == widget.chatId ? null : sourceChatId;
      _messageFocusNode.requestFocus();
      return;
    }

    await _deps.chats.ensureChatCached(_deps.api, _myId, target.chatId);
    if (!mounted) return;
    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: target.chatId,
        name: target.name,
        imageUrl: target.imageUrl,
        chatType: target.chatType,
        replyRequest: ReplyRequest(sourceChatId: sourceChatId, message: reply),
      ),
    );
  }

  void _openSenderProfile(int senderId) {
    if (senderId == 0 || senderId == _myId) return;
    unawaited(
      openContactDialogProfile(
        context,
        contactId: senderId,
        name: ContactCache.get(senderId) ?? 'User #$senderId',
        avatarUrl: ContactCache.getAvatar(senderId),
      ),
    );
  }

  void _openForwardedSource(ForwardedMessageAttachment forwarded) {
    if (forwarded.isChannel) {
      unawaited(_openForwardedChannel(forwarded));
      return;
    }
    final senderId = forwarded.originalSenderId;
    if (senderId == 0 || senderId == _myId) return;
    unawaited(
      openContactDialogProfile(
        context,
        contactId: senderId,
        name:
            forwarded.originalSenderName ??
            ContactCache.get(senderId) ??
            'User #$senderId',
        avatarUrl:
            forwarded.originalSenderAvatar ?? ContactCache.getAvatar(senderId),
      ),
    );
  }

  Future<void> _openForwardedChannel(
    ForwardedMessageAttachment forwarded,
  ) async {
    final sourceChatId = forwarded.originalChatId;
    if (sourceChatId == null) {
      showCustomNotification(context, 'Канал недоступен');
      return;
    }
    final sourceMessageId = forwarded.originalMessageId;
    if (sourceChatId == widget.chatId) {
      if (sourceMessageId == null) return;
      _beginTargetNavigation();
      await _runGoToMessage(sourceMessageId, forwarded.originalTime ?? 0);
      return;
    }

    await _deps.chats.ensureChatCached(_deps.api, _myId, sourceChatId);
    if (!mounted) return;
    final cached = await _deps.chats.getChat(_myId, sourceChatId);
    if (!mounted) return;
    final channel = cached.isEmpty ? null : cached.first;
    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: sourceChatId,
        name: channel?.title ?? forwarded.originalSenderName ?? 'Канал',
        imageUrl: channel?.iconUrl ?? forwarded.originalSenderAvatar ?? '',
        chatType: channel?.type ?? 'CHANNEL',
        initialMessageId: sourceMessageId,
        initialMessageTime: forwarded.originalTime,
      ),
    );
  }

  void _openStickerPack(StickerAttachment sticker) {
    final stickerId = int.tryParse(sticker.stickerId ?? '');
    if (stickerId == null) {
      showCustomNotification(context, 'Стикерпак недоступен');
      return;
    }
    showStickerPackSheet(
      context,
      stickerId: stickerId,
      knownSetId: int.tryParse(sticker.stickerPackId ?? ''),
    );
  }

  void _jumpToMessage(String messageId, {String? fromId}) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) {
      showCustomNotification(context, 'Сообщение не загружено');
      return;
    }

    if (fromId != null) _pushReturnAnchor(fromId);

    final key = _keyForMessage(messageId);
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.4,
      );
    } else {
      unawaited(_scrollToMessagePrecise(messageId, alignment: 0.4));
    }

    _highlightTimer?.cancel();
    _highlightMessageId.value = messageId;
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_highlightMessageId.value == messageId) {
        _highlightMessageId.value = null;
      }
    });
  }

  GlobalKey _keyForMessage(String messageId) =>
      _messageKeys.putIfAbsent(messageId, () => GlobalKey());

  void _openSearch() {
    if (_search.searchMode.value || _selectionMode) return;
    _search.searchMode.value = true;
    _searchAnim.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _search.searchMode.value) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    if (!_search.searchMode.value) return;
    _searchFocusNode.unfocus();
    _searchAnim.reverse();
    _search.reset();
  }

  Future<void> _navigateToInitialMessage() async {
    final id = widget.initialMessageId;
    if (id == null) {
      _finishTargetNavigation();
      return;
    }
    await _runGoToMessage(id, widget.initialMessageTime ?? 0);
  }

  Future<void> _runGoToMessage(String id, int targetTime) async {
    final gen = _chatController.sessionGen;
    await WidgetsBinding.instance.endOfFrame;
    if (!_sessionAlive(gen)) return;

    if (!_messages.any((m) => m.id == id)) {
      await _loadMessageWindow(id, targetTime);
      if (!_sessionAlive(gen)) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!_sessionAlive(gen)) return;
    }

    if (!_messages.any((m) => m.id == id)) {
      if (mounted) showCustomNotification(context, 'Сообщение не загружено');
      _finishTargetNavigation();
      return;
    }

    _highlightTimer?.cancel();
    _highlightMessageId.value = id;
    _highlightTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      if (_highlightMessageId.value == id) _highlightMessageId.value = null;
    });

    await _scrollToMessagePrecise(id);
    _finishTargetNavigation();
  }

  ({int min, int max})? _laidOutMessageRange(List<Object> items) {
    int? lo;
    int? hi;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (it is! ChatListMessageItem) continue;
      final ro = _keyForMessage(
        it.message.id,
      ).currentContext?.findRenderObject();
      if (ro is RenderBox && ro.attached) {
        lo ??= i;
        hi = i;
      }
    }
    if (lo == null) return null;
    return (min: lo, max: hi!);
  }

  Future<void> _scrollToMessagePrecise(
    String id, {
    double alignment = 0.32,
  }) async {
    if (!mounted || !_scrollController.hasClients) return;
    if (_messages.indexWhere((m) => m.id == id) == -1) return;

    final epoch = _userGestureEpoch;
    _historyAutoloadSuppressCount++;
    _holdReadMarker();
    try {
      var stable = 0;
      for (var iter = 0; iter < 120; iter++) {
        if (!mounted || !_scrollController.hasClients) return;
        if (_userGestureEpoch != epoch) return;
        final listObj = _listKey.currentContext?.findRenderObject();
        final boxObj = _keyForMessage(id).currentContext?.findRenderObject();
        final p = _scrollController.position;

        if (listObj is RenderBox && boxObj is RenderBox && boxObj.attached) {
          final viewportH = listObj.size.height;
          final actualTop = boxObj
              .localToGlobal(Offset.zero, ancestor: listObj)
              .dy;
          final desiredTop = alignment * viewportH;
          final delta = desiredTop - actualTop;
          final target = (p.pixels + delta).clamp(
            p.minScrollExtent,
            p.maxScrollExtent,
          );

          if (delta.abs() <= 2.0 || (target - p.pixels).abs() <= 1.0) {
            stable++;
            if (stable >= 4) return;
            await Future.delayed(const Duration(milliseconds: 60));
            continue;
          }
          stable = 0;
          _scrollController.jumpTo(target);
          await WidgetsBinding.instance.endOfFrame;
          continue;
        }

        stable = 0;
        final items = _buildCombinedItems();
        final pos = items.indexWhere(
          (it) => it is ChatListMessageItem && it.message.id == id,
        );
        if (pos == -1) return;

        final viewportH = listObj is RenderBox ? listObj.size.height : 600.0;
        var stepMag = viewportH * 0.8;
        if (stepMag > 700) stepMag = 700;

        final range = _laidOutMessageRange(items);
        final step = (range != null && pos > range.max) ? -stepMag : stepMag;

        final target = (p.pixels + step).clamp(
          p.minScrollExtent,
          p.maxScrollExtent,
        );
        if ((target - p.pixels).abs() < 1.0) return;
        _scrollController.jumpTo(target);
        await WidgetsBinding.instance.endOfFrame;
      }
    } finally {
      _historyAutoloadSuppressCount--;
      _releaseReadMarker();
    }
  }

  Future<void> _openSearchResult(MessageSearchResult result) async {
    _closeSearch();
    if (_messages.any((m) => m.id == result.id)) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _scrollToLoadedMessage(result.id);
      return;
    }
    setState(_beginTargetNavigation);
    await _runGoToMessage(result.id, result.time);
  }

  void _scrollToLoadedMessage(
    String messageId, {
    double alignment = 0.4,
    bool highlight = true,
    bool notifyIfMissing = true,
    VoidCallback? onSettled,
  }) {
    void settle() {
      _releaseReadMarker();
      onSettled?.call();
    }

    _holdReadMarker();
    if (!_scrollController.hasClients) {
      settle();
      return;
    }
    if (_deferredIds.contains(messageId)) _flushDeferredMessages();
    final items = _buildCombinedItems();
    final pos = items.indexWhere(
      (it) => it is ChatListMessageItem && it.message.id == messageId,
    );
    if (pos == -1) {
      if (notifyIfMissing) {
        showCustomNotification(context, 'Сообщение не загружено');
      }
      settle();
      return;
    }

    final laidOut = _keyForMessage(
      messageId,
    ).currentContext?.findRenderObject();
    if (laidOut is! RenderBox || !laidOut.attached) {
      _jumpNearMessage(messageId);
    }

    if (highlight) {
      _highlightTimer?.cancel();
      _highlightMessageId.value = messageId;
      _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        if (_highlightMessageId.value == messageId) {
          _highlightMessageId.value = null;
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _alignLoadedMessage(messageId, alignment, 0, onSettled: settle),
    );
  }

  ({int oldest, int newest}) _visibleItemRange(
    List<Object> items,
    RenderBox listBox,
  ) {
    var oldest = -1;
    var newest = -1;
    final viewportBottom = listBox.size.height;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is! ChatListMessageItem) continue;
      final box = _messageKeys[item.message.id]?.currentContext
          ?.findRenderObject();
      if (box is! RenderBox || !box.attached) {
        if (oldest != -1) break;
        continue;
      }
      final top = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
      if (top + box.size.height <= 0 || top >= viewportBottom) {
        if (oldest != -1) break;
        continue;
      }
      if (oldest == -1) oldest = i;
      newest = i;
    }
    return (oldest: oldest, newest: newest);
  }

  double _jumpStepScreens(int index, ({int oldest, int newest}) visible) {
    if (visible.oldest == -1) return 1;
    final perScreen = visible.newest - visible.oldest + 1;
    if (perScreen <= 0) return 1;
    final away = index < visible.oldest
        ? visible.oldest - index
        : index - visible.newest;
    return (away / perScreen).clamp(1.0, _jumpStepMaxScreens).toDouble();
  }

  bool _jumpNearMessage(String messageId) {
    if (!_scrollController.hasClients) return false;
    final listBox = _listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || listBox.size.height <= 0) return false;
    final items = _buildCombinedItems();
    final index = items.indexWhere(
      (it) => it is ChatListMessageItem && it.message.id == messageId,
    );
    if (index == -1) return false;

    final visible = _visibleItemRange(items, listBox);
    final position = _scrollController.position;
    final step = position.viewportDimension * _jumpStepScreens(index, visible);
    final double next;
    if (visible.oldest == -1 || index < visible.oldest) {
      next = position.pixels + step;
    } else if (index > visible.newest) {
      next = position.pixels - step;
    } else {
      return false;
    }
    final clamped = next.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((clamped - position.pixels).abs() < 0.5) return false;
    _scrollController.jumpTo(clamped);
    return true;
  }

  void _alignLoadedMessage(
    String messageId,
    double alignment,
    int attempt, {
    int frames = 0,
    int? epoch,
    VoidCallback? onSettled,
  }) {
    if (!mounted ||
        !_scrollController.hasClients ||
        (epoch != null && epoch != _userGestureEpoch)) {
      onSettled?.call();
      return;
    }
    final listBox = _listKey.currentContext?.findRenderObject();
    final box = _keyForMessage(messageId).currentContext?.findRenderObject();
    if (listBox is! RenderBox || box is! RenderBox || !box.attached) {
      if (attempt >= _jumpStallLimit || frames >= _jumpFrameLimit) {
        onSettled?.call();
        return;
      }
      final moved = _jumpNearMessage(messageId);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _alignLoadedMessage(
          messageId,
          alignment,
          moved ? 0 : attempt + 1,
          frames: frames + 1,
          epoch: epoch,
          onSettled: onSettled,
        ),
      );
      return;
    }

    final viewportHeight = listBox.size.height;
    final actualTop = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
    final desiredTop = alignment.clamp(0.0, 1.0) * viewportHeight;
    final delta = desiredTop - actualTop;
    final pos = _scrollController.position;
    final target = (pos.pixels + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );

    if (viewportHeight <= 0 ||
        delta.abs() <= 0.5 ||
        (target - pos.pixels).abs() <= 0.5 ||
        attempt >= _jumpStallLimit ||
        frames >= _jumpFrameLimit) {
      onSettled?.call();
      return;
    }

    _scrollController.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _alignLoadedMessage(
        messageId,
        alignment,
        attempt + 1,
        frames: frames + 1,
        epoch: epoch,
        onSettled: onSettled,
      ),
    );
  }

  String _searchSenderName(int senderId) {
    if (senderId == _myId) return 'Вы';
    final cached = ContactCache.get(senderId);
    if (cached != null && cached.isNotEmpty) return cached;
    if (widget.chatType == 'DIALOG') return widget.name;
    return 'Пользователь';
  }

  String? _searchSenderAvatar(int senderId) {
    final cached = ContactCache.getAvatar(senderId);
    if (cached != null && cached.isNotEmpty) return cached;
    if (senderId != _myId &&
        widget.chatType == 'DIALOG' &&
        widget.imageUrl.isNotEmpty) {
      return widget.imageUrl;
    }
    return null;
  }

  int _firstUnreadIndex() {
    final anchor = _unreadAnchorTime;
    if (anchor == null) return -1;
    return _messages.indexWhere((m) => m.time > anchor);
  }

  List<Object> _buildCombinedItems() {
    final visible = _visibleMessageCount;
    final key = Object.hash(
      _messagesRev.value,
      _messages.length,
      visible,
      _unreadAnchorTime,
    );
    final cached = _combinedItemsCache;
    if (cached != null && _combinedItemsKey == key) return cached;

    final unreadIndex = _firstUnreadIndex();

    final List<Object> items = [];
    final Set<int> usedDates = {};

    for (int i = 0; i < visible; i++) {
      final msg = _messages[i];
      final msgDate = DateTime.fromMillisecondsSinceEpoch(msg.time);
      final dayMillis = DateTime(
        msgDate.year,
        msgDate.month,
        msgDate.day,
      ).millisecondsSinceEpoch;

      bool needSeparator = i == 0;
      if (!needSeparator) {
        final prevDate = DateTime.fromMillisecondsSinceEpoch(
          _messages[i - 1].time,
        );
        final prevDayMillis = DateTime(
          prevDate.year,
          prevDate.month,
          prevDate.day,
        ).millisecondsSinceEpoch;
        needSeparator = dayMillis != prevDayMillis;
      }

      if (needSeparator) {
        _separatorKeys.putIfAbsent(dayMillis, () => GlobalKey());
        usedDates.add(dayMillis);
        items.add(
          DateSeparatorItem(
            DateTime.fromMillisecondsSinceEpoch(dayMillis),
            _separatorKeys[dayMillis]!,
          ),
        );
      }

      if (i == unreadIndex) {
        items.add(const UnreadSeparatorItem());
      }

      items.add(ChatListMessageItem(msg, i));
    }

    _separatorKeys.removeWhere((k, _) => !usedDates.contains(k));
    _combinedItemsCache = items;
    _combinedItemsKey = key;
    return items;
  }

  void _onScrollForDate() {
    if (!_scrollController.hasClients) return;

    _floatingDateTimer?.cancel();
    _floatingDateTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) _floatingDateAnimController.reverse();
    });

    if (_floatingDateScheduled) return;
    _floatingDateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _floatingDateScheduled = false;
      _updateFloatingDate();
    });
  }

  void _updateFloatingDate() {
    if (!mounted || _separatorKeys.isEmpty) return;
    DateTime? result;

    final listRenderBox = _listKey.currentContext?.findRenderObject();
    if (listRenderBox is! RenderBox) return;

    _separatorKeys.forEach((dayMillis, gkey) {
      final ctx = gkey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject();
      if (box is! RenderBox) return;
      final pos = box.localToGlobal(Offset.zero, ancestor: listRenderBox);
      if (pos.dy + box.size.height < 4) {
        final date = DateTime.fromMillisecondsSinceEpoch(dayMillis);
        if (result == null || date.isAfter(result!)) {
          result = date;
        }
      }
    });

    if (result == null) return;

    final bool dateChanged = result != _floatingDate.value;
    _floatingDate.value = result;

    if (dateChanged) {
      _floatingDateAnimController.forward(from: 0);
    } else {
      _floatingDateAnimController.forward();
    }
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Сегодня';
    if (d == yesterday) return 'Вчера';

    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    if (date.year == now.year) {
      return '${date.day} ${months[date.month - 1]}';
    }
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
