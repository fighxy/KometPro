import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../backend/api.dart';
import '../../../../backend/app_deps.dart';
import '../../../../backend/modules/chats.dart';
import '../../../../backend/modules/messages.dart';
import '../../../../core/cache/message_session_cache.dart';
import '../../../../core/config/komet_settings.dart';
import '../../../../core/protocol/packet.dart';
import '../../../../core/storage/app_database.dart';
import '../../../../core/utils/logger.dart';

class OptimisticSendResult {
  const OptimisticSendResult({
    this.message,
    this.error,
    this.dropped = false,
  });

  final CachedMessage? message;
  final Object? error;
  final bool dropped;
}

class HistoryGap {
  HistoryGap({
    required this.edgeId,
    required this.edgeTime,
    required this.tailTime,
  });

  String edgeId;
  int edgeTime;
  final int tailTime;
}

class ChatController extends ChangeNotifier {
  ChatController({
    Api? api,
    MessagesModule? messages,
    ChatsModule? chats,
  }) : api = api ?? AppDeps.shared.api,
       messagesModule = messages ?? AppDeps.shared.messages,
       chatsModule = chats ?? AppDeps.shared.chats;

  final Api api;
  final MessagesModule messagesModule;
  final ChatsModule chatsModule;

  static const int historyPageSize = 30;
  static const int historyInitialLimit = 50;
  static const int jumpWindowBefore = 40;
  static const int jumpWindowAfter = 20;
  static const int historyWalkPageSize = 200;
  static const int gapPageSize = 60;

  int chatId = 0;
  int myId = 0;
  int _sessionGen = 0;

  List<CachedMessage> messages = [];
  final ValueNotifier<int> messagesRev = ValueNotifier(0);

  bool hasMoreHistory = true;
  bool isLoadingMore = false;
  bool historyKickedOff = false;
  bool loadingGap = false;

  final List<HistoryGap> gaps = [];

  bool get hasGap => gaps.isNotEmpty;

  static bool gapFillLeavesViewportInPlace(
    HistoryGap gap,
    int? oldestRenderedTime,
  ) => oldestRenderedTime != null && oldestRenderedTime >= gap.tailTime;

  bool Function() isMounted = () => true;

  int get sessionGen => _sessionGen;

  bool accept(int gen) => _sameSession(gen);

  bool _sameSession(int gen) => isMounted() && gen == _sessionGen;

  int attach({required int chatId, int? myId}) {
    _sessionGen++;
    this.chatId = chatId;
    if (myId != null) this.myId = myId;
    return _sessionGen;
  }

  void bump() {
    messagesRev.value++;
  }

  int prependOlder(List<CachedMessage> olderDesc) {
    if (olderDesc.isEmpty) return 0;
    final existing = messages.map((m) => m.id).toSet();
    final toAdd = <CachedMessage>[];
    for (final m in olderDesc.reversed) {
      if (existing.add(m.id)) toAdd.add(m);
    }
    if (toAdd.isEmpty) return 0;
    messages = [...toAdd, ...messages];
    messagesRev.value++;
    return toAdd.length;
  }

  bool mergeMessages(List<CachedMessage> decodedDesc) {
    final byId = <String, CachedMessage>{for (final m in messages) m.id: m};
    var changed = false;
    for (final fresh in decodedDesc) {
      final old = byId[fresh.id];
      if (old == null) {
        byId[fresh.id] = fresh;
        changed = true;
      } else if (!_sameMessage(old, fresh)) {
        byId[fresh.id] = fresh;
        changed = true;
      }
    }

    if (!changed) return false;

    final merged = byId.values.toList()
      ..sort((a, b) {
        final byTime = a.time.compareTo(b.time);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

    messages = merged;
    messagesRev.value++;
    return true;
  }

  bool _sameMessage(CachedMessage a, CachedMessage b) {
    return a.id == b.id &&
        a.time == b.time &&
        a.status == b.status &&
        a.text == b.text &&
        a.senderId == b.senderId &&
        a.deleted == b.deleted;
  }

  Future<List<CachedMessage>> loadInitialFromDb({
    required bool onlyVisible,
  }) async {
    final rows = await AppDatabase.loadMessages(
      myId,
      chatId,
      limit: historyInitialLimit,
      onlyVisible: onlyVisible,
    );
    return CachedMessage.fromDbRowsAsync(rows);
  }

  Future<List<CachedMessage>> loadOlderFromDb(
    int beforeTime,
    bool onlyVisible, {
    int? limit,
  }) async {
    final rows = await AppDatabase.loadMessagesBefore(
      myId,
      chatId,
      beforeTime: beforeTime,
      limit: limit ?? historyPageSize,
      onlyVisible: onlyVisible,
    );
    return CachedMessage.fromDbRowsAsync(rows);
  }

  Future<List<CachedMessage>> loadGapSliceFromDb(
    int afterTime,
    int beforeTime,
    bool onlyVisible,
  ) async {
    final rows = await AppDatabase.loadMessagesBetween(
      myId,
      chatId,
      afterTime: afterTime,
      beforeTime: beforeTime,
      limit: gapPageSize,
      onlyVisible: onlyVisible,
    );
    return CachedMessage.fromDbRowsAsync(rows);
  }

  Future<List<CachedMessage>> loadWindowFromDb(
    int centerTime,
    bool onlyVisible,
  ) async {
    final rows = await AppDatabase.loadMessagesAround(
      myId,
      chatId,
      centerTime: centerTime,
      before: jumpWindowBefore,
      after: jumpWindowAfter,
      onlyVisible: onlyVisible,
    );
    return CachedMessage.fromDbRowsAsync(rows);
  }

  Future<bool> loadMessageWindow({
    required String targetId,
    required int targetTime,
  }) async {
    final gen = _sessionGen;
    if (myId == 0 || targetTime <= 0) return false;
    final onlyVisible = !KometSettings.viewDeleted.value;

    var window = await loadWindowFromDb(targetTime, onlyVisible);
    if (!_sameSession(gen)) return false;

    if (!window.any((m) => m.id == targetId)) {
      final fetched = await messagesModule.fetchHistory(
        myId,
        chatId,
        fromTime: targetTime + 1,
        forward: jumpWindowAfter,
        backward: jumpWindowBefore + 1,
      );
      if (!_sameSession(gen)) return false;
      if (fetched.isNotEmpty && KometSettings.viewDeleted.value) {
        await chatsModule.reconcileDeletedFromFetch(myId, chatId, fetched);
      }
      window = await loadWindowFromDb(targetTime, onlyVisible);
      if (!_sameSession(gen)) return false;
    }

    if (window.isEmpty) return false;

    final oldestLoaded = messages.isEmpty ? 0 : messages.first.time;
    final reachesLoaded =
        messages.isEmpty || window.any((m) => m.time >= oldestLoaded);

    mergeMessages(window);

    if (reachesLoaded) {
      persistSessionCache();
    } else {
      _markGapAfterWindow(window);
    }
    return messages.any((m) => m.id == targetId);
  }

  void _markGapAfterWindow(List<CachedMessage> window) {
    var edge = window.first;
    for (final m in window) {
      if (m.time > edge.time) edge = m;
    }
    final idx = messages.indexWhere((m) => m.id == edge.id);
    if (idx == -1 || idx + 1 >= messages.length) return;
    final tailTime = messages[idx + 1].time;
    gaps.removeWhere((g) => g.tailTime == tailTime);
    gaps.add(
      HistoryGap(edgeId: edge.id, edgeTime: edge.time, tailTime: tailTime),
    );
  }

  void _closeGap(HistoryGap gap) {
    gaps.remove(gap);
    if (gaps.isEmpty) persistSessionCache();
  }

  Future<int> fillGapForward(
    HistoryGap gap, {
    void Function()? beforeApply,
  }) async {
    final gen = _sessionGen;
    if (loadingGap || myId == 0 || !gaps.contains(gap)) return 0;
    if (gap.edgeTime <= 0 || gap.tailTime <= gap.edgeTime) {
      _closeGap(gap);
      return 0;
    }

    loadingGap = true;
    try {
      final onlyVisible = !KometSettings.viewDeleted.value;
      var slice = await loadGapSliceFromDb(
        gap.edgeTime,
        gap.tailTime,
        onlyVisible,
      );
      if (!_sameSession(gen)) return 0;

      if (slice.length < gapPageSize) {
        final fetched = await messagesModule.fetchHistory(
          myId,
          chatId,
          fromTime: gap.edgeTime,
          forward: gapPageSize,
          backward: 0,
        );
        if (!_sameSession(gen)) return 0;
        if (fetched.isNotEmpty && KometSettings.viewDeleted.value) {
          await chatsModule.reconcileDeletedFromFetch(myId, chatId, fetched);
        }
        final refreshed = await loadGapSliceFromDb(
          gap.edgeTime,
          gap.tailTime,
          onlyVisible,
        );
        if (!_sameSession(gen)) return 0;
        if (refreshed.length <= slice.length) {
          if (refreshed.isNotEmpty) {
            beforeApply?.call();
            mergeMessages(refreshed);
          }
          _closeGap(gap);
          return refreshed.length;
        }
        slice = refreshed;
      }

      if (slice.isEmpty) {
        _closeGap(gap);
        return 0;
      }

      beforeApply?.call();
      mergeMessages(slice);

      var edge = slice.first;
      for (final m in slice) {
        if (m.time > edge.time) edge = m;
      }
      gap.edgeId = edge.id;
      gap.edgeTime = edge.time;
      if (edge.time >= gap.tailTime) _closeGap(gap);
      return slice.length;
    } catch (e) {
      logger.e('Error filling history gap: $e');
      return 0;
    } finally {
      loadingGap = false;
    }
  }

  void persistSessionCache() {
    if (myId == 0 || messages.isEmpty || hasGap) return;
    MessageSessionCache.save(
      myId,
      chatId,
      messages,
      reachedStart: !hasMoreHistory,
    );
  }

  Future<void> loadMoreHistory({
    required void Function() onLoadingStarted,
    required void Function(int added) onLoaded,
    required void Function(Object error) onError,
    int? pageSize,
    bool persist = true,
  }) async {
    final gen = _sessionGen;
    if (isLoadingMore || !hasMoreHistory || messages.isEmpty) return;
    isLoadingMore = true;
    onLoadingStarted();

    final size = pageSize ?? historyPageSize;
    final oldest = messages.first;
    final onlyVisible = !KometSettings.viewDeleted.value;

    try {
      var older = await loadOlderFromDb(oldest.time, onlyVisible, limit: size);

      if (older.length < size) {
        final fetched = await messagesModule.fetchHistory(
          myId,
          chatId,
          fromTime: oldest.time,
          count: size,
        );
        if (fetched.isNotEmpty) {
          if (KometSettings.viewDeleted.value) {
            await chatsModule.reconcileDeletedFromFetch(myId, chatId, fetched);
          }
          older = await loadOlderFromDb(oldest.time, onlyVisible, limit: size);
        }
      }

      if (!_sameSession(gen)) return;
      final added = prependOlder(older);
      isLoadingMore = false;
      if (added == 0) hasMoreHistory = false;
      if (persist) persistSessionCache();
      onLoaded(added);
    } catch (e) {
      logger.e('Error loading more history: $e');
      onError(e);
    }
  }

  Future<void> loadRemainingHistory({
    required void Function(List<CachedMessage> decoded, {bool markLoaded})
    onApplyMerged,
    required void Function() onLoadingFinished,
    required void Function() onPreview,
    required void Function() onSenderNames,
  }) async {
    final gen = _sessionGen;
    final onlyVisible = !KometSettings.viewDeleted.value;
    final cachedRows = await AppDatabase.loadChat(myId, chatId);
    final preview =
        cachedRows.isEmpty || !AppDatabase.chatRowIsInList(cachedRows.first);
    if (preview) {
      onPreview();
      if (cachedRows.isEmpty) {
        await chatsModule.ensureChatCached(api, myId, chatId);
      }
      await chatsModule.subscribeChat(api, chatId);
    }

    final fullDecoded = await loadInitialFromDb(onlyVisible: onlyVisible);
    if (_sameSession(gen)) {
      onApplyMerged(fullDecoded);
    }

    if (fullDecoded.isNotEmpty && chatsModule.wasHistoryFetched(chatId)) {
      if (_sameSession(gen)) {
        onLoadingFinished();
      }
      onSenderNames();
      return;
    }

    try {
      final serverMessages = await messagesModule.fetchHistory(myId, chatId);
      chatsModule.markHistoryFetched(chatId);
      if (KometSettings.viewDeleted.value) {
        await chatsModule.reconcileDeletedFromFetch(myId, chatId, serverMessages);
      }
      final updatedDecoded = await loadInitialFromDb(onlyVisible: onlyVisible);
      if (_sameSession(gen)) {
        onApplyMerged(updatedDecoded, markLoaded: true);
      }
      unawaited(chatsModule.reconcileLastMessageIfPlaceholder(myId, chatId));
      onSenderNames();
    } catch (e) {
      logger.e('Error fetching history: $e');
      if (_sameSession(gen)) {
        onLoadingFinished();
      }
    }
  }

  bool get isOnline => api.state == SessionState.online;

  Future<List<CachedMessage>> refreshLatest() async {
    final gen = _sessionGen;
    final serverMessages = await messagesModule.fetchHistory(myId, chatId);
    if (!_sameSession(gen)) return const [];
    if (KometSettings.viewDeleted.value) {
      await chatsModule.reconcileDeletedFromFetch(myId, chatId, serverMessages);
    }
    if (!_sameSession(gen)) return const [];
    final onlyVisible = !KometSettings.viewDeleted.value;
    final rows = await AppDatabase.loadMessages(
      myId,
      chatId,
      limit: 100,
      onlyVisible: onlyVisible,
    );
    if (!_sameSession(gen)) return const [];
    return CachedMessage.fromDbRowsAsync(rows);
  }

  Future<String> sendText(
    String text, {
    int? scheduledTime,
    int? replyToMessageId,
    int? replySourceChatId,
    List<Map<String, dynamic>> elements = const [],
  }) async {
    final gen = _sessionGen;
    final id = await messagesModule.sendMessage(
      myId,
      chatId,
      text,
      scheduledTime: scheduledTime,
      replyToMessageId: replyToMessageId,
      replySourceChatId: replySourceChatId,
      elements: elements,
    );
    if (!_sameSession(gen)) return '';
    return id;
  }

  void appendMessage(CachedMessage msg) {
    messages.add(msg);
    messagesRev.value++;
  }

  void replaceMessage(String id, CachedMessage next) {
    final i = messages.indexWhere((m) => m.id == id);
    if (i == -1) return;
    messages[i] = next;
    messagesRev.value++;
  }

  void removeMessage(String id) {
    final before = messages.length;
    messages.removeWhere((m) => m.id == id);
    if (messages.length != before) messagesRev.value++;
  }

  Future<void> persistOutgoing(CachedMessage msg, {String? removeId}) async {
    try {
      if (removeId != null && removeId != msg.id) {
        await AppDatabase.deleteMessage(myId, chatId, removeId);
      }
      await AppDatabase.saveMessages([msg.toDbRow()]);
    } catch (_) {}
  }

  Future<void> previewOutgoing(
    CachedMessage msg, {
    List<Map<String, dynamic>> elements = const [],
  }) {
    return chatsModule.applyOutgoing(
      myId,
      chatId,
      messageId: msg.id,
      time: msg.time,
      text: msg.text ?? '',
      status: msg.status ?? 'sending',
      elements: elements,
    );
  }

  /// Inserts [composed] immediately, then sends. Session change drops the result.
  Future<OptimisticSendResult> dispatchOptimisticText({
    required CachedMessage composed,
    List<Map<String, dynamic>> elements = const [],
    int? replyToMessageId,
    int? replySourceChatId,
    bool persist = true,
  }) async {
    final gen = _sessionGen;
    final tempId = composed.id;
    appendMessage(composed);
    if (persist) {
      unawaited(persistOutgoing(composed));
      unawaited(previewOutgoing(composed, elements: elements));
    }
    if (!isOnline) {
      return OptimisticSendResult(message: composed);
    }
    try {
      final id = await messagesModule.sendMessage(
        myId,
        chatId,
        composed.text ?? '',
        replyToMessageId: replyToMessageId,
        replySourceChatId: replySourceChatId,
        elements: elements,
      );
      if (!_sameSession(gen)) return const OptimisticSendResult(dropped: true);
      final realId = id.isNotEmpty ? id : tempId;
      final sent = CachedMessage(
        id: realId,
        accountId: composed.accountId,
        chatId: composed.chatId,
        senderId: composed.senderId,
        text: composed.text,
        time: composed.time,
        status: 'sent',
        payload: composed.payload,
        attachments: composed.attachments,
      );
      replaceMessage(tempId, sent);
      if (persist) {
        unawaited(persistOutgoing(sent, removeId: tempId));
        unawaited(previewOutgoing(sent, elements: elements));
      }
      return OptimisticSendResult(message: sent);
    } catch (e) {
      if (!_sameSession(gen)) {
        return OptimisticSendResult(dropped: true, error: e);
      }
      if (replySourceChatId != null) {
        removeMessage(tempId);
        unawaited(AppDatabase.deleteMessage(myId, chatId, tempId));
        return OptimisticSendResult(error: e);
      }
      final status = isPermanentSendFailure(e) ? 'error' : 'pending';
      if (status == 'error') logger.w('Отправка отклонена сервером: $e');
      final queued = CachedMessage(
        id: tempId,
        accountId: composed.accountId,
        chatId: composed.chatId,
        senderId: composed.senderId,
        text: composed.text,
        time: composed.time,
        status: status,
        payload: composed.payload,
        attachments: composed.attachments,
      );
      replaceMessage(tempId, queued);
      if (persist) {
        unawaited(persistOutgoing(queued));
        unawaited(previewOutgoing(queued, elements: elements));
      }
      return OptimisticSendResult(message: queued, error: e);
    }
  }

  Future<bool> editText(String messageId, String text) async {
    final gen = _sessionGen;
    final ok = await messagesModule.editMessage(chatId, messageId, text: text);
    return ok && _sameSession(gen);
  }

  Future<String?> sendFile(
    int fileId, {
    String? token,
  }) async {
    final gen = _sessionGen;
    final id = await messagesModule.sendFileMessage(
      chatId,
      fileId,
      token: token,
    );
    if (!_sameSession(gen)) return null;
    return id;
  }

  Future<Map<String, dynamic>?> sendSticker(int stickerId) async {
    final gen = _sessionGen;
    final result = await messagesModule.sendStickerMessage(chatId, stickerId);
    if (!_sameSession(gen)) return null;
    return result;
  }

  Future<Map<String, dynamic>?> sendLocation(double lat, double lon) async {
    final gen = _sessionGen;
    final result = await messagesModule.sendLocationMessage(chatId, lat, lon);
    if (!_sameSession(gen)) return null;
    return result;
  }

  Future<Map<String, dynamic>?> sendContact(int contactId) async {
    final gen = _sessionGen;
    final result = await messagesModule.sendContactMessage(chatId, contactId);
    if (!_sameSession(gen)) return null;
    return result;
  }

  Future<Map<String, dynamic>?> sendPoll({
    required String title,
    required List<String> options,
    bool multiple = false,
    bool anonymous = true,
  }) async {
    final gen = _sessionGen;
    final result = await messagesModule.sendPollMessage(
      chatId,
      title,
      options,
      multiple: multiple,
      anonymous: anonymous,
    );
    if (!_sameSession(gen)) return null;
    return result;
  }

  Future<Map<String, dynamic>?> sendBotStart(String startPayload) async {
    final gen = _sessionGen;
    final result = await messagesModule.sendBotStart(chatId, startPayload);
    if (!_sameSession(gen)) return null;
    return result;
  }

  @override
  void dispose() {
    _sessionGen++;
    isMounted = () => false;
    messagesRev.dispose();
    super.dispose();
  }
}
