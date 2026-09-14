import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:komet/core/calls/direct_video.dart';

void main() {
  test(
    'audio call starts bidirectional video without a second negotiation',
    () async {
      final caller = await createPeerConnection({});
      final callee = await createPeerConnection({});
      final captures = <MediaStream>[];
      addTearDown(() async {
        await caller.close();
        await callee.close();
        for (final stream in captures) {
          for (final track in stream.getTracks()) {
            await track.stop();
          }
          await stream.dispose();
        }
      });
      final callerTracks = <RTCTrackEvent>[];
      final calleeTracks = <RTCTrackEvent>[];
      caller.onTrack = callerTracks.add;
      callee.onTrack = calleeTracks.add;
      final callerIce = <RTCIceCandidate>[];
      final calleeIce = <RTCIceCandidate>[];
      var negotiated = false;
      caller.onIceCandidate = (candidate) {
        if (candidate.candidate?.isEmpty != false) return;
        if (negotiated) {
          unawaited(callee.addCandidate(candidate));
        } else {
          callerIce.add(candidate);
        }
      };
      callee.onIceCandidate = (candidate) {
        if (candidate.candidate?.isEmpty != false) return;
        if (negotiated) {
          unawaited(caller.addCandidate(candidate));
        } else {
          calleeIce.add(candidate);
        }
      };
      final callerAudio = await navigator.mediaDevices.getUserMedia({
        'audio': true,
      });
      final calleeAudio = await navigator.mediaDevices.getUserMedia({
        'audio': true,
      });
      captures.addAll([callerAudio, calleeAudio]);
      await caller.addTrack(callerAudio.getAudioTracks().single, callerAudio);
      await callee.addTrack(calleeAudio.getAudioTracks().single, calleeAudio);
      final callerVideo = (await DirectVideo.prepare(
        caller,
        stream: callerAudio,
      ))!;
      final offer = await caller.createOffer({});
      await caller.setLocalDescription(offer);
      await callee.setRemoteDescription(
        RTCSessionDescription(
          DirectVideo.withRemoteStreams(offer.sdp!),
          'offer',
        ),
      );
      final calleeVideo = (await DirectVideo.prepare(
        callee,
        stream: calleeAudio,
        remoteOffer: offer.sdp,
      ))!;
      final answer = await callee.createAnswer({});
      await callee.setLocalDescription(answer);
      await caller.setRemoteDescription(
        RTCSessionDescription(
          DirectVideo.withRemoteStreams(answer.sdp!),
          'answer',
        ),
      );
      negotiated = true;
      for (final candidate in callerIce) {
        await callee.addCandidate(candidate);
      }
      for (final candidate in calleeIce) {
        await caller.addCandidate(candidate);
      }
      expect(
        await callerVideo.getCurrentDirection(),
        TransceiverDirection.SendRecv,
      );
      expect(
        await calleeVideo.getCurrentDirection(),
        TransceiverDirection.SendRecv,
      );
      expect(
        callerTracks.where((e) => e.track.kind == 'video').single.streams,
        isNotEmpty,
      );
      expect(
        calleeTracks.where((e) => e.track.kind == 'video').single.streams,
        isNotEmpty,
      );
      final cameraA = await navigator.mediaDevices.getUserMedia({
        'video': true,
      });
      final cameraB = await navigator.mediaDevices.getUserMedia({
        'video': true,
      });
      captures.addAll([cameraA, cameraB]);
      await callerVideo.sender.replaceTrack(cameraA.getVideoTracks().single);
      await calleeVideo.sender.replaceTrack(cameraB.getVideoTracks().single);
      await _waitForFrames(caller);
      await _waitForFrames(callee);
      final before = await _frames(caller);
      await calleeVideo.sender.replaceTrack(null);
      await calleeVideo.sender.replaceTrack(cameraA.getVideoTracks().single);
      await _waitForFrames(caller, after: before);
    },
    skip: !kIsWeb,
  );
}

Future<int> _frames(RTCPeerConnection pc) async {
  final reports = await pc.getStats();
  return reports
      .where((report) => report.type == 'inbound-rtp')
      .fold<int>(
        0,
        (sum, report) =>
            sum + ((report.values['framesDecoded'] as num?)?.toInt() ?? 0),
      );
}

Future<void> _waitForFrames(RTCPeerConnection pc, {int after = 0}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (await _frames(pc) > after + 5) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('No decoded video frames after replaceTrack');
}
