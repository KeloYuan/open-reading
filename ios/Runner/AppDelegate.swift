import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 设置状态栏样式为深色内容（适合浅色背景）
    if #available(iOS 13.0, *) {
      UIApplication.shared.statusBarStyle = .darkContent
    } else {
      UIApplication.shared.statusBarStyle = .default
    }

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let iCloudChannel = FlutterMethodChannel(
        name: "com.niki.xxread/icloud",
        binaryMessenger: controller.binaryMessenger
      )

      iCloudChannel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "getICloudDocumentsPath":
          self?.getICloudDocumentsPath(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getICloudDocumentsPath(result: @escaping FlutterResult) {
    // nil 表示默认容器，需要目标已开启 iCloud Documents capability
    guard let iCloudContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
      result(nil)
      return
    }

    let documentsURL = iCloudContainer.appendingPathComponent("Documents")
    do {
      try FileManager.default.createDirectory(
        at: documentsURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
      result(documentsURL.path)
    } catch {
      result(nil)
    }
  }
}
