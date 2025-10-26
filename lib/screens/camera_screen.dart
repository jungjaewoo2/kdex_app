import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;

  // 바코드 스캐너 사용 모드
  final bool _useBarcodeScanner = true;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    if (_useBarcodeScanner) {
      // 바코드 스캐너는 별도 초기화 불필요
    } else {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        _showErrorDialog('카메라 권한이 필요합니다.');
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('카메라 초기화 실패: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

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
      _showErrorDialog('유효하지 않은 유가증권 코드입니다.');
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
                builder: (context) =>
                    ResultScreen(stockInfo: stockInfo, id: id),
              ),
            );
          }
        } else {
          if (mounted) {
            _showErrorDialog('유가증권 정보를 찾을 수 없습니다.');
          }
        }
      } else {
        if (mounted) {
          _showErrorDialog('서버 오류가 발생했습니다.');
        }
      }
    } catch (e) {
      debugPrint('API 에러: $e');
      if (mounted) {
        _showErrorDialog('네트워크 오류가 발생했습니다.');
      }
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _takePicture() async {
    if (!_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    try {
      setState(() {
        _isCapturing = true;
      });

      final XFile image = await _controller!.takePicture();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CameraResultScreen(imagePath: image.path),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('사진 촬영 실패: $e');
      }
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (image != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraResultScreen(imagePath: image.path),
        ),
      );
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
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isScanning = false;
              });
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useBarcodeScanner) {
      return _buildBarcodeScanner();
    } else {
      return _buildCameraView();
    }
  }

  Widget _buildBarcodeScanner() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      '유가증권 QR코드 스캔',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // 뒤로가기 버튼과 균형 맞추기
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(onDetect: _onBarcodeDetect),
                  Container(
                    margin: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const AspectRatio(aspectRatio: 1, child: SizedBox()),
                  ),
                  if (_isScanning)
                    Container(
                      color: Colors.black.withValues(alpha: 0.54),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.orange),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.black),
              child: const Text(
                'QR 코드를 화면 가운데에 맞춰주세요',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      '유가증권 촬영',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                    onPressed: _pickFromGallery,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isInitialized && _controller != null)
                    Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: CameraPreview(_controller!),
                      ),
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  Container(
                    margin: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const AspectRatio(
                      aspectRatio: 1.6,
                      child: SizedBox(),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: _isCapturing
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.black,
                              ),
                            )
                          : const SizedBox(),
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

class CameraResultScreen extends StatelessWidget {
  final String imagePath;

  const CameraResultScreen({super.key, required this.imagePath});

  void _analyzeSecurity() {
    // 여기에 실제 유가증권 검증 로직 추가
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('촬영 결과'),
        backgroundColor: const Color(0xFF2C1E1A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.file(File(imagePath), fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    _analyzeSecurity();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('유가증권 검증 기능은 구현 예정입니다.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C1E1A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('검증하기'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('다시 촬영'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> stockInfo;
  final String id;

  const ResultScreen({super.key, required this.stockInfo, required this.id});

  String _getStockImagePath(String stockId) {
    final id = stockId.toLowerCase();
    if (id == 'ag01000g') return 'assets/images/stock/ag01000g.png';
    if (id == 'au01000g') return 'assets/images/stock/au01000g.png';
    if (id == 'au00100g') return 'assets/images/stock/au00100g.png';
    if (id == 'au037d5g') return 'assets/images/stock/au037d5g.png';
    if (id == 'au18d75g') return 'assets/images/stock/au18d75g.png';
    if (id == 'au00010g') return 'assets/images/stock/au00010g.png';
    if (id == 'au03d75g') return 'assets/images/stock/au03d75g.png';
    return 'assets/images/logo_gray.png';
  }

  @override
  Widget build(BuildContext context) {
    final stockId = stockInfo['ID']?.toString().toLowerCase() ?? 'no_stock';
    final hasValidStock = stockId != 'no_stock';

    return Scaffold(
      appBar: AppBar(
        title: const Text('유가증권 조회'),
        backgroundColor: const Color(0xFF2C1E1A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 유가증권 이미지
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCF9EE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Image.asset(
                            _getStockImagePath(stockId),
                            height: 150,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 20),
                          Image.asset(
                            hasValidStock
                                ? 'assets/images/logo.png'
                                : 'assets/images/logo_gray.png',
                            height: 50,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 유가증권 정보
                    if (hasValidStock)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (stockInfo['GIFT_NAME'] != null)
                            _buildInfoRow(
                              '상품명',
                              stockInfo['GIFT_NAME'].toString(),
                            ),
                          if (stockInfo['STATUS'] != null)
                            _buildInfoRow('상태', stockInfo['STATUS'].toString()),
                          if (stockInfo['CREATE_DT'] != null)
                            _buildInfoRow(
                              '발급일',
                              stockInfo['CREATE_DT'].toString(),
                            ),
                          if (stockInfo['USE_DT'] != null)
                            _buildInfoRow(
                              '사용일',
                              stockInfo['USE_DT'].toString(),
                            ),
                        ],
                      )
                    else
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            '유효하지 않은 유가증권입니다.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 하단 버튼
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFED7C2A),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '이전화면',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
