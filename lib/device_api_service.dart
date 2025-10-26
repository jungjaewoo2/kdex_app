import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceApiService {
  static const String baseUrl = 'https://www.koreagoldx.co.kr/api/device';

  /// 디바이스 등록/업데이트
  /// 앱 실행 시 디바이스 정보를 등록하거나 업데이트합니다.
  static Future<Map<String, dynamic>> registerDevice({
    required String app,
    required String deviceId,
    required String token,
    required String os,
    String receiveYn = 'N',
  }) async {
    try {
      print(
        '디바이스 등록 요청: app=$app, deviceId=$deviceId, os=$os, receiveYn=$receiveYn',
      );
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'app': app,
          'deviceId': deviceId,
          'token': token,
          'os': os,
          'receiveYn': receiveYn,
        }),
      );

      print('=== 디바이스 등록 API 응답 ===');
      print('HTTP 상태 코드: ${response.statusCode}');
      print('응답 Body: "${response.body}"');
      print('응답 Body 길이: ${response.body.length}');
      print('응답 헤더: ${response.headers}');

      if (response.statusCode == 200) {
        try {
          final result = jsonDecode(utf8.decode(response.bodyBytes));
          print('디바이스 등록 파싱된 응답: $result');

          // 응답이 문자열인 경우 처리
          if (result is String) {
            return {'result': 'success', 'message': '디바이스가 등록되었습니다.'};
          }

          // 응답이 Map인 경우
          if (result is Map<String, dynamic>) {
            print('등록 응답이 Map임: $result');
            // result 필드가 있는지 확인
            if (result.containsKey('result')) {
              print(
                '등록 result 필드 존재: ${result['result']} (타입: ${result['result'].runtimeType})',
              );

              // 서버가 boolean으로 응답하는 경우 처리
              if (result['result'] == true) {
                print('등록 서버 응답이 true - success로 변환');
                return {
                  'result': 'success',
                  'message': result['msg'] ?? '디바이스가 등록되었습니다.',
                  'map': result['map'] ?? {},
                };
              } else if (result['result'] == false) {
                print('등록 서버 응답이 false - fail로 변환');
                return {
                  'result': 'fail',
                  'message': result['msg'] ?? '디바이스 등록에 실패했습니다.',
                };
              } else {
                return result;
              }
            } else {
              return result;
            }
          }

          // 기타 경우 성공으로 처리
          return {'result': 'success', 'message': '디바이스가 등록되었습니다.'};
        } catch (e) {
          print('JSON 파싱 에러: $e');
          // JSON 파싱 실패해도 서버에서 200을 반환했다면 성공으로 처리
          return {'result': 'success', 'message': '디바이스가 등록되었습니다.'};
        }
      } else {
        print(
          '디바이스 등록 HTTP 에러: ${response.statusCode}, Body: ${response.body}',
        );
        return {'result': 'fail', 'message': 'HTTP 에러: ${response.statusCode}'};
      }
    } catch (e) {
      print('디바이스 등록 예외 발생: $e');
      return {'result': 'fail', 'message': '디바이스 등록 중 오류 발생: $e'};
    }
  }

  /// 수신동의 설정 변경
  /// 특정 디바이스의 푸시 알림 수신동의 설정을 변경합니다.
  static Future<Map<String, dynamic>> updateReceiveYn({
    required String app,
    required String deviceId,
    required String receiveYn,
  }) async {
    try {
      print('=== 수신동의 변경 요청 시작 ===');
      print('요청 파라미터: app=$app, deviceId=$deviceId, receiveYn=$receiveYn');
      
      final response = await http.post(
        Uri.parse('$baseUrl/updateReceiveYn'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'app': app,
          'deviceId': deviceId,
          'receiveYn': receiveYn,
        }),
      );

      print('=== 수신동의 변경 API 응답 ===');
      print('HTTP 상태 코드: ${response.statusCode}');
      print('응답 Body: "${response.body}"');

      // HTTP 상태 코드 확인
      if (response.statusCode == 200) {
        // 응답이 비어있는 경우
        if (response.body.isEmpty) {
          print('✅ 응답이 비어있음 - 성공으로 처리');
          return {
            'result': 'success', 
            'message': '수신동의 설정이 변경되었습니다.',
            'data': {'receiveYn': receiveYn}
          };
        }

        try {
          final result = jsonDecode(response.body);
          print('JSON 파싱 성공: $result');

          // 서버 응답 구조에 따른 처리
          if (result is Map<String, dynamic>) {
            // result 필드가 있는 경우
            if (result.containsKey('result')) {
              final serverResult = result['result'];
              
              if (serverResult == true || serverResult == 'success') {
                print('✅ 서버에서 성공 응답');
                return {
                  'result': 'success',
                  'message': result['msg'] ?? '수신동의 설정이 변경되었습니다.',
                  'data': result['data'] ?? {'receiveYn': receiveYn},
                };
              } else if (serverResult == false || serverResult == 'fail') {
                print('❌ 서버에서 실패 응답');
                return {
                  'result': 'fail',
                  'message': result['msg'] ?? '수신동의 설정 변경에 실패했습니다.',
                };
              }
            }
            
            // result 필드가 없는 경우 성공으로 처리
            print('✅ result 필드 없음 - 성공으로 처리');
            return {
              'result': 'success',
              'message': '수신동의 설정이 변경되었습니다.',
              'data': {'receiveYn': receiveYn},
            };
          }

          // 기타 타입의 응답
          print('✅ 기타 응답 타입 - 성공으로 처리');
          return {
            'result': 'success',
            'message': '수신동의 설정이 변경되었습니다.',
            'data': {'receiveYn': receiveYn},
          };
        } catch (e) {
          print('❌ JSON 파싱 실패: $e');
          // JSON 파싱 실패해도 HTTP 200이면 성공으로 처리
          return {
            'result': 'success',
            'message': '수신동의 설정이 변경되었습니다.',
            'data': {'receiveYn': receiveYn},
          };
        }
      } else {
        print('❌ HTTP 에러: ${response.statusCode}');
        return {
          'result': 'fail', 
          'message': '서버 오류: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('❌ 수신동의 변경 예외: $e');
      return {
        'result': 'fail', 
        'message': '네트워크 오류: $e'
      };
    }
  }

  /// 수신동의 설정 조회
  /// 특정 디바이스의 푸시 알림 수신동의 설정을 조회합니다.
  static Future<Map<String, dynamic>> getReceiveYn({
    required String app,
    required String deviceId,
  }) async {
    try {
      print('=== 수신동의 조회 요청 시작 ===');
      print('요청 파라미터: app=$app, deviceId=$deviceId');
      
      // GET 요청으로 변경하고 쿼리 파라미터 사용
      final uri = Uri.parse('$baseUrl/getReceiveYn').replace(
        queryParameters: {
          'app': app,
          'deviceId': deviceId,
        },
      );
      
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      print('=== 수신동의 조회 API 응답 ===');
      print('HTTP 상태 코드: ${response.statusCode}');
      print('응답 Body: "${response.body}"');
      print('응답 Body 길이: ${response.body.length}');
      print('응답 헤더: ${response.headers}');

      if (response.statusCode == 200) {
        // 응답이 비어있는 경우 기본값 반환
        if (response.body.isEmpty) {
          print('⚠️ 조회 응답이 비어있음 - 기본값 반환 (서버에 등록되지 않았을 수 있음)');
          final defaultData = {'receiveYn': 'N'};
          return {
            'result': 'success',
            'message': '조회되었습니다.',
            'map': defaultData,  // device_manager.dart에서 map 필드를 확인함
            'data': defaultData, // 호환성을 위해 data도 함께 반환
          };
        }

        try {
          final result = jsonDecode(response.body);
          print('JSON 파싱 성공: $result');

          if (result is Map<String, dynamic>) {
            // result 필드가 있는 경우
            if (result.containsKey('result')) {
              final serverResult = result['result'];
              
              if (serverResult == true || serverResult == 'success') {
                print('✅ 서버에서 성공 응답');
                // 서버 응답 구조에 따라 map 또는 data 필드 확인
                Map<String, dynamic> dataMap;
                if (result.containsKey('map') && result['map'] != null) {
                  dataMap = result['map'] as Map<String, dynamic>;
                  print('map 필드에서 데이터 추출: $dataMap');
                } else if (result.containsKey('data') && result['data'] != null) {
                  dataMap = result['data'] as Map<String, dynamic>;
                  print('data 필드에서 데이터 추출: $dataMap');
                } else {
                  dataMap = {'receiveYn': 'N'};
                  print('map/data 필드 없음 - 기본값 사용');
                }

                return {
                  'result': 'success',
                  'message': result['message'] ?? result['msg'] ?? '조회되었습니다.',
                  'map': dataMap,  // device_manager.dart에서 map 필드를 확인함
                  'data': dataMap, // 호환성을 위해 data도 함께 반환
                };
              } else if (serverResult == false || serverResult == 'fail') {
                print('❌ 서버에서 실패 응답');
                return {
                  'result': 'fail',
                  'message': result['msg'] ?? '조회에 실패했습니다.',
                };
              }
            }

            // result 필드가 없는 경우 성공으로 처리
            print('✅ result 필드 없음 - 성공으로 처리');
            // map 필드 확인
            Map<String, dynamic> dataMap;
            if (result.containsKey('map') && result['map'] != null) {
              dataMap = result['map'] as Map<String, dynamic>;
              print('map 필드에서 데이터 추출: $dataMap');
            } else if (result.containsKey('data') && result['data'] != null) {
              dataMap = result['data'] as Map<String, dynamic>;
              print('data 필드에서 데이터 추출: $dataMap');
            } else {
              dataMap = {'receiveYn': 'N'};
              print('map/data 필드 없음 - 기본값 사용');
            }

            return {
              'result': 'success',
              'message': '조회되었습니다.',
              'map': dataMap,  // device_manager.dart에서 map 필드를 확인함
              'data': dataMap, // 호환성을 위해 data도 함께 반환
            };
          }

          // 기타 타입의 응답
          print('⚠️ 기타 응답 타입 - 기본값 반환');
          final defaultData = {'receiveYn': 'N'};
          return {
            'result': 'success',
            'message': '조회되었습니다.',
            'map': defaultData,  // device_manager.dart에서 map 필드를 확인함
            'data': defaultData, // 호환성을 위해 data도 함께 반환
          };
        } catch (e) {
          print('❌ JSON 파싱 실패: $e');
          print('응답 내용: ${response.body}');
          // JSON 파싱 실패해도 HTTP 200이면 기본값 반환
          final defaultData = {'receiveYn': 'N'};
          return {
            'result': 'success',
            'message': '조회되었습니다.',
            'map': defaultData,  // device_manager.dart에서 map 필드를 확인함
            'data': defaultData, // 호환성을 위해 data도 함께 반환
          };
        }
      } else {
        print('❌ HTTP 에러: ${response.statusCode}');
        return {
          'result': 'fail', 
          'message': '서버 오류: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('❌ 수신동의 조회 예외: $e');
      return {
        'result': 'fail', 
        'message': '네트워크 오류: $e'
      };
    }
  }
}
