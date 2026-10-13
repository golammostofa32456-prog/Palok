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

  // FEED

  final List<VideoPost> _videos = [];

  List<VideoPost> get videos => List.unmodifiable(_videos);

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  // VIDEO CONTROLLERS

  final Map<int, VideoPlayerController> _controllers = {};

  // Prevent duplicate initialization of the same video.
  final Map<int, Future<void>> _preparing = {};

  VideoPlayerController? controllerFor(int index) {
    return _controllers[index];
  }

  // CURRENT VIDEO

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  bool _disposed = false;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // USER STATES

  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  final Set<String> _followingIds = {};

  bool isLiked(String videoId) => _likedIds.contains(videoId);

  bool isSaved(String videoId) => _savedIds.contains(videoId);

  bool isFollowing(String userId) =>
      _followingIds.contains(userId);

  // LOCAL COUNT DELTAS

  final Map<String, int> _likeDeltas = {};
  final Map<String, int> _saveDeltas = {};
  final Map<String, int> _commentDeltas = {};
  final Map<String, int> _shareDeltas = {};

  int _safeCount(int value) => value < 0 ? 0 : value;

  int likeCount(VideoPost video) => _safeCount(
        video.likeCount + (_likeDeltas[video.id] ?? 0),
      );

  int saveCount(VideoPost video) => _safeCount(
        video.saveCount + (_saveDeltas[video.id] ?? 0),
      );

  int commentCount(VideoPost video) => _safeCount(
        video.commentCount + (_commentDeltas[video.id] ?? 0),
      );

  int shareCount(VideoPost video) => _safeCount(
        video.shareCount + (_shareDeltas[video.id] ?? 0),
      );

  // LOAD

  Future<void> load() async {
    if (_loading || _disposed) return;

    _loading = true;
    _error = null;
    _notify();

    try {
      final loadedVideos = await _videoService.getVideos();

      if (_disposed) return;

      _videos
        ..clear()
        ..addAll(loadedVideos);

      await _loadUserData();

      if (_disposed) return;

      if (_videos.isNotEmpty) {
        // Prepare the first video and preload nearby content.
        unawaited(_preloadNearby(0));
        await prepareVideo(0);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Home load error: $e');
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;

    await disposeControllers();

    _videos.clear();
    _likeDeltas.clear();
    _saveDeltas.clear();
    _commentDeltas.clear();
    _shareDeltas.clear();

    _currentIndex = 0;
    _notify();

    await load();
  }

  // USER DATA

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;

    if (user == null || _disposed) return;

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

      if (_disposed) return;

      _likedIds
        ..clear()
        ..addAll(results[0].docs.map((doc) => doc.id));

      _savedIds
        ..clear()
        ..addAll(results[1].docs.map((doc) => doc.id));

      _followingIds
        ..clear()
        ..addAll(results[2].docs.map((doc) => doc.id));
    } catch (e) {
      debugPrint('Home user data error: $e');
    }

    _notify();
  }

  // VIDEO PREPARATION

  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') ||
        url.startsWith('https://');
  }

  VideoPlayerController _createController(String url) {
    if (_isNetworkUrl(url)) {
      return VideoPlayerController.networkUrl(
        Uri.parse(url),
      );
    }

    return VideoPlayerController.asset(url);
  }

  Future<void> prepareVideo(int index) async {
    if (_disposed || index < 0 || index >= _videos.length) {
      return;
    }

    final url = _videos[index].videoUrl.trim();
    if (url.isEmpty) return;

    await _ensurePrepared(index);

    if (_disposed || index != _currentIndex) return;

    final controller = _controllers[index];

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    try {
      // Don't wait for unrelated videos to pause.
      await controller.play();
    } catch (e) {
      debugPrint('Video play error at index $index: $e');
    }

    _notify();

    if (!_disposed) {
      unawaited(_preloadNearby(index));
    }
  }

  Future<void> _ensurePrepared(int index) async {
    if (_disposed || index < 0 || index >= _videos.length) {
      return;
    }

    final existing = _controllers[index];

    if (existing != null && existing.value.isInitialized) {
      return;
    }

    // Reuse an initialization already in progress.
    final pending = _preparing[index];

    if (pending != null) {
      await pending;
      return;
    }

    final url = _videos[index].videoUrl.trim();
    if (url.isEmpty) return;

    late final Future<void> task;

    task = _initializeController(index, url);

    _preparing[index] = task;

    try {
      await task;
    } finally {
      if (identical(_preparing[index], task)) {
        _preparing.remove(index);
      }
    }
  }

  Future<void> _initializeController(
    int index,
    String url,
  ) async {
    VideoPlayerController? controller;

    try {
      controller = _createController(url);
      _controllers[index] = controller;

      await controller.initialize();

      if (_disposed ||
          !identical(_controllers[index], controller)) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(true);

      if (_disposed ||
          !identical(_controllers[index], controller)) {
        return;
      }

      // Play only if this is still the selected page.
      if (index == _currentIndex) {
        await controller.play();
      } else {
        await controller.pause();
      }

      _notify();
    } catch (e) {
      debugPrint(
        'Video initialization failed at index $index: $e',
      );

      if (identical(_controllers[index], controller)) {
        _controllers.remove(index);
      }

      if (controller != null) {
        try {
          await controller.dispose();
        } catch (_) {}
      }

      _notify();
    }
  }

  // PRELOAD NEARBY VIDEOS

  Future<void> _preloadNearby(int index) async {
    if (_disposed) return;

    // Preload the next video first to reduce data and memory use.
    final nextIndex = index + 1;

    if (nextIndex < _videos.length) {
      await _ensurePrepared(nextIndex);
    }
  }

  // PAGE CHANGED

  Future<void> onVideoChanged(int index) async {
    if (_disposed || index < 0 || index >= _videos.length) {
      return;
    }

    _currentIndex = index;

    final target = _controllers[index];

    // Pause other videos without serially awaiting each pause.
    for (final entry in _controllers.entries.toList()) {
      if (entry.key != index &&
          entry.value.value.isInitialized &&
          entry.value.value.isPlaying) {
        unawaited(
          entry.value.pause().catchError((Object e) {
            debugPrint('Video pause error: $e');
          }),
        );
      }
    }

    // If preloaded, play immediately; otherwise initialize it.
    if (target != null && target.value.isInitialized) {
      try {
        await target.play();
      } catch (e) {
        debugPrint('Video play error at index $index: $e');
      }
    } else {
      await prepareVideo(index);
    }

    if (_disposed || index != _currentIndex) return;

    _disposeFarControllers(index);
    _notify();

    // Start preloading the next page in the background.
    unawaited(_preloadNearby(index));
  }

  // PLAY / PAUSE

  Future<void> togglePlay() async {
    if (_disposed) return;

    final controller = _controllers[_currentIndex];

    if (controller == null ||
        !controller.value.isInitialized) {
      await prepareVideo(_currentIndex);
      return;
    }

    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
    } catch (e) {
      debugPrint('Toggle play error: $e');
    }

    _notify();
  }

  bool isPlaying(int index) {
    final controller = _controllers[index];

    if (controller == null ||
        !controller.value.isInitialized) {
      return false;
    }

    return controller.value.isPlaying;
  }

  // LIKE

  Future<bool> toggleLike(VideoPost video) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final videoId = video.id;
    final currentlyLiked = _likedIds.contains(videoId);

    if (currentlyLiked) {
      _likedIds.remove(videoId);
      _likeDeltas[videoId] =
          (_likeDeltas[videoId] ?? 0) - 1;
    } else {
      _likedIds.add(videoId);
      _likeDeltas[videoId] =
          (_likeDeltas[videoId] ?? 0) + 1;
    }

    _notify();

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

      _notify();
      debugPrint('Like error: $e');
      return false;
    }
  }

  // SAVE

  Future<bool> toggleSave(VideoPost video) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final videoId = video.id;
    final currentlySaved = _savedIds.contains(videoId);

    if (currentlySaved) {
      _savedIds.remove(videoId);
      _saveDeltas[videoId] =
          (_saveDeltas[videoId] ?? 0) - 1;
    } else {
      _savedIds.add(videoId);
      _saveDeltas[videoId] =
          (_saveDeltas[videoId] ?? 0) + 1;
    }

    _notify();

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

      _notify();
      debugPrint('Save error: $e');
      return false;
    }
  }

  // FOLLOW

  Future<bool> toggleFollow(VideoPost video) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final targetUserId = video.ownerId.trim();

    if (targetUserId.isEmpty || targetUserId == user.uid) {
      return false;
    }

    final currentlyFollowing =
        _followingIds.contains(targetUserId);

    if (currentlyFollowing) {
      _followingIds.remove(targetUserId);
    } else {
      _followingIds.add(targetUserId);
    }

    _notify();

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

      _notify();
      debugPrint('Follow error: $e');
      return false;
    }
  }

  // COMMENT COUNT

  void addCommentCount(String videoId, int amount) {
    if (amount == 0) return;

    _commentDeltas[videoId] =
        (_commentDeltas[videoId] ?? 0) + amount;

    _notify();
  }

  // ADD COMMENT

  Future<bool> addComment(
    VideoPost video,
    String text,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final cleanText = text.trim();
    if (cleanText.isEmpty) return false;

    final videoId = video.id;

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

      final username = (
        data?['username'] ??
        data?['displayName'] ??
        user.displayName ??
        'PALOK User'
      ).toString();

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

  // COMMENT STREAM

  Stream<QuerySnapshot<Map<String, dynamic>>> commentsStream(
    String videoId,
  ) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // SHARE

  Future<bool> addShare(VideoPost video) async {
    final videoId = video.id;

    _shareDeltas[videoId] =
        (_shareDeltas[videoId] ?? 0) + 1;

    _notify();

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

      _notify();
      debugPrint('Share error: $e');
      return false;
    }
  }

  // DEMO VIDEO

  bool _isDemoVideo(String id) => id.startsWith('demo_');

  // DISPOSE FAR CONTROLLERS

  void _disposeFarControllers(int currentIndex) {
    final indexesToRemove = <int>[];

    for (final index in _controllers.keys) {
      if ((index - currentIndex).abs() > 1 &&
          !_preparing.containsKey(index)) {
        indexesToRemove.add(index);
      }
    }

    for (final index in indexesToRemove) {
      final controller = _controllers.remove(index);

      if (controller != null) {
        unawaited(controller.dispose());
      }
    }
  }

  // DISPOSE ALL CONTROLLERS

  Future<void> disposeControllers() async {
    final controllers =
        List<VideoPlayerController>.from(_controllers.values);

    _controllers.clear();
    _preparing.clear();

    for (final controller in controllers) {
      try {
        await controller.dispose();
      } catch (e) {
        debugPrint('Controller dispose error: $e');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;

    final controllers =
        List<VideoPlayerController>.from(_controllers.values);

    _controllers.clear();
    _preparing.clear();

    for (final controller in controllers) {
      unawaited(controller.dispose());
    }

    super.dispose();
  }
}
