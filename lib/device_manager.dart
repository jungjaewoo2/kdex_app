import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_api_service.dart';
import 'firebase_notification_service.dart';

class DeviceManager {
  static const String appPackageName = 'com.kdex.app.v2';
  static const String _receiveYnKey = 'push_receive_yn';

  /// 디바이스 ID 가져오기
  static Future<String?> getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor; // iOS UUID
      }
    } catch (e) {
      print('디바이스 ID 가져오기 실패: $e');
    }

    return null;
  }

  /// OS 이름 가져오기
  static String getOSName() {
    if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isIOS) {
      return 'iOS';
    }
    return 'Unknown';
  }

  /// 로컬에 저장된 수신동의 상태 가져오기
  static Future<String> getLocalReceiveYn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_receiveYnKey) ?? 'N';
  }

  /// 로컬에 수신동의 상태 저장
  static Future<void> setLocalReceiveYn(String receiveYn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_receiveYnKey, receiveYn);
  }

  /// 디바이스 등록 또는 업데이트
  /// 앱 실행 시 호출하여 디바이스 정보를 서버에 등록/업데이트합니다.
  static Future<bool> registerOrUpdateDevice() async {
    try {
      // 디바이스 ID 가져오기
      final String? deviceId = await getDeviceId();
      if (deviceId == null) {
        print('디바이스 ID를 가져올 수 없습니다.');
        return false;
      }

      // FCM 토큰 가져오기
      final String? fcmToken = await FirebaseNotificationService.getToken();
      if (fcmToken == null) {
        print('FCM 토큰을 가져올 수 없습니다.');
        return false;
      }

      // 로컬에 저장된 수신동의 상태 가져오기
      final String receiveYn = await getLocalReceiveYn();

      // OS 정보
      final String os = getOSName();

      // API 호출
      final response = await DeviceApiService.registerDevice(
        app: appPackageName,
        deviceId: deviceId,
        token: fcmToken,
        os: os,
        receiveYn: receiveYn,
      );

      if (response['result'] == 'success') {
        print('디바이스 등록/업데이트 성공: ${response['message']}');
        return true;
      } else {
        print('디바이스 등록/업데이트 실패: ${response['message']}');
        return false;
      }
    } catch (e) {
      print('디바이스 등록/업데이트 중 오류: $e');
      return false;
    }
  }

  /// 수신동의 상태 변경
  /// UI에서 사용자가 수신동의를 변경할 때 호출합니다.
  static Future<Map<String, dynamic>> updateReceiveYn(String receiveYn) async {
    print('=== DeviceManager.updateReceiveYn 시작 ===');
    print('요청된 receiveYn: $receiveYn');

    try {
      final String? deviceId = await getDeviceId();
      print('디바이스 ID: $deviceId');

      if (deviceId == null) {
        print('❌ 디바이스 ID가 null');
        return {'result': 'fail', 'message': '디바이스 ID를 가져올 수 없습니다.'};
      }

      print(
        'API 호출 시작 - app: $appPackageName, deviceId: $deviceId, receiveYn: $receiveYn',
      );

      // API 호출
      final response = await DeviceApiService.updateReceiveYn(
        app: appPackageName,
        deviceId: deviceId,
        receiveYn: receiveYn,
      );

      print('DeviceApiService 응답: $response');
      print('응답 타입: ${response.runtimeType}');
      print('응답 result: ${response['result']}');
      print('응답 message: ${response['message']}');

      if (response['result'] == 'success') {
        // 로컬에도 저장
        await setLocalReceiveYn(receiveYn);
        print('✅ 로컬 저장 완료: $receiveYn');
        print('수신동의 변경 성공: $receiveYn');
      } else {
        print('❌ 수신동의 변경 실패: ${response['message']}');
      }

      return response;
    } catch (e) {
      print('❌ DeviceManager 예외 발생: $e');
      return {'result': 'fail', 'message': '수신동의 변경 중 오류 발생: $e'};
    }
  }

  /// 서버에서 현재 수신동의 상태 조회
  static Future<String?> getServerReceiveYn() async {
    print('=== 서버에서 수신동의 상태 조회 시작 ===');

    try {
      final String? deviceId = await getDeviceId();

      if (deviceId == null) {
        return null;
      }

      final response = await DeviceApiService.getReceiveYn(
        app: appPackageName,
        deviceId: deviceId,
      );

      if (response['result'] == 'success') {
        // 응답에서 receiveYn 값 추출
        final data = response['data'];
        if (data != null && data is Map && data.containsKey('receiveYn')) {
          final String receiveYn = data['receiveYn'] ?? 'N';

          // 서버 상태를 로컬에도 동기화
          await setLocalReceiveYn(receiveYn);

          return receiveYn;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      print('❌ 수신동의 조회 중 오류: $e');
      return null;
    }
  }
}
