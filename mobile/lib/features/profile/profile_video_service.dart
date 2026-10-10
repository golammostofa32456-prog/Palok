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

    if (id.isEmpty) return [];

    try {
      final collection = _firestore.collection('videos');

      final results = await Future.wait([
        collection.where('userId', isEqualTo: id).get(),
        collection.where('ownerId', isEqualTo: id).get(),
      ]);

      final byId = <String, VideoPost>{};

      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          final video = VideoPost.fromMap(doc.id, doc.data());

          if (video.videoUrl.trim().isNotEmpty) {
            byId[doc.id] = video;
          }
        }
      }

      final videos = byId.values.toList()
        ..sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
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

  const ProfileVideoServiceException(this.message, [this.originalError]);

  @override
  String toString() => message;
}
