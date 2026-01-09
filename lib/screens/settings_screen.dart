import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:soop_notification_app/models/app_settings.dart';
import 'package:soop_notification_app/services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;

  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings _settings = AppSettings();
  String _appVersion = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await AppSettings.load();
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _settings = settings;
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await _settings.save();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          _buildSectionTitle('모니터링'),
          _buildIntervalSetting(),
          const Divider(),

          _buildSectionTitle('알림'),
          _buildSwitchTile(
            title: '알림 소리',
            subtitle: '알림 시 소리 재생',
            value: _settings.notificationSound,
            onChanged: (value) {
              setState(() => _settings.notificationSound = value);
              _saveSettings();
            },
            icon: Icons.volume_up,
          ),
          _buildSwitchTile(
            title: '진동',
            subtitle: '알림 시 진동',
            value: _settings.notificationVibration,
            onChanged: (value) {
              setState(() => _settings.notificationVibration = value);
              _saveSettings();
            },
            icon: Icons.vibration,
          ),
          const Divider(),

          _buildSectionTitle('방해 금지'),
          _buildSwitchTile(
            title: '방해 금지 모드',
            subtitle: '설정 시간대에 알림 차단',
            value: _settings.dndEnabled,
            onChanged: (value) {
              setState(() => _settings.dndEnabled = value);
              _saveSettings();
            },
            icon: Icons.do_not_disturb,
          ),
          if (_settings.dndEnabled) ...[
            _buildTimePicker(
              title: '시작 시간',
              time: _settings.dndStartTime,
              onChanged: (time) {
                setState(() => _settings.dndStartTime = time);
                _saveSettings();
              },
            ),
            _buildTimePicker(
              title: '종료 시간',
              time: _settings.dndEndTime,
              onChanged: (time) {
                setState(() => _settings.dndEndTime = time);
                _saveSettings();
              },
            ),
          ],
          const Divider(),

          _buildSectionTitle('테마'),
          _buildThemeSetting(),
          const Divider(),

          _buildSectionTitle('정보'),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('업데이트 내역'),
            subtitle: const Text('체인지 로그 보기'),
            onTap: _showChangelog,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('앱 버전'),
            subtitle: Text(_appVersion),
            trailing: TextButton(
              onPressed: _manualCheckForUpdate,
              child: const Text('업데이트 확인'),
            ),
          ),
          const Divider(),

          _buildSectionTitle('데이터'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('데이터 초기화', style: TextStyle(color: Colors.red)),
            subtitle: const Text('모든 설정 및 방송인 목록 삭제'),
            onTap: _confirmReset,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildIntervalSetting() {
    return ListTile(
      leading: const Icon(Icons.timer),
      title: const Text('체크 주기'),
      subtitle: Text('${_settings.checkIntervalSeconds}초마다 방송 상태 확인'),
      trailing: SizedBox(
        width: 150,
        child: Slider(
          value: _settings.checkIntervalSeconds.toDouble(),
          min: 10,
          max: 120,
          divisions: 11,
          label: '${_settings.checkIntervalSeconds}초',
          onChanged: (value) {
            setState(() => _settings.checkIntervalSeconds = value.toInt());
          },
          onChangeEnd: (value) {
            _saveSettings();
          },
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildTimePicker({
    required String title,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 56, right: 16),
      title: Text(title),
      trailing: TextButton(
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time,
          );
          if (picked != null) {
            onChanged(picked);
          }
        },
        child: Text(time.format(context), style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildThemeSetting() {
    return ListTile(
      leading: const Icon(Icons.palette),
      title: const Text('테마'),
      trailing: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.dark, label: Text('다크')),
          ButtonSegment(value: ThemeMode.light, label: Text('라이트')),
          ButtonSegment(value: ThemeMode.system, label: Text('시스템')),
        ],
        selected: {_settings.themeMode},
        onSelectionChanged: (Set<ThemeMode> selected) {
          setState(() => _settings.themeMode = selected.first);
          _saveSettings();
          widget.onThemeChanged(selected.first);
        },
      ),
    );
  }

  Future<void> _showChangelog() async {
    try {
      final jsonString = await rootBundle.loadString('assets/changelog.json');
      final List<dynamic> changelog = jsonDecode(jsonString);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      '업데이트 내역',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: changelog.length,
                  itemBuilder: (context, index) {
                    final entry = changelog[index];
                    final version = entry['version'];
                    final date = entry['date'];
                    final changes = List<String>.from(entry['changes']);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'v$version',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  date,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...changes.map(
                              (change) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '• ',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Expanded(child: Text(change)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('체인지 로그를 불러오는데 실패했습니다.')));
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text('모든 설정과 등록된 방송인 목록이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppSettings.resetAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 데이터가 초기화되었습니다.')));
      Navigator.pop(context, true); // 홈으로 돌아가기
    }
  }

  Future<void> _manualCheckForUpdate() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final isAvailable = await UpdateService.isUpdateAvailable();

    if (!mounted) return;

    if (isAvailable) {
      await UpdateService.showUpdateDialogIfNeeded(context);
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('현재 최신 버전을 사용 중입니다.')),
      );
    }
  }
}
