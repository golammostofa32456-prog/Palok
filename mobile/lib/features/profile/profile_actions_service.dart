
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileActionsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> isFollowing(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId == targetUserId) {
      return false;
    }

    final doc = await _db
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .get();

    return doc.exists;
  }

  Future<bool> toggleFollow(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      throw Exception('ফলো করতে আগে লগইন করুন');
    }
    if (currentUserId == targetUserId) {
      throw Exception('নিজের প্রোফাইল ফলো করা যাবে না');
    }

    final currentUser = _db.collection('users').doc(currentUserId);
    final targetUser = _db.collection('users').doc(targetUserId);

    final followingRef =
        currentUser.collection('following').doc(targetUserId);
    final followerRef =
        targetUser.collection('followers').doc(currentUserId);

    return _db.runTransaction<bool>((transaction) async {
      final followingSnapshot = await transaction.get(followingRef);
      final currentSnapshot = await transaction.get(currentUser);
      final targetSnapshot = await transaction.get(targetUser);

      if (!targetSnapshot.exists) {
        throw Exception('এই ব্যবহারকারীকে পাওয়া যায়নি');
      }

      final currentData = currentSnapshot.data() ?? <String, dynamic>{};
      final targetData = targetSnapshot.data() ?? <String, dynamic>{};

      final followingCount =
          (currentData['followingCount'] as num?)?.toInt() ?? 0;
      final followersCount =
          (targetData['followersCount'] as num?)?.toInt() ?? 0;

      if (followingSnapshot.exists) {
        transaction.delete(followingRef);
        transaction.delete(followerRef);

        transaction.set(
          currentUser,
          {'followingCount': followingCount > 0 ? followingCount - 1 : 0},
          SetOptions(merge: true),
        );
        transaction.set(
          targetUser,
          {'followersCount': followersCount > 0 ? followersCount - 1 : 0},
          SetOptions(merge: true),
        );

        return false;
      }

      transaction.set(followingRef, {
        'userId': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(followerRef, {
        'userId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        currentUser,
        {'followingCount': followingCount + 1},
        SetOptions(merge: true),
      );
      transaction.set(
        targetUser,
        {'followersCount': followersCount + 1},
        SetOptions(merge: true),
      );

      return true;
    });
  }

  Future<void> createNotification({
    required String recipientUserId,
    required String type,
    required String message,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || recipientUserId == currentUser.uid) return;

    final notificationRef = _db
        .collection('users')
        .doc(recipientUserId)
        .collection('notifications')
        .doc();

    await notificationRef.set({
      'id': notificationRef.id,
      'type': type,
      'message': message,
      'senderId': currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }
}
