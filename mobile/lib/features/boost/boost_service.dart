
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'boost_model.dart';

class BoostService {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  BoostService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _boosts =>
      firestore.collection('boosts');

  String? get currentUserId => auth.currentUser?.uid;

  Future<String> createBoost({
    required String videoId,
    required int budget,
    required int durationDays,
  }) async {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('LOGIN_REQUIRED');
    }

    if (videoId.trim().isEmpty) {
      throw Exception('VIDEO_ID_REQUIRED');
    }

    if (budget <= 0) {
      throw Exception('INVALID_BUDGET');
    }

    if (durationDays <= 0) {
      throw Exception('INVALID_DURATION');
    }

    final doc = _boosts.doc();

    final data = <String, dynamic>{
      'userId': user.uid,
      'videoId': videoId,
      'status': 'pending',
      'budget': budget,
      'durationDays': durationDays,
      'impressions': 0,
      'clicks': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'startAt': null,
      'endAt': null,
    };

    await doc.set(data);

    return doc.id;
  }

  Future<BoostModel?> getBoost(String boostId) async {
    final snapshot = await _boosts.doc(boostId).get();

    if (!snapshot.exists) {
      return null;
    }

    return BoostModel.fromMap(
      snapshot.id,
      snapshot.data() ?? {},
    );
  }

  Stream<List<BoostModel>> watchMyBoosts() {
    final user = auth.currentUser;

    if (user == null) {
      return Stream.value(<BoostModel>[]);
    }

    return _boosts
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) {
            return snapshot.docs
                .map(
                  (doc) => BoostModel.fromMap(
                    doc.id,
                    doc.data(),
                  ),
                )
                .toList();
          },
        );
  }

  Future<List<BoostModel>> getMyBoosts() async {
    final user = auth.currentUser;

    if (user == null) {
      return <BoostModel>[];
    }

    final snapshot = await _boosts
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) => BoostModel.fromMap(
            doc.id,
            doc.data(),
          ),
        )
        .toList();
  }

  Future<void> cancelBoost(String boostId) async {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('LOGIN_REQUIRED');
    }

    final doc = await _boosts.doc(boostId).get();

    if (!doc.exists) {
      throw Exception('BOOST_NOT_FOUND');
    }

    final data = doc.data() ?? {};

    if (data['userId'] != user.uid) {
      throw Exception('NOT_AUTHORIZED');
    }

    final status = (data['status'] ?? '').toString();

    if (status == 'completed' || status == 'cancelled') {
      return;
    }

    await _boosts.doc(boostId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBoostStatus({
    required String boostId,
    required String status,
  }) async {
    const allowedStatuses = <String>{
      'pending',
      'approved',
      'active',
      'completed',
      'cancelled',
      'rejected',
    };

    if (!allowedStatuses.contains(status)) {
      throw Exception('INVALID_STATUS');
    }

    await _boosts.doc(boostId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementImpressions(String boostId) async {
    await _boosts.doc(boostId).update({
      'impressions': FieldValue.increment(1),
    });
  }

  Future<void> incrementClicks(String boostId) async {
    await _boosts.doc(boostId).update({
      'clicks': FieldValue.increment(1),
    });
  }
}
