
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

class VideoInteractionService {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  VideoInteractionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance;

  /// Like / Unlike a video.
  ///
  /// Returns:
  /// true  = video is now liked
  /// false = video is now unliked
  Future<bool> toggleLike({
    required String videoId,
    required String videoOwnerId,
    required String currentUsername,
  }) async {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('LOGIN_REQUIRED');
    }

    final likeRef = firestore
        .collection('users')
        .doc(user.uid)
        .collection('likedVideos')
        .doc(videoId);

    final videoRef = firestore
        .collection('videos')
        .doc(videoId);

    final likeDoc = await likeRef.get();
    final isLiked = likeDoc.exists;

    if (isLiked) {
      await likeRef.delete();

      if (!videoId.startsWith('demo_')) {
        await videoRef.set(
          {
            'likeCount': FieldValue.increment(-1),
          },
          SetOptions(merge: true),
        );
      }

      return false;
    }

    await likeRef.set({
      'videoId': videoId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!videoId.startsWith('demo_')) {
      await videoRef.set(
        {
          'likeCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    }

    // Send notification to video owner.
    if (videoOwnerId.isNotEmpty &&
        videoOwnerId != user.uid) {
      try {
        await firestore
            .collection('users')
            .doc(videoOwnerId)
            .collection('notifications')
            .add({
          'type': 'like',
          'fromUserId': user.uid,
          'fromUsername': currentUsername,
          'text': 'তোমার ভিডিওটি Like করেছে',
          'videoId': videoId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Notification failure should not cancel the Like.
      }
    }

    return true;
  }

  /// Save / Unsave a video.
  ///
  /// Returns:
  /// true  = video is now saved
  /// false = video is now unsaved
  Future<bool> toggleSave({
    required String videoId,
  }) async {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('LOGIN_REQUIRED');
    }

    final saveRef = firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedVideos')
        .doc(videoId);

    final videoRef = firestore
        .collection('videos')
        .doc(videoId);

    final saveDoc = await saveRef.get();
    final isSaved = saveDoc.exists;

    if (isSaved) {
      await saveRef.delete();

      if (!videoId.startsWith('demo_')) {
        await videoRef.set(
          {
            'saveCount': FieldValue.increment(-1),
          },
          SetOptions(merge: true),
        );
      }

      return false;
    }

    await saveRef.set({
      'videoId': videoId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!videoId.startsWith('demo_')) {
      await videoRef.set(
        {
          'saveCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    }

    return true;
  }

  /// Share a video.
  ///
  /// The share counter is updated only after
  /// Share Plus successfully starts the share action.
  Future<void> shareVideo({
    required String videoId,
  }) async {
    final link = 'https://palok.app/video/$videoId';

    final text = 'Watch this video on PALOK\n\n$link';

    await Share.share(text);

    if (videoId.startsWith('demo_')) {
      return;
    }

    try {
      await firestore
          .collection('videos')
          .doc(videoId)
          .set(
        {
          'shareCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Share already happened.
      // Counter failure should not cancel the share.
    }

    final user = auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      await firestore
          .collection('videos')
          .doc(videoId)
          .collection('shares')
          .add({
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Share record failure should not cancel the share.
    }
  }
}
