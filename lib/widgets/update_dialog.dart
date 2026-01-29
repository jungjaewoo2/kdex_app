import 'package:flutter/material.dart';
import '../services/app_version_checker.dart';

class UpdateDialog extends StatelessWidget {
  final Map<String, dynamic> updateInfo;
  final bool forceUpdate;
  
  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.forceUpdate = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !forceUpdate, // 강제 업데이트 시 뒤로가기 방지
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Color(0xFFED7C2A)),
            const SizedBox(width: 8),
            const Text(
              '앱 업데이트',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              updateInfo['message'] ?? '새 버전이 있습니다. 업데이트하시겠습니까?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              '현재 버전: ${updateInfo['current_version'] ?? ''}\n최신 버전: ${updateInfo['latest_version'] ?? ''}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '나중에',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await AppVersionChecker.openPlayStore();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Play Store를 열 수 없습니다: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFED7C2A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('업데이트'),
          ),
        ],
      ),
    );
  }
}
