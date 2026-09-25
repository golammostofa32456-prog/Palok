import 'package:cloud_firestore/cloud_firestore.dart';

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Search users by username or name
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final text = query.trim().toLowerCase();

    if (text.isEmpty) {
      return [];
    }

    final snapshot = await _firestore
        .collection('users')
        .limit(50)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();

          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'username': data['username'] ?? '',
            'photoURL': data['photoURL'] ?? '',
          };
        })
        .where((user) {
          final name = user['name'].toString().toLowerCase();
          final username = user['username'].toString().toLowerCase();

          return name.contains(text) || username.contains(text);
        })
        .toList();
  }

  /// Search videos
  Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    final text = query.trim().toLowerCase();

    if (text.isEmpty) {
      return [];
    }

    final snapshot = await _firestore
        .collection('videos')
        .limit(50)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();

          return {
            'id': doc.id,
            'caption': data['caption'] ?? '',
            'username': data['username'] ?? '',
            'videoUrl': data['videoUrl'] ?? '',
            'thumbnailUrl': data['thumbnailUrl'] ?? '',
          };
        })
        .where((video) {
          final caption = video['caption'].toString().toLowerCase();
          final username = video['username'].toString().toLowerCase();

          return caption.contains(text) || username.contains(text);
        })
        .toList();
  }
}
