import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../backend/api.dart';
import '../../frontend/widgets/max_link_nav.dart';
import '../../main.dart';
import '../desktop/desktop_tray.dart';
import '../utils/logger.dart';

class NotificationBridge {
  NotificationBridge._();
  static final NotificationBridge instance = NotificationBridge._();

  static const _method = MethodChannel('ru.komet.app/notifications');
  static const _events = EventChannel('ru.komet.app/notification_events');
  static const _retryDelay = Duration(milliseconds: 300);
  static const _maxRetries = 100;

  final List<int> _activeChats = [];

  bool _started = false;
  bool _ready = false;
  int _pendingChatId = 0;
  int _sentChatId = 0;
  int _retriesLeft = 0;
  Timer? _retry;

  int get _activeChatId => _activeChats.isEmpty ? 0 : _activeChats.last;

  int? get activeChatId {
    final id = _activeChatId;
    return id > 0 ? id : null;
  }

  bool get _native {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  void init() {
    if (_started) return;
    _started = true;
    if (_native) {
      _events.receiveBroadcastStream().listen(
        _onEvent,
        onError: (e) => logger.w('NotificationBridge: events stream error: $e'),
      );
    }
    api.stateStream.listen((state) {
      if (state == SessionState.online) _flushPending();
    });
  }

  void markReady() {
    _ready = true;
    _flushPending();
  }

  Future<void> openFromPayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    int? chatId;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        chatId = (decoded['chat'] as num?)?.toInt();
      }
    } catch (_) {
      chatId = int.tryParse(payload);
    }
    if (chatId == null || chatId <= 0) return;
    await DesktopTray.instance.reveal();
    final context = KometApp.navigatorKey.currentContext;
    if (context == null) return;
    await openChatById(context, chatId);
  }

  Future<void> checkInitialChat() async {
    if (!_native) return;
    try {
      _onEvent(await _method.invokeMethod<dynamic>('consumeInitialChat'));
    } catch (e) {
      logger.w('NotificationBridge.checkInitialChat: $e');
    }
  }

  Future<void> pushActiveChat(int chatId) async {
    if (chatId <= 0) return;
    _activeChats.add(chatId);
    await _syncActiveChat();
  }

  Future<void> popActiveChat(int chatId) async {
    if (chatId <= 0) return;
    final index = _activeChats.lastIndexOf(chatId);
    if (index < 0) return;
    _activeChats.removeAt(index);
    await _syncActiveChat();
  }

  Future<void> _syncActiveChat() async {
    final chatId = _activeChatId;
    if (chatId == _sentChatId) return;
    _sentChatId = chatId;
    if (!_native) return;
    try {
      if (chatId > 0) {
        await _method.invokeMethod<void>('setActiveChat', {'chatId': chatId});
      } else {
        await _method.invokeMethod<void>('clearActiveChat');
      }
    } catch (e) {
      logger.w('NotificationBridge: активный чат не синхронизирован: $e');
    }
  }

  void _onEvent(Object? event) {
    final chatId = event is int ? event : int.tryParse(event?.toString() ?? '');
    if (chatId == null || chatId <= 0) return;
    _pendingChatId = chatId;
    _retriesLeft = _maxRetries;
    _flushPending();
  }

  void _flushPending() {
    final chatId = _pendingChatId;
    if (chatId <= 0) return;

    final context = KometApp.navigatorKey.currentContext;
    if (!_ready || context == null || api.state != SessionState.online) {
      if (_retriesLeft <= 0) {
        _pendingChatId = 0;
        return;
      }
      _retriesLeft--;
      _retry ??= Timer(_retryDelay, () {
        _retry = null;
        _flushPending();
      });
      return;
    }

    _pendingChatId = 0;
    if (_activeChatId == chatId) return;
    unawaited(openChatById(context, chatId));
  }
}
