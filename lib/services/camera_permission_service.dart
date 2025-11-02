import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// 카메라 권한을 한 번만 요청하도록 관리하는 서비스
class CameraPermissionService {
  static final CameraPermissionService _instance =
      CameraPermissionService._internal();
  factory CameraPermissionService() => _instance;
  CameraPermissionService._internal();

  bool _isRequesting = false;
  bool _hasRequested = false;
  PermissionStatus? _lastStatus;

  /// 카메라 권한 상태를 확인하고 필요시 요청
  /// 이미 허용되었거나 요청 중이면 즉시 반환
  Future<PermissionStatus> requestIfNeeded() async {
    debugPrint('[CameraPermissionService] 권한 요청 확인 시작');

    // 이미 요청 중이면 대기
    if (_isRequesting) {
      debugPrint('[CameraPermissionService] 이미 요청 중 является. 대기...');
      while (_isRequesting) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      debugPrint('[CameraPermissionService] 요청 완료, 상태: $_lastStatus');
      return _lastStatus ?? PermissionStatus.denied;
    }

    // 현재 권한 상태 확인
    final currentStatus = await Permission.camera.status;
    debugPrint('[CameraPermissionService] 현재 권한 상태: $currentStatus');

    // 이미 허용되었으면 반환
    if (currentStatus.isGranted) {
      debugPrint('[CameraPermissionService] 권한이 이미 허용됨');
      _lastStatus = currentStatus;
      return currentStatus;
    }

    // 이미 요청한 적이 있고 거부된 경우, 다시 요청하지 않음
    if (_hasRequested && currentStatus.isPermanentlyDenied) {
      debugPrint('[CameraPermissionService] 권한이 영구적으로 거부됨');
      _lastStatus = currentStatus;
      return currentStatus;
    }

    // 권한 요청
    _isRequesting = true;
    _hasRequested = true;

    try {
      debugPrint('[CameraPermissionService] 권한 요청 시작 (한 번만)');
      final result = await Permission.camera.request();
      debugPrint('[CameraPermissionService] 권한 요청 결과: $result');
      _lastStatus = result;
      return result;
    } finally {
      _isRequesting = false;
    }
  }

  /// 권한 상태만 확인 (요청하지 않음)
  Future<PermissionStatus> getStatus() async {
    return await Permission.camera.status;
  }

  /// 권한 요청 상태 초기화 (테스트용)
  void reset() {
    _isRequesting = false;
    _hasRequested = false;
    _lastStatus = null;
  }
}
