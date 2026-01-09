import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelName = '방송 알림';
  static const String _channelDescription = '관심 방송인의 방송 시작 알림을 받습니다.';

  // 설정별 채널 ID 정의
  static const String _channelIdSV = 'soop_noti_sv'; // 소리 O, 진동 O
  static const String _channelIdS = 'soop_noti_s'; // 소리 O, 진동 X
  static const String _channelIdV = 'soop_noti_v'; // 소리 X, 진동 O
  static const String _channelIdN = 'soop_noti_n'; // 소리 X, 진동 X (무음)

  // 초기화
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _openBroadcast(response.payload!);
        }
      },
    );

    // 알림 채널 생성 (Android 8.0+)
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // 4가지 조합의 채널 생성 (설정 변경 시 즉시 반영을 위해)
      // 1. 소리 O, 진동 O
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelIdSV,
          '$_channelName (소리+진동)',
          description: _channelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // 2. 소리 O, 진동 X
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelIdS,
          '$_channelName (소리)',
          description: _channelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: false,
        ),
      );

      // 3. 소리 X, 진동 O
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelIdV,
          '$_channelName (진동)',
          description: _channelDescription,
          importance: Importance.high,
          playSound: false,
          enableVibration: true,
        ),
      );

      // 4. 소리 X, 진동 X
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelIdN,
          '$_channelName (무음)',
          description: _channelDescription,
          importance:
              Importance.low, // 무음은 중요도 낮음 (팝업 안 뜰 수 있음) -> High로 하면 소리 없이 뜸
          playSound: false,
          enableVibration: false,
        ),
      );

      // 포그라운드 서비스 알림 채널 (BackgroundService에서 사용)
      const AndroidNotificationChannel foregroundChannel =
          AndroidNotificationChannel(
            'soop_foreground_service',
            '방송 모니터링 서비스',
            description: '백그라운드에서 방송 상태를 확인합니다.',
            importance: Importance.low, // 덜 눈에 띄게
          );
      await androidPlugin?.createNotificationChannel(foregroundChannel);
    }
  }

  // 설정에 맞는 채널 ID 반환
  static String _getChannelId(bool sound, bool vibration) {
    if (sound && vibration) return _channelIdSV;
    if (sound && !vibration) return _channelIdS;
    if (!sound && vibration) return _channelIdV;
    return _channelIdN;
  }

  // 알림 발송
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String
    channelId, // 호출하는 쪽에서 보내준 channelId (여기선 streamerId 등으로 쓰이지만 실제 노티 채널 ID는 아님)
    required int broadNo,
    String? profileImageUrl,
    bool enableSound = true,
    bool enableVibration = true,
  }) async {
    // Payload에 채널ID와 방송번호를 담아서 전달 (형식: channelId/broadNo)
    final String payload = '$channelId/$broadNo';

    // 설정에 맞는 실제 Android Notification Channel ID 선택
    final String notificationChannelId = _getChannelId(
      enableSound,
      enableVibration,
    );

    // 프로필 이미지 다운로드
    ByteArrayAndroidBitmap? largeIcon;
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(profileImageUrl));
        if (response.statusCode == 200) {
          largeIcon = ByteArrayAndroidBitmap(response.bodyBytes);
        }
      } catch (e) {
        print('Failed to load profile image: $e');
      }
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          notificationChannelId, // 동적으로 선택된 채널 ID
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          largeIcon: largeIcon,
          playSound: enableSound,
          enableVibration: enableVibration,
        );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(id, title, body, details, payload: payload);
  }

  static Future<void> _openBroadcast(String payload) async {
    final parts = payload.split('/');
    if (parts.length < 2) return;

    final channelId = parts[0];
    final broadNo = parts[1];
    final webUrl = Uri.parse('https://play.sooplive.co.kr/$channelId/$broadNo');

    try {
      if (!await launchUrl(webUrl, mode: LaunchMode.externalApplication)) {
        print('Could not launch $webUrl');
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }
}
