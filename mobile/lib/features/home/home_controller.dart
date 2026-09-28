import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../video/video_post.dart';
import '../video/video_service.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    VideoService? videoService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _videoService = videoService ?? VideoService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final VideoService _videoService;

  // ============================================================
  // FEED
  // ============================================================

  final List<VideoPost> _videos = [];

  List<VideoPost> get videos => List.unmodifiable(_videos);

  bool _loading = false;

  bool get loading => _loading;

  String? _error;

  String? get error => _error;

  // ============================================================
  // VIDEO CONTROLLERS
  // ============================================================

  final Map<int, VideoPlayerController> _controllers = {};

  VideoPlayerController? controllerFor(int index) {
    return _controllers[index];
  }

  // ============================================================
  // CURRENT VIDEO
  // ============================================================

  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  // ============================================================
  // USER STATES
  // ============================================================

  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  final Set<String> _followingIds = {};

  bool isLiked(String videoId) {
    return _likedIds.contains(videoId);
  }

  bool isSaved(String videoId) {
    return _savedIds.contains(videoId);
  }

  bool isFollowing(String userId) {
    return _followingIds.contains(userId);
  }

  // ============================================================
  // LOCAL COUNT DELTAS
  // ============================================================

  final Map<String, int> _likeDeltas = {};
  final Map<String, int> _saveDeltas = {};
  final Map<String, int> _commentDeltas = {};
  final Map<String, int> _shareDeltas = {};

  int likeCount(VideoPost video) {
    return _safeCount(
      video.likeCount + (_likeDeltas[video.id] ?? 0),
    );
  }

  int saveCount(VideoPost video) {
    return _safeCount(
      video.saveCount + (_saveDeltas[video.id] ?? 0),
    );
  }

  int commentCount(VideoPost video) {
    return _safeCount(
      video.commentCount + (_commentDeltas[video.id] ?? 0),
    );
  }

  int shareCount(VideoPost video) {
    return _safeCount(
      video.shareCount + (_shareDeltas[video.id] ?? 0),
    );
  }

  int _safeCount(int value) {
    return value < 0 ? 0 : value;
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> load() async {
    if (_loading) return;

    _loading = true;
    _error = null;

    notifyListeners();

    try {
      final loadedVideos = await _videoService.getVideos();

      _videos
        ..clear()
        ..addAll(loadedVideos);

      await _loadUserData();

      if (_videos.isNotEmpty) {
        await prepareVideo(0);
      }
    } catch (e) {
      _error = e.toString();

      debugPrint('Home load error: $e');
    } finally {
      _loading = false;

      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await disposeControllers();

    _videos.clear();

    _likeDeltas.clear();
    _saveDeltas.clear();
    _commentDeltas.clear();
    _shareDeltas.clear();

    _currentIndex = 0;

    notifyListeners();

    await load();
  }

  // ============================================================
  // USER DATA
  // ============================================================

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final results = await Future.wait([
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('likedVideos')
            .get(),

        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('savedVideos')
            .get(),

        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('following')
            .get(),
      ]);

      _likedIds
        ..clear()
        ..addAll(
          results[0].docs.map((doc) => doc.id),
        );

      _savedIds
        ..clear()
        ..addAll(
          results[1].docs.map((doc) => doc.id),
        );

      _followingIds
        ..clear()
        ..addAll(
          results[2].docs.map((doc) => doc.id),
        );
    } catch (e) {
      debugPrint('Home user data error: $e');
    }

    notifyListeners();
  }

  // ============================================================
  // VIDEO PREPARATION
  // ============================================================

  Future<void> prepareVideo(int index) async {
    if (index < 0 || index >= _videos.length) {
      return;
    }

    final existing = _controllers[index];

    if (existing != null && existing.value.isInitialized) {
      await existing.play();
      return;
    }

    final video = _videos[index];

    final url = video.videoUrl.trim();

    if (url.isEmpty) return;

    VideoPlayerController? controller;

    try {
      if (_isNetworkUrl(url)) {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
        );
      } else {
        controller = VideoPlayerController.asset(url);
      }

      _controllers[index] = controller;

      await controller.initialize();

      await controller.setLooping(true);

      if (index == _currentIndex) {
        await controller.play();
      }

      notifyListeners();

      unawaited(
        _preloadNearby(index),
      );
    } catch (e) {
      debugPrint(
        'Video initialization failed at index $index: $e',
      );

      _controllers.remove(index);

      await controller?.dispose();

      notifyListeners();
    }
  }

  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') ||
        url.startsWith('https://');
  }

  // ============================================================
  // PRELOAD
  // ============================================================

  Future<void> _preloadNearby(int index) async {
    final nextIndex = index + 1;
    final previousIndex = index - 1;

    if (nextIndex < _videos.length) {
      unawaited(
        _prepareWithoutPlaying(nextIndex),
      );
    }

    if (previousIndex >= 0) {
      unawaited(
        _prepareWithoutPlaying(previousIndex),
      );
    }
  }

  Future<void> _prepareWithoutPlaying(int index) async {
    if (index < 0 || index >= _videos.length) {
      return;
    }

    final existing = _controllers[index];

    if (existing != null && existing.value.isInitialized) {
      return;
    }

    final url = _videos[index].videoUrl.trim();

    if (url.isEmpty) return;

    VideoPlayerController? controller;

    try {
      if (_isNetworkUrl(url)) {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
        );
      } else {
        controller = VideoPlayerController.asset(url);
      }

      _controllers[index] = controller;

      await controller.initialize();

      await controller.setLooping(true);

      await controller.pause();

      notifyListeners();
    } catch (e) {
      debugPrint(
        'Video preload failed at index $index: $e',
      );

      _controllers.remove(index);

      await controller?.dispose();
    }
  }

  // ============================================================
  // PAGE CHANGED
  // ============================================================

  Future<void> onVideoChanged(int index) async {
    if (index < 0 || index >= _videos.length) {
      return;
    }

    _currentIndex = index;

    for (final entry in _controllers.entries) {
      if (entry.key != index &&
          entry.value.value.isInitialized) {
        await entry.value.pause();
      }
    }

    await prepareVideo(index);

    _disposeFarControllers(index);

    notifyListeners();
  }

  // ============================================================
  // PLAY / PAUSE
  // ============================================================

  Future<void> togglePlay() async {
    final controller = _controllers[_currentIndex];

    if (controller == null ||
        !controller.value.isInitialized) {
      await prepareVideo(_currentIndex);
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    notifyListeners();
  }

  bool isPlaying(int index) {
    final controller = _controllers[index];

    if (controller == null ||
        !controller.value.isInitialized) {
      return false;
    }

    return controller.value.isPlaying;
  }

  // ============================================================
  // LIKE
  // ============================================================

  Future<bool> toggleLike(VideoPost video) async {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    final videoId = video.id;

    final currentlyLiked =
        _likedIds.contains(videoId);

    if (currentlyLiked) {
      _likedIds.remove(videoId);

      _likeDeltas[videoId] =
          (_likeDeltas[videoId] ?? 0) - 1;
    } else {
      _likedIds.add(videoId);

      _likeDeltas[videoId] =
          (_likeDeltas[videoId] ?? 0) + 1;
    }

    notifyListeners();

    try {
      final likedRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .doc(videoId);

      final videoRef =
          _firestore.collection('videos').doc(videoId);

      if (currentlyLiked) {
        await likedRef.delete();

        if (!_isDemoVideo(videoId)) {
          await videoRef.update({
            'likeCount': FieldValue.increment(-1),
          });
        }
      } else {
        await likedRef.set({
          'videoId': videoId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!_isDemoVideo(videoId)) {
          await videoRef.update({
            'likeCount': FieldValue.increment(1),
          });
        }
      }

      return true;
    } catch (e) {
      if (currentlyLiked) {
        _likedIds.add(videoId);

        _likeDeltas[videoId] =
            (_likeDeltas[videoId] ?? 0) + 1;
      } else {
        _likedIds.remove(videoId);

        _likeDeltas[videoId] =
            (_likeDeltas[videoId] ?? 0) - 1;
      }

      notifyListeners();

      debugPrint('Like error: $e');

      return false;
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<bool> toggleSave(VideoPost video) async {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    final videoId = video.id;

    final currentlySaved =
        _savedIds.contains(videoId);

    if (currentlySaved) {
      _savedIds.remove(videoId);

      _saveDeltas[videoId] =
          (_saveDeltas[videoId] ?? 0) - 1;
    } else {
      _savedIds.add(videoId);

      _saveDeltas[videoId] =
          (_saveDeltas[videoId] ?? 0) + 1;
    }

    notifyListeners();

    try {
      final savedRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedVideos')
          .doc(videoId);

      final videoRef =
          _firestore.collection('videos').doc(videoId);

      if (currentlySaved) {
        await savedRef.delete();

        if (!_isDemoVideo(videoId)) {
          await videoRef.update({
            'saveCount': FieldValue.increment(-1),
          });
        }
      } else {
        await savedRef.set({
          'videoId': videoId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!_isDemoVideo(videoId)) {
          await videoRef.update({
            'saveCount': FieldValue.increment(1),
          });
        }
      }

      return true;
    } catch (e) {
      if (currentlySaved) {
        _savedIds.add(videoId);

        _saveDeltas[videoId] =
            (_saveDeltas[videoId] ?? 0) + 1;
      } else {
        _savedIds.remove(videoId);

        _saveDeltas[videoId] =
            (_saveDeltas[videoId] ?? 0) - 1;
      }

      notifyListeners();

      debugPrint('Save error: $e');

      return false;
    }
  }

  // ============================================================
  // FOLLOW
  // ============================================================

  Future<bool> toggleFollow(VideoPost video) async {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    final targetUserId = video.ownerId.trim();

    if (targetUserId.isEmpty) {
      return false;
    }

    if (targetUserId == user.uid) {
      return false;
    }

    final currentlyFollowing =
        _followingIds.contains(targetUserId);

    if (currentlyFollowing) {
      _followingIds.remove(targetUserId);
    } else {
      _followingIds.add(targetUserId);
    }

    notifyListeners();

    try {
      final followingRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(targetUserId);

      if (currentlyFollowing) {
        await followingRef.delete();
      } else {
        await followingRef.set({
          'userId': targetUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return true;
    } catch (e) {
      if (currentlyFollowing) {
        _followingIds.add(targetUserId);
      } else {
        _followingIds.remove(targetUserId);
      }

      notifyListeners();

      debugPrint('Follow error: $e');

      return false;
    }
  }

  // ============================================================
  // COMMENT COUNT
  // ============================================================

  void addCommentCount(
    String videoId,
    int amount,
  ) {
    if (amount == 0) return;

    _commentDeltas[videoId] =
        (_commentDeltas[videoId] ?? 0) + amount;

    notifyListeners();
  }

  // ============================================================
  // ADD COMMENT
  // ============================================================

  Future<bool> addComment(
    VideoPost video,
    String text,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      return false;
    }

    final videoId = video.id;

    // Demo video হলে Firestore video document নেই।
    if (_isDemoVideo(videoId)) {
      addCommentCount(videoId, 1);
      return true;
    }

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();

      final username =
          (data?['username'] ??
                  data?['displayName'] ??
                  user.displayName ??
                  'PALOK User')
              .toString();

      final commentRef = _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc();

      final videoRef =
          _firestore.collection('videos').doc(videoId);

      final batch = _firestore.batch();

      batch.set(commentRef, {
        'userId': user.uid,
        'username': username,
        'text': cleanText,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(videoRef, {
        'commentCount': FieldValue.increment(1),
      });

      await batch.commit();

      addCommentCount(videoId, 1);

      return true;
    } catch (e) {
      debugPrint('Comment error: $e');

      return false;
    }
  }

  // ============================================================
  // COMMENT STREAM
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> commentsStream(
    String videoId,
  ) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .orderBy(
          'createdAt',
          descending: false,
        )
        .snapshots();
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<bool> addShare(VideoPost video) async {
    final videoId = video.id;

    _shareDeltas[videoId] =
        (_shareDeltas[videoId] ?? 0) + 1;

    notifyListeners();

    try {
      if (!_isDemoVideo(videoId)) {
        await _firestore
            .collection('videos')
            .doc(videoId)
            .update({
          'shareCount': FieldValue.increment(1),
        });

        final user = _auth.currentUser;

        if (user != null) {
          await _firestore
              .collection('videos')
              .doc(videoId)
              .collection('shares')
              .add({
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return true;
    } catch (e) {
      _shareDeltas[videoId] =
          (_shareDeltas[videoId] ?? 0) - 1;

      notifyListeners();

      debugPrint('Share error: $e');

      return false;
    }
  }

  // ============================================================
  // DEMO VIDEO
  // ============================================================

  bool _isDemoVideo(String id) {
    return id.startsWith('demo_');
  }

  // ============================================================
  // DISPOSE FAR CONTROLLERS
  // ============================================================

  void _disposeFarControllers(
    int currentIndex,
  ) {
    final indexesToRemove = <int>[];

    for (final index in _controllers.keys) {
      if ((index - currentIndex).abs() > 1) {
        indexesToRemove.add(index);
      }
    }

    for (final index in indexesToRemove) {
      final controller =
          _controllers.remove(index);

      unawaited(
        controller?.dispose(),
      );
    }
  }

  // ============================================================
  // DISPOSE CONTROLLERS
  // ============================================================

  Future<void> disposeControllers() async {
    final controllers =
        List<VideoPlayerController>.from(
      _controllers.values,
    );

    _controllers.clear();

    for (final controller in controllers) {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      unawaited(
        controller.dispose(),
      );
    }

    _controllers.clear();

    super.dispose();
  }
}
