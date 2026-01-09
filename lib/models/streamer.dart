class Streamer {
  final String id;
  final String nickname;
  final String? profileImageUrl;
  int? lastBroadNo;
  bool notificationEnabled; // 알림 활성화 여부

  // 런타임 전용 (저장되지 않음)
  bool isBroadcasting = false;
  String? broadTitle;
  int? broadNo;

  Streamer({
    required this.id,
    required this.nickname,
    this.profileImageUrl,
    this.lastBroadNo,
    this.notificationEnabled = true,
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
      notificationEnabled: json['notificationEnabled'] ?? true,
    );
  }

  // Object -> JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'lastBroadNo': lastBroadNo,
      'notificationEnabled': notificationEnabled,
    };
  }
}
