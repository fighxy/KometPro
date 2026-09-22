import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Claims the shared iOS audio session while media is playing.
///
/// `video_player` deliberately leaves `AVAudioSession` alone, so playback
/// inherits whatever category is live: the launch default that the ring
/// switch silences, or the `playAndRecord` route that a finished call or a
/// voice recording leaves pointing at the earpiece. Every player holds the
/// session here for as long as it is playing and hands it back afterwards.
class MediaAudioSession {
  MediaAudioSession._();

  static final MediaAudioSession instance = MediaAudioSession._();

  static const _method = MethodChannel('ru.komet.app/audio_session');

  final Set<Object> _holders = {};

  static bool get _supported {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  void hold(Object owner) {
    if (!_supported || !_holders.add(owner)) return;
    if (_holders.length == 1) unawaited(_invoke('beginPlayback'));
  }

  void release(Object owner) {
    if (!_supported || !_holders.remove(owner)) return;
    if (_holders.isEmpty) unawaited(_invoke('endPlayback'));
  }

  Future<void> _invoke(String method) async {
    try {
      await _method.invokeMethod<void>(method);
    } catch (e) {
      logger.w('MediaAudioSession.$method: $e');
    }
  }
}
