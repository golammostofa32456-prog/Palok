
class VideoPost {
  final String id;
  final String ownerId;
  final String username;
  final String videoUrl;
  final String caption;
  final List<String> hashtags;
  final String thumbnailUrl;
  final String soundName;

  final int likeCount;
  final int commentCount;
  final int saveCount;
  final int shareCount;

  final DateTime? createdAt;

  const VideoPost({
    required this.id,
    required this.ownerId,
    required this.username,
    required this.videoUrl,
    required this.caption,
    required this.hashtags,
    required this.thumbnailUrl,
    required this.soundName,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.shareCount,
    required this.createdAt,
  });

  factory VideoPost.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return VideoPost(
      id: id,
      ownerId: (data['ownerId'] ?? data['userId'] ?? '').toString(),
      username: (data['username'] ?? 'PALOK User').toString(),
      videoUrl: (data['videoUrl'] ?? '').toString(),
      caption: (data['caption'] ?? '').toString(),
      hashtags: _parseHashtags(data['hashtags']),
      thumbnailUrl: (data['thumbnailUrl'] ?? '').toString(),
      soundName: (data['soundName'] ?? '').toString(),

      likeCount: _toInt(data['likeCount']),
      commentCount: _toInt(data['commentCount']),
      saveCount: _toInt(data['saveCount']),
      shareCount: _toInt(data['shareCount']),

      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'username': username,
      'videoUrl': videoUrl,
      'caption': caption,
      'hashtags': hashtags,
      'thumbnailUrl': thumbnailUrl,
      'soundName': soundName,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'saveCount': saveCount,
      'shareCount': shareCount,
      'createdAt': createdAt,
    };
  }

  VideoPost copyWith({
    String? id,
    String? ownerId,
    String? username,
    String? videoUrl,
    String? caption,
    List<String>? hashtags,
    String? thumbnailUrl,
    String? soundName,
    int? likeCount,
    int? commentCount,
    int? saveCount,
    int? shareCount,
    DateTime? createdAt,
  }) {
    return VideoPost(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      username: username ?? this.username,
      videoUrl: videoUrl ?? this.videoUrl,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      soundName: soundName ?? this.soundName,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      saveCount: saveCount ?? this.saveCount,
      shareCount: shareCount ?? this.shareCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    try {
      if (value is dynamic &&
          value.runtimeType.toString().contains('Timestamp')) {
        return value.toDate() as DateTime;
      }
    } catch (_) {}

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static List<String> _parseHashtags(dynamic value) {
    if (value == null) {
      return <String>[];
    }

    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
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
