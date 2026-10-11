
import 'package:cloud_firestore/cloud_firestore.dart';

import '../video/video_post.dart';

class ProfileVideoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<VideoPost>> getUserVideos(String userId) async {
    if (userId.trim().isEmpty) {
      return <VideoPost>[];
    }

    final snapshot = await _db
        .collection('videos')
        .where('userId', isEqualTo: userId)
        .get();

    final videos = snapshot.docs
        .map((doc) => VideoPost.fromMap(doc.id, doc.data()))
        .where((video) => video.videoUrl.trim().isNotEmpty)
        .toList();

    videos.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return videos;
  }
}
