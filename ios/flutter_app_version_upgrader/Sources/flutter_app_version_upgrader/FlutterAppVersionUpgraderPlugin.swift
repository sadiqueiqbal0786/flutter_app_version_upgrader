import Flutter
import UIKit

/// Native half of `flutter_app_version_upgrader`.
///
/// Exposes only what Dart cannot do on its own:
///  - `getAppInfo`   : bundle identifier, CFBundleShortVersionString, CFBundleVersion
///  - `readCache` / `writeCache` / `clearCache` : UserDefaults-backed cache
///  - `openStore`    : opens a URL, or the App Store listing for a given app id
public class FlutterAppVersionUpgraderPlugin: NSObject, FlutterPlugin {
  static let channelName = "flutter_app_version_upgrader"
  static let cachePrefix = "flutter_app_version_upgrader."

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = FlutterAppVersionUpgraderPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "getAppInfo":
      result(appInfo())

    case "readCache":
      guard let key = args["key"] as? String else {
        return result(invalidArgument("key"))
      }
      result(UserDefaults.standard.string(forKey: Self.cachePrefix + key))

    case "writeCache":
      guard let key = args["key"] as? String else {
        return result(invalidArgument("key"))
      }
      guard let value = args["value"] as? String else {
        return result(invalidArgument("value"))
      }
      UserDefaults.standard.set(value, forKey: Self.cachePrefix + key)
      result(nil)

    case "clearCache":
      guard let key = args["key"] as? String else {
        return result(invalidArgument("key"))
      }
      UserDefaults.standard.removeObject(forKey: Self.cachePrefix + key)
      result(nil)

    case "openStore":
      openStore(url: args["url"] as? String, appStoreId: args["appStoreId"] as? String) { launched in
        result(launched)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func invalidArgument(_ name: String) -> FlutterError {
    FlutterError(code: "invalid_argument", message: "Missing '\(name)'", details: nil)
  }

  private func appInfo() -> [String: Any] {
    let bundle = Bundle.main
    let info = bundle.infoDictionary ?? [:]
    let version = info["CFBundleShortVersionString"] as? String ?? ""
    let buildString = info["CFBundleVersion"] as? String ?? ""
    // CFBundleVersion may be "123" or "1.2.3"; only a plain integer is a
    // usable build number. Dart treats anything else as unknown.
    let build: Any = Int(buildString) ?? buildString
    return [
      "packageName": bundle.bundleIdentifier ?? "",
      "versionName": version,
      "buildNumber": build,
      "platform": "ios",
    ]
  }

  /// Opens `url` when provided. Otherwise opens the App Store listing for
  /// `appStoreId`, preferring the `itms-apps` scheme and falling back to the
  /// web URL.
  private func openStore(url: String?, appStoreId: String?, completion: @escaping (Bool) -> Void) {
    var candidates: [String] = []
    if let url = url, !url.isEmpty {
      candidates.append(url)
    } else if let id = appStoreId, !id.isEmpty {
      candidates.append("itms-apps://apps.apple.com/app/id\(id)")
      candidates.append("https://apps.apple.com/app/id\(id)")
    }
    tryOpen(candidates, completion: completion)
  }

  private func tryOpen(_ candidates: [String], completion: @escaping (Bool) -> Void) {
    guard let first = candidates.first, let target = URL(string: first) else {
      return completion(false)
    }
    let rest = Array(candidates.dropFirst())
    // `open` reports failure through its completion, so no `canOpenURL`
    // (which would require LSApplicationQueriesSchemes for itms-apps).
    DispatchQueue.main.async {
      UIApplication.shared.open(target, options: [:]) { success in
        if success {
          completion(true)
        } else {
          self.tryOpen(rest, completion: completion)
        }
      }
    }
  }
}
