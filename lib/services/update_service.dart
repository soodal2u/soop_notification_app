import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    this.forceUpdate = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] ?? '0.0.0',
      buildNumber: json['buildNumber'] ?? 0,
      downloadUrl: json['downloadUrl'] ?? '',
      releaseNotes: json['releaseNotes'] ?? '',
      forceUpdate: json['forceUpdate'] ?? false,
    );
  }
}

class UpdateService {
  static const String _versionUrl =
      'https://raw.githubusercontent.com/soodal2u/soop_notification_app/main/version.json';

  /// GitHub에서 최신 버전 정보 가져오기
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(_versionUrl),
        headers: {'Cache-Control': 'no-cache'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UpdateInfo.fromJson(data);
      }
    } catch (e) {
      print('업데이트 확인 실패: $e');
    }
    return null;
  }

  /// 현재 앱 버전과 비교하여 업데이트 필요 여부 확인
  static Future<bool> isUpdateAvailable() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final updateInfo = await checkForUpdate();
      if (updateInfo == null) return false;

      return updateInfo.buildNumber > currentBuildNumber;
    } catch (e) {
      print('버전 비교 실패: $e');
      return false;
    }
  }

  /// 업데이트 다이얼로그 표시
  static Future<void> showUpdateDialogIfNeeded(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      final currentVersion = packageInfo.version;

      final updateInfo = await checkForUpdate();
      if (updateInfo == null) return;

      if (updateInfo.buildNumber > currentBuildNumber) {
        if (!context.mounted) return;

        showDialog(
          context: context,
          barrierDismissible: !updateInfo.forceUpdate,
          builder: (context) => _UpdateDialog(
            currentVersion: currentVersion,
            updateInfo: updateInfo,
          ),
        );
      }
    } catch (e) {
      print('업데이트 다이얼로그 표시 실패: $e');
    }
  }
}

class _UpdateDialog extends StatelessWidget {
  final String currentVersion;
  final UpdateInfo updateInfo;

  const _UpdateDialog({required this.currentVersion, required this.updateInfo});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00C73C).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.system_update,
              color: Color(0xFF00C73C),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '새 버전 출시!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _VersionBadge(
                  label: '현재',
                  version: currentVersion,
                  color: Colors.grey,
                ),
                const Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                _VersionBadge(
                  label: '최신',
                  version: updateInfo.version,
                  color: const Color(0xFF00C73C),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '업데이트 내용',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            updateInfo.releaseNotes,
            style: const TextStyle(fontSize: 14, color: Colors.white60),
          ),
        ],
      ),
      actions: [
        if (!updateInfo.forceUpdate)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('나중에', style: TextStyle(color: Colors.grey)),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C73C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            final url = Uri.parse(updateInfo.downloadUrl);
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          child: const Text('업데이트'),
        ),
      ],
    );
  }
}

class _VersionBadge extends StatelessWidget {
  final String label;
  final String version;
  final Color color;

  const _VersionBadge({
    required this.label,
    required this.version,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 4),
        Text(
          'v$version',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
