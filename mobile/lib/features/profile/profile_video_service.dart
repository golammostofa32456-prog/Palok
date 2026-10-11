
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../video/video_post.dart';

class ProfileVideoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<VideoPost>> getUserVideos(String userId) async {
    if (userId.trim().isEmpty) {
      return [];
    }

    final snapshot = await _db
        .collection('videos')
        .where('userId', isEqualTo: userId)
        .get();

    final videos = snapshot.docs.map((doc) {
      final data = doc.data();

      return VideoPost(
        id: doc.id,
        videoUrl: (data['videoUrl'] ?? '').toString(),
        userId: (data['userId'] ?? userId).toString(),
        username: (data['username'] ?? 'PALOK User').toString(),
        caption: (data['caption'] ?? '').toString(),
        hashtags: _hashtagsToString(data['hashtags']),
        likeCount: _toInt(data['likeCount']),
        commentCount: _toInt(data['commentCount']),
        saveCount: _toInt(data['saveCount']),
        shareCount: _toInt(data['shareCount']),
        thumbnailUrl: (data['thumbnailUrl'] ?? '').toString(),
        viewCount: _toInt(data['viewCount']),
      );
    }).where((video) => video.videoUrl.trim().isNotEmpty).toList();

    videos.sort((a, b) {
      return b.videoUrl.compareTo(a.videoUrl);
    });

    return videos;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _hashtagsToString(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).join(' ');
    }
    return value?.toString() ?? '';
  }
}
