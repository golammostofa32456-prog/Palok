import 'package:cloud_firestore/cloud_firestore.dart';

import 'video_post.dart';

class VideoService {
  final FirebaseFirestore _firestore;

  VideoService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<VideoPost>> getVideos({
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
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
    } catch (e) {
      throw VideoServiceException(
        'ভিডিও লোড করা যায়নি।',
        e,
      );
    }
  }

  Future<VideoPost?> getVideoById(String videoId) async {
    try {
      final doc = await _firestore
          .collection('videos')
          .doc(videoId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final video = VideoPost.fromMap(
        doc.id,
        doc.data()!,
      );

      if (video.videoUrl.trim().isEmpty) {
        return null;
      }

      return video;
    } catch (e) {
      throw VideoServiceException(
        'ভিডিও পাওয়া যায়নি।',
        e,
      );
    }
  }

  Stream<List<VideoPost>> watchVideos({
    int limit = 50,
  }) {
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => VideoPost.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .where(
                (video) => video.videoUrl.trim().isNotEmpty,
              )
              .toList(),
        );
  }
}

class VideoServiceException implements Exception {
  final String message;
  final Object? originalError;

  const VideoServiceException(
    this.message, [
    this.originalError,
  ]);

  @override
  String toString() {
    return message;
  }
}
