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
                        '유가증권Check한국금거래소의 최신 소식과 중요한 알림을 받아보세요.',
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
