import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile_model.dart';

class ProfileService {
  final FirebaseFirestore _firestore;

  ProfileService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<ProfileModel?> getProfile(String userId) async {
    final id = userId.trim();

    if (id.isEmpty) {
      return null;
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(id)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return ProfileModel.fromMap(snapshot.id, data);
  }
}
