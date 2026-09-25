class SearchResult {
  final String id;
  final String username;
  final String name;
  final String? photoUrl;
  final String type;

  SearchResult({
    required this.id,
    required this.username,
    required this.name,
    this.photoUrl,
    required this.type,
  });

  factory SearchResult.fromMap(Map<String, dynamic> map) {
    return SearchResult(
      id: map['id']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      photoUrl: map['photoUrl']?.toString(),
      type: map['type']?.toString() ?? 'user',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'photoUrl': photoUrl,
      'type': type,
    };
  }
}
