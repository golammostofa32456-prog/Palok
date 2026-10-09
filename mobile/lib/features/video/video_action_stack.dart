class VideoPost {
  final String id;
  final String ownerId;
  final String username;
  final String profileImageUrl;
  final String videoUrl;
  final String caption;
  final List<String> hashtags;
  final String thumbnailUrl;
  final String soundName;

  final int likeCount;
  final int commentCount;
  final int saveCount;
  final int shareCount;
  final int viewCount;
  final DateTime? createdAt;

  const VideoPost({
    required this.id,
    required this.ownerId,
    required this.username,
    this.profileImageUrl = '',
    required this.videoUrl,
    required this.caption,
    required this.hashtags,
    required this.thumbnailUrl,
    required this.soundName,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.shareCount,
    required this.viewCount,
    required this.createdAt,
  });
  

  String get userId => ownerId;

  factory VideoPost.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return VideoPost(
      id: id,
      ownerId: (data['ownerId'] ?? data['userId'] ?? '').toString(),
      username: (data['username'] ?? 'PALOK User').toString(),
      profileImageUrl: (
        data['profileImageUrl'] ??
        data['profileImage'] ??
        data['photoURL'] ??
        data['photoUrl'] ??
        ''
      ).toString(),
      videoUrl: (data['videoUrl'] ?? '').toString(),
      caption: (data['caption'] ?? '').toString(),
      hashtags: _parseHashtags(data['hashtags']),
      thumbnailUrl: (data['thumbnailUrl'] ?? '').toString(),
      soundName: (data['soundName'] ?? '').toString(),
      likeCount: _toInt(data['likeCount']),
      commentCount: _toInt(data['commentCount']),
      saveCount: _toInt(data['saveCount']),
      shareCount: _toInt(data['shareCount']),
      viewCount: _toInt(data['viewCount']),
      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'videoUrl': videoUrl,
      'caption': caption,
      'hashtags': hashtags,
      'thumbnailUrl': thumbnailUrl,
      'soundName': soundName,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'saveCount': saveCount,
      'shareCount': shareCount,
      'viewCount': viewCount,
      'createdAt': createdAt,
    };
  }

  VideoPost copyWith({
    String? id,
    String? ownerId,
    String? username,
    String? profileImageUrl,
    String? videoUrl,
    String? caption,
    List<String>? hashtags,
    String? thumbnailUrl,
    String? soundName,
    int? likeCount,
    int? commentCount,
    int? saveCount,
    int? shareCount,
    int? viewCount,
    DateTime? createdAt,
  }) {
    return VideoPost(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      soundName: soundName ?? this.soundName,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      saveCount: saveCount ?? this.saveCount,
      shareCount: shareCount ?? this.shareCount,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    try {
      if (value.runtimeType.toString().contains('Timestamp')) {
        return value.toDate() as DateTime;
      }
    } catch (_) {}

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static List<String> _parseHashtags(dynamic value) {
    if (value == null) return <String>[];

    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String) {
      return value
          .split(RegExp(r'[\s,]+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return <String>[];
  }
}
