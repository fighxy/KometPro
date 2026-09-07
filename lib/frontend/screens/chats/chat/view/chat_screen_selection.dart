part of '../../chat_screen.dart';

extension _ChatSelectionActions on _ChatScreenState {
  void _enterSelection(CachedMessage message) {
    if (message.isControl) return;
    Haptics.medium();
    if (_selectedIds.value.contains(message.id)) return;
    _selectedIds.value = {..._selectedIds.value, message.id};
    _syncSelectionAnim();
  }

  void _toggleSelection(CachedMessage message) {
    if (message.isControl) return;
    final next = Set<String>.from(_selectedIds.value);
    if (!next.remove(message.id)) next.add(message.id);
    Haptics.selection();
    _selectedIds.value = next;
    if (!next.contains(message.id)) _exitTextSelection(message.id);
    _syncSelectionAnim();
  }

  void _clearSelection() {
    _exitTextSelection();
    if (_selectedIds.value.isEmpty) return;
    _selectedIds.value = const {};
    _syncSelectionAnim();
  }

  void _startTextSelection(CachedMessage message, Offset globalPosition) {
    if (message.isControl || message.selectableText == null) return;
    _textSelectionDrag.value = null;
    _textSelection.value = (id: message.id, pos: globalPosition);
  }

  void _exitTextSelection([String? onlyId]) {
    final current = _textSelection.value;
    if (current == null) return;
    if (onlyId != null && current.id != onlyId) return;
    _textSelection.value = null;
  }

  void _syncSelectionAnim() {
    if (_selectedIds.value.isEmpty) {
      _selectionAnim.reverse();
    } else if (_selectionAnim.status != AnimationStatus.forward &&
        _selectionAnim.value < 1) {
      _selectionAnim.forward();
    }
  }

  List<CachedMessage> _selectedMessages(Set<String> ids) =>
      _messages.where((m) => ids.contains(m.id)).toList();

  List<CachedMessage> _copyableSelection(Set<String> ids) => [
    for (final m in _messages)
      if (ids.contains(m.id) && (m.selectableText ?? '').isNotEmpty) m,
  ];

  CachedMessage? _singleEditable(Set<String> ids) {
    if (ids.length != 1) return null;
    final list = _selectedMessages(ids);
    if (list.isEmpty) return null;
    return _canEditMessage(list.first) ? list.first : null;
  }

  void _copySelected(List<CachedMessage> messages) {
    if (messages.isEmpty) return;
    final text = messages.map((m) => m.selectableText!).join('\n\n');
    Clipboard.setData(ClipboardData(text: text));
    Haptics.tap();
    showCustomNotification(context, 'Скопировано');
    _clearSelection();
  }

  void _editSelected(CachedMessage message) {
    _clearSelection();
    _startEditMessage(message);
  }

  Future<void> _deleteSelected() async {
    final msgs = _selectedMessages(_selectedIds.value);
    if (msgs.isEmpty) return;

    final serverMsgs = msgs.where((m) => !m.id.startsWith('temp_')).toList();
    if (serverMsgs.isEmpty) {
      for (final m in msgs) {
        _startDeleteAnimation(m.id);
      }
      _clearSelection();
      return;
    }

    final canForEveryone = serverMsgs.every((m) => m.senderId == _myId);
    final forEveryone = await _showDeleteMessageDialog(canForEveryone);
    if (forEveryone == null || !mounted) return;

    final ok = await _deps.messages.deleteMessages(
      widget.chatId,
      serverMsgs.map((m) => m.id).toList(),
      forEveryone: forEveryone,
    );
    if (!mounted) return;
    if (!ok) {
      Haptics.error();
      showCustomNotification(context, 'Не удалось удалить сообщения');
      return;
    }
    for (final m in msgs) {
      _startDeleteAnimation(m.id);
    }
    _clearSelection();
  }

  void _replySelected() {
    final msgs = _selectedMessages(_selectedIds.value);
    if (msgs.isEmpty) return;
    final message = msgs.first;
    _clearSelection();
    _startReply(message);
  }

  void _forwardSelected() {
    final msgs = _selectedMessages(_selectedIds.value);
    _clearSelection();
    unawaited(_forwardMessages(msgs));
  }

  Future<void> _forwardMessages(List<CachedMessage> msgs) async {
    final forwardable = msgs
        .where((message) => int.tryParse(message.id) != null)
        .toList();
    if (forwardable.isEmpty) {
      showCustomNotification(context, 'Нечего пересылать');
      return;
    }

    final target = await openForwardScreen(
      context: context,
      messageCount: forwardable.length,
    );
    if (target == null || !mounted) return;

    final ordered = [...forwardable]..sort((a, b) => a.time.compareTo(b.time));
    final request = ForwardRequest(
      sourceChatId: widget.chatId,
      sourceChatName: widget.name,
      sourceChatIconUrl: widget.imageUrl,
      sourceChatType: widget.chatType,
      messages: ordered,
    );

    if (target.chatId == widget.chatId) {
      _setForwardRequest(request);
      return;
    }

    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: target.chatId,
        name: target.name,
        imageUrl: target.imageUrl,
        chatType: target.chatType,
        forwardRequest: request,
      ),
    );
  }

  void _setForwardRequest(ForwardRequest request) {
    _cancelReply();
    _forwardRequest = request;
    _pendingForwards.value = request.messages;
  }

  void _cancelForward() {
    _forwardRequest = null;
    _pendingForwards.value = const [];
  }

  Future<bool> _sendForwardRequest() async {
    var request = _forwardRequest;
    if (request == null) return true;
    if (_deps.api.state != SessionState.online) {
      showCustomNotification(context, 'Нет соединения');
      return false;
    }
    Haptics.send();
    while (request != null && request.messages.isNotEmpty) {
      if (!identical(_forwardRequest, request)) return false;
      final source = request.messages.first;
      final optimistic = MessagesModule.buildForwardMessage(
        myId: _myId,
        targetChatId: widget.chatId,
        sourceChatId: request.sourceChatId,
        source: source,
        tempId: _nextTempId(),
        time: DateTime.now().millisecondsSinceEpoch,
        status: 'sending',
        sourceChatName: request.sourceChatName,
        sourceChatIconUrl: request.sourceChatIconUrl,
        sourceChatType: request.sourceChatType,
      );
      _messages.add(optimistic);
      _bumpMessages();
      _scrollToBottom();
      await _syncForwardOutgoing(optimistic);
      final sent = await _sendOneForward(optimistic, request.sourceChatId);
      if (!sent || !mounted) return false;
      if (!identical(_forwardRequest, request)) return false;
      final remaining = request.messages.skip(1).toList(growable: false);
      if (remaining.isEmpty) {
        _cancelForward();
        return true;
      }
      request = request.withMessages(remaining);
      _forwardRequest = request;
      _pendingForwards.value = request.messages;
    }
    _cancelForward();
    return true;
  }

  Future<bool> _sendOneForward(
    CachedMessage optimistic,
    int sourceChatId,
  ) async {
    final link = optimistic.payload?['link'];
    final rawWireId = link is Map ? link['messageId'] : null;
    final wireId = rawWireId is int ? rawWireId : null;
    if (wireId == null) return false;
    try {
      final realId = await _deps.messages.forwardMessage(
        widget.chatId,
        sourceChatId,
        wireId,
      );
      final sent = MessagesModule.reidentifyMessage(
        optimistic,
        realId.isNotEmpty ? realId : optimistic.id,
        status: 'sent',
      );
      if (mounted) {
        final index = _messages.indexWhere((m) => m.id == optimistic.id);
        if (index != -1) {
          _messages[index] = sent;
          _bumpMessages();
        }
      }
      await _syncForwardOutgoing(sent, removeId: optimistic.id);
      return true;
    } catch (_) {
      final index = _messages.indexWhere((m) => m.id == optimistic.id);
      if (index != -1 && mounted) {
        _messages.removeAt(index);
        _bumpMessages();
      }
      try {
        await AppDatabase.deleteMessage(_myId, widget.chatId, optimistic.id);
      } catch (_) {}
      if (mounted) {
        Haptics.error();
        showCustomNotification(context, 'Не удалось переслать');
      }
      return false;
    }
  }

  Future<void> _syncForwardOutgoing(
    CachedMessage message, {
    String? removeId,
  }) async {
    await _persistOutgoing(message, removeId: removeId);
    try {
      await _deps.chats.applyOutgoing(
        _myId,
        widget.chatId,
        messageId: message.id,
        time: message.time,
        text: MessagesModule.forwardPreviewText(message),
        status: message.status ?? 'sending',
      );
    } catch (_) {}
  }


  bool _canEditMessage(CachedMessage message) {
    if (message.senderId != _myId) return false;
    if (message.id.startsWith('temp_')) return false;
    if (message.isControl) return false;
    final status = message.status;
    if (status == 'sending' || status == 'error') return false;
    return true;
  }

  Future<void> _startEditMessage(CachedMessage message) async {
    final cs = Theme.of(context).colorScheme;

    final content =
        await showModalBottomSheet<
          ({String text, List<Map<String, dynamic>> elements})
        >(
          context: context,
          isScrollControlled: true,
          backgroundColor: cs.surfaceContainerHigh,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheetContext) => EditMessageSheet(
            text: message.text ?? '',
            formatRanges: message.formatRanges,
            contextMenuBuilder: _formatContextMenu,
          ),
        );

    if (content == null || !mounted) return;

    final rawText = content.text;
    final newText = rawText.trim();
    final elements = _trimmedElements(content.elements, rawText, newText);

    final oldElements = serializeFormatElements(
      message.formatRanges.where((r) => composerFormats.contains(r.format)),
    );
    if (newText == (message.text ?? '') &&
        _sameElements(elements, oldElements)) {
      return;
    }

    final ok = await _deps.messages.editMessage(
      widget.chatId,
      message.id,
      text: newText,
      elements: elements,
    );
    if (!mounted) return;
    if (!ok) {
      Haptics.error();
      showCustomNotification(context, 'Не удалось изменить сообщение');
      return;
    }

    final idx = _messages.indexWhere((m) => m.id == message.id);
    if (idx != -1) {
      final old = _messages[idx];
      final newHistory = KometSettings.viewRedacted.value
          ? CachedMessage.appendEditHistory(
              old.editHistory,
              old.text,
              DateTime.now().millisecondsSinceEpoch,
            )
          : old.editHistory;
      final edited = CachedMessage(
        id: old.id,
        accountId: old.accountId,
        chatId: old.chatId,
        senderId: old.senderId,
        text: newText.isEmpty ? null : newText,
        time: old.time,
        status: 'EDITED',
        payload: {...?old.payload, 'elements': elements},
        attachments: old.attachments,
        isControl: old.isControl,
        editHistory: newHistory,
      );
      _messages[idx] = edited;
      _bumpMessages();
      unawaited(_persistOutgoing(edited));
    }
    Haptics.send();
  }

  Future<void> _confirmDeleteMessage(String messageId, bool isMe) async {
    final isLocalOnly = messageId.startsWith('temp_');
    final canForEveryone = isMe && !isLocalOnly;

    if (isLocalOnly) {
      _startDeleteAnimation(messageId);
      return;
    }

    final forEveryone = await _showDeleteMessageDialog(canForEveryone);
    if (forEveryone == null || !mounted) return;

    final ok = await _deps.messages.deleteMessages(widget.chatId, [
      messageId,
    ], forEveryone: forEveryone);
    if (!mounted) return;
    if (!ok) {
      Haptics.error();
      showCustomNotification(context, 'Не удалось удалить сообщение');
      return;
    }
    _startDeleteAnimation(messageId);
  }

  void _startDeleteAnimation(String messageId) {
    if (!_deletingIds.add(messageId)) return;
    Haptics.tap();
    _bumpMessages();
  }

  Future<void> _finalizeDelete(String messageId) async {
    if (!mounted) return;
    _deletingIds.remove(messageId);
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      _messages.removeAt(idx);
      _reactionNotifiers.remove(messageId)?.dispose();
    }
    _bumpMessages();
    try {
      await AppDatabase.deleteMessage(_myId, widget.chatId, messageId);
      await _deps.chats.reconcileLastMessage(_myId, widget.chatId);
    } catch (_) {}
  }

  Future<bool?> _showDeleteMessageDialog(bool canForEveryone) {
    final cs = Theme.of(context).colorScheme;
    var alsoForEveryone = canForEveryone;
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              backgroundColor: cs.surfaceContainerHigh,
              shape: AppShape.dialogBorder,
              title: const Text('Удалить сообщение'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Вы точно хотите удалить это сообщение?',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
                  ),
                  if (canForEveryone) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => setLocalState(
                        () => alsoForEveryone = !alsoForEveryone,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: alsoForEveryone,
                            onChanged: (v) => setLocalState(
                              () => alsoForEveryone = v ?? false,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Также удалить для ${widget.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, canForEveryone && alsoForEveryone),
                  child: Text('Удалить', style: TextStyle(color: cs.error)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
