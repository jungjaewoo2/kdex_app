import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'result_screen.dart';
import '../services/camera_permission_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  bool _isScanning = false;
  String? _lastScannedCode;
  MobileScannerController? _scannerController;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 스캐너 안전하게 종료 (stop은 async이므로 dispose에서는 호출하지 않음)
    _scannerController?.dispose();
    _scannerController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('[MainScreen] 앱 라이프사이클 변경: $state');

    if (state == AppLifecycleState.resumed) {
      // 앱이 다시 활성화될 때 권한 재확인 및 스캐너 재시작
      debugPrint('[MainScreen] 앱 재개, 권한 재확인 및 스캐너 재시작');
      _checkPermissionAndRestart();
    } else if (state == AppLifecycleState.paused) {
      // 앱이 백그라운드로 갈 때 스캐너 중지
      debugPrint('[MainScreen] 앱 일시정지, 스캐너 중지');
      _scannerController?.stop();
    }
  }

  Future<void> _checkPermissionAndRestart() async {
    final permissionService = CameraPermissionService();
    final permissionStatus = await permissionService.getStatus();
    debugPrint('[MainScreen] 앱 재개 시 권한 상태: $permissionStatus');

    if (permissionStatus.isGranted) {
      // 권한이 허용되었으면 다이얼로그가 있다면 닫고 스캐너 재시작
      if (_isInitializing || _scannerController == null) {
        debugPrint('[MainScreen] 권한 허용됨, 스캐너 초기화');
        await _initializeScanner();
      } else {
        debugPrint('[MainScreen] 권한 허용됨, 스캐너 재시작');
        await _restartScanner();
      }
    } else {
      debugPrint('[MainScreen] 권한이 여전히 거부됨');
    }
  }

  Future<void> _restartScanner() async {
    debugPrint('[MainScreen] 스캐너 재시작 시작');

    // 권한 재확인
    final permissionService = CameraPermissionService();
    final permissionStatus = await permissionService.getStatus();
    debugPrint('[MainScreen] 재시작 시 권한 상태: $permissionStatus');

    if (!permissionStatus.isGranted) {
      debugPrint('[MainScreen] 권한이 없어 재초기화');
      await _initializeScanner();
      return;
    }

    if (_scannerController == null) {
      debugPrint('[MainScreen] 컨트롤러가 없어 재초기화');
      await _initializeScanner();
      return;
    }

    try {
      setState(() {
        _isInitializing = true;
      });

      // 기존 스캐너 중지
      await _scannerController?.stop();
      await Future.delayed(const Duration(milliseconds: 500));

      // 스캐너 재시작
      await _scannerController?.start();

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {
          _isInitializing = false;
        });
        debugPrint('[MainScreen] 스캐너 재시작 성공');
      }
    } catch (e) {
      debugPrint('[MainScreen] 스캐너 재시작 오류: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        // 재초기화 시도
        await _initializeScanner();
      }
    }
  }

  Future<void> _initializeScanner() async {
    debugPrint('[MainScreen] 스캐너 초기화 시작');

    // 기존 컨트롤러 완전 정리
    if (_scannerController != null) {
      try {
        await _scannerController?.stop();
      } catch (e) {
        debugPrint('[MainScreen] 스캐너 중지 오류: $e');
      }
      try {
        await _scannerController?.dispose();
      } catch (e) {
        debugPrint('[MainScreen] 스캐너 해제 오류: $e');
      }
      _scannerController = null;
      // 리소스 완전 해제를 위한 대기
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // 권한 서비스를 통해 권한 확인 및 요청 (싱글톤으로 중복 방지)
    final permissionService = CameraPermissionService();
    debugPrint('[MainScreen] 권한 확인 시작');
    final permissionStatus = await permissionService.requestIfNeeded();
    debugPrint('[MainScreen] 권한 상태: $permissionStatus');

    if (!permissionStatus.isGranted) {
      debugPrint('[MainScreen] 권한이 거부됨');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        _showPermissionErrorDialog();
      }
      return;
    }

    // 권한이 허용된 경우에만 컨트롤러 생성
    try {
      debugPrint('[MainScreen] 스캐너 컨트롤러 생성 시작');

      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );

      debugPrint('[MainScreen] 스캐너 컨트롤러 생성 완료');

      // 위젯 빌드 후 스캐너 시작
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _scannerController == null) {
          debugPrint('[MainScreen] 위젯이 마운트되지 않거나 컨트롤러가 null');
          return;
        }

        try {
          debugPrint('[MainScreen] 스캐너 시작 시도...');

          // 카메라 리소스가 완전히 해제될 시간 확보
          await Future.delayed(const Duration(milliseconds: 500));

          if (!mounted || _scannerController == null) {
            debugPrint('[MainScreen] 대기 중 위젯이 마운트 해제되거나 컨트롤러가 null');
            return;
          }

          // 권한이 이미 허용되었으므로 MobileScanner는 자동 요청하지 않음
          await _scannerController?.start();
          debugPrint('[MainScreen] 스캐너 시작 성공');

          // 카메라 프리뷰가 렌더링될 시간 확보
          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            debugPrint('[MainScreen] 상태 업데이트: _isInitializing = false');
            setState(() {
              _isInitializing = false;
            });
          }
        } catch (e, stackTrace) {
          debugPrint('[MainScreen] 스캐너 시작 오류: $e');
          debugPrint('[MainScreen] 스택 트레이스: $stackTrace');
          if (mounted) {
            setState(() {
              _isInitializing = false;
            });
            _showErrorDialog('카메라를 시작할 수 없습니다: $e');
          }
        }
      });
    } catch (e) {
      debugPrint('[MainScreen] 스캐너 컨트롤러 생성 오류: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        _showErrorDialog('카메라 초기화 실패: $e');
      }
    }
  }

  void _showPermissionErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카메라 권한 필요'),
        content: const Text(
          'QR 코드 스캔을 위해 카메라 권한이 필요합니다.\n설정에서 카메라 권한을 허용해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // 설정 앱 열기
              await openAppSettings();
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
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

  void _onBarcodeDetect(BarcodeCapture capture) async {
    if (_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;

    // 같은 코드를 연속으로 스캔하는 것을 방지
    if (_lastScannedCode == barcode.rawValue) return;

    setState(() {
      _isScanning = true;
      _lastScannedCode = barcode.rawValue;
    });

    // 스캔 중지
    await _scannerController?.stop();

    _processBarcode(barcode.rawValue!);
  }

  Future<void> _processBarcode(String code) async {
    debugPrint('스캔된 바코드: $code');

    const prefix = 'http://www.exgold.co.kr/securities/spot_securities.html?';
    if (!code.startsWith(prefix)) {
      setState(() {
        _isScanning = false;
        _lastScannedCode = null;
      });
      _scannerController?.start();
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
          if (mounted) {
            // 결과 화면으로 이동
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResultScreen(id: id, lat: 0.0, lng: 0.0),
              ),
            );
            // 결과 화면에서 돌아왔을 때 스캐너 재시작 및 상태 초기화
            if (mounted) {
              setState(() {
                _isScanning = false;
                _lastScannedCode = null;
              });
              _scannerController?.start();
            }
          }
        } else {
          // 유가증권 정보를 찾을 수 없는 경우 스캐너 재시작
          if (mounted) {
            setState(() {
              _isScanning = false;
              _lastScannedCode = null;
            });
            _scannerController?.start();
          }
        }
      } else {
        // API 오류 시 스캐너 재시작
        if (mounted) {
          setState(() {
            _isScanning = false;
            _lastScannedCode = null;
          });
          _scannerController?.start();
        }
      }
    } catch (e) {
      debugPrint('API 에러: $e');
      // 에러 발생 시 스캐너 재시작
      if (mounted) {
        setState(() {
          _isScanning = false;
          _lastScannedCode = null;
        });
        _scannerController?.start();
      }
    }
  }

  void _onAppDownloadTap() {
    // 센골드 앱 다운로드 처리
    debugPrint('센골드 앱 다운로드');
  }

  @override
  Widget build(BuildContext context) {
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
                          child: _isInitializing
                              ? Container(
                                  color: Colors.black,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.orange,
                                    ),
                                  ),
                                )
                              : _scannerController != null
                              ? SizedBox.expand(
                                  child: MobileScanner(
                                    controller: _scannerController,
                                    onDetect: _onBarcodeDetect,
                                    errorBuilder: (context, error, child) {
                                      debugPrint('MobileScanner 에러: $error');
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
                                )
                              : Container(
                                  color: Colors.black,
                                  child: const Center(
                                    child: Text(
                                      '카메라를 초기화할 수 없습니다',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
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
                    'assets/images/banner.png',
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
