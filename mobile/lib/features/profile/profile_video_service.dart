import 'package:cloud_firestore/cloud_firestore.dart';

import '../video/video_post.dart';

class ProfileVideoService {
  final FirebaseFirestore _firestore;

  ProfileVideoService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<VideoPost>> getUserVideos(
    String userId, {
    int limit = 100,
  }) async {
    final id = userId.trim();

    if (id.isEmpty) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: id)
          .get();

      final videos = snapshot.docs
          .map(
            (doc) => VideoPost.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .where(
            (video) => video.videoUrl.trim().isNotEmpty,
          )
          .toList();

      videos.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate);
      });

      return videos.take(limit).toList();
    } catch (e) {
      throw ProfileVideoServiceException(
        'প্রোফাইলের ভিডিও লোড করা যায়নি।',
        e,
      );
    }
  }
}

class ProfileVideoServiceException implements Exception {
  final String message;
  final Object? originalError;

  const ProfileVideoServiceException(
    this.message, [
    this.originalError,
  ]);

  @override
  String toString() => message;
}
