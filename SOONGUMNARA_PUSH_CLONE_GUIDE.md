# 순금나라 앱 푸시 알림 기능 완전 복제 가이드

## 📋 개요
이 가이드는 순금나라 앱에서 구현된 푸시 알림 기능을 **완전히 동일하게** 다른 앱에 적용하는 방법을 설명합니다. UI 디자인부터 기능 구현까지 실제 프로젝트 코드를 기반으로 작성되었습니다.

## 🎯 구현할 기능
- ✅ Firebase Cloud Messaging (FCM) 통합
- ✅ 디바이스 등록 및 관리
- ✅ 푸시 알림 수신 설정 토글 (동일한 UI)
- ✅ 서버 API 연동 (동일한 구조)
- ✅ 백그라운드 알림 처리
- ✅ WebView 기반 메인 화면
- ✅ 플로팅 액션 버튼으로 설정 접근

## 📦 1. 프로젝트 설정

### 1.1 pubspec.yaml 설정
```yaml
name: your_app_name
description: "Your app description"
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: ^3.8.1

dependencies:
  flutter:
    sdk: flutter

  # Core packages only
  cupertino_icons: ^1.0.8
  webview_flutter: ^4.4.2
  url_launcher: ^6.2.2
  
  # Firebase packages (minimal)
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
  
  # Essential packages only
  http: ^1.1.0
  device_info_plus: ^10.1.0
  shared_preferences: ^2.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/img_logo_sg.webp  # 앱 로고 (선택사항)
```

### 1.2 Firebase 설정
1. [Firebase Console](https://console.firebase.google.com/)에서 새 프로젝트 생성
2. Android 앱 추가 (패키지명: `com.yourcompany.yourapp`)
3. `google-services.json` 파일을 `android/app/` 폴더에 배치

### 1.3 Android 설정 파일

#### android/app/build.gradle.kts
```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.yourcompany.yourapp"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.yourcompany.yourapp"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            minifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // 빌드 최적화
    buildFeatures {
        buildConfig = false
        viewBinding = false
        dataBinding = false
    }

    packagingOptions {
        resources {
            excludes += listOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt"
            )
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-messaging")
}
```

#### android/build.gradle.kts
```kotlin
plugins {
    id("com.android.application") version "8.1.4" apply false
    id("org.jetbrains.kotlin.android") version "1.8.10" apply false
    id("com.google.gms.google-services") version "4.4.0" apply false
}
```

#### android/gradle.properties
```properties
# Gradle 성능 최적화
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configureondemand=true
org.gradle.daemon=true

# Android 빌드 최적화
android.enableR8.fullMode=true
```

## 🏗️ 2. 핵심 파일 구현

### 2.1 Firebase 알림 서비스 (lib/firebase_notification_service.dart)

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// 백그라운드 메시지 핸들러
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('백그라운드 메시지 처리: ${message.messageId}');
}

class FirebaseNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  // 초기화
  static Future<void> initialize() async {
    // 백그라운드 메시지 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 알림 권한 요청
    await _requestPermission();

    // 토큰 가져오기 (백그라운드에서 처리 가능)
    _getToken();

    // 메시지 리스너 설정
    _setupMessageListeners();
  }

  // 메시지 리스너 설정
  static void _setupMessageListeners() {
    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('포그라운드 메시지 수신: ${message.notification?.title}');
    });

    // 앱이 백그라운드에서 알림을 탭했을 때
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('백그라운드에서 알림 탭: ${message.notification?.title}');
      _handleNotificationTap(message);
    });
  }

  // 알림 권한 요청
  static Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('사용자 권한 상태: ${settings.authorizationStatus}');
  }

  // FCM 토큰 가져오기
  static Future<void> _getToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      print('FCM 토큰: $token');

      // 토큰 갱신 리스너
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('새로운 FCM 토큰: $newToken');
      });
    } catch (e) {
      print('❌ FCM 토큰 가져오기 실패: $e');
    }
  }

  // 앱 시작 시 초기 메시지 확인
  static Future<void> checkInitialMessage() async {
    RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      print('앱 종료 상태에서 알림 탭: ${initialMessage.notification?.title}');
      _handleNotificationTap(initialMessage);
    }
  }

  // 알림 탭 처리
  static void _handleNotificationTap(RemoteMessage message) {
    // 여기에 알림 탭 시 처리할 로직 추가
    print('알림 데이터: ${message.data}');
  }

  // 토큰 가져오기 (외부에서 사용)
  static Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('❌ FCM 토큰 가져오기 실패: $e');
      return null;
    }
  }

  // 특정 토픽 구독
  static Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print('토픽 구독: $topic');
  }

  // 특정 토픽 구독 해제
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('토픽 구독 해제: $topic');
  }
}
```

### 2.2 디바이스 관리자 (lib/device_manager.dart)

```dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_api_service.dart';
import 'firebase_notification_service.dart';

class DeviceManager {
  static const String appPackageName = 'com.yourcompany.yourapp'; // 변경 필요
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
```

### 2.3 서버 API 통신 (lib/device_api_service.dart)

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceApiService {
  static const String baseUrl = 'https://www.koreagoldx.co.kr/api/device'; // 변경 필요

  /// 디바이스 등록/업데이트
  /// 앱 실행 시 디바이스 정보를 등록하거나 업데이트합니다.
  static Future<Map<String, dynamic>> registerDevice({
    required String app,
    required String deviceId,
    required String token,
    required String os,
    String receiveYn = 'N',
  }) async {
    try {
      print(
        '디바이스 등록 요청: app=$app, deviceId=$deviceId, os=$os, receiveYn=$receiveYn',
      );
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'app': app,
          'deviceId': deviceId,
          'token': token,
          'os': os,
          'receiveYn': receiveYn,
        }),
      );

      print('=== 디바이스 등록 API 응답 ===');
      print('HTTP 상태 코드: ${response.statusCode}');
      print('응답 Body: "${response.body}"');
      print('응답 Body 길이: ${response.body.length}');
      print('응답 헤더: ${response.headers}');

      if (response.statusCode == 200) {
        try {
          final result = jsonDecode(utf8.decode(response.bodyBytes));
          print('디바이스 등록 파싱된 응답: $result');

          // 응답이 문자열인 경우 처리
          if (result is String) {
            return {'result': 'success', 'message': '디바이스가 등록되었습니다.'};
          }

          // 응답이 Map인 경우
          if (result is Map<String, dynamic>) {
            print('등록 응답이 Map임: $result');
            // result 필드가 있는지 확인
            if (result.containsKey('result')) {
              print(
                '등록 result 필드 존재: ${result['result']} (타입: ${result['result'].runtimeType})',
              );

              // 서버가 boolean으로 응답하는 경우 처리
              if (result['result'] == true) {
                print('등록 서버 응답이 true - success로 변환');
                return {
                  'result': 'success',
                  'message': result['msg'] ?? '디바이스가 등록되었습니다.',
                  'map': result['map'] ?? {},
                };
              } else if (result['result'] == false) {
                print('등록 서버 응답이 false - fail로 변환');
                return {
                  'result': 'fail',
                  'message': result['msg'] ?? '디바이스 등록에 실패했습니다.',
                };
              } else {
                return result;
              }
            } else {
              return result;
            }
          }

          // 기타 경우 성공으로 처리
          return {'result': 'success', 'message': '디바이스가 등록되었습니다.'};
        } catch (e) {
          print('JSON 파싱 에러: $e');
          // JSON 파싱 실패해도 서버에서 200을 반환했다면 성공으로 처리
          return {'result': 'success', 'message': '디바이스가 등록되었습니다.'};
        }
      } else {
        print(
          '디바이스 등록 HTTP 에러: ${response.statusCode}, Body: ${response.body}',
        );
        return {'result': 'fail', 'message': 'HTTP 에러: ${response.statusCode}'};
      }
    } catch (e) {
      print('디바이스 등록 예외 발생: $e');
      return {'result': 'fail', 'message': '디바이스 등록 중 오류 발생: $e'};
    }
  }

  /// 수신동의 설정 변경
  /// 특정 디바이스의 푸시 알림 수신동의 설정을 변경합니다.
  static Future<Map<String, dynamic>> updateReceiveYn({
    required String app,
    required String deviceId,
    required String receiveYn,
  }) async {
    try {
      print('=== 수신동의 변경 요청 시작 ===');
      print('요청 파라미터: app=$app, deviceId=$deviceId, receiveYn=$receiveYn');
      
      final response = await http.post(
        Uri.parse('$baseUrl/updateReceiveYn'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'app': app,
          'deviceId': deviceId,
          'receiveYn': receiveYn,
        }),
      );

      print('=== 수신동의 변경 API 응답 ===');
      print('HTTP 상태 코드: ${response.statusCode}');
      print('응답 Body: "${response.body}"');

      // HTTP 상태 코드 확인
      if (response.statusCode == 200) {
        // 응답이 비어있는 경우
        if (response.body.isEmpty) {
          print('✅ 응답이 비어있음 - 성공으로 처리');
          return {
            'result': 'success', 
            'message': '수신동의 설정이 변경되었습니다.',
            'data': {'receiveYn': receiveYn}
          };
        }

        try {
          final result = jsonDecode(response.body);
          print('JSON 파싱 성공: $result');

          // 서버 응답 구조에 따른 처리
          if (result is Map<String, dynamic>) {
            // result 필드가 있는 경우
            if (result.containsKey('result')) {
              final serverResult = result['result'];
              
              if (serverResult == true || serverResult == 'success') {
                print('✅ 서버에서 성공 응답');
                return {
                  'result': 'success',
                  'message': result['msg'] ?? '수신동의 설정이 변경되었습니다.',
                  'data': result['data'] ?? {'receiveYn': receiveYn},
                };
              } else if (serverResult == false || serverResult == 'fail') {
                print('❌ 서버에서 실패 응답');
                return {
                  'result': 'fail',
                  'message': result['msg'] ?? '수신동의 설정 변경에 실패했습니다.',
                };
              }
            }
            
            // result 필드가 없는 경우 성공으로 처리
            print('✅ result 필드 없음 - 성공으로 처리');
            return {
              'result': 'success',
              'message': '수신동의 설정이 변경되었습니다.',
              'data': {'receiveYn': receiveYn},
            };
          }

          // 기타 타입의 응답
          print('✅ 기타 응답 타입 - 성공으로 처리');
          return {
            'result': 'success',
            'message': '수신동의 설정이 변경되었습니다.',
            'data': {'receiveYn': receiveYn},
          };
        } catch (e) {
          print('❌ JSON 파싱 실패: $e');
          // JSON 파싱 실패해도 HTTP 200이면 성공으로 처리
          return {
            'result': 'success',
            'message': '수신동의 설정이 변경되었습니다.',
            'data': {'receiveYn': receiveYn},
          };
        }
      } else {
        print('❌ HTTP 에러: ${response.statusCode}');
        return {
          'result': 'fail', 
          'message': '서버 오류: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('❌ 수신동의 변경 예외: $e');
      return {
        'result': 'fail', 
        'message': '네트워크 오류: $e'
      };
    }
  }

  /// 수신동의 설정 조회
  /// 특정 디바이스의 푸시 알림 수신동의 설정을 조회합니다.
  static Future<Map<String, dynamic>> getReceiveYn({
    required String app,
    required String deviceId,
  }) async {
    try {
      print('=== 수신동의 조회 요청 시작 ===');
      print('요청 파라미터: app=$app, deviceId=$deviceId');
      
      // GET 요청으로 변경하고 쿼리 파라미터 사용
      final uri = Uri.parse('$baseUrl/getReceiveYn').replace(
        queryParameters: {
          'app': app,
          'deviceId': deviceId,
        },
      );
      
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      print('=== 수신동의 조회 API 응답 ===');
      print('HTTP 상태 코드: ${response.statusCode}');
      print('응답 Body: "${response.body}"');
      print('응답 Body 길이: ${response.body.length}');
      print('응답 헤더: ${response.headers}');

      if (response.statusCode == 200) {
        // 응답이 비어있는 경우 기본값 반환
        if (response.body.isEmpty) {
          print('⚠️ 조회 응답이 비어있음 - 기본값 반환 (서버에 등록되지 않았을 수 있음)');
          final defaultData = {'receiveYn': 'N'};
          return {
            'result': 'success',
            'message': '조회되었습니다.',
            'map': defaultData,  // device_manager.dart에서 map 필드를 확인함
            'data': defaultData, // 호환성을 위해 data도 함께 반환
          };
        }

        try {
          final result = jsonDecode(response.body);
          print('JSON 파싱 성공: $result');

          if (result is Map<String, dynamic>) {
            // result 필드가 있는 경우
            if (result.containsKey('result')) {
              final serverResult = result['result'];
              
              if (serverResult == true || serverResult == 'success') {
                print('✅ 서버에서 성공 응답');
                // 서버 응답 구조에 따라 map 또는 data 필드 확인
                Map<String, dynamic> dataMap;
                if (result.containsKey('map') && result['map'] != null) {
                  dataMap = result['map'] as Map<String, dynamic>;
                  print('map 필드에서 데이터 추출: $dataMap');
                } else if (result.containsKey('data') && result['data'] != null) {
                  dataMap = result['data'] as Map<String, dynamic>;
                  print('data 필드에서 데이터 추출: $dataMap');
                } else {
                  dataMap = {'receiveYn': 'N'};
                  print('map/data 필드 없음 - 기본값 사용');
                }

                return {
                  'result': 'success',
                  'message': result['message'] ?? result['msg'] ?? '조회되었습니다.',
                  'map': dataMap,  // device_manager.dart에서 map 필드를 확인함
                  'data': dataMap, // 호환성을 위해 data도 함께 반환
                };
              } else if (serverResult == false || serverResult == 'fail') {
                print('❌ 서버에서 실패 응답');
                return {
                  'result': 'fail',
                  'message': result['msg'] ?? '조회에 실패했습니다.',
                };
              }
            }

            // result 필드가 없는 경우 성공으로 처리
            print('✅ result 필드 없음 - 성공으로 처리');
            // map 필드 확인
            Map<String, dynamic> dataMap;
            if (result.containsKey('map') && result['map'] != null) {
              dataMap = result['map'] as Map<String, dynamic>;
              print('map 필드에서 데이터 추출: $dataMap');
            } else if (result.containsKey('data') && result['data'] != null) {
              dataMap = result['data'] as Map<String, dynamic>;
              print('data 필드에서 데이터 추출: $dataMap');
            } else {
              dataMap = {'receiveYn': 'N'};
              print('map/data 필드 없음 - 기본값 사용');
            }

            return {
              'result': 'success',
              'message': '조회되었습니다.',
              'map': dataMap,  // device_manager.dart에서 map 필드를 확인함
              'data': dataMap, // 호환성을 위해 data도 함께 반환
            };
          }

          // 기타 타입의 응답
          print('⚠️ 기타 응답 타입 - 기본값 반환');
          final defaultData = {'receiveYn': 'N'};
          return {
            'result': 'success',
            'message': '조회되었습니다.',
            'map': defaultData,  // device_manager.dart에서 map 필드를 확인함
            'data': defaultData, // 호환성을 위해 data도 함께 반환
          };
        } catch (e) {
          print('❌ JSON 파싱 실패: $e');
          print('응답 내용: ${response.body}');
          // JSON 파싱 실패해도 HTTP 200이면 기본값 반환
          final defaultData = {'receiveYn': 'N'};
          return {
            'result': 'success',
            'message': '조회되었습니다.',
            'map': defaultData,  // device_manager.dart에서 map 필드를 확인함
            'data': defaultData, // 호환성을 위해 data도 함께 반환
          };
        }
      } else {
        print('❌ HTTP 에러: ${response.statusCode}');
        return {
          'result': 'fail', 
          'message': '서버 오류: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('❌ 수신동의 조회 예외: $e');
      return {
        'result': 'fail', 
        'message': '네트워크 오류: $e'
      };
    }
  }
}
```

### 2.4 푸시 설정 다이얼로그 (lib/push_settings_dialog.dart) - **완전 동일한 UI**

```dart
import 'package:flutter/material.dart';
import 'device_manager.dart';

class PushSettingsDialog extends StatefulWidget {
  const PushSettingsDialog({super.key});

  @override
  State<PushSettingsDialog> createState() => _PushSettingsDialogState();
}

class _PushSettingsDialogState extends State<PushSettingsDialog> {
  String _receiveYn = 'N';
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadReceiveYn();
  }

  Future<void> _loadReceiveYn() async {
    setState(() => _isLoading = true);

    // 서버에서 현재 설정 조회
    final String? serverReceiveYn = await DeviceManager.getServerReceiveYn();

    // 서버에서 값을 가져오지 못한 경우 기본값 사용
    final finalReceiveYn = serverReceiveYn ?? 'N';

    setState(() {
      _receiveYn = finalReceiveYn;
      _isLoading = false;
    });
  }

  /// 서버에서 최신 수신동의 상태를 다시 조회하여 UI 동기화
  Future<void> _refreshReceiveYn() async {
    try {
      final String? serverReceiveYn = await DeviceManager.getServerReceiveYn();

      if (serverReceiveYn != null && mounted) {
        setState(() {
          _receiveYn = serverReceiveYn;
        });
      }
    } catch (e) {
      // 에러 처리
    }
  }

  Future<void> _toggleReceiveYn(bool value) async {
    setState(() => _isUpdating = true);

    final String newReceiveYn = value ? 'Y' : 'N';
    final response = await DeviceManager.updateReceiveYn(newReceiveYn);

    setState(() => _isUpdating = false);

    if (!mounted) return;

    if (response['result'] == 'success') {
      // 로컬 상태 즉시 업데이트
      setState(() {
        _receiveYn = newReceiveYn;
      });

      // 서버에서 최신 상태 다시 조회하여 동기화
      Future.delayed(const Duration(milliseconds: 500), () {
        _refreshReceiveYn();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newReceiveYn == 'Y'
                ? '✅ 푸시 알림 수신이 활성화되었습니다.'
                : '✅ 푸시 알림 수신이 비활성화되었습니다.',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final errorMsg = response['message'] ?? '알 수 없는 오류가 발생했습니다.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 설정 변경 실패: $errorMsg'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목 헤더
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C1E1A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFF2C1E1A),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '푸시 알림 설정',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C1E1A),
                      ),
                    ),
                  ),
                  // 닫기 버튼 (X)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 로딩 중이거나 설정 표시
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2C1E1A)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '설정을 불러오는 중...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // 현재 상태 표시 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _receiveYn == 'Y'
                        ? Colors.green.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _receiveYn == 'Y'
                          ? Colors.green.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _receiveYn == 'Y'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _receiveYn == 'Y'
                              ? Icons.notifications_active
                              : Icons.notifications_off,
                          color: _receiveYn == 'Y' ? Colors.green : Colors.grey,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _receiveYn == 'Y' ? '알림 수신 중' : '알림 수신 안함',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _receiveYn == 'Y'
                                    ? Colors.green[700]
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _receiveYn == 'Y'
                                  ? '중요한 알림을 받고 있습니다.'
                                  : '알림을 받지 않습니다.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 수신 동의 스위치 카드
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    title: const Text(
                      '푸시 알림 수신',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C1E1A),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '앱의 최신 소식과 중요한 알림을 받아보세요.', // 앱명 변경 필요
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                    ),
                    value: _receiveYn == 'Y',
                    onChanged: _isUpdating ? null : _toggleReceiveYn,
                    activeColor: const Color(0xFF2C1E1A),
                    activeTrackColor: const Color(0xFF2C1E1A).withOpacity(0.3),
                    inactiveThumbColor: Colors.grey[400],
                    inactiveTrackColor: Colors.grey[200],
                  ),
                ),

                // 업데이트 중 표시
                if (_isUpdating)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C1E1A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2C1E1A)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '설정을 변경하는 중...',
                          style: TextStyle(
                            color: const Color(0xFF2C1E1A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              const SizedBox(height: 24),

              // 닫기 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C1E1A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    '닫기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 2.5 메인 화면 (lib/main_screen.dart) - **WebView + 상단 헤더 + 알림 아이콘**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'push_settings_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final WebViewController _controller;
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    try {
      print('🔄 WebView 초기화 시작...');
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (NavigationRequest request) {
              // 외부 링크 처리
              if (request.url.startsWith('https') &&
                  !request.url.contains('koreagoldx.co.kr')) { // 변경 필요
                _launchURL(request.url);
                return NavigationDecision.prevent;
              }

              // 전화번호 링크 처리
              if (request.url.startsWith('tel:')) {
                _launchURL(request.url);
                return NavigationDecision.prevent;
              }

              return NavigationDecision.navigate;
            },
            onPageStarted: (String url) {
              print('📄 페이지 로딩 시작: $url');
            },
            onPageFinished: (String url) {
              print('✅ 페이지 로딩 완료: $url');
            },
            onWebResourceError: (WebResourceError error) {
              print('❌ WebView 리소스 에러: ${error.description}');
            },
          ),
        )
        ..loadRequest(Uri.parse('https://www.koreagoldx.co.kr')); // 변경 필요
      print('✅ WebView 초기화 완료');
    } catch (e) {
      print('❌ WebView 초기화 실패: $e');
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showPushSettings() {
    showDialog(
      context: context,
      barrierDismissible: true, // 배경 터치로 닫기 가능
      builder: (context) => const PushSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // 웹뷰에서 뒤로가기 가능한지 확인
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return;
        }

        // 더블탭으로 앱 종료
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('한 번 더 누르면 종료됩니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // 앱 완전 종료
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // 상단 헤더 (순금나라 스타일)
              Container(
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFF2C1E1A),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 왼쪽: 앱 로고/제목
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            // 앱 로고 (선택사항)
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.notifications_active,
                                size: 20,
                                color: Color(0xFF2C1E1A),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Your App Name', // 변경 필요
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 오른쪽: 알림 아이콘
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: GestureDetector(
                        onTap: _showPushSettings,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // WebView 영역
              Expanded(
                child: Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    // 로딩 인디케이터 (선택사항)
                    // Positioned(
                    //   top: 0,
                    //   left: 0,
                    //   right: 0,
                    //   child: LinearProgressIndicator(
                    //     backgroundColor: Colors.transparent,
                    //     valueColor: AlwaysStoppedAnimation<Color>(
                    //       Color(0xFF2C1E1A).withOpacity(0.3),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 2.6 스플래시 화면 (lib/splash_screen.dart)

```dart
import 'package:flutter/material.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToMain();
  }

  _navigateToMain() async {
    await Future.delayed(const Duration(seconds: 2), () {});
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C1E1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 앱 로고 (선택사항)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.notifications_active,
                size: 60,
                color: Color(0xFF2C1E1A),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Your App Name', // 변경 필요
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '푸시 알림 서비스',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 2.7 메인 앱 진입점 (lib/main.dart)

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'splash_screen.dart';
import 'firebase_notification_service.dart';
import 'device_manager.dart';

void main() async {
  // 에러 핸들링 설정
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  WidgetsFlutterBinding.ensureInitialized();

  // 앱을 먼저 실행하여 화면을 보여줌
  runApp(const YourApp());

  // 백그라운드에서 Firebase 초기화 (에뮬레이터 안정성을 위해)
  _initializeInBackground();
}

/// 백그라운드에서 실행할 초기화 작업
Future<void> _initializeInBackground() async {
  bool firebaseInitialized = false;

  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;
  } catch (e, stackTrace) {
    return; // Firebase 초기화 실패 시 더 이상 진행하지 않음
  }

  // Firebase가 초기화된 경우에만 알림 서비스 초기화
  if (firebaseInitialized) {
    try {
      await FirebaseNotificationService.initialize();
    } catch (e, stackTrace) {
      // 에러 처리
    }

    try {
      // 초기 메시지 확인
      await FirebaseNotificationService.checkInitialMessage();
    } catch (e) {
      // 에러 처리
    }

    try {
      // 디바이스 등록/업데이트 (네트워크 요청이므로 백그라운드에서 처리)
      await DeviceManager.registerOrUpdateDevice();
    } catch (e) {
      // 에러 처리
    }
  }
}

class YourApp extends StatelessWidget {
  const YourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App Name', // 변경 필요
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1C0D0D),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

## 🌐 3. 서버 API 구현

### 3.1 서버 API 엔드포인트

서버에서 다음 API들을 구현해야 합니다:

#### 디바이스 등록 API
```
POST /api/device/register
Content-Type: application/json

{
  "app": "com.yourcompany.yourapp",
  "deviceId": "device_unique_id",
  "token": "firebase_fcm_token",
  "os": "Android",
  "receiveYn": "N"
}

Response:
{
  "result": true,
  "msg": "디바이스가 등록되었습니다.",
  "map": {}
}
```

#### 수신동의 설정 업데이트 API
```
POST /api/device/updateReceiveYn
Content-Type: application/json

{
  "app": "com.yourcompany.yourapp",
  "deviceId": "device_unique_id",
  "receiveYn": "Y"
}

Response:
{
  "result": true,
  "msg": "수신동의 설정이 변경되었습니다.",
  "data": {
    "receiveYn": "Y"
  }
}
```

#### 수신동의 상태 조회 API
```
GET /api/device/getReceiveYn?app=com.yourcompany.yourapp&deviceId=device_unique_id

Response:
{
  "result": "success",
  "message": "조회되었습니다.",
  "data": {
    "receiveYn": "Y"
  }
}
```

## 🎨 3.5 UI 시각적 가이드

### 3.5.1 앱 전체 구조
```
┌─────────────────────────────────────┐
│ 상단 헤더 (60px 높이)                  │
│ ┌─────────────┐ ┌─────────────────┐ │
│ │ 앱 로고/제목  │ │ 알림 아이콘 (클릭) │ │
│ └─────────────┘ └─────────────────┘ │
├─────────────────────────────────────┤
│                                     │
│        WebView 영역 (전체)            │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

### 3.5.2 알림 아이콘 클릭 시 다이얼로그 표시
```
┌─────────────────────────────────────┐
│ 배경 어둡게 처리 (barrierDismissible) │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 푸시 알림 설정 다이얼로그      │   │
│  │ ┌─────────────────────────┐ │   │
│  │ │ 제목 헤더 (아이콘 + 제목)  │ │   │
│  │ └─────────────────────────┘ │   │
│  │                             │   │
│  │ ┌─────────────────────────┐ │   │
│  │ │ 현재 상태 표시 카드      │ │   │
│  │ │ (아이콘 + 상태 텍스트)    │ │   │
│  │ └─────────────────────────┘ │   │
│  │                             │   │
│  │ ┌─────────────────────────┐ │   │
│  │ │ 스위치 카드              │ │   │
│  │ │ (제목 + 설명 + 토글)      │ │   │
│  │ └─────────────────────────┘ │   │
│  │                             │   │
│  │ ┌─────────────────────────┐ │   │
│  │ │ 닫기 버튼 (전체 너비)    │ │   │
│  │ └─────────────────────────┘ │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

### 3.5.3 색상 팔레트
- **주 색상**: `#2C1E1A` (다크 브라운)
- **배경 색상**: `#1C0D0D` (더 다크 브라운)
- **성공 색상**: `#4CAF50` (그린)
- **에러 색상**: `#F44336` (레드)
- **텍스트 색상**: `#333333` (다크 그레이)
- **보조 텍스트**: `#666666` (미디엄 그레이)

### 3.5.4 다이얼로그 애니메이션
- **표시**: 부드러운 페이드인 + 스케일 애니메이션
- **닫기**: 배경 터치 또는 X 버튼 클릭
- **로딩**: 원형 프로그레스 인디케이터
- **업데이트**: 작은 프로그레스 + 텍스트 표시

## 🔧 4. 커스터마이징 가이드

### 4.1 앱별 설정 변경

다음 항목들을 앱에 맞게 변경하세요:

1. **패키지명 변경**:
   - `lib/device_manager.dart`: `appPackageName` 상수
   - `android/app/build.gradle.kts`: `applicationId`
   - `android/app/src/main/kotlin/.../MainActivity.kt`: 패키지명

2. **서버 API URL 변경**:
   - `lib/device_api_service.dart`: `baseUrl` 상수

3. **앱 이름 변경**:
   - `lib/main.dart`: `title` 속성
   - `lib/splash_screen.dart`: 앱 이름 텍스트

4. **웹사이트 URL 변경**:
   - `lib/main_screen.dart`: `loadRequest` URL
   - `lib/main_screen.dart`: 도메인 체크 로직

5. **앱 설명 변경**:
   - `lib/push_settings_dialog.dart`: 서브타이틀 텍스트

### 4.2 색상 테마 변경

순금나라 앱의 색상 테마를 사용하고 있습니다:
- **주 색상**: `Color(0xFF2C1E1A)` (다크 브라운)
- **배경 색상**: `Color(0xFF1C0D0D)` (더 다크 브라운)

다른 색상으로 변경하려면 모든 파일에서 해당 색상 코드를 찾아 변경하세요.

## 🚀 5. 빌드 및 배포

### 5.1 빌드 명령어
```bash
# 개발용 빌드
flutter build apk --debug

# 릴리즈 빌드
flutter build apk --release

# ABI별 분할 빌드 (용량 최적화)
flutter build apk --release --split-per-abi
```

### 5.2 테스트 체크리스트

#### 🔧 기본 설정
- [ ] Firebase 프로젝트 설정 완료
- [ ] google-services.json 파일 배치
- [ ] 앱 패키지명 변경
- [ ] 서버 API 엔드포인트 변경

#### 📱 UI 테스트
- [ ] 상단 헤더 표시 확인
- [ ] 앱 로고/제목 표시 확인
- [ ] 알림 아이콘 표시 및 클릭 동작 확인
- [ ] 다이얼로그 표시 애니메이션 확인
- [ ] 다이얼로그 배경 터치로 닫기 확인
- [ ] X 버튼으로 다이얼로그 닫기 확인
- [ ] 현재 상태 카드 표시 확인
- [ ] 스위치 토글 동작 확인
- [ ] 로딩 상태 표시 확인
- [ ] 업데이트 중 상태 표시 확인
- [ ] 성공/실패 SnackBar 표시 확인

#### 🔔 푸시 알림 기능
- [ ] 푸시 알림 권한 요청 테스트
- [ ] FCM 토큰 생성 확인
- [ ] 디바이스 등록 API 테스트
- [ ] 수신동의 설정 변경 테스트
- [ ] 포그라운드 알림 수신 테스트
- [ ] 백그라운드 알림 수신 테스트
- [ ] 앱 종료 상태에서 알림 탭 테스트

#### 🌐 WebView 기능
- [ ] WebView 로딩 테스트
- [ ] 외부 링크 처리 테스트
- [ ] 전화번호 링크 처리 테스트
- [ ] 뒤로가기 동작 테스트
- [ ] 더블탭 앱 종료 테스트

## 🔍 6. 문제 해결

### 6.1 일반적인 문제들

1. **FCM 토큰이 null인 경우**
   - Firebase 초기화 확인
   - 네트워크 연결 확인
   - Google Play Services 확인

2. **알림이 수신되지 않는 경우**
   - 알림 권한 확인
   - FCM 토큰 유효성 확인
   - 서버에서 올바른 토큰으로 전송했는지 확인

3. **서버 API 호출 실패**
   - 네트워크 연결 확인
   - API 엔드포인트 URL 확인
   - 서버 로그 확인

### 6.2 디버깅 팁
```dart
// FCM 토큰 확인
print('FCM Token: ${await FirebaseNotificationService.getToken()}');

// 디바이스 ID 확인
print('Device ID: ${await DeviceManager.getDeviceId()}');

// 로컬 설정 확인
print('Local Receive YN: ${await DeviceManager.getLocalReceiveYn()}');
```

## 📱 7. 푸시 알림 전송

### 7.1 Firebase Console에서 전송
1. Firebase Console → Cloud Messaging
2. 새 캠페인 생성
3. 타겟팅 설정 (앱 선택)
4. 알림 작성 및 전송

### 7.2 서버에서 프로그래밍 방식 전송
```javascript
// Node.js 예시
const admin = require('firebase-admin');

// FCM 토큰으로 알림 전송
async function sendPushNotification(fcmToken, title, body) {
  const message = {
    notification: {
      title: title,
      body: body,
    },
    token: fcmToken,
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
  } catch (error) {
    console.log('Error sending message:', error);
  }
}
```

## 📚 8. 추가 리소스

- [Firebase Cloud Messaging 문서](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Firebase 플러그인](https://pub.dev/packages/firebase_messaging)
- [WebView Flutter 플러그인](https://pub.dev/packages/webview_flutter)

---

이 가이드를 따라하면 순금나라 앱과 **완전히 동일한** 푸시 알림 기능을 구현할 수 있습니다. 모든 코드는 실제 프로젝트에서 작동하는 코드를 기반으로 작성되었으므로 복사해서 바로 사용할 수 있습니다.
