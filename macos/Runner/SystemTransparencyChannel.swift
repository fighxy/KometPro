import Cocoa
import FlutterMacOS

/// Reports whether the system wants translucent surfaces.
///
/// System Settings → Accessibility → Display → Reduce transparency.
enum SystemTransparencyChannel {
  private static let channelName = "komet/system_transparency"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "allowsBlur":
        result(!NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
