import 'dart:convert';
import 'package:http/http.dart' as http;

class BroadcastStatus {
  final bool isBroadcasting;
  final int? broadNo;
  final String? broadTitle;
  final int? viewerCount;
  final String? stationName;
  final String? userNick;
  final String? profileImageUrl;

  BroadcastStatus({
    required this.isBroadcasting,
    this.broadNo,
    this.broadTitle,
    this.viewerCount,
    this.stationName,
    this.userNick,
    this.profileImageUrl,
  });
}

class ApiService {
  static const String _baseUrl = 'https://bjapi.afreecatv.com/api';

  // 방송 정보 조회
  Future<BroadcastStatus?> fetchBroadcastInfo(String channelId) async {
    final url = Uri.parse('$_baseUrl/$channelId/station');

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      print('API Response for $channelId: ${response.statusCode}'); // 디버깅

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 방송국 정보
        final station = data['station'];
        final stationName = station?['station_name'];
        final userNick = station?['user_nick'];

        // 프로필 이미지 (프로토콜이 없는 경우 https 추가)
        String? profileImage = data['profile_image'];
        if (profileImage != null && profileImage.startsWith('//')) {
          profileImage = 'https:$profileImage';
        }

        // 방송 정보
        final broad = data['broad'];

        if (broad != null) {
          // 방송 중
          return BroadcastStatus(
            isBroadcasting: true,
            broadNo: broad['broad_no'],
            broadTitle: broad['broad_title'],
            viewerCount: broad['current_sum_viewer'],
            stationName: stationName,
            userNick: userNick,
            profileImageUrl: profileImage,
          );
        } else {
          // 방송 중 아님
          return BroadcastStatus(
            isBroadcasting: false,
            stationName: stationName,
            userNick: userNick,
            profileImageUrl: profileImage,
          );
        }
      } else {
        print('Failed to load broadcast info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching broadcast info: $e');
      return null;
    }
  }

  // 닉네임으로 방송인 검색 (SOOP 공식 API)
  Future<List<Map<String, String>>> searchByNickname(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse(
      'https://sch.sooplive.co.kr/api.php?m=searchHistory&service=list&d=$encodedQuery&v=3.0',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://www.sooplive.co.kr/',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['suggest_bj'] ?? [];

        return results
            .map<Map<String, String>>((item) {
              String profileImage = item['station_logo']?.toString() ?? '';
              // 프로토콜이 없으면 https 추가
              if (profileImage.isNotEmpty && profileImage.startsWith('//')) {
                profileImage = 'https:$profileImage';
              }

              return {
                'id': item['user_id']?.toString() ?? '',
                'nickname': item['user_nick']?.toString() ?? '',
                'profileImage': profileImage,
              };
            })
            .where((item) => item['id']!.isNotEmpty)
            .toList();
      }
    } catch (e) {
      print('Search error: $e');
    }
    return [];
  }
}
