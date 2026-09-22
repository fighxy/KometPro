import Flutter
import UIKit
import UserNotifications

/// Incoming-call notifications on iOS.
///
/// There is no FCM or PushKit on this platform, so a call only ever arrives
/// over the app's own socket. While the app is in the foreground the call
/// sheet handles it; backgrounded, this posts a time-sensitive local
/// notification and feeds the tap back through `calls_events`, the same
/// contract the Android side uses.
final class KometCalls: NSObject {
  static let shared = KometCalls()

  private static let categoryId = "KOMET_INCOMING_CALL"
  private static let answerActionId = "KOMET_CALL_ANSWER"
  private static let requestId = "komet_incoming_call"
  private static let payloadKey = "komet_call"

  private var sink: FlutterEventSink?
  private var pending: [String: Any]?

  func start() {
    let answer = UNNotificationAction(
      identifier: Self.answerActionId,
      title: "Ответить",
      options: [.foreground])
    let category = UNNotificationCategory(
      identifier: Self.categoryId,
      actions: [answer],
      intentIdentifiers: [],
      options: [.hiddenPreviewsShowTitle])
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  func attach(_ sink: FlutterEventSink?) {
    self.sink = sink
    guard let sink = sink, let pending = pending else { return }
    self.pending = nil
    sink(pending)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermission":
      requestAuthorization { granted in result(NSNumber(value: granted)) }
    case "showIncoming":
      let data = (call.arguments as? [String: Any])?["data"] as? [String: String]
      guard let data = data else {
        result(FlutterError(code: "BAD_ARGS", message: "data required", details: nil))
        return
      }
      showIncoming(data)
      result(nil)
    case "consumeInitialCall":
      let event = pending
      pending = nil
      result(event)
    case "cancelIncoming", "notifyAccepted", "notifyEnded":
      cancelIncoming()
      result(nil)
    case "ensureOngoing", "setScreenShare", "dropOngoing":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
    UNUserNotificationCenter.current()
      .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if let error = error {
          NSLog("[komet] call notification authorization failed: \(error)")
        }
        DispatchQueue.main.async { completion?(granted) }
      }
  }

  private func showIncoming(_ data: [String: String]) {
    guard let payload = Self.json(data) else { return }
    let name = data["userName"] ?? data["title"] ?? "Неизвестный"
    let isVideo = data["iv"] == "true" || data["type"] == "VIDEO"

    let content = UNMutableNotificationContent()
    content.title = name
    content.body = isVideo ? "Входящий видеозвонок" : "Входящий звонок"
    content.sound = .default
    content.categoryIdentifier = Self.categoryId
    content.userInfo = [Self.payloadKey: payload]
    if #available(iOS 15.0, *) {
      content.interruptionLevel = .timeSensitive
      content.relevanceScore = 1
    }

    let request = UNNotificationRequest(
      identifier: Self.requestId, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
      guard let error = error else { return }
      NSLog("[komet] incoming call notification failed: \(error)")
    }
  }

  private func cancelIncoming() {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [Self.requestId])
    center.removeDeliveredNotifications(withIdentifiers: [Self.requestId])
  }

  /// Returns true when the notification belonged to a call, so the chat
  /// delegate leaves it alone.
  func handleResponse(_ response: UNNotificationResponse) -> Bool {
    let userInfo = response.notification.request.content.userInfo
    guard let payload = userInfo[Self.payloadKey] as? String else { return false }
    cancelIncoming()
    guard response.actionIdentifier != UNNotificationDismissActionIdentifier else {
      return true
    }
    let action = response.actionIdentifier == Self.answerActionId ? "answer" : "ring"
    let event: [String: Any] = ["action": action, "data": payload]
    if let sink = sink {
      sink(event)
    } else {
      pending = event
    }
    return true
  }

  func isCallNotification(_ notification: UNNotification) -> Bool {
    notification.request.content.userInfo[Self.payloadKey] is String
  }

  private static func json(_ data: [String: String]) -> String? {
    guard let encoded = try? JSONSerialization.data(withJSONObject: data) else { return nil }
    return String(data: encoded, encoding: .utf8)
  }
}
