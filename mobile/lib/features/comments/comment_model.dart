class CommentModel {
  final String id;
  final String userId;
  final String username;
  final String userPhoto;
  final String text;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.userPhoto,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'userPhoto': userPhoto,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CommentModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return CommentModel(
      id: id,
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'WWC User',
      userPhoto: map['userPhoto'] ?? '',
      text: map['text'] ?? '',
      createdAt: DateTime.tryParse(
            map['createdAt'] ?? '',
          ) ??
          DateTime.now(),
    );
  }
}
