
class FriendModel {
  final String userId;
  final String username;
  final String displayName;
  final String photoUrl;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;

  const FriendModel({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.photoUrl,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
  });

  factory FriendModel.fromMap(
    String id,
    Map<String, dynamic> data, {
    bool isFollowing = false,
  }) {
    return FriendModel(
      userId: id,
      username: (data['username'] ?? '').toString(),
      displayName: (data['displayName'] ?? '').toString(),
      photoUrl: (data['photoUrl'] ?? data['profileImage'] ?? '').toString(),
      followersCount: _toInt(data['followersCount']),
      followingCount: _toInt(data['followingCount']),
      isFollowing: isFollowing,
    );
  }

  FriendModel copyWith({
    String? userId,
    String? username,
    String? displayName,
    String? photoUrl,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
  }) {
    return FriendModel(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
