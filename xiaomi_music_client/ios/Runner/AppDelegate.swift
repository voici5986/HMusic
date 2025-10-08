import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var splashScreenView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let splashChannel = FlutterMethodChannel(
      name: "com.hupc.hmusic/splash",
      binaryMessenger: controller.binaryMessenger
    )

    // 保持启动屏显示
    showSplashScreen()

    splashChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "hideSplash" {
        self?.hideSplashScreen()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func showSplashScreen() {
    guard let window = window,
          let launchScreenVC = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController(),
          splashScreenView == nil else {
      return
    }

    splashScreenView = launchScreenVC.view
    splashScreenView?.frame = window.bounds
    window.addSubview(splashScreenView!)
  }

  private func hideSplashScreen() {
    DispatchQueue.main.async { [weak self] in
      UIView.animate(withDuration: 0.3, animations: {
        self?.splashScreenView?.alpha = 0
      }) { _ in
        self?.splashScreenView?.removeFromSuperview()
        self?.splashScreenView = nil
      }
    }
  }
}
