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
    final cleanUserId = userId.trim();

    if (cleanUserId.isEmpty || limit <= 0) {
      return <VideoPost>[];
    }

    try {
      final collection = _firestore.collection('videos');

      final snapshots = await Future.wait([
        collection.where('userId', isEqualTo: cleanUserId).get(),
        collection.where('ownerId', isEqualTo: cleanUserId).get(),
      ]);

      final Map<String, VideoPost> uniqueVideos = {};

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final video = VideoPost.fromMap(doc.id, doc.data());

          if (video.videoUrl.trim().isEmpty) {
            continue;
          }

          uniqueVideos[doc.id] = video;
        }
      }

      final videos = uniqueVideos.values.toList();

      videos.sort((a, b) {
        final dateA = a.createdAt;
        final dateB = b.createdAt;

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        return dateB.compareTo(dateA);
      });

      return videos.take(limit).toList();
    } catch (error) {
      throw ProfileVideoServiceException(
        'প্রোফাইলের ভিডিও লোড করা যায়নি।',
        error,
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
