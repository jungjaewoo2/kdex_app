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
