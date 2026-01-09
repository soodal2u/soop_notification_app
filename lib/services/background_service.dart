import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soop_notification_app/models/streamer.dart';
import 'package:soop_notification_app/services/api_service.dart';
import 'package:soop_notification_app/services/notification_service.dart';

@pragma('vm:entry-point')
class BackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // onStart는 별도의 Isolate에서 실행됩니다.
        onStart: onStart,
        autoStart: false, // 사용자가 직접 켜도록 설정 (또는 true로 하여 자동 시작)
        isForegroundMode: true,
        notificationChannelId: 'soop_foreground_service',
        initialNotificationTitle: 'SOOP 알리미 서비스',
        initialNotificationContent: '방송 상태를 모니터링 중입니다...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  // iOS 백그라운드 핸들러 (제한적)
  @pragma('vm:entry-point')
  static bool onIosBackground(ServiceInstance service) {
    return true;
  }

  // 서비스 시작 시 실행되는 메인 로직
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Dart Plugin 등록 (필요한 경우)
    DartPluginRegistrant.ensureInitialized();

    // 서비스에서 사용할 모듈 초기화
    await NotificationService.initialize();

    // 서비스 중지 이벤트 리스너
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    final apiService = ApiService();

    // 30초마다 실행되는 타이머
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _checkBroadcasts(apiService);

      // 서비스 인스턴스가 종료되었는지 확인하는 로직이 필요할 수 있음
      // 서비스 인스턴스가 종료되었는지 확인하는 로직 (생략 - 포그라운드 모드 유지)

      // 현재 실행 중임을 알림 내용 업데이트 (선택 사항)
      service.invoke('update', {
        "current_date": DateTime.now().toIso8601String(),
      });
    });
  }

  static Future<void> _checkBroadcasts(ApiService apiService) async {
    final prefs = await SharedPreferences.getInstance();
    // 저장된 방송인 목록 불러오기
    // (UI에서 'streamers' 키로 저장한다고 가정)
    final String? streamersJson = prefs.getString('streamers');
    if (streamersJson == null) return;

    List<dynamic> decoded = jsonDecode(streamersJson);
    List<Streamer> streamers = decoded
        .map((e) => Streamer.fromJson(e))
        .toList();

    bool isUpdated = false;

    for (var streamer in streamers) {
      print('Checking streamer: ${streamer.id}'); // 디버깅 로그
      final status = await apiService.fetchBroadcastInfo(streamer.id);
      if (status == null) continue;

      if (status.isBroadcasting) {
        // 방송 중
        // lastBroadNo가 null(처음 체크 또는 이전에 종료됨)이거나
        // 방송 번호가 다르면(새 방송) 알림 발송
        if (streamer.lastBroadNo == null ||
            streamer.lastBroadNo != status.broadNo) {
          streamer.lastBroadNo = status.broadNo;
          isUpdated = true;

          // 방송 시작 알림 발송
          await NotificationService.showNotification(
            id: streamer.id.hashCode,
            title: '🔴 ${status.userNick} 방송 시작!',
            body: status.broadTitle ?? '방송이 시작되었습니다.',
            channelId: streamer.id,
            broadNo: status.broadNo!,
            profileImageUrl: status.profileImageUrl,
          );
        }
        // 이미 같은 방송 번호면 중복 알림 X (아무것도 안함)
      } else {
        // 방송 중 아님
        if (streamer.lastBroadNo != null) {
          // 이전에 방송 중이었는데 지금 종료됨 -> 종료 알림
          await NotificationService.showNotification(
            id: streamer.id.hashCode + 1, // 다른 알림 ID
            title: '⚫ ${status.userNick} 방송 종료',
            body: '방송이 종료되었습니다.',
            channelId: streamer.id,
            broadNo: 0, // 종료이므로 0
          );

          streamer.lastBroadNo = null;
          isUpdated = true;
        }
        // lastBroadNo가 이미 null이면 중복 알림 X (아무것도 안함)
      }
    }

    // 변경 사항이 있으면 저장
    if (isUpdated) {
      final String updatedJson = jsonEncode(
        streamers.map((e) => e.toJson()).toList(),
      );
      await prefs.setString('streamers', updatedJson);
    }
  }
}
