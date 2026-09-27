import 'package:cloud_firestore/cloud_firestore.dart';

import 'comment_model.dart';

class CommentService {
  final FirebaseFirestore firestore;

  CommentService({
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _commentsRef(
    String videoId,
  ) {
    return firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments');
  }

  Future<List<CommentModel>> getComments(
    String videoId,
  ) async {
    final snapshot = await _commentsRef(videoId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) => CommentModel.fromMap(
            doc.id,
            doc.data(),
          ),
        )
        .toList();
  }

  Future<String> addComment({
    required String videoId,
    required String userId,
    required String username,
    required String userPhoto,
    required String text,
  }) async {
    final commentText = text.trim();

    if (commentText.isEmpty) {
      throw Exception('Comment cannot be empty');
    }

    final doc = await _commentsRef(videoId).add({
      'userId': userId,
      'username': username,
      'userPhoto': userPhoto,
      'text': commentText,
      'createdAt': DateTime.now().toIso8601String(),
    });

    return doc.id;
  }

  Future<void> deleteComment({
    required String videoId,
    required String commentId,
  }) async {
    await _commentsRef(videoId).doc(commentId).delete();
  }
}
