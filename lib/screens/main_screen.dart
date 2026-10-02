import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:url_launcher/url_launcher.dart';
import 'result_screen.dart';
import '../services/app_version_checker.dart';
import '../widgets/update_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  bool _isScanning = false;
  String? _lastScannedCode;
  late MobileScannerController _scannerController;
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    developer.log('🟢 MainScreen initState 시작', name: 'MainScreen');
    print('🟢 MainScreen initState 시작');
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
    
    // 앱 시작 시 업그레이드 체크
    _checkForUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('[MainScreen] dispose 호출, 스캐너 정리 중...');
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('[MainScreen] 앱 라이프사이클 변경: $state');

    // ✅ 라이프사이클 관리 간소화: 위젯 상태만 리셋
    if (state == AppLifecycleState.resumed) {
      debugPrint('[MainScreen] 앱 재개');
      // 스캔 중이었다면 상태 초기화
      if (_isScanning) {
        debugPrint('[MainScreen] 스캔 상태 리셋');
        if (mounted) {
          setState(() {
            _isScanning = false;
            _lastScannedCode = null;
            _lastScanTime = null;
          });
        }
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      debugPrint('[MainScreen] 앱 일시정지/비활성');
      // 위젯이 제거되면 자동으로 정리되므로 명시적 stop() 불필요
    }
  }

  void _initializeScanner() {
    developer.log('🟡 스캐너 초기화 시작', name: 'MainScreen');
    print('🟡 스캐너 초기화 시작');
    debugPrint('[MainScreen] ========== 스캐너 초기화 시작 ==========');

    try {
      debugPrint('[MainScreen] 컨트롤러 생성 중...');

      // ✅ 한 번만 생성, MobileScanner가 모든 권한 및 생명주기 관리
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
        returnImage: false,
      );

      debugPrint('[MainScreen] 컨트롤러 생성 완료');
      developer.log('✅ 스캐너 생성 성공', name: 'MainScreen');
      print('✅ 스캐너 생성 성공');
      
    } catch (e, stackTrace) {
      debugPrint('[MainScreen] ❌ 스캐너 초기화 실패: $e');
      debugPrint('[MainScreen] 스택 트레이스: $stackTrace');
      _showErrorDialog('카메라 초기화 실패: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 업그레이드 체크 메서드
  Future<void> _checkForUpdate() async {
    try {
      // 약간의 딜레이를 주어 앱이 완전히 로드된 후 체크
      await Future.delayed(const Duration(seconds: 1));
      
      final needsUpdate = await AppVersionChecker.checkForUpdate();
      
      if (needsUpdate && mounted) {
        final updateInfo = AppVersionChecker.getUpdateInfo();
        final currentVersion = await AppVersionChecker.getCurrentVersion();
        final forceUpdate = updateInfo['force_update'] as bool;
        
        // 현재 버전 정보 추가
        updateInfo['current_version'] = currentVersion;
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: !forceUpdate, // 강제 업데이트 시 닫기 방지
            builder: (context) => UpdateDialog(
              updateInfo: updateInfo,
              forceUpdate: forceUpdate,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('업그레이드 체크 오류: $e');
    }
  }

  void _onBarcodeDetect(BarcodeCapture capture) async {
    developer.log('🔵 onBarcodeDetect 호출됨!', name: 'MainScreen');
    print('🔵 onBarcodeDetect 호출됨! _isScanning: $_isScanning');
    debugPrint('[MainScreen] ========== onBarcodeDetect 호출됨 ==========');
    debugPrint('[MainScreen] _isScanning: $_isScanning');
    
    // 스캔 중이면 무시 (즉시 리턴)
    if (_isScanning) {
      debugPrint('[MainScreen] 이미 스캔 중, 무시함');
      return;
    }

    final List<Barcode> barcodes = capture.barcodes;
    debugPrint('[MainScreen] 감지된 바코드 개수: ${barcodes.length}');
    
    if (barcodes.isEmpty) {
      debugPrint('[MainScreen] 바코드가 비어있음');
      return;
    }

    final barcode = barcodes.first;
    if (barcode.rawValue == null) {
      debugPrint('[MainScreen] 바코드 값이 null');
      return;
    }

    final code = barcode.rawValue!;
    final now = DateTime.now();
    
    developer.log('🎯 바코드 감지: $code', name: 'MainScreen');
    print('🎯 바코드 감지: $code');
    debugPrint('[MainScreen] 바코드 값: $code');
    debugPrint('[MainScreen] 마지막 스캔 코드: $_lastScannedCode');
    
    // 같은 코드를 연속으로 스캔하는 것을 방지
    if (_lastScannedCode == code) {
      debugPrint('[MainScreen] 중복 코드, 무시');
      return;
    }

    // 디바운싱: 마지막 스캔으로부터 500ms 이내 스캔 무시
    if (_lastScanTime != null) {
      final diff = now.difference(_lastScanTime!);
      debugPrint('[MainScreen] 마지막 스캔으로부터 ${diff.inMilliseconds}ms 경과');
      if (diff < const Duration(milliseconds: 500)) {
        debugPrint('[MainScreen] 너무 빠른 스캔, 무시');
        return;
      }
    }

    // ✅ 플래그를 즉시 설정하여 추가 onDetect 차단
    debugPrint('[MainScreen] ✅ 바코드 처리 시작');
    _isScanning = true;
    _lastScannedCode = code;
    _lastScanTime = now;

    // ✅ UI를 즉시 업데이트하여 MobileScanner 위젯 제거 (카메라 완전 중지)
    if (mounted) {
      setState(() {});
      debugPrint('[MainScreen] UI 업데이트: 스캐너 위젯 숨김');
    }

    // 카메라 리소스 해제 대기
    await Future.delayed(const Duration(milliseconds: 100));

    // 바코드 처리
    debugPrint('[MainScreen] _processBarcode 호출');
    await _processBarcode(code);
  }

  Future<void> _processBarcode(String code) async {
    debugPrint('[MainScreen] 스캔된 바코드 처리 시작: $code');

    const prefix = 'http://www.exgold.co.kr/securities/spot_securities.html?';
    if (!code.startsWith(prefix)) {
      debugPrint('[MainScreen] 유효하지 않은 QR 코드 형식');
      if (mounted) {
        setState(() {
          _isScanning = false;
          _lastScannedCode = null;
        });
        // MobileScanner 위젯이 다시 빌드되며 자동 시작됨
        debugPrint('[MainScreen] 스캐너 위젯 다시 표시');
      }
      return;
    }

    final id = code.replaceFirst(prefix, '');
    debugPrint('[MainScreen] 유가증권 ID 추출: $id');

    // API 호출
    await _fetchSecurityInfo(id);
  }

  Future<void> _fetchSecurityInfo(String id) async {
    try {
      debugPrint('[MainScreen] API 호출 시작: $id');
      
      // 새로운 API 엔드포인트
      final url = Uri.parse(
        'https://www.exgold.co.kr/api/kdex/v2/securities',
      ).replace(queryParameters: {'id': id});

      final response = await http.get(url);
      developer.log('📡 API 응답: ${response.statusCode}', name: 'MainScreen');
      print('📡 API 응답 코드: ${response.statusCode}');
      print('📡 API 응답 본문 길이: ${response.body.length}');
      print('📡 API 응답 본문: ${response.body}');
      debugPrint('[MainScreen] API 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        // 빈 응답 체크
        if (response.body.isEmpty) {
          developer.log('⚠️ API 응답이 비어있음', name: 'MainScreen');
          print('⚠️ API 응답이 비어있음');
          debugPrint('[MainScreen] API 응답이 비어있음');
          if (mounted) {
            // ✅ 즉시 재스캔 방지: 3초 대기 후 재활성화
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _isScanning = false;
                  _lastScannedCode = null;
                  _lastScanTime = null;
                });
              }
            });
            
            // 사용자에게 에러 알림
            _showErrorDialog('서버 응답이 비어있습니다.\n잠시 후 다시 시도해주세요.');
          }
          return;
        }

        dynamic data;
        try {
          data = json.decode(response.body);
          developer.log('✅ JSON 파싱 성공', name: 'MainScreen');
          print('✅ JSON 파싱 성공: ${data.toString().substring(0, data.toString().length > 100 ? 100 : data.toString().length)}...');
        } catch (e) {
          developer.log('❌ JSON 파싱 실패: $e', name: 'MainScreen');
          print('❌ JSON 파싱 실패: $e');
          debugPrint('[MainScreen] JSON 파싱 오류: $e');
          if (mounted) {
            // ✅ 즉시 재스캔 방지: 3초 대기 후 재활성화
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _isScanning = false;
                  _lastScannedCode = null;
                  _lastScanTime = null;
                });
              }
            });
            
            // 사용자에게 에러 알림
            _showErrorDialog('서버 응답 형식이 올바르지 않습니다.\n잠시 후 다시 시도해주세요.');
          }
          return;
        }
        
        debugPrint('[MainScreen] API 데이터: ${data.toString()}');

        if (data['rows'] != null && data['rows'].length > 0) {
          debugPrint('[MainScreen] 유가증권 정보 발견, 결과 화면으로 이동');
          if (mounted) {
            // 결과 화면으로 이동
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResultScreen(id: id, lat: 0.0, lng: 0.0),
              ),
            );
            debugPrint('[MainScreen] 결과 화면에서 돌아옴');
            // 결과 화면에서 돌아왔을 때 스캐너 재시작 및 상태 초기화
            if (mounted) {
              await Future.delayed(const Duration(milliseconds: 300));
              
              setState(() {
                _isScanning = false;
                _lastScannedCode = null;
                _lastScanTime = null;
              });
              // MobileScanner 위젯이 다시 빌드되며 자동 시작됨
              debugPrint('[MainScreen] 상태 초기화 완료');
            }
          }
        } else {
          debugPrint('[MainScreen] 유가증권 정보 없음');
          // 유가증권 정보를 찾을 수 없는 경우
          if (mounted) {
            // ✅ lastScannedCode는 유지하여 재스캔 방지
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _isScanning = false;
                  _lastScannedCode = null;
                  _lastScanTime = null;
                });
              }
            });
            
            _showErrorDialog('유가증권 정보를 찾을 수 없습니다.');
          }
        }
      } else {
        debugPrint('[MainScreen] API 오류: ${response.statusCode}');
        // API 오류 시
        if (mounted) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _isScanning = false;
                _lastScannedCode = null;
                _lastScanTime = null;
              });
            }
          });
          
          _showErrorDialog('서버 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.');
        }
      }
    } catch (e) {
      debugPrint('[MainScreen] API 에러: $e');
      // 에러 발생 시
      if (mounted) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isScanning = false;
              _lastScannedCode = null;
              _lastScanTime = null;
            });
          }
        });
        
        _showErrorDialog('네트워크 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.');
      }
    }
  }

  Future<void> _onAppDownloadTap() async {
    // 플랫폼별 앱 다운로드 링크
    String url;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android - Google Play Store
      url = 'https://play.google.com/store/apps/details?id=com.korda.goldmarket';
      debugPrint('센골드 앱 다운로드 - Android Play Store');
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS - App Store
      url = 'https://apps.apple.com/kr/app/%EA%B8%88%EB%B0%A9%EA%B8%88%EB%B0%A9/id1575200660';
      debugPrint('센골드 앱 다운로드 - iOS App Store');
    } else {
      // 기타 플랫폼
      debugPrint('지원하지 않는 플랫폼');
      return;
    }
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint('URL을 열 수 없습니다: $url');
        if (mounted) {
          _showErrorDialog('앱 스토어를 열 수 없습니다.');
        }
      }
    } catch (e) {
      debugPrint('URL 열기 오류: $e');
      if (mounted) {
        _showErrorDialog('앱 스토어를 열 수 없습니다.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 빌드 시 상태 로그 추가
    debugPrint('[MainScreen] 🏗️ build() 호출 - _isScanning: $_isScanning');
    print('🏗️ build() - _isScanning: $_isScanning');

    final String bannerAsset = 'assets/images/kodex_banner_new_1.jpg';
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // iOS 상태바 영역 주황색 배경
          Container(
            color: const Color(0xFFED7C2A),
            height: MediaQuery.of(context).padding.top,
          ),
          // 메인 콘텐츠
          SafeArea(
            child: Column(
              children: [
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
                          child: _isScanning
                              ? ((){
                                  debugPrint('[MainScreen] 📦 렌더링: 스캔 중 (검은색 + 로딩)');
                                  print('📦 렌더링: 스캔 중');
                                  return Container(
                                    color: Colors.black,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.orange,
                                      ),
                                    ),
                                  );
                                }())
                              : ((){
                                  debugPrint('[MainScreen] 📦 렌더링: MobileScanner 위젯');
                                  print('📦 렌더링: MobileScanner 위젯');
                                  return SizedBox.expand(
                                    child: MobileScanner(
                                      key: const ValueKey('main_scanner'),  // ✅ Key 추가
                                      controller: _scannerController,
                                      onDetect: _onBarcodeDetect,
                                      errorBuilder: (context, error, child) {
                                        debugPrint('[MainScreen] ❌ MobileScanner 에러: $error');
                                        print('❌ MobileScanner 에러: $error');
                                        return Container(
                                          color: Colors.black,
                                          child: Center(
                                            child: Text(
                                              '카메라 오류: $error',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }()),
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
                GestureDetector(
                  onTap: _onAppDownloadTap,
                  child: Image.asset(
                    bannerAsset,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
