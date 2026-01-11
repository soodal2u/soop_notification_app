import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BatteryOptimizationService {
  static const platform = MethodChannel('com.example.soop_notification_app/battery');

  /// 배터리 최적화가 비활성화되어 있는지 확인
  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final bool result = await platform.invokeMethod('isBatteryOptimizationDisabled');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to check battery optimization: '${e.message}'.");
      return false;
    }
  }

  /// 배터리 최적화 비활성화 요청
  static Future<void> requestBatteryOptimization() async {
    try {
      await platform.invokeMethod('requestBatteryOptimization');
    } on PlatformException catch (e) {
      debugPrint("Failed to request battery optimization: '${e.message}'.");
    }
  }
}
