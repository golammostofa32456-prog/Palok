import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static Future<void> ensureUserProfile(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);

    final snapshot = await ref.get();

    if (snapshot.exists) {
      return;
    }

    final email = user.email ?? '';
    final displayName = user.displayName?.trim() ?? '';

    String username;

    if (displayName.isNotEmpty) {
      username = _makeUsername(displayName);
    } else if (email.isNotEmpty) {
      username = _makeUsername(email.split('@').first);
    } else {
      username = 'palok_user_${user.uid.substring(0, 6)}';
    }

    await ref.set({
      'uid': user.uid,
      'name': displayName,
      'displayName': displayName,
      'username': username,
      'bio': '',
      'email': email,
      'profileImage': user.photoURL ?? '',
      'followersCount': 0,
      'followingCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static String _makeUsername(String value) {
    var username = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._]'), '');

    if (username.isEmpty) {
      username = 'palok_user';
    }

    if (username.length > 20) {
      username = username.substring(0, 20);
    }

    return username;
  }
}
