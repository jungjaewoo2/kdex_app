import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../push_settings_dialog.dart';
import 'camera_screen.dart' hide ResultScreen;
import 'result_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isScanning = false;

  void _onBarcodeDetect(BarcodeCapture capture) async {
    if (_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    setState(() {
      _isScanning = true;
    });

    final barcode = barcodes.first;
    if (barcode.rawValue != null) {
      _processBarcode(barcode.rawValue!);
    }
  }

  Future<void> _processBarcode(String code) async {
    debugPrint('스캔된 바코드: $code');

    const prefix = 'http://www.exgold.co.kr/securities/spot_securities.html?';
    if (!code.startsWith(prefix)) {
      setState(() {
        _isScanning = false;
      });
      return;
    }

    final id = code.replaceFirst(prefix, '');
    debugPrint('유가증권 ID: $id');

    // API 호출
    await _fetchSecurityInfo(id);
  }

  Future<void> _fetchSecurityInfo(String id) async {
    try {
      final url = Uri.parse(
        'https://pennygold.kr/kgex/viewGiftCardInfo',
      ).replace(queryParameters: {'id': id, 'lat': '0', 'lng': '0', 'ip': ''});

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['rows'] != null && data['rows'].length > 0) {
          final stockInfo = data['rows'][0];

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResultScreen(id: id, lat: 0.0, lng: 0.0),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('API 에러: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _showPushSettings() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PushSettingsDialog(),
    );
  }

  void _onAppDownloadTap() {
    // 센골드 앱 다운로드 처리
    debugPrint('센골드 앱 다운로드');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFED7C2A),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 왼쪽: 타이틀
                  const Text(
                    '유가증권 Check',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  // 중앙: 빈 공간
                  const Spacer(),
                  // 오른쪽: 푸시 아이콘
                  GestureDetector(
                    onTap: _showPushSettings,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 상단 로고 및 체크 아이콘
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Image.asset('assets/images/logo.png', height: 80),
                  const SizedBox(height: 10),
                  Image.asset('assets/images/check.png', height: 60),
                ],
              ),
            ),

            // 카메라 스캔 영역
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MobileScanner(onDetect: _onBarcodeDetect),
                    ),
                    // 중앙 스캔 가이드
                    Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.8),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    // 로딩 인디케이터
                    if (_isScanning)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 버전 정보
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                '2020.10.12:001',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),

            // 하단 센골드 앱 다운로드 배너
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(color: Color(0xFF8E57FE)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '100원으로 금거래',
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          '#센골드',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _onAppDownloadTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.yellow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'GO >',
                        style: TextStyle(
                          color: Color(0xFF8E57FE),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
