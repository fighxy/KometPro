import AVFoundation
import Flutter

/// Owns `AVAudioSession` while the app plays media.
///
/// `video_player_avfoundation` never configures the session, so playback
/// inherits the launch default (silenced by the ring switch) or whatever
/// `flutter_webrtc` and `record_ios` left behind after a call or a voice
/// recording — `playAndRecord`, routed to the earpiece. Claiming `.playback`
/// for the duration of playback is the only thing that makes media audible in
/// every one of those states.
final class KometAudioSession {
  static let shared = KometAudioSession()

  private var owned = false

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "beginPlayback":
      result(NSNumber(value: begin()))
    case "endPlayback":
      result(NSNumber(value: end()))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func begin() -> Bool {
    let session = AVAudioSession.sharedInstance()
    guard session.mode != .voiceChat else { return false }
    do {
      try session.setCategory(.playback, mode: .moviePlayback)
      try session.setActive(true)
      owned = true
      return true
    } catch {
      NSLog("[komet] audio session activate failed: \(error)")
      return false
    }
  }

  private func end() -> Bool {
    guard owned else { return true }
    owned = false
    let session = AVAudioSession.sharedInstance()
    guard session.category == .playback else { return true }
    do {
      try session.setActive(false, options: .notifyOthersOnDeactivation)
      return true
    } catch {
      NSLog("[komet] audio session deactivate failed: \(error)")
      return false
    }
  }
}
