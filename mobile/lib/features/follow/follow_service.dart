import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowService {
  FollowService._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static final FirebaseAuth _auth =
      FirebaseAuth.instance;

  /// Current user অন্য একজন user-কে follow করবে।
  static Future<void> followUser(String targetUserId) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('User is not logged in.');
    }

    if (currentUser.uid == targetUserId) {
      return;
    }

    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(targetUserId)
        .set({
      'userId': targetUserId,
      'followedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Current user অন্য একজন user-কে unfollow করবে।
  static Future<void> unfollowUser(String targetUserId) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('User is not logged in.');
    }

    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(targetUserId)
        .delete();
  }

  /// Current user এই user-কে follow করছে কি না।
  static Future<bool> isFollowing(String targetUserId) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return false;
    }

    final doc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(targetUserId)
        .get();

    return doc.exists;
  }
}
