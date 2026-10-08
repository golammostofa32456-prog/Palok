import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoViewService {
  VideoViewService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // ============================================================
  // REGISTER VIDEO VIEW
  // ============================================================

  /// Registers one view for the current user.
  ///
  /// The same logged-in user is counted only once per video.
  ///
  /// Returns:
  /// true  = a new view was counted
  /// false = this user already viewed this video
  Future<bool> registerView({
    required String videoId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    if (videoId.trim().isEmpty) {
      return false;
    }

    // Demo videos are local/demo data.
    // They should not modify Firestore.
    if (videoId.startsWith('demo_')) {
      return false;
    }

    final cleanVideoId = videoId.trim();

    final viewedRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('viewedVideos')
        .doc(cleanVideoId);

    final videoRef = _firestore
        .collection('videos')
        .doc(cleanVideoId);

    final viewedDoc = await viewedRef.get();

    // Already counted for this user.
    if (viewedDoc.exists) {
      return false;
    }

    // Make sure the video still exists.
    final videoDoc = await videoRef.get();

    if (!videoDoc.exists) {
      return false;
    }

    // Record the view and increment the video counter.
    final batch = _firestore.batch();

    batch.set(
      viewedRef,
      {
        'videoId': cleanVideoId,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    batch.update(
      videoRef,
      {
        'viewCount': FieldValue.increment(1),
      },
    );

    await batch.commit();

    return true;
  }

  // ============================================================
  // CHECK WHETHER USER HAS VIEWED VIDEO
  // ============================================================

  Future<bool> hasViewed({
    required String videoId,
  }) async {
    final user = _auth.currentUser;

    if (user == null || videoId.trim().isEmpty) {
      return false;
    }

    final viewedDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('viewedVideos')
        .doc(videoId.trim())
        .get();

    return viewedDoc.exists;
  }
}
