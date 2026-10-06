import 'package:cloud_firestore/cloud_firestore.dart';

import 'friend_model.dart';

class FriendsService {
  FriendsService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<FriendModel>> getSuggestedCreators({
    required String currentUserId,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .limit(50)
        .get();

    final creators = <FriendModel>[];

    for (final doc in snapshot.docs) {
      if (doc.id == currentUserId) {
        continue;
      }

      final data = doc.data();

      // Empty / incomplete user document বাদ
      final username = (data['username'] ?? '').toString().trim();
      final displayName = (data['displayName'] ?? data['name'] ?? '')
          .toString()
          .trim();
      final profileImage = (data['profileImage'] ?? '').toString().trim();

      if (username.isEmpty &&
          displayName.isEmpty &&
          profileImage.isEmpty) {
        continue;
      }

      creators.add(
        FriendModel.fromMap(
          doc.id,
          data,
          isFollowing: false,
        ),
      );
    }

    return creators;
  }

  Future<List<FriendModel>> getFollowing({
    required String currentUserId,
  }) async {
    final followingSnapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .get();

    final following = <FriendModel>[];

    for (final followingDoc in followingSnapshot.docs) {
      final userId = followingDoc.id;

      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        continue;
      }

      final data = userDoc.data() ?? {};

      final username = (data['username'] ?? '').toString().trim();
      final displayName = (data['displayName'] ?? data['name'] ?? '')
          .toString()
          .trim();
      final profileImage = (data['profileImage'] ?? '').toString().trim();

      if (username.isEmpty &&
          displayName.isEmpty &&
          profileImage.isEmpty) {
        continue;
      }

      following.add(
        FriendModel.fromMap(
          userDoc.id,
          data,
          isFollowing: true,
        ),
      );
    }

    return following;
  }

  Future<void> toggleFollow({
    required String currentUserId,
    required FriendModel friend,
  }) async {
    if (currentUserId.isEmpty || friend.userId.isEmpty) {
      return;
    }

    if (currentUserId == friend.userId) {
      return;
    }

    final followingRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(friend.userId);

    final followerRef = _firestore
        .collection('users')
        .doc(friend.userId)
        .collection('followers')
        .doc(currentUserId);

    final batch = _firestore.batch();

    if (friend.isFollowing) {
      batch.delete(followingRef);
      batch.delete(followerRef);
    } else {
      batch.set(
        followingRef,
        {
          'userId': friend.userId,
          'username': friend.username,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      batch.set(
        followerRef,
        {
          'userId': currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();
  }
}
