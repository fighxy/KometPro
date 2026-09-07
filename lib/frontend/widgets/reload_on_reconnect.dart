import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../backend/api.dart';
import 'app_scope.dart';

mixin ReloadOnReconnect<T extends StatefulWidget> on State<T> {
  StreamSubscription<SessionState>? _reconnectSub;
  late Api _api;
  int _reloadedEpoch = 0;

  void reloadAfterReconnect();

  @override
  void initState() {
    super.initState();
    _api = AppScope.read(context).api;
    _reloadedEpoch = _api.sessionEpoch;
    _reconnectSub = _api.stateStream.listen(_onSessionState);
  }

  @override
  void dispose() {
    _reconnectSub?.cancel();
    super.dispose();
  }

  void _onSessionState(SessionState state) {
    if (state != SessionState.online) return;
    if (_api.sessionEpoch == _reloadedEpoch) return;
    _reloadedEpoch = _api.sessionEpoch;
    if (mounted) reloadAfterReconnect();
  }
}
