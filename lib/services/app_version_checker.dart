import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppVersionChecker {
  // Play Store 패키지명 (Android)
  static const String playStorePackageId = 'com.kdex.app.v2';

  // 최신 버전 (하드코딩 - 업데이트 시 이 값만 변경)
  static const String latestVersion = "1.0.1";

  // 강제 업데이트 여부 (true면 업데이트 전까지 앱 사용 불가)
  static const bool forceUpdate = false;

  // 업데이트 메시지
  static const String updateMessage = "새로운 기능이 추가되었습니다.\n업데이트해주세요.";

  /// 현재 앱 버전 가져오기
  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version; // 예: "1.0.1"
  }

  /// 버전 비교 (예: "1.0.1" vs "1.0.2")
  static bool isUpdateNeeded(String currentVersion, String latestVersion) {
    final current = _parseVersion(currentVersion);
    final latest = _parseVersion(latestVersion);

    for (int i = 0; i < 3; i++) {
      if (latest[i] > current[i]) {
        return true;
      } else if (latest[i] < current[i]) {
        return false;
      }
    }
    return false;
  }

  /// 버전 문자열을 숫자 배열로 변환 (예: "1.0.1" -> [1, 0, 1])
  static List<int> _parseVersion(String version) {
    return version.split('.').map((v) => int.tryParse(v) ?? 0).toList();
  }

  /// Play Store로 이동
  static Future<void> openPlayStore() async {
    final url = Uri.parse(
      'https://play.google.com/store/apps/details?id=$playStorePackageId',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Play Store를 열 수 없습니다.';
    }
  }

  /// 업그레이드 체크 및 처리
  /// 반환값: 업데이트 필요 여부
  static Future<bool> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();

      // 현재 버전과 최신 버전 비교
      if (isUpdateNeeded(currentVersion, latestVersion)) {
        return true; // 업데이트 필요
      }

      return false;
    } catch (e) {
      print('업데이트 체크 오류: $e');
      return false;
    }
  }

  /// 업데이트 정보 가져오기
  static Map<String, dynamic> getUpdateInfo() {
    return {
      'latest_version': latestVersion,
      'force_update': forceUpdate,
      'message': updateMessage,
    };
  }
}
