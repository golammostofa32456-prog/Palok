import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../inbox/inbox_screen.dart' show InboxNotifier;

/// ফলো / আনফলো (দুই ব্যবহারকারীর সাব-কালেকশন ও কাউন্টার একসাথে আপডেট করে)
class FollowService {
  FollowService._();

  static Future<void> setFollow(String peerId, bool follow) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || peerId.isEmpty || peerId == me.uid) return;

    final db = FirebaseFirestore.instance;
    final myDoc = db.collection('users').doc(me.uid);
    final peerDoc = db.collection('users').doc(peerId);
    final myFollowing = myDoc.collection('following').doc(peerId);
    final theirFollowers = peerDoc.collection('followers').doc(me.uid);

    final peerSnap = await peerDoc.get();
    final mySnap = await myDoc.get();
    final peerCount = peerSnap.data()?['followersCount'];
    final myCount = mySnap.data()?['followingCount'];

    final batch = db.batch();
    if (follow) {
      batch.set(myFollowing, {
        'userId': peerId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(theirFollowers, {
        'userId': me.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (peerCount is int) {
        batch.update(peerDoc, {'followersCount': FieldValue.increment(1)});
      }
      batch.set(
        myDoc,
        {'followingCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    } else {
      batch.delete(myFollowing);
      batch.delete(theirFollowers);
      if (peerCount is int && peerCount > 0) {
        batch.update(peerDoc, {'followersCount': FieldValue.increment(-1)});
      }
      if (myCount is int && myCount > 0) {
        batch.update(myDoc, {'followingCount': FieldValue.increment(-1)});
      }
    }
    await batch.commit();

    if (follow) {
      try {
        await InboxNotifier.send(
          toUserId: peerId,
          type: 'follow',
          text: 'আপনাকে অনুসরণ করা শুরু করেছে',
        );
      } catch (e) {
        debugPrint('Follow notification error: $e');
      }
    }
  }
}
