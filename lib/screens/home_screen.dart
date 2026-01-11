import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:soop_notification_app/models/streamer.dart';
import 'package:soop_notification_app/services/api_service.dart';
import 'package:soop_notification_app/services/update_service.dart';
import 'package:soop_notification_app/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeChanged;

  const HomeScreen({super.key, this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Streamer> _streamers = [];
  bool _isServiceRunning = false;
  final ApiService _apiService = ApiService();
  Timer? _statusUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadStreamers();
    _checkServiceStatus();
    _checkForUpdates();
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateBroadcastStatus();
    });
  }

  Future<void> _checkForUpdates() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      UpdateService.showUpdateDialogIfNeeded(context);
    }
  }

  @override
  void dispose() {
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStreamers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? streamersJson = prefs.getString('streamers');
    if (streamersJson != null) {
      List<dynamic> decoded = jsonDecode(streamersJson);
      setState(() {
        _streamers = decoded.map((e) => Streamer.fromJson(e)).toList();
      });
      _updateBroadcastStatus();
    }
  }

  Future<void> _updateBroadcastStatus() async {
    for (var streamer in _streamers) {
      final status = await _apiService.fetchBroadcastInfo(streamer.id);
      if (status != null) {
        streamer.isBroadcasting = status.isBroadcasting;
        streamer.broadTitle = status.broadTitle;
        streamer.broadNo = status.broadNo;
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveStreamers() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _streamers.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('streamers', encoded);
  }

  Future<void> _checkServiceStatus() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    setState(() {
      _isServiceRunning = isRunning;
    });
  }

  Future<void> _toggleService(bool value) async {
    final service = FlutterBackgroundService();
    final prefs = await SharedPreferences.getInstance();
    
    if (value) {
      await service.startService();
      await prefs.setBool('service_running', true);
    } else {
      service.invoke('stopService');
      await prefs.setBool('service_running', false);
    }
    await Future.delayed(const Duration(milliseconds: 500));
    _checkServiceStatus();
  }

  Future<void> _addStreamer() async {
    String inputQuery = "";
    List<Map<String, String>> searchResults = [];
    bool isSearching = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('방송인 추가'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: '아이디 또는 닉네임 입력',
                    labelText: 'ID / 닉네임',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) async {
                    inputQuery = value.trim();
                    if (inputQuery.length >= 2) {
                      setDialogState(() => isSearching = true);
                      final results = await _apiService.searchByNickname(
                        inputQuery,
                      );
                      setDialogState(() {
                        searchResults = results;
                        isSearching = false;
                      });
                    } else {
                      setDialogState(() => searchResults = []);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (isSearching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  )
                else if (searchResults.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final result = searchResults[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: result['profileImage']!.isNotEmpty
                                ? NetworkImage(result['profileImage']!)
                                : null,
                            child: result['profileImage']!.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(result['nickname'] ?? ''),
                          subtitle: Text(result['id'] ?? ''),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            _fetchAndAddStreamer(result['id']!);
                          },
                        );
                      },
                    ),
                  )
                else if (inputQuery.isNotEmpty && inputQuery.length >= 2)
                  const Text(
                    '검색 결과가 없습니다.\n아이디로 직접 추가해보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                if (inputQuery.isEmpty) return;
                Navigator.pop(dialogContext);
                await _fetchAndAddStreamer(inputQuery);
              },
              child: const Text('ID로 추가'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchAndAddStreamer(String id) async {
    if (_streamers.any((s) => s.id == id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 추가된 방송인입니다.')));
      return;
    }

    try {
      final info = await _apiService.fetchBroadcastInfo(id);
      final nickname = info?.userNick ?? id;
      final profileImage = info?.profileImageUrl;

      final newStreamer = Streamer(
        id: id,
        nickname: nickname,
        profileImageUrl: profileImage,
      );

      if (!mounted) return;

      setState(() {
        _streamers.add(newStreamer);
      });
      await _saveStreamers();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$nickname($id) 추가 완료')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('방송인 정보를 가져오는데 실패했습니다.')));
    }
  }

  Future<void> _removeStreamer(String id) async {
    setState(() {
      _streamers.removeWhere((s) => s.id == id);
    });
    await _saveStreamers();
  }

  void _toggleNotification(Streamer streamer) {
    setState(() {
      streamer.notificationEnabled = !streamer.notificationEnabled;
    });
    _saveStreamers();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          streamer.notificationEnabled
              ? '${streamer.nickname} 알림이 활성화되었습니다.'
              : '${streamer.nickname} 알림이 비활성화되었습니다.',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _streamers.removeAt(oldIndex);
      _streamers.insert(newIndex, item);
    });
    _saveStreamers();
  }

  void _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SettingsScreen(onThemeChanged: widget.onThemeChanged ?? (theme) {}),
      ),
    );

    if (result == true) {
      setState(() {
        _streamers = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.person_add),
          onPressed: _addStreamer,
          tooltip: '방송인 추가',
        ),
        title: const Text('SOOP Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
          Row(
            children: [
              Text(
                _isServiceRunning ? 'ON' : 'OFF',
                style: TextStyle(
                  color: _isServiceRunning
                      ? const Color(0xFF00C73C)
                      : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: _isServiceRunning,
                onChanged: _toggleService,
                activeThumbColor: const Color(0xFF00C73C),
                activeTrackColor: const Color(0xFF00C73C).withAlpha(77),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withAlpha(77),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: _streamers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tv_off, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  const Text(
                    '등록된 방송인이 없습니다.\n좌측 상단 버튼을 눌러 추가해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _streamers.length,
              onReorder: _onReorder,
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final streamer = _streamers[index];
                return Padding(
                  key: ValueKey(streamer.id),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildStreamerCard(streamer, index),
                );
              },
            ),
    );
  }

  Widget _buildStreamerCard(Streamer streamer, int index) {
    final statusColor = streamer.isBroadcasting
        ? const Color(0xFF00C73C)
        : Colors.grey;

    return Slidable(
      // 왼쪽 → 오른쪽 스와이프: 삭제 (빨간색 배경)
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        dismissible: DismissiblePane(
          onDismissed: () => _removeStreamer(streamer.id),
        ),
        children: [
          SlidableAction(
            onPressed: (_) => _removeStreamer(streamer.id),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: '삭제',
            borderRadius: BorderRadius.circular(16),
          ),
        ],
      ),
      // 오른쪽 → 왼쪽 스와이프: 알림 설정
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (_) => _toggleNotification(streamer),
            backgroundColor: streamer.notificationEnabled
                ? Colors.orange
                : const Color(0xFF00C73C),
            foregroundColor: Colors.white,
            icon: streamer.notificationEnabled
                ? Icons.notifications_off
                : Icons.notifications_active,
            label: streamer.notificationEnabled ? '알림 끄기' : '알림 켜기',
            borderRadius: BorderRadius.circular(16),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white.withAlpha(13)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final String urlStr =
                  streamer.isBroadcasting && streamer.broadNo != null
                  ? 'https://play.sooplive.co.kr/${streamer.id}/${streamer.broadNo}'
                  : 'https://sooplive.co.kr/${streamer.id}';
              final url = Uri.parse(urlStr);
              try {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } catch (e) {
                print('Failed to open URL: $e');
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 프로필 이미지
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: statusColor, width: 2),
                      boxShadow: streamer.isBroadcasting
                          ? [
                              BoxShadow(
                                color: statusColor.withAlpha(77),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: streamer.profileImageUrl != null
                          ? NetworkImage(streamer.profileImageUrl!)
                          : null,
                      child: streamer.profileImageUrl == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 정보 텍스트
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              streamer.nickname,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (!streamer.notificationEnabled) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.notifications_off,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                            ],
                            if (streamer.isBroadcasting) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C73C),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          streamer.isBroadcasting && streamer.broadTitle != null
                              ? streamer.broadTitle!
                              : streamer.id,
                          style: TextStyle(
                            color: streamer.isBroadcasting
                                ? Colors.grey[300]
                                : Colors.grey[400],
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // 드래그 핸들
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(Icons.drag_handle, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
