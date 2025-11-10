import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // 상태바 스타일 설정 (주황색 배경에 맞춰 밝은 아이콘)
    // Info.plist에서 UIViewControllerBasedStatusBarAppearance를 false로 설정하고
    // UIStatusBarStyle을 UIStatusBarStyleLightContent로 설정했으므로 자동 적용됨
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
