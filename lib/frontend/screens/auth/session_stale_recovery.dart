import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../backend/api.dart';
import 'package:komet/frontend/widgets/app_scope.dart';
import '../../widgets/custom_notification.dart';

mixin SessionStaleRecovery<T extends StatefulWidget> on State<T> {
  int sessionEpoch = 0;
  bool recovering = false;
  bool dropNotified = false;
  StreamSubscription<SessionState>? _stateSub;

  bool get sessionStale =>
      AppScope.read(context).api.sessionEpoch != sessionEpoch || AppScope.read(context).api.state != SessionState.online;

  String get connectionDroppedMessage;

  void recoverStaleSession();

  void startSessionRecovery() {
    sessionEpoch = AppScope.read(context).api.sessionEpoch;
    _stateSub = AppScope.read(context).api.stateStream.listen(_onSessionState);
  }

  void stopSessionRecovery() {
    _stateSub?.cancel();
  }

  void _onSessionState(SessionState state) {
    if (!mounted) return;
    if (state != SessionState.online) {
      if (!dropNotified) {
        dropNotified = true;
        showCustomNotification(context, connectionDroppedMessage);
      }
      return;
    }
    if (AppScope.read(context).api.sessionEpoch != sessionEpoch) recoverStaleSession();
  }
}
