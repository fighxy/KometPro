part of '../../chat_screen.dart';

extension _ChatSendPipeline on _ChatScreenState {
  Future<String?> _encryptOutgoing(String text) async {
    if (!_encryptionEnabled || _myId == 0) return text;
    final result = await ChatCryptoService.instance.encrypt(
      _myId,
      widget.chatId,
      text,
    );
    if (result.isOk) {
      if (result.text!.length > kMaxEncryptedMessageLength) {
        if (mounted) {
          showCustomNotification(
            context,
            'Слишком длинное сообщение. Разделите на несколько',
          );
        }
        return null;
      }
      return result.text;
    }
    if (mounted) {
      showCustomNotification(
        context,
        result.failure == CryptoFailure.noKey
            ? 'Не задан ключ шифрования'
            : 'Не удалось зашифровать сообщение',
      );
    }
    return null;
  }

  Future<void> _sendMessage() async {
    if (_forwardRequest == null) {
      await _sendTextMessage();
      return;
    }
    if (_forwardSending || _myId == 0) return;
    _forwardSending = true;
    try {
      final forwarded = await _sendForwardRequest();
      if (!forwarded || !mounted) return;
      if (_messageController.text.trim().isEmpty) return;
      await _sendTextMessage();
    } finally {
      _forwardSending = false;
    }
  }

  Future<void> _sendTextMessage() async {
    final gen = _chatController.sessionGen;
    final content = _messageController.buildContent();
    final rawText = content.text;
    final text = rawText.trim();
    if (text.isEmpty || _myId == 0) return;

    if (AppCommands.current.value && text.startsWith('/')) {
      final command = findSlashCommand(text);
      if (command == null) {
        _messageController.clear();
        _hasText.value = false;
        showCustomNotification(context, 'ТАКОЙ КОМАНДЫ НЕТУ🚨🚨🚨');
        return;
      }
      if (command.run != null) {
        final args = commandArgs(text);
        _messageController.clear();
        _hasText.value = false;
        unawaited(command.run!(_commandContext(args)));
        return;
      }
    }

    if (chat?.confirmBeforeSend ?? false) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showConfirmDialog(
        context,
        message: l10n.chatSendConfirmMessage,
        confirmLabel: l10n.chatSendConfirmAction,
      );
      if (!confirmed || !_sessionAlive(gen)) return;
    }

    final wireText = await _encryptOutgoing(text);
    if (wireText == null || !_sessionAlive(gen)) return;
    final encrypted = wireText != text;

    final tempId = _nextTempId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final online = api.state == SessionState.online;

    final reply = _replyTo.value;
    final int? replyId = reply == null ? null : int.tryParse(reply.id);
    final int? replySourceChatId = replyId == null ? null : _replySourceChatId;
    Map<String, dynamic>? replyPayload;
    if (reply != null && replyId != null) {
      replyPayload = {
        'link': {
          'type': 'REPLY',
          'chatId': replySourceChatId ?? widget.chatId,
          'message': {
            'id': replyId,
            'sender': reply.senderId,
            'text': reply.text,
            'time': reply.time,
            'attaches': reply.payload?['attaches'] ?? const [],
          },
        },
      };
    }
    _replyTo.value = null;
    _replySourceChatId = null;

    final elements = encrypted
        ? const <Map<String, dynamic>>[]
        : _trimmedElements(content.elements, rawText, text);
    final Map<String, dynamic>? composedPayload =
        (replyPayload == null && elements.isEmpty)
        ? null
        : {...?replyPayload, if (elements.isNotEmpty) 'elements': elements};

    final composed = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: widget.chatId,
      senderId: _myId,
      text: wireText,
      time: now,
      status: online ? 'sending' : 'pending',
      payload: composedPayload,
    );
    if (encrypted) MessageDecryptionCache.instance.seed(tempId, text);

    _hasText.value = false;
    _lastSentId = tempId;
    _messages.add(composed);
    _messageController.clear();
    if (!_commentsMode &&
        DraftStore.instance.get(_myId, widget.chatId) != null) {
      unawaited(DraftStore.instance.clear(_myId, widget.chatId));
    }
    _bumpMessages();
    if (!_commentsMode) {
      unawaited(_persistOutgoing(composed));
      unawaited(
        chats.applyOutgoing(
          _myId,
          widget.chatId,
          messageId: tempId,
          time: now,
          text: wireText,
          status: composed.status ?? 'sending',
          elements: elements,
        ),
      );
    }

    // Instant tactile "whoosh" the moment the message leaves the composer,
    // not after the network round-trip — feedback must feel immediate.
    Haptics.send();

    _scrollToBottom();
    _prank.checkTrigger(composed);

    if (!online) return;

    try {
      final actualId = _commentsMode
          ? await commentsModule.sendComment(
              _myId,
              widget.chatId,
              widget.commentPostId!,
              wireText,
              replyToMessageId: replyId,
              elements: elements,
            )
          : await messagesModule.sendMessage(
              _myId,
              widget.chatId,
              wireText,
              replyToMessageId: replyId,
              replySourceChatId: replySourceChatId,
              elements: elements,
            );

      if (!_sessionAlive(gen)) return;

      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1 && mounted) {
        final sent = CachedMessage(
          id: actualId.isNotEmpty ? actualId : tempId,
          accountId: _myId,
          chatId: widget.chatId,
          senderId: _myId,
          text: wireText,
          time: now,
          status: 'sent',
          payload: composedPayload,
        );
        if (encrypted) {
          MessageDecryptionCache.instance.adopt(tempId, sent.id);
        }
        _messages[index] = sent;
        _bumpMessages();
        if (!_commentsMode) {
          unawaited(_persistOutgoing(sent, removeId: tempId));
          unawaited(
            chats.applyOutgoing(
              _myId,
              widget.chatId,
              messageId: sent.id,
              time: now,
              text: wireText,
              status: 'sent',
              elements: elements,
            ),
          );
        }
      }

      if (!_commentsMode && chat == null) {
        unawaited(
          chats.refreshChats(api, [widget.chatId]).then((list) {
            if (!mounted || list.isEmpty) return;
            setState(() => chat = list.first);
            _bumpMessages();
            _syncOtherReadTime();
          }),
        );
      }
    } catch (e) {
      if (replySourceChatId != null) {
        logger.w('Cross-chat reply rejected: $e');
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1 && mounted) {
          _messages.removeAt(index);
          _bumpMessages();
        }
        unawaited(AppDatabase.deleteMessage(_myId, widget.chatId, tempId));
        if (mounted) {
          Haptics.error();
          showCustomNotification(context, e.toString());
        }
        return;
      }
      final failed = isPermanentSendFailure(e);
      final status = failed ? 'error' : 'pending';
      if (failed) logger.w('Отправка отклонена сервером: $e');
      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1 && mounted) {
        final queued = CachedMessage(
          id: tempId,
          accountId: _myId,
          chatId: widget.chatId,
          senderId: _myId,
          text: text,
          time: now,
          status: status,
          payload: composedPayload,
        );
        _messages[index] = queued;
        _bumpMessages();
        if (!_commentsMode) {
          unawaited(_persistOutgoing(queued));
          unawaited(
            chats.applyOutgoing(
              _myId,
              widget.chatId,
              messageId: tempId,
              time: now,
              text: text,
              status: status,
              elements: elements,
            ),
          );
        }
      }
    }
  }

  int? _resolveOtherId() {
    if (widget.chatType != 'DIALOG' || _myId == 0) return null;
    if (widget.chatId == 0) return null;
    final id = widget.chatId ^ _myId;
    return id > 0 ? id : null;
  }

  int _complaintTypeId(String type) {
    switch (type) {
      case 'CHANNEL':
        return 5;
      case 'CHAT':
        return 4;
      default:
        return 3;
    }
  }

  Future<List<({int id, String title})>> _loadReportReasons(int typeId) async {
    final reasons = await ComplaintsModule.reasonsFor(api, typeId);
    return reasons.map((r) => (id: r.reasonId, title: r.reasonTitle)).toList();
  }

  Future<bool> _reportMessage(
    CachedMessage message,
    int typeId,
    int reasonId,
  ) async {
    final messageIdNum = int.tryParse(message.id);
    if (messageIdNum == null) {
      if (mounted) {
        showCustomNotification(context, 'Не удалось отправить жалобу');
      }
      return false;
    }
    final ok = await ComplaintsModule.sendComplaint(
      api,
      reasonId: reasonId,
      typeId: typeId,
      ids: [messageIdNum],
      parentId: widget.chatId,
    );
    if (!mounted) return ok;
    showCustomNotification(
      context,
      ok ? 'Жалоба отправлена' : 'Не удалось отправить жалобу',
    );
    return ok;
  }

  CachedMessage _replaceMessage(
    int index, {
    String? id,
    String? text,
    String? status,
  }) {
    final old = _messages[index];
    final updated = CachedMessage(
      id: id ?? old.id,
      accountId: old.accountId,
      chatId: old.chatId,
      senderId: old.senderId,
      text: text ?? old.text,
      time: old.time,
      status: status ?? old.status,
      payload: old.payload,
      attachments: old.attachments,
      isControl: old.isControl,
      editHistory: old.editHistory,
    );
    _messages[index] = updated;
    _bumpMessages();
    return updated;
  }

  Future<String> _postCommandMessage(String text) async {
    if (!mounted || _myId == 0) return '';
    final tempId = _nextTempId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final online = api.state == SessionState.online;
    final composed = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: widget.chatId,
      senderId: _myId,
      text: text,
      time: now,
      status: online ? 'sending' : 'pending',
    );
    _messages.add(composed);
    _bumpMessages();
    _scrollToBottom();
    unawaited(_persistOutgoing(composed));
    unawaited(
      chats.applyOutgoing(
        _myId,
        widget.chatId,
        messageId: tempId,
        time: now,
        text: text,
        status: composed.status ?? 'sending',
      ),
    );
    if (!online) return tempId;
    try {
      final actualId = await messagesModule.sendMessage(
        _myId,
        widget.chatId,
        text,
      );
      final realId = actualId.isNotEmpty ? actualId : tempId;
      final i = _messages.indexWhere((m) => m.id == tempId);
      if (i != -1) {
        final sent = _replaceMessage(i, id: realId, status: 'sent');
        unawaited(_persistOutgoing(sent, removeId: tempId));
        unawaited(
          chats.applyOutgoing(
            _myId,
            widget.chatId,
            messageId: realId,
            time: now,
            text: text,
            status: 'sent',
          ),
        );
      }
      return realId;
    } catch (_) {
      return tempId;
    }
  }

  Future<void> _updateCommandMessage(String id, String text) async {
    if (id.isEmpty) return;
    final i = _messages.indexWhere((m) => m.id == id);
    if (i != -1) {
      final edited = _replaceMessage(i, text: text, status: 'EDITED');
      unawaited(_persistOutgoing(edited));
    }
    if (!id.startsWith('temp_')) {
      await messagesModule.editMessage(widget.chatId, id, text: text);
    }
  }

  CommandContext _commandContext(String args) => CommandContext(
    accountId: _myId,
    chatId: widget.chatId,
    otherUserId: _resolveOtherId(),
    args: args,
    messages: messagesModule,
    isOnline: () => api.state == SessionState.online,
    isActive: () => mounted,
    notify: (message, {duration}) {
      if (mounted) showCustomNotification(context, message, duration: duration);
    },
    postMessage: _postCommandMessage,
    updateMessage: _updateCommandMessage,
    sendPhotos: _sendPhotos,
    sendVideoNote: _sendVideoNote,
  );

  Future<void> _scheduleMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _myId == 0) return;

    final when = await _pickScheduleTime();
    if (when == null || !mounted) return;

    try {
      await messagesModule.sendMessage(
        _myId,
        widget.chatId,
        text,
        scheduledTime: when.millisecondsSinceEpoch,
      );
      if (!mounted) return;
      _hasText.value = false;
      _messageController.clear();
      Haptics.send();
      _markHasScheduled();
      showCustomNotification(
        context,
        'Запланировано на ${formatDateTimeWords(when)}',
      );
    } catch (_) {
      if (!mounted) return;
      Haptics.error();
      showCustomNotification(context, 'Не удалось запланировать сообщение');
    }
  }

  Future<DateTime?> _pickScheduleTime() => showScheduleTimePicker(context);

  void _openScheduledMessages() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ScheduledMessagesScreen(
              chatId: widget.chatId,
              accountId: _myId,
              chatName: widget.name,
            ),
          ),
        )
        .then((_) {
          if (mounted) _refreshScheduledCount();
        });
  }

  Future<void> _persistOutgoing(CachedMessage msg, {String? removeId}) async {
    try {
      if (removeId != null && removeId != msg.id) {
        await AppDatabase.deleteMessage(_myId, widget.chatId, removeId);
      }
      await AppDatabase.saveMessages([msg.toDbRow()]);
    } catch (_) {}
  }

  Future<void> _loadGroupSenderNames() async {
    if (widget.chatType != 'CHAT' && widget.chatType != 'CHANNEL') return;

    final unknownIds = <int>{};
    for (final msg in _messages) {
      if (msg.isControl) continue;
      final id = msg.senderId;
      if (id == 0 || id == _myId) continue;
      if (ContactCache.get(id) == null) unknownIds.add(id);
    }
    if (unknownIds.isEmpty) return;

    final resolved = await messagesModule.ensureContactNames(unknownIds);
    if (resolved && mounted) _bumpMessages();
  }

  Future<void> _loadForwardedSenderNames() async {
    final forwardIds = <int>{};
    for (final msg in _messages) {
      if (msg.attachments != null) {
        for (final a in msg.attachments!) {
          if (a is ForwardedMessageAttachment) {
            if (a.originalSenderId != 0 &&
                a.originalSenderName == null &&
                ContactCache.get(a.originalSenderId) == null) {
              forwardIds.add(a.originalSenderId);
            }
          }
        }
      }
    }
    if (forwardIds.isEmpty) return;

    final resolved = <int, ({String name, String? avatar})>{};
    for (final id in forwardIds) {
      final name = await messagesModule.searchContactById(id);
      if (name != null) {
        resolved[id] = (name: name, avatar: ContactCache.getAvatar(id));
      }
    }
    if (resolved.isEmpty || !mounted) return;

    var anyChanged = false;
    for (var i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      final attaches = msg.attachments;
      if (attaches == null) continue;

      var msgChanged = false;
      final newAttaches = attaches.map((a) {
        if (a is ForwardedMessageAttachment &&
            a.originalSenderName == null &&
            resolved.containsKey(a.originalSenderId)) {
          final r = resolved[a.originalSenderId]!;
          msgChanged = true;
          return ForwardedMessageAttachment(
            originalSenderId: a.originalSenderId,
            originalSenderName: r.name,
            originalSenderAvatar: r.avatar,
            originalType: a.originalType,
            originalMessageId: a.originalMessageId,
            originalTime: a.originalTime,
            originalText: a.originalText,
            originalChatId: a.originalChatId,
            originalFormatRanges: a.originalFormatRanges,
            originalAttachments: a.originalAttachments,
            originalContact: a.originalContact,
          );
        }
        return a;
      }).toList();

      if (!msgChanged) continue;
      anyChanged = true;
      _messages[i] = msg.copyWith(attachments: newAttaches);
    }

    if (anyChanged) {
      _bumpMessages();
    }
  }

  Uint8List _buildWave(List<double> amps, {int bars = 80}) {
    final out = Uint8List(bars);
    if (amps.isEmpty) return out;
    for (var i = 0; i < bars; i++) {
      final start = (i * amps.length / bars).floor();
      final end = (((i + 1) * amps.length / bars).ceil()).clamp(
        start + 1,
        amps.length,
      );
      var peak = 0.0;
      for (var j = start; j < end; j++) {
        if (amps[j] > peak) peak = amps[j];
      }
      out[i] = (peak * 120).round().clamp(0, 120);
    }
    return out;
  }

  Future<void> _sendVoice(File file, int durationMs, List<double> amps) async {
    if (_myId == 0) {
      try {
        await file.delete();
      } catch (_) {}
      return;
    }
    final wave = _buildWave(amps);
    final placeholder = _addOptimisticMediaMessage(
      AudioAttachment(
        duration: durationMs,
        waveform: String.fromCharCodes(wave),
      ),
    );

    unawaited(
      UploadService.instance.sendVoice(
        accountId: _myId,
        chatId: widget.chatId,
        tempId: placeholder.id,
        file: file,
        durationMs: durationMs,
        wave: wave,
        placeholder: placeholder,
      ),
    );
  }

  Future<void> _sendVideoNote(File file, int durationMs) async {
    if (_myId == 0) {
      try {
        await file.delete();
      } catch (_) {}
      return;
    }
    final placeholder = _addOptimisticMediaMessage(
      VideoAttachment(duration: durationMs, videoType: 1, localPath: file.path),
    );

    unawaited(
      UploadService.instance.sendVideoNote(
        accountId: _myId,
        chatId: widget.chatId,
        tempId: placeholder.id,
        file: file,
        durationMs: durationMs,
        placeholder: placeholder,
      ),
    );
  }

  CachedMessage _addOptimisticMediaMessage(MessageAttachment attachment) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tempId = _nextTempId();
    final msg = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: widget.chatId,
      senderId: _myId,
      time: now,
      status: 'sending',
      attachments: [attachment],
    );
    _lastSentId = tempId;
    _messages.add(msg);
    _bumpMessages();
    Haptics.send();
    _scrollToBottom();
    return msg;
  }

  void _updateFileMessageStatus(
    String tempId,
    String status, {
    FileAttachment? attachment,
    String? realId,
  }) {
    if (!mounted) return;
    final idx = _messages.indexWhere((m) => m.id == tempId);
    if (idx == -1) return;
    final old = _messages[idx];
    _messages[idx] = CachedMessage(
      id: realId != null && realId.isNotEmpty ? realId : tempId,
      accountId: old.accountId,
      chatId: old.chatId,
      senderId: old.senderId,
      text: old.text,
      time: old.time,
      status: status,
      payload: old.payload,
      attachments: attachment != null ? [attachment] : old.attachments,
    );
    _bumpMessages();
  }

  Future<void> _sendHistoryFile(FileHistoryEntry entry) async {
    final tempId = _addOptimisticMediaMessage(
      FileAttachment(
        fileId: entry.fileId,
        fileToken: entry.token,
        name: entry.filename,
        size: entry.size,
      ),
    ).id;
    _showAttachmentPanel.value = false;
    try {
      final realId = await messagesModule.sendFileMessage(
        widget.chatId,
        entry.fileId,
        token: entry.token,
      );
      _updateFileMessageStatus(
        tempId,
        realId != null ? 'sent' : 'error',
        realId: realId,
      );
    } catch (_) {
      _updateFileMessageStatus(tempId, 'error');
    }
  }

  Future<bool> _sendFileById(int fileId) async {
    final tempId = _addOptimisticMediaMessage(
      FileAttachment(fileId: fileId),
    ).id;
    try {
      final realId = await messagesModule.sendFileMessage(
        widget.chatId,
        fileId,
      );
      final ok = realId != null;
      if (!mounted) return ok;
      if (ok) {
        FileHistoryCache.add(
          FileHistoryEntry(fileId: fileId, sentAt: DateTime.now()),
        );
        _updateFileMessageStatus(tempId, 'sent', realId: realId);
        _showAttachmentPanel.value = false;
      } else {
        _updateFileMessageStatus(tempId, 'error');
        showCustomNotification(context, 'Ошибка отправки');
      }
      return ok;
    } catch (e) {
      _updateFileMessageStatus(tempId, 'error');
      if (mounted) showCustomNotification(context, 'Ошибка: $e');
      return false;
    }
  }

  Future<void> _openAttachmentSheetScheduled() async {
    final when = await _pickScheduleTime();
    if (when == null || !mounted) return;
    await _openAttachmentSheet(scheduledTime: when.millisecondsSinceEpoch);
  }

  Future<void> _openAttachmentSheet({int? scheduledTime}) async {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final hadKeyboard = keyboard > 0;
    if (hadKeyboard) {
      setState(() => _keyboardReserve = keyboard);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await showAttachmentSheet(
      context,
      title: widget.name,
      onSend: scheduledTime == null
          ? _sendPhotos
          : (picked, caption) =>
                _sendScheduledPhotos(picked, caption, scheduledTime),
      onPickFile: _encryptionEnabled
          ? () => _refuseUnencrypted('Файлы')
          : (scheduledTime == null
                ? _pickAndUploadFile
                : () => _pickAndUploadFile(scheduledTime: scheduledTime)),
      onShareLocation: _encryptionEnabled
          ? () => _refuseUnencrypted('Геолокацию')
          : _shareLocation,
      onCreatePoll: _encryptionEnabled
          ? () => _refuseUnencrypted('Опросы')
          : _createPoll,
      onSendContact: _encryptionEnabled
          ? (_) => _refuseUnencrypted('Контакты')
          : _sendContact,
    );
    if (!mounted || !hadKeyboard) return;
    _messageFocusNode.requestFocus();
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() => _keyboardReserve = 0);
  }

  Future<void> _sendPhotos(List<PickedPhoto> picked, String caption) async {
    if (_myId == 0) return;
    final gen = _chatController.sessionGen;
    if (_encryptionEnabled) return _sendEncryptedPhotos(picked, caption);
    final videos = picked.where((ph) => ph.item.isVideo).toList();
    final photos = picked.where((ph) => !ph.item.isVideo).toList();
    if (photos.isEmpty && videos.isEmpty) return;

    for (var i = 0; i < videos.length; i++) {
      final cap = (photos.isEmpty && i == 0) ? caption : '';
      await _sendVideo(videos[i], cap);
    }
    if (photos.isEmpty) return;

    final jobs = <({File file, GalleryItem? item})>[];
    final attachments = <PhotoAttachment>[];
    for (final photo in photos) {
      final edited = photo.editedFile;
      final file =
          edited ?? photo.item.localFile ?? await photo.item.originFile();
      if (file == null) continue;
      final dim = edited != null
          ? await imageFileDimensions(edited)
          : await photo.item.dimensions();
      jobs.add((file: file, item: edited == null ? photo.item : null));
      attachments.add(
        PhotoAttachment(localPath: file.path, width: dim?.$1, height: dim?.$2),
      );
    }
    if (jobs.isEmpty || !_sessionAlive(gen)) return;

    final tempId = _nextTempId();
    final placeholder = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: widget.chatId,
      senderId: _myId,
      text: caption.isEmpty ? null : caption,
      time: DateTime.now().millisecondsSinceEpoch,
      status: 'sending',
      attachments: attachments,
    );

    _messages.add(placeholder);
    _lastSentId = tempId;
    _bumpMessages();
    Haptics.send();
    _scrollToBottom();

    unawaited(
      UploadService.instance.sendPhotos(
        accountId: _myId,
        chatId: widget.chatId,
        tempId: tempId,
        jobs: jobs,
        caption: caption,
        placeholder: placeholder,
      ),
    );
  }

  Future<void> _sendVideo(
    PickedPhoto video,
    String caption, {
    int? scheduledTime,
  }) async {
    if (_myId == 0) return;
    final file =
        video.editedFile ??
        video.item.localFile ??
        await video.item.originFile();
    if (file == null || !mounted) return;

    final edited = video.editedFile;
    var durationMs = video.item.duration?.inMilliseconds;
    var dims = await video.item.dimensions();
    Uint8List? thumbBytes;
    if (edited != null) {
      final info = await VideoTranscoder.probe(edited.path);
      if (info != null) {
        if (info.durationMs > 0) durationMs = info.durationMs;
        if (info.width > 0 && info.height > 0) dims = (info.width, info.height);
      }
      final frames = await VideoTranscoder.frames(edited.path, const [
        0,
      ], size: 512);
      if (frames.isNotEmpty) thumbBytes = frames.first;
    }
    if (durationMs == null && DesktopVideoProbe.supported) {
      durationMs = (await DesktopVideoProbe.duration(
        file.path,
      ))?.inMilliseconds;
    }
    if (thumbBytes == null) {
      try {
        thumbBytes = await video.item.thumbnail(512);
      } catch (_) {}
    }
    if (!mounted) return;
    final thumbData = thumbBytes == null || thumbBytes.isEmpty
        ? null
        : 'data:image/jpeg;base64,${base64Encode(thumbBytes)}';

    final tempId = _nextTempId();
    CachedMessage? placeholder;

    if (scheduledTime != null) {
      showCustomNotification(context, 'Загрузка…');
    } else {
      placeholder = CachedMessage(
        id: tempId,
        accountId: _myId,
        chatId: widget.chatId,
        senderId: _myId,
        text: caption.isEmpty ? null : caption,
        time: DateTime.now().millisecondsSinceEpoch,
        status: 'sending',
        attachments: [
          VideoAttachment(
            duration: durationMs,
            localPath: file.path,
            previewData: thumbData,
            width: dims?.$1,
            height: dims?.$2,
          ),
        ],
      );
      _messages.add(placeholder);
      _lastSentId = tempId;
      _bumpMessages();
      Haptics.send();
      _scrollToBottom();
    }

    unawaited(
      UploadService.instance.sendVideo(
        accountId: _myId,
        chatId: widget.chatId,
        tempId: tempId,
        file: file,
        caption: caption,
        placeholder: placeholder,
        scheduledTime: scheduledTime,
      ),
    );
  }

  void _onUploadEvent(UploadJobEvent event) {
    if (!mounted || event.chatId != widget.chatId) return;
    _syncUploadStatus();
    if (event is UploadJobDone) {
      if (event.scheduled) {
        Haptics.send();
        _markHasScheduled();
        final at = event.scheduledTime;
        showCustomNotification(
          context,
          at == null
              ? 'Запланировано'
              : 'Запланировано на '
                    '${formatDateTimeWords(DateTime.fromMillisecondsSinceEpoch(at))}',
        );
        return;
      }
      final real = event.message;
      if (real == null) return;
      final idx = _messages.indexWhere((m) => m.id == event.tempId);
      if (idx != -1) {
        _messages[idx] = real;
        _bumpMessages();
      }
    } else if (event is UploadJobFailed) {
      if (event.scheduled) {
        Haptics.error();
        showCustomNotification(context, 'Не удалось запланировать');
        return;
      }
      _failPhotoMessage(event.tempId);
      final text = _uploadFailureText(event.kind, event.reason);
      if (text != null) showCustomNotification(context, text);
    }
  }

  String? _uploadFailureText(UploadKind kind, String reason) {
    final detail = switch (reason) {
      'no_upload_url' => 'сервер не выдал ссылку',
      'upload_failed' => 'загрузка отклонена',
      'send_failed' => 'сервер не принял сообщение',
      _ => reason,
    };
    return switch (kind) {
      UploadKind.file => 'Ошибка: $reason',
      UploadKind.videoNote => 'Кружок не отправлен: $detail',
      UploadKind.voice => 'Голосовое не отправлено: $detail',
      UploadKind.photo || UploadKind.video => null,
    };
  }

  void _syncUploadStatus() {
    final job = UploadService.instance.activeFileJob(widget.chatId);
    if (job?.id == _uploadStatusJobId) return;
    _detachUploadStatus();
    if (job == null) {
      _uploadStatus.value = const UploadStatus();
      return;
    }
    _uploadStatusJobId = job.id;
    _uploadStatusBytes = job.bytes;
    job.bytes.addListener(_onUploadBytes);
    _onUploadBytes();
  }

  void _onUploadBytes() {
    final bytes = _uploadStatusBytes?.value;
    if (bytes == null) return;
    _uploadStatus.value = UploadStatus(
      active: true,
      sent: bytes.sent,
      total: bytes.total,
    );
  }

  void _detachUploadStatus() {
    _uploadStatusBytes?.removeListener(_onUploadBytes);
    _uploadStatusBytes = null;
    _uploadStatusJobId = null;
  }

  void _mergePendingMedia() {
    _syncUploadStatus();
    final service = UploadService.instance;
    var changed = false;

    for (var i = _messages.length - 1; i >= 0; i--) {
      final msg = _messages[i];
      if (!isSendingStatus(msg.status)) continue;
      final done = service.completedFor(msg.id);
      if (done != null) {
        if (done.id != msg.id && _messages.any((m) => m.id == done.id)) {
          _messages.removeAt(i);
        } else {
          _messages[i] = done;
        }
        changed = true;
        continue;
      }
      if (service.didFail(msg.id)) {
        _messages[i] = msg.copyWith(status: 'error');
        changed = true;
      }
    }

    for (final msg in service.pendingFor(widget.chatId)) {
      if (_messages.any((m) => m.id == msg.id)) continue;
      _messages.add(msg);
      changed = true;
    }

    if (changed) _bumpMessages();
  }

  Future<void> _sendScheduledPhotos(
    List<PickedPhoto> picked,
    String caption,
    int scheduledTime,
  ) async {
    if (_myId == 0) return;
    final videos = picked.where((ph) => ph.item.isVideo).toList();
    final photos = picked.where((ph) => !ph.item.isVideo).toList();
    if (photos.isEmpty && videos.isEmpty) return;

    for (var i = 0; i < videos.length; i++) {
      final cap = (photos.isEmpty && i == 0) ? caption : '';
      await _sendVideo(videos[i], cap, scheduledTime: scheduledTime);
    }
    if (photos.isEmpty) return;

    final jobs = <({File file, GalleryItem? item})>[];
    for (final photo in photos) {
      final edited = photo.editedFile;
      final file =
          edited ?? photo.item.localFile ?? await photo.item.originFile();
      if (file != null) {
        jobs.add((file: file, item: edited == null ? photo.item : null));
      }
    }
    if (jobs.isEmpty || !mounted) return;

    showCustomNotification(context, 'Загрузка…');
    unawaited(
      UploadService.instance.sendPhotos(
        accountId: _myId,
        chatId: widget.chatId,
        tempId: _nextTempId(),
        jobs: jobs,
        caption: caption,
        scheduledTime: scheduledTime,
      ),
    );
  }

  Future<void> _sendAttachMessage(
    List<MessageAttachment> optimistic,
    Future<Map<String, dynamic>?> Function() send,
  ) async {
    if (_myId == 0) return;
    final tempId = _nextTempId();
    final now = DateTime.now().millisecondsSinceEpoch;

    final tempMessage = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: widget.chatId,
      senderId: _myId,
      time: now,
      status: 'sending',
      attachments: optimistic,
    );
    _messages.add(tempMessage);
    _lastSentId = tempId;
    _bumpMessages();
    Haptics.send();
    _scrollToBottom();

    try {
      final serverMsg = await send();
      if (!mounted) return;
      final idx = _messages.indexWhere((m) => m.id == tempId);
      if (idx == -1) return;
      if (serverMsg == null) {
        _updateFileMessageStatus(tempId, 'error');
        showCustomNotification(context, 'Ошибка отправки');
        return;
      }
      final real = CachedMessage.fromPushPayload(
        _myId,
        widget.chatId,
        serverMsg,
      );
      _messages[idx] = real;
      _bumpMessages();
      unawaited(_persistOutgoing(real, removeId: tempId));
    } catch (e) {
      if (!mounted) return;
      _updateFileMessageStatus(tempId, 'error');
      showCustomNotification(context, 'Ошибка: $e');
    }
  }

  void _toggleStickerPanel() {
    if (_stickers.showPanel.value) {
      _stickers.hide();
      if (_keyboardBeforeStickers) _messageFocusNode.requestFocus();
      return;
    }
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    _keyboardBeforeStickers = keyboard > 120 || _messageFocusNode.hasFocus;
    if (keyboard > 120) _stickers.setBaseHeight(keyboard);
    FocusManager.instance.primaryFocus?.unfocus();
    _stickers.showPanel.value = true;
  }

  Future<void> _sendSticker(StickerItem sticker) async {
    await _sendAttachMessage([
      StickerAttachment(
        stickerId: sticker.id.toString(),
        baseUrl: sticker.url,
        lottieUrl: sticker.lottieUrl,
        width: sticker.width,
        height: sticker.height,
      ),
    ], () => messagesModule.sendStickerMessage(widget.chatId, sticker.id));
  }

  void _insertAnimoji(Animoji animoji) {
    _messageController.insertAnimoji(animoji);
    unawaited(animojiModule.noteUsed(animoji));
    Haptics.selection();
  }

  Future<void> _shareLocation() async {
    final position = await _resolveCurrentPosition();
    if (position == null || !mounted) return;
    final lat = position.latitude;
    final lon = position.longitude;
    await _sendAttachMessage([
      LocationAttachment(latitude: lat, longitude: lon, zoom: 15),
    ], () => messagesModule.sendLocationMessage(widget.chatId, lat, lon));
  }

  Future<Position?> _resolveCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) showCustomNotification(context, 'Включите геолокацию');
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          showCustomNotification(context, 'Нет доступа к геолокации');
        }
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, 'Не удалось получить геопозицию');
      }
      return null;
    }
  }

  Future<void> _sendContact(CachedContact contact) async {
    final last = contact.lastName;
    final fullName = (last != null && last.isNotEmpty)
        ? '${contact.firstName} $last'
        : contact.firstName;
    await _sendAttachMessage([
      ContactAttachment(
        contactId: contact.id,
        firstName: contact.firstName,
        lastName: last,
        name: fullName,
        photoUrl: contact.baseUrl,
      ),
    ], () => messagesModule.sendContactMessage(widget.chatId, contact.id));
  }

  Future<void> _createPoll() async {
    final draft = await showCreatePollSheet(context);
    if (draft == null || !mounted) return;
    await _sendAttachMessage(
      [PollAttachment(pollId: 0, title: draft.title)],
      () => messagesModule.sendPollMessage(
        widget.chatId,
        draft.title,
        draft.answers,
        multiple: draft.multiple,
        anonymous: draft.anonymous,
      ),
    );
  }

  void _failPhotoMessage(String tempId) {
    final idx = _messages.indexWhere((m) => m.id == tempId);
    if (idx != -1) {
      _messages[idx] = _messages[idx].copyWith(status: 'error');
      _bumpMessages();
    }
    Haptics.error();
  }

  void _refuseUnencrypted(String what) {
    if (!mounted) return;
    _showAttachmentPanel.value = false;
    showCustomNotification(context, '$what пока нельзя зашифровать');
  }

  Future<void> _sendEncryptedPhotos(
    List<PickedPhoto> picked,
    String caption,
  ) async {
    final photos = picked.where((ph) => !ph.item.isVideo).toList();
    if (photos.length != picked.length && mounted) {
      showCustomNotification(context, 'Видео пока нельзя зашифровать');
    }
    if (photos.isEmpty) return;

    for (final photo in photos) {
      final source =
          photo.editedFile ??
          photo.item.localFile ??
          await photo.item.originFile();
      if (source == null || !mounted) continue;

      _showAttachmentPanel.value = false;
      _uploadStatus.value = const UploadStatus(active: true);
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      final prepared = await prepareEncryptedPhoto(
        accountId: _myId,
        chatId: widget.chatId,
        source: source,
        stamp: stamp,
      );
      if (!mounted) return;
      if (!prepared.isOk) {
        _uploadStatus.value = const UploadStatus();
        showCustomNotification(
          context,
          prepared.failure == CryptoFailure.noKey
              ? 'Не задан ключ шифрования'
              : 'Не удалось зашифровать фото',
        );
        return;
      }

      final encrypted = prepared.file!;
      await _uploadAsFile(
        source: encrypted,
        filename: 'photo_$stamp$kEncryptedPhotoExtension',
        size: await encrypted.length(),
      );
      if (!mounted) return;
    }

    if (caption.isNotEmpty) {
      final wire = await _encryptOutgoing(caption);
      if (wire != null && mounted) {
        await messagesModule.sendMessage(_myId, widget.chatId, wire);
      }
    }
  }

  List<ContextMenuButtonItem> _pasteMenuItems(
    BuildContext context,
    EditableTextState editableState,
  ) {
    if (!ClipboardMedia.supported) return const [];
    return [
      ContextMenuButtonItem(
        label: AppLocalizations.of(context)!.composerPasteAttachment,
        onPressed: () {
          editableState.hideToolbar();
          unawaited(_pasteClipboardMedia());
        },
      ),
    ];
  }

  Future<bool> _handlePasteMedia() async {
    if (!await ClipboardMedia.hasMedia()) return false;
    unawaited(_pasteClipboardMedia());
    return true;
  }

  Future<void> _pasteClipboardMedia() async {
    if (_myId == 0 || _pastePending) return;
    _pastePending = true;
    try {
      final payload = await ClipboardMedia.read();
      if (!mounted) return;
      final items = payload == null
          ? const <PastedAttachment>[]
          : await materializeClipboardMedia(payload);
      if (!mounted) return;
      if (items.isEmpty) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.pasteAttachFailed,
        );
        return;
      }

      final media = items.where((it) => it.isMedia).toList();
      final documents = items.where((it) => !it.isMedia).toList();
      if (_encryptionEnabled && documents.isNotEmpty) {
        _refuseUnencrypted('Файлы');
        if (media.isEmpty) return;
        documents.clear();
      }

      final caption = await showPastePreviewSheet(
        context,
        items: [...media, ...documents],
      );
      if (caption == null || !mounted) return;

      if (media.isNotEmpty) {
        await _sendPhotos(
          media
              .map((it) => PickedPhoto(item: GalleryItem.fromFile(it.file)))
              .toList(),
          caption,
        );
      }
      for (final document in documents) {
        if (!mounted) return;
        await _uploadAsFile(
          source: document.file,
          filename: document.name,
          size: document.size,
        );
      }
    } finally {
      _pastePending = false;
    }
  }

  Future<void> _pickAndUploadFile({int? scheduledTime}) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;
    await _uploadAsFile(
      source: File(picked.path!),
      filename: picked.name,
      size: picked.size,
      scheduledTime: scheduledTime,
    );
  }

  Future<void> _uploadAsFile({
    required File source,
    required String filename,
    required int size,
    int? scheduledTime,
  }) async {
    if (_myId == 0) return;

    _showAttachmentPanel.value = false;

    final placeholder = scheduledTime != null
        ? null
        : _addOptimisticMediaMessage(
            FileAttachment(name: filename, size: size),
          );

    final sending = UploadService.instance.sendFile(
      accountId: _myId,
      chatId: widget.chatId,
      tempId: placeholder?.id ?? _nextTempId(),
      source: source,
      filename: filename,
      size: size,
      placeholder: placeholder,
      scheduledTime: scheduledTime,
    );
    _syncUploadStatus();
    await sending;
  }

}
