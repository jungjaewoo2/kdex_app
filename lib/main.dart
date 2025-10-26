import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/main_screen.dart';
import 'firebase_notification_service.dart';
import 'device_manager.dart';

void main() async {
  // 에러 핸들링 설정
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  WidgetsFlutterBinding.ensureInitialized();

  // 앱을 먼저 실행하여 화면을 보여줌
  runApp(const KdexApp());

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

class KdexApp extends StatelessWidget {
  const KdexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '유가증권Check한국금거래소',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1C0D0D),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
