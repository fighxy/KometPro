import 'package:flutter_webrtc/flutter_webrtc.dart';

class DirectVideo {
  static Iterable<List<String>> _sections(String sdp) sync* {
    var section = <String>[];
    for (final line in sdp.split(RegExp(r'\r?\n'))) {
      if (line.startsWith('m=') && section.isNotEmpty) {
        yield section;
        section = [];
      }
      section.add(line);
    }
    if (section.isNotEmpty) yield section;
  }

  static Set<String> videoMids(String sdp) => {
    for (final section in _sections(sdp))
      if (section.first.startsWith('m=video '))
        for (final line in section)
          if (line.startsWith('a=mid:')) line.substring(6),
  };

  static String withRemoteStreams(String sdp) {
    final sections = _sections(sdp).toList();
    for (final section in sections) {
      if (!section.first.startsWith('m=video ')) continue;
      final mid = section
          .where((line) => line.startsWith('a=mid:'))
          .firstOrNull
          ?.substring(6);
      if (mid == null) continue;
      final streamId = 'komet-remote-video-$mid';
      for (var i = 0; i < section.length; i++) {
        section[i] = section[i].replaceFirst(
          RegExp(r'^a=msid:-(?=\s|$)'),
          'a=msid:$streamId',
        );
        section[i] = section[i].replaceFirstMapped(
          RegExp(r'^(a=ssrc:\d+ msid:)-(?=\s|$)'),
          (match) => '${match[1]}$streamId',
        );
      }
    }
    return sections.expand((section) => section).join('\r\n');
  }

  static Future<RTCRtpTransceiver?> prepare(
    RTCPeerConnection pc, {
    required MediaStream stream,
    String? remoteOffer,
    RTCRtpSender? previousSender,
  }) async {
    final transceivers = await pc.getTransceivers();
    final mids = remoteOffer == null ? null : videoMids(remoteOffer);
    final candidates = transceivers.where((item) {
      if (item.stoped) return false;
      if (mids != null) return mids.contains(item.mid);
      return item.sender.track?.kind == 'video' ||
          item.receiver.track?.kind == 'video';
    }).toList();
    var transceiver =
        candidates
            .where((item) => item.sender.senderId == previousSender?.senderId)
            .firstOrNull ??
        candidates.where((item) => item.mid.isNotEmpty).firstOrNull ??
        candidates.firstOrNull;
    if (transceiver == null) {
      if (remoteOffer != null) return null;
      transceiver = await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.SendRecv,
          streams: [stream],
        ),
      );
    } else {
      await transceiver.setDirection(TransceiverDirection.SendRecv);
      await transceiver.sender.setStreams([stream]);
    }
    if (previousSender != null &&
        previousSender.senderId != transceiver.sender.senderId) {
      final track = previousSender.track;
      await previousSender.replaceTrack(null);
      if (track != null) await transceiver.sender.replaceTrack(track);
    }
    return transceiver;
  }
}
