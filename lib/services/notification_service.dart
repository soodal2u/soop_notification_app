import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'soop_broadcast_channel';
  static const String _channelName = '방송 알림';
  static const String _channelDescription = '관심 방송인의 방송 시작 알림을 받습니다.';

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

      // 방송 시작 알림 채널
      final AndroidNotificationChannel broadcastChannel =
          AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          );
      await androidPlugin?.createNotificationChannel(broadcastChannel);

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

  // 알림 발송
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required int broadNo,
    String? profileImageUrl,
    bool enableSound = true,
    bool enableVibration = true,
  }) async {
    // Payload에 채널ID와 방송번호를 담아서 전달 (형식: channelId/broadNo)
    final String payload = '$channelId/$broadNo';

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
          _channelId,
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

  // 방송 열기 (앱 실행 시도 -> 실패 시 웹)
  static Future<void> _openBroadcast(String payload) async {
    final parts = payload.split('/');
    if (parts.length < 2) return;

    final channelId = parts[0];
    final broadNo = parts[1];

    // 1. 앱 실행 시도 (URL Scheme)
    // AfreecaTV 앱 스킴: afreeca:// (정확한 딥링크 포맷은 불명확하나, 메인 진입 시도)
    // 알려진 딥링크가 확실하지 않으므로, 일반적인 시도를 하되
    // Intent URL 형식을 사용할 수도 있습니다.
    // 여기서는 가장 일반적인 afreeca:// 스킴과 soop:// 스킴을 시도해봅니다.

    // NOTE: 정확한 딥링크를 모를 때는 웹 URL을 launchUrl로 열 때
    // mode: LaunchMode.externalApplication으로 설정하면
    // 시스템이 자동으로 앱을 제안하거나 엽니다. (가장 확실한 방법)

    final webUrl = Uri.parse('https://play.sooplive.co.kr/$channelId/$broadNo');

    try {
      // LaunchMode.externalApplication: 브라우저나 설치된 앱으로 열기
      if (!await launchUrl(webUrl, mode: LaunchMode.externalApplication)) {
        print('Could not launch $webUrl');
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }
}
