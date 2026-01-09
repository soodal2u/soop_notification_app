import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soop_notification_app/models/streamer.dart';
import 'package:soop_notification_app/models/app_settings.dart';
import 'package:soop_notification_app/services/api_service.dart';
import 'package:soop_notification_app/services/notification_service.dart';

@pragma('vm:entry-point')
class BackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
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

  @pragma('vm:entry-point')
  static bool onIosBackground(ServiceInstance service) {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    await NotificationService.initialize();

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    final apiService = ApiService();

    // 설정에서 체크 주기 가져오기
    final prefs = await SharedPreferences.getInstance();
    int checkInterval = prefs.getInt('checkIntervalSeconds') ?? 30;

    // 설정 변경 감지를 위한 타이머
    Timer.periodic(Duration(seconds: checkInterval), (timer) async {
      // 최신 설정 다시 로드 (사용자가 설정을 변경했을 수 있음)
      final currentInterval = prefs.getInt('checkIntervalSeconds') ?? 30;
      if (currentInterval != checkInterval) {
        // 주기가 변경되면 타이머 재시작 필요 (서비스 재시작으로 처리)
        checkInterval = currentInterval;
      }

      await _checkBroadcasts(apiService, prefs);

      service.invoke('update', {
        "current_date": DateTime.now().toIso8601String(),
      });
    });
  }

  static Future<void> _checkBroadcasts(
    ApiService apiService,
    SharedPreferences prefs,
  ) async {
    // 방해 금지 시간대 체크
    final settings = await AppSettings.load();
    if (settings.isInDndTime()) {
      print('방해 금지 시간대입니다. 알림을 보내지 않습니다.');
      return;
    }

    final String? streamersJson = prefs.getString('streamers');
    if (streamersJson == null) return;

    List<dynamic> decoded = jsonDecode(streamersJson);
    List<Streamer> streamers = decoded
        .map((e) => Streamer.fromJson(e))
        .toList();

    bool isUpdated = false;

    for (var streamer in streamers) {
      print('Checking streamer: ${streamer.id}');
      final status = await apiService.fetchBroadcastInfo(streamer.id);
      if (status == null) continue;

      if (status.isBroadcasting) {
        if (streamer.lastBroadNo == null ||
            streamer.lastBroadNo != status.broadNo) {
          streamer.lastBroadNo = status.broadNo;
          isUpdated = true;

          // 알림이 활성화된 경우에만 알림 발송
          if (streamer.notificationEnabled) {
            await NotificationService.showNotification(
              id: streamer.id.hashCode,
              title: '🔴 ${status.userNick} 방송 시작!',
              body: status.broadTitle ?? '방송이 시작되었습니다.',
              channelId: streamer.id,
              broadNo: status.broadNo!,
              profileImageUrl: status.profileImageUrl,
              enableSound: settings.notificationSound,
              enableVibration: settings.notificationVibration,
            );
          }
        }
      } else {
        if (streamer.lastBroadNo != null) {
          // 알림이 활성화된 경우에만 종료 알림 발송
          if (streamer.notificationEnabled) {
            await NotificationService.showNotification(
              id: streamer.id.hashCode + 1,
              title: '⚫ ${status.userNick} 방송 종료',
              body: '방송이 종료되었습니다.',
              channelId: streamer.id,
              broadNo: 0,
              enableSound: settings.notificationSound,
              enableVibration: settings.notificationVibration,
            );
          }

          streamer.lastBroadNo = null;
          isUpdated = true;
        }
      }
    }

    if (isUpdated) {
      final String updatedJson = jsonEncode(
        streamers.map((e) => e.toJson()).toList(),
      );
      await prefs.setString('streamers', updatedJson);
    }
  }
}
