class Streamer {
  final String id;
  final String nickname;
  final String? profileImageUrl;
  int? lastBroadNo; // 마지막으로 확인한 방송 번호 (방송 중이 아니면 null 또는 이전 방송 번호)

  // 런타임 전용 (저장되지 않음)
  bool isBroadcasting = false;
  String? broadTitle;
  int? broadNo; // 현재 방송 번호 (런타임)

  Streamer({
    required this.id,
    required this.nickname,
    this.profileImageUrl,
    this.lastBroadNo,
    this.isBroadcasting = false,
    this.broadTitle,
  });

  // JSON -> Object
  factory Streamer.fromJson(Map<String, dynamic> json) {
    return Streamer(
      id: json['id'],
      nickname: json['nickname'],
      profileImageUrl: json['profileImageUrl'],
      lastBroadNo: json['lastBroadNo'],
    );
  }

  // Object -> JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'lastBroadNo': lastBroadNo,
    };
  }
}
