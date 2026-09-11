import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dbus/dbus.dart';

import '../../backend/api.dart';
import '../protocol/opcode_map.dart';
import '../protocol/packet.dart';
import '../utils/logger.dart';
import 'fkm_controller.dart';
import 'notification_bridge.dart';

class LinuxNotifier {
  LinuxNotifier._();
  static final LinuxNotifier instance = LinuxNotifier._();

  static const _interface = 'org.freedesktop.Notifications';
  static const _path = '/org/freedesktop/Notifications';

  static bool get isSupported {
    try {
      return Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  final Map<int, int> _notificationChats = {};
  final Map<int, int> _chatNotifications = {};
  StreamSubscription<Packet>? _pushSub;
  StreamSubscription<DBusSignal>? _actionSub;
  StreamSubscription<DBusSignal>? _closedSub;
  DBusClient? _client;
  DBusRemoteObject? _notifications;
  bool _started = false;

  Future<void> init(Api api) async {
    if (_started || !isSupported) return;
    _started = true;
    try {
      final client = DBusClient.session();
      final notifications = DBusRemoteObject(
        client,
        name: _interface,
        path: DBusObjectPath(_path),
      );
      _client = client;
      _notifications = notifications;
      _actionSub = DBusRemoteObjectSignalStream(
        object: notifications,
        interface: _interface,
        name: 'ActionInvoked',
        signature: DBusSignature('us'),
      ).listen(_onAction, onError: _onSignalError);
      _closedSub = DBusRemoteObjectSignalStream(
        object: notifications,
        interface: _interface,
        name: 'NotificationClosed',
        signature: DBusSignature('uu'),
      ).listen(_onClosed, onError: _onSignalError);
      _pushSub = api.pushStream
          .where(
            (packet) =>
                packet.opcode == Opcode.notifMessage ||
                packet.opcode == Opcode.notifMsgDelete,
          )
          .listen(_onPush);
    } catch (e) {
      logger.w('LinuxNotifier: initialization failed: $e');
      await dispose();
    }
  }

  Future<void> _onPush(Packet packet) async {
    try {
      if (packet.opcode == Opcode.notifMsgDelete) {
        await _onDelete(packet);
      } else {
        await _onMessage(packet);
      }
    } catch (e) {
      logger.w('LinuxNotifier: $e');
    }
  }

  Future<void> _onMessage(Packet packet) async {
    final payload = packet.payload;
    if (payload is! Map) return;
    final chatId = payload['chatId'];
    final message = payload['message'];
    if (chatId is! int || message is! Map) return;
    if (payload['postId'] != null || message['postId'] != null) return;

    switch (message['status']?.toString()) {
      case 'REMOVED':
        await _closeChat(chatId);
        return;
      case 'EDITED':
        break;
    }
    if (NotificationBridge.instance.activeChatId == chatId) return;

    final data = await FkmController.instance.buildMessageNotification(
      chatId,
      message,
    );
    if (data == null) return;
    final object = _notifications;
    if (object == null) return;

    final response = await object.callMethod(
      _interface,
      'Notify',
      [
        const DBusString('Komet'),
        DBusUint32(_chatNotifications[chatId] ?? 0),
        const DBusString('ru.komet.app'),
        DBusString(_escapeMarkup(data['title'] ?? 'Komet')),
        DBusString(_escapeMarkup(data['msg'] ?? 'Новое сообщение')),
        DBusArray.string(const ['default', 'Открыть']),
        DBusDict.stringVariant({
          'desktop-entry': const DBusString('ru.komet.app'),
          'category': const DBusString('im.received'),
          'urgency': const DBusByte(1),
        }),
        const DBusInt32(-1),
      ],
      replySignature: DBusSignature('u'),
    );
    final notificationId = response.returnValues.first.asUint32();
    final previousId = _chatNotifications[chatId];
    if (previousId != null && previousId != notificationId) {
      _notificationChats.remove(previousId);
    }
    _chatNotifications[chatId] = notificationId;
    _notificationChats[notificationId] = chatId;
  }

  Future<void> _onDelete(Packet packet) async {
    final payload = packet.payload;
    if (payload is! Map) return;
    final chat = payload['chat'];
    final chatId = chat is Map && chat['id'] is int
        ? chat['id'] as int
        : payload['chatId'];
    if (chatId is int) await _closeChat(chatId);
  }

  void _onAction(DBusSignal signal) {
    if (signal.values.length < 2) return;
    final notificationId = signal.values[0].asUint32();
    final chatId = _notificationChats[notificationId];
    if (chatId == null) return;
    unawaited(
      NotificationBridge.instance.openFromPayload(jsonEncode({'chat': chatId})),
    );
  }

  void _onClosed(DBusSignal signal) {
    if (signal.values.isEmpty) return;
    final notificationId = signal.values.first.asUint32();
    final chatId = _notificationChats.remove(notificationId);
    if (chatId != null && _chatNotifications[chatId] == notificationId) {
      _chatNotifications.remove(chatId);
    }
  }

  void _onSignalError(Object error, StackTrace stackTrace) {
    logger.w('LinuxNotifier: signal error: $error');
  }

  Future<void> _closeChat(int chatId) async {
    final notificationId = _chatNotifications.remove(chatId);
    if (notificationId == null) return;
    _notificationChats.remove(notificationId);
    final object = _notifications;
    if (object == null) return;
    try {
      await object.callMethod(
        _interface,
        'CloseNotification',
        [DBusUint32(notificationId)],
      );
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _pushSub?.cancel();
    await _actionSub?.cancel();
    await _closedSub?.cancel();
    _pushSub = null;
    _actionSub = null;
    _closedSub = null;
    _notifications = null;
    _notificationChats.clear();
    _chatNotifications.clear();
    await _client?.close();
    _client = null;
    _started = false;
  }
}

String _escapeMarkup(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
