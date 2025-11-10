import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ResultScreen extends StatefulWidget {
  final String id;
  final double lat;
  final double lng;

  const ResultScreen({
    super.key,
    required this.id,
    required this.lat,
    required this.lng,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Map<String, dynamic>? stockData;
  String stockId = 'no_stock';
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStockData();
  }

  Future<void> _fetchStockData() async {
    try {
      final ipAddress = await _getIPAddress();

      final params = {
        'id': widget.id,
        'lat': widget.lat.toString(),
        'lng': widget.lng.toString(),
        'ip': ipAddress,
      };

      final uri = Uri.parse(
        'https://pennygold.kr/kgex/viewGiftCardInfo',
      ).replace(queryParameters: params);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['rows'] != null && data['rows'].length == 1) {
          setState(() {
            stockData = data['rows'][0];
            stockId = data['rows'][0]['ID'].toLowerCase();
            isLoading = false;
          });
        } else {
          setState(() {
            stockData = null;
            stockId = 'no_stock';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = '서버 오류가 발생했습니다.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = '네트워크 오류가 발생했습니다.';
        isLoading = false;
      });
    }
  }

  Future<String> _getIPAddress() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      return response.body;
    } catch (e) {
      return '0.0.0.0';
    }
  }

  String _getStockImagePath() {
    return 'assets/images/stock/$stockId.png';
  }

  String _toDisplayDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String _toDisplayNumber(double number) {
    return number.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _toDisplayDecimalNumber(double number) {
    return number
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  double _calculatePrice() {
    if (stockData == null) return 0.0;
    final perPrice = double.tryParse(stockData!['TICKERG'].toString()) ?? 0.0;
    final weightStr = stockData!['ID']
        .toString()
        .substring(2, 7)
        .replaceAll('d', '.');
    final weight = double.tryParse(weightStr) ?? 0.0;
    return perPrice * weight;
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('유가증권 조회'),
          backgroundColor: const Color(0xFF2C1E1A),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('유가증권 조회'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // iOS 상태바 영역 주황색 배경
          Container(
            color: const Color(0xFFED7C2A),
            height: MediaQuery.of(context).padding.top,
          ),
          // 메인 콘텐츠
          Column(
            children: [
              // 이미지 영역
              Container(
                width: double.infinity,
                color: const Color(0xFFFCF9EE),
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 유가증권 이미지 - 가로 폭에 맞게 크게 표시
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Image.asset(
                        _getStockImagePath(),
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/stock/no_stock.png',
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.contain,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Image.asset(
                      stockId == 'no_stock'
                          ? 'assets/images/logo_gray.png'
                          : 'assets/images/logo.png',
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
              // 정보 영역
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (stockData == null || errorMessage != null)
                        _buildErrorWidget()
                      else
                        Column(
                          children: [
                            _buildStockInfo(),
                            const SizedBox(height: 20),
                            _buildStockEvaluation(),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 60,
        color: const Color(0xFFED7C2A),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _goBack,
            child: const Center(
              child: Text(
                '이전화면',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(50),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 20),
          Text(
            errorMessage ?? '사용이 불가능한 상품권입니다.',
            style: const TextStyle(color: Colors.red, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStockInfo() {
    final buyDate = DateTime.parse(stockData!['DATETIME']);
    final endDate = DateTime.parse(stockData!['ENDDATE']);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFC),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '유가증권 정보',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildInfoRow('구입일', _toDisplayDate(buyDate)),
          _buildInfoRow(
            '기준금액',
            '${_toDisplayDecimalNumber(double.parse(stockData!['APPLIEDAMOUNT'].toString()))} 원',
          ),
          _buildInfoRow(
            '유가증권 구입금액',
            '${_toDisplayNumber(double.parse(stockData!['AMOUNT'].toString()))} 원',
          ),
          _buildInfoRow('유가증권 유효성', '유효'),
          _buildInfoRow('유가증권 유효기간', '구입일로부터 20년'),
          _buildInfoRow('', '(~ ${_toDisplayDate(endDate)})', isSubText: true),
        ],
      ),
    );
  }

  Widget _buildStockEvaluation() {
    final currentDate = DateTime.now();
    final perPrice = double.parse(stockData!['TICKERG'].toString());
    final calculatedPrice = _calculatePrice();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFC),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '유가증권 평가',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildInfoRow('평가일', _toDisplayDate(currentDate)),
          _buildInfoRow('기준금액', '${_toDisplayDecimalNumber(perPrice)} 원'),
          _buildInfoRow('유가증권 평가금액', '${_toDisplayNumber(calculatedPrice)} 원'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, {bool isSubText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(title, style: const TextStyle(fontSize: 16)),
          ),
          Expanded(
            flex: 1,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: isSubText ? Colors.grey[600] : Colors.black,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
