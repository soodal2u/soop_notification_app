import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:soop_notification_app/models/streamer.dart';
import 'package:soop_notification_app/services/api_service.dart';
import 'package:soop_notification_app/services/update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
    // 30초마다 상태 업데이트
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateBroadcastStatus();
    });
  }

  // 앱 업데이트 확인
  Future<void> _checkForUpdates() async {
    // 약간의 딜레이 후 업데이트 확인 (UI 로딩 후)
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

  // 저장된 방송인 목록 불러오기
  Future<void> _loadStreamers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? streamersJson = prefs.getString('streamers');
    if (streamersJson != null) {
      List<dynamic> decoded = jsonDecode(streamersJson);
      setState(() {
        _streamers = decoded.map((e) => Streamer.fromJson(e)).toList();
      });
      // 실시간 상태 업데이트
      _updateBroadcastStatus();
    }
  }

  // 방송인들의 실시간 상태 업데이트
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

  // 방송인 목록 저장
  Future<void> _saveStreamers() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _streamers.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('streamers', encoded);
  }

  // 서비스 상태 확인
  Future<void> _checkServiceStatus() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    setState(() {
      _isServiceRunning = isRunning;
    });
  }

  // 서비스 토글
  Future<void> _toggleService(bool value) async {
    final service = FlutterBackgroundService();
    if (value) {
      await service.startService();
    } else {
      service.invoke('stopService');
    }

    // 상태 반영을 위해 잠시 대기
    await Future.delayed(const Duration(milliseconds: 500));
    _checkServiceStatus();
  }

  // 방송인 추가
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
    // 중복 체크
    if (_streamers.any((s) => s.id == id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 추가된 방송인입니다.')));
      return;
    }

    // 닉네임 가져오기
    try {
      final info = await _apiService.fetchBroadcastInfo(id);
      // 방송 중이 아니어도 방송국 정보는 옴 (BroadCastStatus가 null이 아닐 수 있음)
      // fetchBroadcastInfo가 200 OK면 정보를 줌.
      // 닉네임이 없으면 알 수 없음 처리

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

  // 방송인 삭제
  Future<void> _removeStreamer(String id) async {
    setState(() {
      _streamers.removeWhere((s) => s.id == id);
    });
    await _saveStreamers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOOP Monitoring'),
        actions: [
          // 서비스 상태 표시 (텍스트 + 스위치)
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
                    '등록된 방송인이 없습니다.\n우측 하단 버튼을 눌러 추가해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _streamers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final streamer = _streamers[index];
                return _buildStreamerCard(streamer);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addStreamer,
        backgroundColor: const Color(0xFF00C73C),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStreamerCard(Streamer streamer) {
    // 방송 상태에 따른 색상
    final statusColor = streamer.isBroadcasting
        ? const Color(0xFF00C73C) // 방송 중: 초록색
        : Colors.grey; // 오프라인: 회색

    return Container(
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
            // 방송 중이면 라이브 방송으로, 아니면 프로필로 이동
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
                // 프로필 이미지 + 상태 링
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

                // 삭제 버튼
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.grey[600]),
                  onPressed: () => _removeStreamer(streamer.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
