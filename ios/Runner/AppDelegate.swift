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
    // Info.plist에서 UIViewControllerBasedStatusBarAppearance를 false로 설정했으므로
    // 여기서 전역적으로 설정 가능
    if #available(iOS 13.0, *) {
      // iOS 13+ 에서는 SceneDelegate를 통해 설정하거나
      // UIViewControllerBasedStatusBarAppearance가 false면 전역 설정 가능
      // Info.plist에 UIStatusBarStyle을 설정했으므로 자동 적용됨
    } else {
      // iOS 12 이하 지원
      UIApplication.shared.statusBarStyle = .lightContent
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // iOS 9 이하 지원
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
}
