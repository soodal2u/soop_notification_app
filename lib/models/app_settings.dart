import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  int checkIntervalSeconds;
  bool notificationSound;
  bool notificationVibration;
  bool dndEnabled;
  TimeOfDay dndStartTime;
  TimeOfDay dndEndTime;
  ThemeMode themeMode;

  AppSettings({
    this.checkIntervalSeconds = 30,
    this.notificationSound = true,
    this.notificationVibration = true,
    this.dndEnabled = false,
    TimeOfDay? dndStartTime,
    TimeOfDay? dndEndTime,
    this.themeMode = ThemeMode.dark,
  }) : dndStartTime = dndStartTime ?? const TimeOfDay(hour: 23, minute: 0),
       dndEndTime = dndEndTime ?? const TimeOfDay(hour: 7, minute: 0);

  // SharedPreferences에서 설정 로드
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    return AppSettings(
      checkIntervalSeconds: prefs.getInt('checkIntervalSeconds') ?? 30,
      notificationSound: prefs.getBool('notificationSound') ?? true,
      notificationVibration: prefs.getBool('notificationVibration') ?? true,
      dndEnabled: prefs.getBool('dndEnabled') ?? false,
      dndStartTime: _timeFromMinutes(
        prefs.getInt('dndStartMinutes') ?? 23 * 60,
      ),
      dndEndTime: _timeFromMinutes(prefs.getInt('dndEndMinutes') ?? 7 * 60),
      themeMode: ThemeMode.values[prefs.getInt('themeMode') ?? 0],
    );
  }

  // SharedPreferences에 설정 저장
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('checkIntervalSeconds', checkIntervalSeconds);
    await prefs.setBool('notificationSound', notificationSound);
    await prefs.setBool('notificationVibration', notificationVibration);
    await prefs.setBool('dndEnabled', dndEnabled);
    await prefs.setInt('dndStartMinutes', _timeToMinutes(dndStartTime));
    await prefs.setInt('dndEndMinutes', _timeToMinutes(dndEndTime));
    await prefs.setInt('themeMode', themeMode.index);
  }

  // 현재 시간이 방해 금지 시간대인지 확인
  bool isInDndTime() {
    if (!dndEnabled) return false;

    final now = TimeOfDay.now();
    final nowMinutes = _timeToMinutes(now);
    final startMinutes = _timeToMinutes(dndStartTime);
    final endMinutes = _timeToMinutes(dndEndTime);

    if (startMinutes <= endMinutes) {
      // 같은 날 (예: 09:00 ~ 17:00)
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      // 다음 날로 넘어가는 경우 (예: 23:00 ~ 07:00)
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
  }

  // 모든 설정 초기화
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('checkIntervalSeconds');
    await prefs.remove('notificationSound');
    await prefs.remove('notificationVibration');
    await prefs.remove('dndEnabled');
    await prefs.remove('dndStartMinutes');
    await prefs.remove('dndEndMinutes');
    await prefs.remove('themeMode');
    await prefs.remove('streamers');
  }

  // TimeOfDay -> 분 변환
  static int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  // 분 -> TimeOfDay 변환
  static TimeOfDay _timeFromMinutes(int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }
}
