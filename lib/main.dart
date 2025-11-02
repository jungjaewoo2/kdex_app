import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_screen.dart';

void main() async {
  // 에러 핸들링 설정
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  WidgetsFlutterBinding.ensureInitialized();

  // 상태바 색상 설정 (주황색) - Android용
  // iOS는 Info.plist와 AppDelegate.swift에서 설정됨
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFED7C2A), // Android 상태바 배경색
      statusBarIconBrightness:
          Brightness.light, // Android 아이콘을 밝게 (주황 배경에 잘 보이도록)
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // 앱 실행
  runApp(const KdexApp());
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
