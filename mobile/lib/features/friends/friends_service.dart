import 'package:cloud_firestore/cloud_firestore.dart';

import 'friend_model.dart';

class FriendsService {
  FriendsService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ============================================================
  // SUGGESTED CREATORS
  // ============================================================

  Future<List<FriendModel>> getSuggestedCreators({
    required String currentUserId,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .limit(100)
        .get();

    final creators = <FriendModel>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      // --------------------------------------------------------
      // User ID
      // --------------------------------------------------------
      final userId = _firstNonEmpty([
        data['uid'],
        data['userId'],
        doc.id,
      ]);

      // নিজের account বাদ
      if (userId == currentUserId ||
          doc.id == currentUserId) {
        continue;
      }

      // --------------------------------------------------------
      // Username
      // --------------------------------------------------------
      final username = _firstNonEmpty([
        data['username'],
        data['userName'],
        data['handle'],
      ]);

      // --------------------------------------------------------
      // Display name
      // --------------------------------------------------------
      String displayName = _firstNonEmpty([
        data['displayName'],
        data['name'],
        data['fullName'],
        data['display_name'],
      ]);

      // --------------------------------------------------------
      // Email fallback
      // --------------------------------------------------------
      final email = _firstNonEmpty([
        data['email'],
      ]);

      if (displayName.isEmpty && email.isNotEmpty) {
        final emailName = email.split('@').first.trim();

        if (emailName.isNotEmpty) {
          displayName = emailName;
        }
      }

      // --------------------------------------------------------
      // Photo
      // --------------------------------------------------------
      final photoUrl = _firstNonEmpty([
        data['photoUrl'],
        data['profileImage'],
        data['profileImageUrl'],
        data['avatarUrl'],
        data['imageUrl'],
        data['photoURL'],
      ]);

      // --------------------------------------------------------
      // Completely empty user document বাদ
      // --------------------------------------------------------
      if (username.isEmpty &&
          displayName.isEmpty &&
          photoUrl.isEmpty &&
          email.isEmpty) {
        continue;
      }

      // FriendModel-এর expected fields normalize করছি।
      final normalizedData = <String, dynamic>{
        ...data,
        'uid': userId,
        'username': username,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'profileImage': photoUrl,
      };

      creators.add(
        FriendModel.fromMap(
          doc.id,
          normalizedData,
          isFollowing: false,
        ),
      );
    }

    return creators;
  }

  // ============================================================
  // FOLLOWING
  // ============================================================

  Future<List<FriendModel>> getFollowing({
    required String currentUserId,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .get();

    final following = <FriendModel>[];

    for (final doc in snapshot.docs) {
      final userId = doc.id;

      if (userId.isEmpty || userId == currentUserId) {
        continue;
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        continue;
      }

      final data = userDoc.data() ?? {};

      final username = _firstNonEmpty([
        data['username'],
        data['userName'],
        data['handle'],
      ]);

      String displayName = _firstNonEmpty([
        data['displayName'],
        data['name'],
        data['fullName'],
        data['display_name'],
      ]);

      final email = _firstNonEmpty([
        data['email'],
      ]);

      if (displayName.isEmpty && email.isNotEmpty) {
        displayName = email.split('@').first.trim();
      }

      final photoUrl = _firstNonEmpty([
        data['photoUrl'],
        data['profileImage'],
        data['profileImageUrl'],
        data['avatarUrl'],
        data['imageUrl'],
        data['photoURL'],
      ]);

      if (username.isEmpty &&
          displayName.isEmpty &&
          photoUrl.isEmpty &&
          email.isEmpty) {
        continue;
      }

      final normalizedData = <String, dynamic>{
        ...data,
        'uid': userId,
        'username': username,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'profileImage': photoUrl,
      };

      following.add(
        FriendModel.fromMap(
          userDoc.id,
          normalizedData,
          isFollowing: true,
        ),
      );
    }

    return following;
  }

  // ============================================================
  // FOLLOW / UNFOLLOW
  // ============================================================

  Future<void> toggleFollow({
    required String currentUserId,
    required FriendModel friend,
  }) async {
    if (currentUserId.isEmpty ||
        friend.userId.isEmpty ||
        currentUserId == friend.userId) {
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

  // ============================================================
  // HELPER
  // ============================================================

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) {
        continue;
      }

      final text = value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }
}
