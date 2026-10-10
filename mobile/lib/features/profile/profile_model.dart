class ProfileModel {
  final String id;
  final String username;
  final String displayName;
  final String profileImageUrl;
  final String bio;
  final int followersCount;
  final int followingCount;
  final int likesCount;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.profileImageUrl,
    required this.bio,
    required this.followersCount,
    required this.followingCount,
    required this.likesCount,
  });

  factory ProfileModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return ProfileModel(
      id: id,
      username: _readString(data, [
        'username',
        'userName',
        'handle',
      ]),
      displayName: _readString(data, [
        'displayName',
        'name',
        'fullName',
        'username',
      ]),
      profileImageUrl: _readString(data, [
        'profileImageUrl',
        'profileImage',
        'photoURL',
        'photoUrl',
      ]),
      bio: _readString(data, ['bio']),
      followersCount: _readInt(data, [
        'followersCount',
        'followers',
      ]),
      followingCount: _readInt(data, [
        'followingCount',
        'following',
      ]),
      likesCount: _readInt(data, [
        'likesCount',
        'totalLikes',
      ]),
    );
  }

  static String _readString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  static int _readInt(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }
}
