import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../backend/api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../utils/logger.dart';
import 'fkm_controller.dart';
import 'notification_bridge.dart';
import 'push_service.dart';

class WindowsNotifier {
  WindowsNotifier._();
  static final WindowsNotifier instance = WindowsNotifier._();

  static bool get isSupported {
    try {
      return Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  StreamSubscription<Packet>? _pushSub;
  bool _started = false;

  Future<void> init(Api api) async {
    if (_started || !isSupported) return;
    _started = true;
    await initLocalNotificationActions();
    _pushSub = api.pushStream
        .where(
          (packet) =>
              packet.opcode == Opcode.notifMessage ||
              packet.opcode == Opcode.notifMsgDelete,
        )
        .listen(_onPush);
  }

  Future<void> _onPush(Packet packet) async {
    try {
      if (packet.opcode == Opcode.notifMsgDelete) {
        await _onDelete(packet);
      } else {
        await _onMessage(packet);
      }
    } catch (e) {
      logger.w('WindowsNotifier: $e');
    }
  }

  Future<void> _onMessage(Packet packet) async {
    final payload = packet.payload;
    if (payload is! Map) return;
    final chatId = payload['chatId'];
    if (chatId is! int) return;
    final msg = payload['message'];
    if (msg is! Map) return;
    if (payload['postId'] != null || msg['postId'] != null) return;

    final msgId = msg['id']?.toString();
    switch (msg['status']?.toString()) {
      case 'REMOVED':
        if (msgId != null) await PushService.clearChatNotification(chatId);
        return;
      case 'EDITED':
        break;
    }

    if (NotificationBridge.instance.activeChatId == chatId) return;

    final data = await FkmController.instance.buildMessageNotification(
      chatId,
      msg,
    );
    if (data == null) return;

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.show(
      id: chatId & 0x7fffffff,
      title: data['title'] ?? 'Komet',
      body: data['msg'] ?? 'Новое сообщение',
      notificationDetails: const NotificationDetails(
        windows: WindowsNotificationDetails(),
      ),
      payload: jsonEncode({'chat': chatId}),
    );
  }

  Future<void> _onDelete(Packet packet) async {
    final payload = packet.payload;
    if (payload is! Map) return;
    final chat = payload['chat'];
    final chatId = (chat is Map && chat['id'] is int)
        ? chat['id'] as int
        : payload['chatId'];
    if (chatId is! int) return;
    await PushService.clearChatNotification(chatId);
  }

  void dispose() {
    _pushSub?.cancel();
    _pushSub = null;
    _started = false;
  }
}
