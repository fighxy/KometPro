import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:komet/core/calls/direct_video.dart';

const _offer =
    'v=0\r\n'
    'a=msid-semantic: WMS *\r\n'
    'm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
    'a=mid:audio\r\n'
    'a=msid:audio-stream microphone\r\n'
    'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
    'a=mid:camera\r\n'
    'a=sendrecv\r\n'
    'a=msid:- video-track\r\n'
    'a=ssrc:1234 msid:- video-track\r\n';

void main() {
  test(
    'streamless video gets a native stream without changing track identity',
    () {
      final sdp = DirectVideo.withRemoteStreams(_offer);
      expect(sdp, contains('a=msid:komet-remote-video-camera video-track\r\n'));
      expect(
        sdp,
        contains('a=ssrc:1234 msid:komet-remote-video-camera video-track'),
      );
      expect(sdp, contains('a=msid:audio-stream microphone\r\n'));
      expect(sdp, contains('a=sendrecv\r\n'));
      expect(DirectVideo.withRemoteStreams(sdp), sdp);
    },
  );

  test('existing remote stream associations are preserved', () {
    final sdp = _offer.replaceAll('msid:- ', 'msid:peer-stream ');
    expect(DirectVideo.withRemoteStreams(sdp), sdp);
  });

  test('each streamless video section gets its own stable stream', () {
    final sdp = DirectVideo.withRemoteStreams(
      '$_offer'
      'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
      'a=mid:screen\r\n'
      'a=msid:- screen-track\r\n',
    );
    expect(sdp, contains('a=msid:komet-remote-video-camera video-track'));
    expect(sdp, contains('a=msid:komet-remote-video-screen screen-track'));
  });

  test('caller reserves a bidirectional video slot with a stream', () async {
    final pc = _Peer([]);
    final stream = _Stream();
    final transceiver = await DirectVideo.prepare(pc, stream: stream);
    expect(transceiver, same(pc.slots.single));
    expect(pc.addedInit!.direction, TransceiverDirection.SendRecv);
    expect(pc.addedInit!.streams, [stream]);
  });

  test(
    'callee uses the offered mid instead of an unassociated local slot',
    () async {
      final unused = _Transceiver('', _Sender('unused'));
      final negotiated = _Transceiver('camera', _Sender('negotiated'));
      final pc = _Peer([unused, negotiated]);
      final stream = _Stream();
      final chosen = await DirectVideo.prepare(
        pc,
        stream: stream,
        remoteOffer: _offer,
        previousSender: unused.sender,
      );
      expect(chosen, same(negotiated));
      expect(negotiated.direction, TransceiverDirection.SendRecv);
      expect(negotiated.sender.streams, [stream]);
      expect(pc.addedInit, isNull);
      expect(unused.direction, isNull);
    },
  );

  test(
    'camera already attached to the wrong sender moves to the negotiated slot',
    () async {
      final camera = _Track();
      final unused = _Transceiver('', _Sender('unused', camera));
      final negotiated = _Transceiver('camera', _Sender('negotiated'));
      await DirectVideo.prepare(
        _Peer([unused, negotiated]),
        stream: _Stream(),
        remoteOffer: _offer,
        previousSender: unused.sender,
      );
      expect(unused.sender.track, isNull);
      expect(negotiated.sender.track, same(camera));
    },
  );

  test('renegotiation keeps the existing sender and attached track', () async {
    final camera = _Track();
    final slot = _Transceiver('camera', _Sender('sender', camera));
    final pc = _Peer([_Transceiver('', _Sender('unused')), slot]);
    await DirectVideo.prepare(
      pc,
      stream: _Stream(),
      previousSender: slot.sender,
    );
    expect(slot.sender.track, same(camera));
    expect(slot.sender.replacements, isEmpty);
    expect(pc.addedInit, isNull);
  });

  test(
    'audio-only offer does not create an unnegotiated video sender',
    () async {
      final pc = _Peer([]);
      final chosen = await DirectVideo.prepare(
        pc,
        stream: _Stream(),
        remoteOffer:
            'v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111\r\na=mid:audio\r\n',
      );
      expect(chosen, isNull);
      expect(pc.addedInit, isNull);
    },
  );
}

class _Peer extends Fake implements RTCPeerConnection {
  _Peer(this.slots);
  final List<_Transceiver> slots;
  RTCRtpTransceiverInit? addedInit;

  @override
  Future<List<RTCRtpTransceiver>> getTransceivers() async => slots;

  @override
  Future<RTCRtpTransceiver> addTransceiver({
    MediaStreamTrack? track,
    RTCRtpMediaType? kind,
    RTCRtpTransceiverInit? init,
  }) async {
    addedInit = init;
    final slot = _Transceiver('', _Sender('added'));
    slots.add(slot);
    return slot;
  }
}

class _Transceiver extends Fake implements RTCRtpTransceiver {
  _Transceiver(this.mid, this.sender);
  @override
  final String mid;
  @override
  final _Sender sender;
  TransceiverDirection? direction;

  @override
  bool get stoped => false;

  @override
  RTCRtpReceiver get receiver => _Receiver();

  @override
  Future<void> setDirection(TransceiverDirection direction) async {
    this.direction = direction;
  }
}

class _Sender extends Fake implements RTCRtpSender {
  _Sender(this.senderId, [this.track]);
  @override
  final String senderId;
  @override
  MediaStreamTrack? track;
  List<MediaStream>? streams;
  final replacements = <MediaStreamTrack?>[];

  @override
  Future<void> setStreams(List<MediaStream> streams) async {
    this.streams = streams;
  }

  @override
  Future<void> replaceTrack(MediaStreamTrack? track) async {
    replacements.add(track);
    this.track = track;
  }
}

class _Receiver extends Fake implements RTCRtpReceiver {
  @override
  MediaStreamTrack get track => _Track();
}

class _Track extends Fake implements MediaStreamTrack {
  @override
  String get kind => 'video';
}

class _Stream extends Fake implements MediaStream {}
