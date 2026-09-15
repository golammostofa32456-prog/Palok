import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const Color pink = Color(0xFFFF2D75);
  static const Color cyan = Color(0xFF25F4EE);

  static const String cloudName = 'u0jufmrl';
  static const String uploadPreset = 'palok_video_upload';
  static const int maxVideoBytes = 100 * 1024 * 1024;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();

  final List<VideoItem> _videos = [
    VideoItem.demo(
      url: 'assets/videos/video.mp4',
      username: '@palok_user',
      caption: 'Welcome to PALOK 🎬',
      hashtags: ['PALOK', 'ForYou'],
      likes: 11700,
      comments: 234,
      saves: 811,
      shares: 431,
    ),
    VideoItem.demo(
      url: 'assets/videos/video1.mp4',
      username: '@palok_user',
      caption: 'Enjoy short videos on PALOK ✨',
      hashtags: ['PALOK', 'ShortVideo'],
      likes: 8500,
      comments: 128,
      saves: 452,
      shares: 201,
    ),
    VideoItem.demo(
      url: 'assets/videos/video2.mp4',
      username: '@palok_user',
      caption: 'Create. Share. Connect. 🚀',
      hashtags: ['PALOK', 'Bangladesh'],
      likes: 6200,
      comments: 96,
      saves: 317,
      shares: 145,
    ),
  ];

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, Future<void>> _controllerJobs = {};

  // Permanent user interaction state.
  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  final Set<String> _followingIds = {};

  // Demo counter changes are also remembered.
  final Map<String, int> _likeDeltas = {};
  final Map<String, int> _saveDeltas = {};
  final Map<String, int> _shareDeltas = {};
  final Map<String, int> _commentDeltas = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _videoSubscription;

  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  int _currentIndex = 0;
  int _bottomIndex = 0;
  int _topIndex = 0;

  bool _uploading = false;
  double _uploadProgress = 0;
  String _uploadText = '';

  User? get _user => FirebaseAuth.instance.currentUser;

  VideoItem? get _currentVideo {
    if (_videos.isEmpty) return null;
    if (_currentIndex < 0 || _currentIndex >= _videos.length) {
      return null;
    }
    return _videos[_currentIndex];
  }

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeInOut,
      ),
    );

    _logoOpacity = Tween<double>(
      begin: 0.82,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeInOut,
      ),
    );

    _loadFollowing();
    _loadInteractions();
    _listenToVideos();

    unawaited(_prepareCurrentVideo());
  }

  @override
  void dispose() {
    _videoSubscription?.cancel();
    _logoController.dispose();
    _pageController.dispose();

    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // FIRESTORE USER INTERACTION STORAGE
  // ============================================================

  CollectionReference<Map<String, dynamic>> _interactionCollection(
    String uid,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('videoInteractions');
  }

  CollectionReference<Map<String, dynamic>> _savedCollection(
    String uid,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('saved');
  }

  CollectionReference<Map<String, dynamic>> _likedCollection(
    String uid,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('likedVideos');
  }

  String _videoKey(VideoItem video) {
    if (video.id != null && video.id!.isNotEmpty) {
      return video.id!;
    }

    return video.url.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
  }

  Future<void> _loadInteractions() async {
    final user = _user;

    if (user == null) {
      return;
    }

    try {
      final interactionSnapshot =
          await _interactionCollection(user.uid).get();

      final savedSnapshot =
          await _savedCollection(user.uid).get();

      final likedSnapshot =
          await _likedCollection(user.uid).get();

      if (!mounted) return;

      for (final doc in interactionSnapshot.docs) {
        final data = doc.data();

        final key = doc.id;

        if (data['liked'] == true) {
          _likedIds.add(key);
        }

        if (data['saved'] == true) {
          _savedIds.add(key);
        }

        final likeDelta =
            (data['likeDelta'] as num?)?.toInt() ?? 0;

        final saveDelta =
            (data['saveDelta'] as num?)?.toInt() ?? 0;

        final shareDelta =
            (data['shareDelta'] as num?)?.toInt() ?? 0;

        final commentDelta =
            (data['commentDelta'] as num?)?.toInt() ?? 0;

        if (likeDelta != 0) {
          _likeDeltas[key] = likeDelta;
        }

        if (saveDelta != 0) {
          _saveDeltas[key] = saveDelta;
        }

        if (shareDelta != 0) {
          _shareDeltas[key] = shareDelta;
        }

        if (commentDelta != 0) {
          _commentDeltas[key] = commentDelta;
        }
      }

      // Canonical saved collection.
      for (final doc in savedSnapshot.docs) {
        _savedIds.add(doc.id);
      }

      // Canonical liked collection.
      for (final doc in likedSnapshot.docs) {
        _likedIds.add(doc.id);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Interaction load error: $e');
    }
  }

  Future<void> _saveInteraction({
    required VideoItem video,
    bool? liked,
    bool? saved,
    int? likeDelta,
    int? saveDelta,
    int? shareDelta,
    int? commentDelta,
  }) async {
    final user = _user;

    if (user == null) {
      return;
    }

    final key = _videoKey(video);

    final ref = _interactionCollection(user.uid).doc(key);

    final Map<String, dynamic> data = {
      'videoKey': key,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (liked != null) {
      data['liked'] = liked;
    }

    if (saved != null) {
      data['saved'] = saved;
    }

    if (likeDelta != null) {
      data['likeDelta'] = likeDelta;
    }

    if (saveDelta != null) {
      data['saveDelta'] = saveDelta;
    }

    if (shareDelta != null) {
      data['shareDelta'] = shareDelta;
    }

    if (commentDelta != null) {
      data['commentDelta'] = commentDelta;
    }

    await ref.set(
      data,
      SetOptions(merge: true),
    );
  }

  Future<void> _loadFollowing() async {
    final user = _user;

    if (user == null) {
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();

      if (!mounted) return;

      setState(() {
        _followingIds.addAll(
          snapshot.docs.map((doc) => doc.id),
        );
      });
    } catch (e) {
      debugPrint('Following load error: $e');
    }
  }

  Future<User?> _requireUser() async {
    final user = _user;

    if (user == null) {
      _message('আগে Login করুন।');
      return null;
    }

    return user;
  }

  // ============================================================
  // FIRESTORE VIDEO FEED
  // ============================================================

  void _listenToVideos() {
    _videoSubscription = _firestore
        .collection('videos')
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots()
        .listen(
      (snapshot) {
        final remoteVideos = snapshot.docs
            .map(
              (doc) => VideoItem.fromFirestore(
                doc,
              ),
            )
            .toList();

        final demoVideos =
            _videos.where((video) => video.id == null).toList();

        if (!mounted) return;

        setState(() {
          _videos
            ..clear()
            ..addAll(remoteVideos)
            ..addAll(demoVideos);
        });

        unawaited(_prepareCurrentVideo());
      },
      onError: (error) {
        debugPrint('Video stream error: $error');
      },
    );
  }

  List<VideoItem> get _visibleVideos {
    if (_topIndex == 1) {
      final following = _videos.where((video) {
        final owner = video.ownerId;

        if (owner == null) {
          return false;
        }

        return _followingIds.contains(owner);
      }).toList();

      if (following.isNotEmpty) {
        return following;
      }
    }

    return _videos;
  }

  // ============================================================
  // VIDEO PLAYER
  // ============================================================

  String _controllerKey(VideoItem video) {
    return _videoKey(video);
  }

  Future<VideoPlayerController?> _getController(
    VideoItem video,
  ) async {
    final key = _controllerKey(video);

    final existing = _controllers[key];

    if (existing != null) {
      return existing;
    }

    final job = _controllerJobs[key];

    if (job != null) {
      await job;

      return _controllers[key];
    }

    final completer = Completer<void>();

    _controllerJobs[key] = completer.future;

    try {
      final controller = video.isNetwork
          ? VideoPlayerController.networkUrl(
              Uri.parse(video.url),
            )
          : VideoPlayerController.asset(
              video.url,
            );

      await controller.initialize();

      await controller.setLooping(true);

      _controllers[key] = controller;

      completer.complete();

      return controller;
    } catch (e) {
      debugPrint(
        'Video initialize error: $e',
      );

      completer.completeError(e);

      return null;
    } finally {
      _controllerJobs.remove(key);
    }
  }

  Future<void> _prepareCurrentVideo() async {
    final video = _currentVideo;

    if (video == null) {
      return;
    }

    final controller = await _getController(video);

    if (!mounted || controller == null) {
      return;
    }

    await controller.play();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _changeVideo(int index) async {
    if (index < 0 || index >= _visibleVideos.length) {
      return;
    }

    final oldVideo = _currentVideo;

    if (oldVideo != null) {
      final oldController =
          _controllers[_controllerKey(oldVideo)];

      await oldController?.pause();
    }

    final selected = _visibleVideos[index];

    final realIndex = _videos.indexOf(selected);

    if (realIndex >= 0) {
      _currentIndex = realIndex;
    }

    final controller = await _getController(selected);

    if (!mounted || controller == null) {
      return;
    }

    await controller.play();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _togglePlay() async {
    final video = _currentVideo;

    if (video == null) {
      return;
    }

    final controller =
        await _getController(video);

    if (controller == null) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // LIKE
  // ============================================================

  Future<void> _toggleLike() async {
    final user = await _requireUser();
    final video = _currentVideo;

    if (user == null || video == null) {
      return;
    }

    final key = _videoKey(video);

    final wasLiked = _likedIds.contains(key);
    final newLiked = !wasLiked;

    final oldDelta = _likeDeltas[key] ?? 0;

    setState(() {
      if (newLiked) {
        _likedIds.add(key);
      } else {
        _likedIds.remove(key);
      }

      if (video.id == null) {
        _likeDeltas[key] = newLiked ? 1 : 0;
      }
    });

    try {
      final batch = _firestore.batch();

      final interactionRef =
          _interactionCollection(user.uid).doc(key);

      batch.set(
        interactionRef,
        {
          'videoKey': key,
          'liked': newLiked,
          'likeDelta': video.id == null
              ? (newLiked ? 1 : 0)
              : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final likedRef =
          _likedCollection(user.uid).doc(key);

      if (newLiked) {
        batch.set(
          likedRef,
          {
            'videoKey': key,
            'videoId': video.id,
            'videoUrl': video.url,
            'username': video.username,
            'caption': video.caption,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        batch.delete(likedRef);
      }

      if (video.id != null) {
        final videoRef =
            _firestore.collection('videos').doc(video.id);

        final likeRef =
            videoRef.collection('likes').doc(user.uid);

        batch.update(
          videoRef,
          {
            'likeCount':
                FieldValue.increment(
              newLiked ? 1 : -1,
            ),
          },
        );

        if (newLiked) {
          batch.set(
            likeRef,
            {
              'userId': user.uid,
              'createdAt':
                  FieldValue.serverTimestamp(),
            },
          );
        } else {
          batch.delete(likeRef);
        }
      }

      await batch.commit();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (newLiked) {
          _likedIds.remove(key);
        } else {
          _likedIds.add(key);
        }

        if (video.id == null) {
          _likeDeltas[key] = oldDelta;
        }
      });

      debugPrint('Like save error: $e');

      _message(
        'Like সংরক্ষণ করা যায়নি।',
      );
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _toggleSave() async {
    final user = await _requireUser();
    final video = _currentVideo;

    if (user == null || video == null) {
      return;
    }

    final key = _videoKey(video);

    final wasSaved = _savedIds.contains(key);
    final newSaved = !wasSaved;

    final oldDelta = _saveDeltas[key] ?? 0;

    setState(() {
      if (newSaved) {
        _savedIds.add(key);
      } else {
        _savedIds.remove(key);
      }

      if (video.id == null) {
        _saveDeltas[key] = newSaved ? 1 : 0;
      }
    });

    try {
      final batch = _firestore.batch();

      // --------------------------------------------------------
      // 1. User interaction document
      // --------------------------------------------------------

      final interactionRef =
          _interactionCollection(user.uid).doc(key);

      batch.set(
        interactionRef,
        {
          'videoKey': key,
          'saved': newSaved,
          'saveDelta': video.id == null
              ? (newSaved ? 1 : 0)
              : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // --------------------------------------------------------
      // 2. Permanent savedVideos collection
      // --------------------------------------------------------

      final savedRef =
          _savedCollection(user.uid).doc(key);

      if (newSaved) {
        batch.set(
          savedRef,
          {
            'videoKey': key,
            'videoId': video.id,
            'videoUrl': video.url,
            'ownerId': video.ownerId,
            'username': video.username,
            'caption': video.caption,
            'hashtags': video.hashtags,
            'soundName': video.soundName,
            'savedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        batch.delete(savedRef);
      }

      // --------------------------------------------------------
      // 3. Update public video save counter
      // --------------------------------------------------------

      if (video.id != null) {
        final videoRef =
            _firestore.collection('videos').doc(video.id);

        batch.update(
          videoRef,
          {
            'saveCount':
                FieldValue.increment(
              newSaved ? 1 : -1,
            ),
          },
        );
      }

      await batch.commit();

      _message(
        newSaved
            ? 'ভিডিওটি সংরক্ষণ করা হয়েছে ✓'
            : 'ভিডিওটি Unsave করা হয়েছে',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (newSaved) {
          _savedIds.remove(key);
        } else {
          _savedIds.add(key);
        }

        if (video.id == null) {
          _saveDeltas[key] = oldDelta;
        }
      });

      debugPrint('Save error: $e');

      _message(
        'Save সংরক্ষণ করা যায়নি।',
      );
    }
  }

  // ============================================================
  // FOLLOW
  // ============================================================

  Future<void> _toggleFollow() async {
    final user = await _requireUser();
    final video = _currentVideo;

    if (user == null || video == null) {
      return;
    }

    final ownerId = video.ownerId;

    if (ownerId == null ||
        ownerId.isEmpty ||
        ownerId == user.uid) {
      _message('এই demo account follow করা যাবে না।');
      return;
    }

    final following =
        _followingIds.contains(ownerId);

    try {
      final batch = _firestore.batch();

      final followingRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(ownerId);

      final followerRef = _firestore
          .collection('users')
          .doc(ownerId)
          .collection('followers')
          .doc(user.uid);

      if (following) {
        batch.delete(followingRef);
        batch.delete(followerRef);
      } else {
        batch.set(
          followingRef,
          {
            'userId': ownerId,
            'createdAt':
                FieldValue.serverTimestamp(),
          },
        );

        batch.set(
          followerRef,
          {
            'userId': user.uid,
            'createdAt':
                FieldValue.serverTimestamp(),
          },
        );
      }

      await batch.commit();

      if (!mounted) return;

      setState(() {
        if (following) {
          _followingIds.remove(ownerId);
        } else {
          _followingIds.add(ownerId);
        }
      });

      _message(
        following
            ? 'Unfollow করা হয়েছে'
            : 'Follow করা হয়েছে ✓',
      );
    } catch (e) {
      debugPrint('Follow error: $e');

      _message(
        'Follow সংরক্ষণ করা যায়নি।',
      );
    }
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _shareVideo() async {
    final user = await _requireUser();
    final video = _currentVideo;

    if (user == null || video == null) {
      return;
    }

    final key = _videoKey(video);

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'দেখুন এই ভিডিওটি PALOK-এ 🎬\n${video.url}',
        ),
      );

      setState(() {
        if (video.id == null) {
          _shareDeltas[key] =
              (_shareDeltas[key] ?? 0) + 1;
        }
      });

      final interactionRef =
          _interactionCollection(user.uid).doc(key);

      await interactionRef.set(
        {
          'videoKey': key,
          'shareDelta':
              video.id == null ? 1 : 0,
          'lastSharedAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (video.id != null) {
        await _firestore
            .collection('videos')
            .doc(video.id)
            .update(
          {
            'shareCount':
                FieldValue.increment(1),
          },
        );
      }
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  Future<void> _openComments() async {
    final video = _currentVideo;

    if (video == null) {
      return;
    }

    final controller =
        TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CommentsSheet(
          video: video,
          controller: controller,
          onSend: (text) async {
            await _addComment(
              video,
              text,
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Future<void> _addComment(
    VideoItem video,
    String text,
  ) async {
    final user = await _requireUser();

    if (user == null) {
      return;
    }

    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    final key = _videoKey(video);

    try {
      if (video.id != null) {
        final commentsRef = _firestore
            .collection('videos')
            .doc(video.id)
            .collection('comments');

        await commentsRef.add(
          {
            'userId': user.uid,
            'username':
                user.displayName ??
                    user.email?.split('@').first ??
                    'PALOK User',
            'text': cleanText,
            'createdAt':
                FieldValue.serverTimestamp(),
          },
        );

        await _firestore
            .collection('videos')
            .doc(video.id)
            .update(
          {
            'commentCount':
                FieldValue.increment(1),
          },
        );
      } else {
        final newCount =
            (_commentDeltas[key] ?? 0) + 1;

        setState(() {
          _commentDeltas[key] = newCount;
        });

        await _saveInteraction(
          video: video,
          commentDelta: newCount,
        );
      }

      _message('Comment সংরক্ষণ করা হয়েছে ✓');
    } catch (e) {
      debugPrint('Comment error: $e');

      _message(
        'Comment সংরক্ষণ করা যায়নি।',
      );
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _openSearch() {
    final controller =
        TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 22,
            bottom:
                MediaQuery.of(context)
                        .viewInsets
                        .bottom +
                    20,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Search PALOK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Search videos, users...',
                    hintStyle:
                        const TextStyle(
                      color: Colors.white54,
                    ),
                    prefixIcon:
                        const Icon(
                      Icons.search,
                      color: Colors.white70,
                    ),
                    filled: true,
                    fillColor:
                        const Color(0xFF252525),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                  onSubmitted: (value) {
                    Navigator.pop(context);

                    if (value.trim().isNotEmpty) {
                      _message(
                        'Searching for "${value.trim()}"',
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // UPLOAD
  // ============================================================

  Future<void> _openCreateSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color: Colors.white30,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Create on PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _createOption(
                  Icons.videocam,
                  'Record Video',
                  () {
                    Navigator.pop(context);
                    _pickVideo(
                      ImageSource.camera,
                    );
                  },
                ),
                _createOption(
                  Icons.video_library,
                  'Upload Video',
                  () {
                    Navigator.pop(context);
                    _pickVideo(
                      ImageSource.gallery,
                    );
                  },
                ),
                _createOption(
                  Icons.music_note,
                  'Add Sound',
                  () {
                    Navigator.pop(context);
                    _message(
                      'Sound library শীঘ্রই যোগ করা হবে।',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _createOption(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: Colors.white,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight:
              FontWeight.w600,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white54,
      ),
    );
  }

  Future<void> _pickVideo(
    ImageSource source,
  ) async {
    final user = await _requireUser();

    if (user == null) {
      return;
    }

    try {
      final file =
          await _picker.pickVideo(
        source: source,
        maxDuration:
            const Duration(
          minutes: 10,
        ),
      );

      if (file == null) {
        return;
      }

      final videoFile =
          File(file.path);

      final size =
          await videoFile.length();

      if (size > maxVideoBytes) {
        _message(
          'ভিডিও 100 MB-এর বেশি হতে পারবে না।',
        );
        return;
      }

      await _showComposer(
        videoFile,
      );
    } catch (e) {
      debugPrint('Video picker error: $e');

      _message(
        'ভিডিও নির্বাচন করা যায়নি।',
      );
    }
  }

  Future<void> _showComposer(
    File videoFile,
  ) async {
    final captionController =
        TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return _UploadComposer(
          videoFile: videoFile,
          captionController:
              captionController,
          onPost: () async {
            final caption =
                captionController.text.trim();

            Navigator.pop(context);

            await _uploadVideo(
              videoFile,
              caption,
            );
          },
        );
      },
    );

    captionController.dispose();
  }

  Future<void> _uploadVideo(
    File videoFile,
    String caption,
  ) async {
    final user = await _requireUser();

    if (user == null) {
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _uploadText =
          'Uploading video...';
    });

    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '$cloudName/video/upload',
      );

      final request =
          http.MultipartRequest(
        'POST',
        uri,
      );

      request.fields['upload_preset'] =
          uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          videoFile.path,
        ),
      );

      setState(() {
        _uploadProgress = 0.15;
        _uploadText =
            'Uploading video...';
      });

      final streamedResponse =
          await request.send();

      setState(() {
        _uploadProgress = 0.90;
        _uploadText =
            'Finishing upload...';
      });

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Cloudinary upload failed: '
          '${response.statusCode}',
        );
      }

      final data =
          jsonDecode(response.body)
              as Map<String, dynamic>;

      final secureUrl =
          data['secure_url']?.toString();

      final publicId =
          data['public_id']?.toString();

      final assetId =
          data['asset_id']?.toString();

      if (secureUrl == null ||
          secureUrl.isEmpty) {
        throw Exception(
          'Cloudinary URL missing',
        );
      }

      setState(() {
        _uploadProgress = 0.96;
        _uploadText =
            'Saving PALOK post...';
      });

      await _firestore
          .collection('videos')
          .add(
        {
          'ownerId': user.uid,
          'username':
              user.displayName ??
                  user.email?.split('@').first ??
                  'PALOK User',
          'caption': caption,
          'hashtags':
              _extractHashtags(caption),
          'videoUrl': secureUrl,
          'cloudinaryPublicId': publicId,
          'cloudinaryAssetId': assetId,
          'likeCount': 0,
          'commentCount': 0,
          'saveCount': 0,
          'shareCount': 0,
          'createdAt':
              FieldValue.serverTimestamp(),
        },
      );

      setState(() {
        _uploadProgress = 1;
        _uploadText =
            'Video posted successfully!';
      });

      await Future.delayed(
        const Duration(
          milliseconds: 700,
        ),
      );

      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }

      _message(
        'PALOK-এ ভিডিও Post হয়েছে ✓',
      );
    } catch (e) {
      debugPrint('Upload error: $e');

      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }

      _message(
        'ভিডিও Upload করা যায়নি।',
      );
    }
  }

  List<String> _extractHashtags(
    String text,
  ) {
    final matches = RegExp(
      r'#[A-Za-z0-9_]+',
    ).allMatches(text);

    return matches
        .map(
          (match) =>
              match.group(0) ?? '',
        )
        .where(
          (value) => value.isNotEmpty,
        )
        .toList();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final visibleVideos =
        _visibleVideos;

    if (visibleVideos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: pink,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection:
                Axis.vertical,
            itemCount:
                visibleVideos.length,
            onPageChanged: (index) {
              unawaited(
                _changeVideo(index),
              );
            },
            itemBuilder:
                (context, index) {
              return _buildVideoPage(
                visibleVideos[index],
              );
            },
          ),

          _buildTopBar(),

          // LOCKED RIGHT-SIDE POSITION
          Positioned(
            right: 10,
            bottom: 116,
            child:
                _buildRightActions(),
          ),

          // LOCKED BOTTOM NAVIGATION
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child:
                  _buildBottomNavigation(),
            ),
          ),

          if (_uploading)
            _buildUploadProgress(),
        ],
      ),
    );
  }

  Widget _buildVideoPage(
    VideoItem video,
  ) {
    final controller =
        _controllers[_controllerKey(video)];

    final initialized =
        controller != null &&
            controller.value.isInitialized;

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
          ),

          if (initialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width:
                    controller!.value.size.width,
                height:
                    controller.value.size.height,
                child: VideoPlayer(
                  controller,
                ),
              ),
            )
          else
            const Center(
              child:
                  CircularProgressIndicator(
                color: pink,
              ),
            ),

          // Dark gradient for readable UI.
          IgnorePointer(
            child: DecoratedBox(
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topCenter,
                  end:
                      Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(
                      .18,
                    ),
                    Colors.transparent,
                    Colors.black.withOpacity(
                      .72,
                    ),
                  ],
                  stops: const [
                    0,
                    .45,
                    1,
                  ],
                ),
              ),
            ),
          ),

          _buildVideoInfo(video),

          if (controller != null &&
              controller.value.isInitialized &&
              !controller.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white70,
                size: 76,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          24,
          14,
          16,
          0,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation:
                  _logoController,
              builder:
                  (context, child) {
                return Opacity(
                  opacity:
                      _logoOpacity.value,
                  child: Transform.scale(
                    scale:
                        _logoScale.value,
                    child: child,
                  ),
                );
              },
              child: _buildLogo(),
            ),
            const Spacer(),
            _topTab(
              'For You',
              0,
            ),
            const SizedBox(width: 22),
            _topTab(
              'Following',
              1,
            ),
            const SizedBox(width: 18),
            GestureDetector(
              onTap: _openSearch,
              child: Container(
                width: 58,
                height: 58,
                decoration:
                    BoxDecoration(
                  color: Colors.black
                      .withOpacity(.28),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 78,
      height: 78,
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFFFF197A),
            Color(0xFF9C3CFF),
          ],
        ),
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                pink.withOpacity(.35),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'P',
          style: TextStyle(
            color: Colors.white,
            fontSize: 50,
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _topTab(
    String title,
    int index,
  ) {
    final selected =
        _topIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _topIndex = index;
          _currentIndex = 0;
        });

        _pageController.jumpToPage(
          0,
        );
      },
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white54,
              fontSize: 20,
              fontWeight:
                  selected
                      ? FontWeight.bold
                      : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 200,
            ),
            width:
                selected ? 48 : 0,
            height: 3,
            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInfo(
    VideoItem video,
  ) {
    final key =
        _videoKey(video);

    final following =
        video.ownerId != null &&
            _followingIds.contains(
              video.ownerId,
            );

    return Positioned(
      left: 18,
      right: 92,
      bottom: 124,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      LinearGradient(
                    colors: [
                      pink,
                      cyan,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  video.username,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            video.caption,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 7),
          if (video.hashtags.isNotEmpty)
            Text(
              video.hashtags
                  .map(
                    (tag) =>
                        '#$tag',
                  )
                  .join(' '),
              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          if (video.soundName.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 10,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.music_note,
                    color: Colors.white,
                    size: 17,
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Flexible(
                    child: Text(
                      video.soundName,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (video.ownerId != null &&
              video.ownerId !=
                  _user?.uid)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 7,
              ),
              child: GestureDetector(
                onTap:
                    _toggleFollow,
                child: Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(
                      7,
                    ),
                    border:
                        Border.all(
                      color:
                          Colors.white54,
                    ),
                  ),
                  child: Text(
                    following
                        ? 'Following'
                        : 'Follow',
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRightActions() {
    final video =
        _currentVideo;

    if (video == null) {
      return const SizedBox();
    }

    final key =
        _videoKey(video);

    final liked =
        _likedIds.contains(key);

    final saved =
        _savedIds.contains(key);

    final following =
        video.ownerId != null &&
            _followingIds.contains(
              video.ownerId,
            );

    final likes =
        video.likes +
            (video.id == null
                ? (_likeDeltas[key] ?? 0)
                : 0);

    final saves =
        video.saves +
            (video.id == null
                ? (_saveDeltas[key] ?? 0)
                : 0);

    final shares =
        video.shares +
            (video.id == null
                ? (_shareDeltas[key] ?? 0)
                : 0);

    final comments =
        video.comments +
            (video.id == null
                ? (_commentDeltas[key] ?? 0)
                : 0);

    return Column(
      children: [
        if (video.ownerId != null &&
            video.ownerId !=
                _user?.uid)
          _actionButton(
            icon:
                following
                    ? Icons.person
                    : Icons.person_add_alt_1,
            color: Colors.white,
            label:
                following
                    ? 'Following'
                    : 'Follow',
            onTap:
                _toggleFollow,
          ),
        _actionButton(
          icon: liked
              ? Icons.favorite
              : Icons.favorite_border,
          color: liked
              ? pink
              : Colors.white,
          label:
              _format(likes),
          onTap:
              _toggleLike,
        ),
        _actionButton(
          icon:
              Icons.comment_outlined,
          color: Colors.white,
          label:
              _format(comments),
          onTap:
              _openComments,
        ),
        _actionButton(
          icon: saved
              ? Icons.bookmark
              : Icons.bookmark_border,
          color: saved
              ? const Color(0xFFFFC107)
              : Colors.white,
          label:
              _format(saves),
          onTap:
              _toggleSave,
        ),
        _actionButton(
          icon:
              Icons.share_outlined,
          color: Colors.white,
          label:
              _format(shares),
          onTap:
              _shareVideo,
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 54,
              height: 54,
              decoration:
                  BoxDecoration(
                color: Colors.black
                    .withOpacity(.34),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 86,
      decoration:
          BoxDecoration(
        color: Colors.black
            .withOpacity(.86),
        border: const Border(
          top: BorderSide(
            color: Colors.white10,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround,
        children: [
          _bottomButton(
            Icons.home,
            'Home',
            0,
          ),
          _bottomButton(
            Icons.people_outline,
            'Friends',
            1,
          ),
          GestureDetector(
            onTap:
                _openCreateSheet,
            child: Container(
              width: 94,
              height: 56,
              decoration:
                  BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    cyan,
                    pink,
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
          _bottomButton(
            Icons.chat_bubble_outline,
            'Inbox',
            3,
          ),
          _bottomButton(
            Icons.person_outline,
            'Profile',
            4,
          ),
        ],
      ),
    );
  }

  Widget _bottomButton(
    IconData icon,
    String label,
    int index,
  ) {
    final selected =
        _bottomIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _bottomIndex = index;
        });

        if (index == 0) {
          _pageController.jumpToPage(
            0,
          );
        } else {
          _message(
            '$label শীঘ্রই আসছে।',
          );
        }
      },
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected
                  ? Colors.white
                  : Colors.white54,
              size: 28,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white54,
                fontSize: 12,
                fontWeight:
                    selected
                        ? FontWeight.bold
                        : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Positioned(
      left: 18,
      right: 18,
      bottom: 88,
      child: Container(
        padding:
            const EdgeInsets.all(18),
        decoration:
            BoxDecoration(
          color:
              const Color(0xFF181818)
                  .withOpacity(.96),
          borderRadius:
              BorderRadius.circular(18),
          border:
              Border.all(
            color: Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: pink,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Text(
                    _uploadText,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${(_uploadProgress * 100).round()}%',
                  style:
                      const TextStyle(
                    color: pink,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
              child:
                  LinearProgressIndicator(
                value:
                    _uploadProgress,
                minHeight: 6,
                backgroundColor:
                    Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation<
                        Color>(
                  pink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _format(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }

    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }

    return number.toString();
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              const Color(0xFF252525),
        ),
      );
  }
}

// ================================================================
// VIDEO MODEL
// ================================================================

class VideoItem {
  final String url;
  final String? id;
  final String? ownerId;
  final String username;
  final String caption;
  final List<String> hashtags;
  final String soundName;

  final int likes;
  final int comments;
  final int saves;
  final int shares;

  const VideoItem({
    required this.url,
    this.id,
    this.ownerId,
    required this.username,
    required this.caption,
    required this.hashtags,
    this.soundName = 'Original sound',
    this.likes = 0,
    this.comments = 0,
    this.saves = 0,
    this.shares = 0,
  });

  const VideoItem.demo({
    required this.url,
    required this.username,
    required this.caption,
    required this.hashtags,
    this.likes = 0,
    this.comments = 0,
    this.saves = 0,
    this.shares = 0,
  })  : id = null,
        ownerId = null,
        soundName = 'Original sound';

  bool get isNetwork {
    return url.startsWith('http://') ||
        url.startsWith('https://');
  }

  factory VideoItem.fromFirestore(
    QueryDocumentSnapshot<
        Map<String, dynamic>>
        doc,
  ) {
    final data = doc.data();

    int number(String key) {
      final value = data[key];

      if (value is num) {
        return value.toInt();
      }

      return 0;
    }

    List<String> stringList(
      String key,
    ) {
      final value = data[key];

      if (value is Iterable) {
        return value
            .map(
              (item) =>
                  item.toString(),
            )
            .toList();
      }

      return [];
    }

    return VideoItem(
      id: doc.id,
      ownerId:
          data['ownerId']?.toString(),
      url:
          data['videoUrl']?.toString() ??
              '',
      username:
          data['username']?.toString() ??
              '@palok_user',
      caption:
          data['caption']?.toString() ??
              '',
      hashtags:
          stringList('hashtags'),
      soundName:
          data['soundName']?.toString() ??
              'Original sound',
      likes:
          number('likeCount'),
      comments:
          number('commentCount'),
      saves:
          number('saveCount'),
      shares:
          number('shareCount'),
    );
  }
}

// ================================================================
// COMMENTS SHEET
// ================================================================

class _CommentsSheet extends StatefulWidget {
  final VideoItem video;
  final TextEditingController controller;
  final Future<void> Function(
    String text,
  ) onSend;

  const _CommentsSheet({
    required this.video,
    required this.controller,
    required this.onSend,
  });

  @override
  State<_CommentsSheet> createState() =>
      _CommentsSheetState();
}

class _CommentsSheetState
    extends State<_CommentsSheet> {
  final List<Map<String, String>>
      _localComments = [];

  bool _sending = false;

  Future<void> _send() async {
    final text =
        widget.controller.text.trim();

    if (text.isEmpty ||
        _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.onSend(text);

      if (!mounted) return;

      setState(() {
        _localComments.add({
          'username': 'You',
          'text': text,
        });
      });

      widget.controller.clear();
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard =
        MediaQuery.of(context)
            .viewInsets
            .bottom;

    return Container(
      height:
          MediaQuery.of(context)
                  .size
                  .height *
              .62,
      decoration:
          const BoxDecoration(
        color: Color(0xFF101010),
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          Container(
            width: 44,
            height: 5,
            decoration:
                BoxDecoration(
              color: Colors.white30,
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              18,
              12,
              14,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.video.comments + _localComments.length} Comments',
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      Navigator.pop(
                    context,
                  ),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            color: Colors.white12,
            height: 1,
          ),
          Expanded(
            child:
                widget.video.id == null
                    ? _buildDemoComments()
                    : _buildFirestoreComments(),
          ),
          Padding(
            padding:
                EdgeInsets.fromLTRB(
              16,
              10,
              16,
              keyboard + 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller:
                        widget.controller,
                    textInputAction:
                        TextInputAction.send,
                    onSubmitted: (_) =>
                        _send(),
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                    ),
                    decoration:
                        InputDecoration(
                      hintText:
                          'Add comment...',
                      hintStyle:
                          const TextStyle(
                        color: Colors.white54,
                      ),
                      filled: true,
                      fillColor:
                          const Color(
                        0xFF292929,
                      ),
                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          30,
                        ),
                        borderSide:
                            BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration:
                        const BoxDecoration(
                      color:
                          Color(0xFFFF2D75),
                      shape:
                          BoxShape.circle,
                    ),
                    child:
                        _sending
                            ? const Padding(
                                padding:
                                    EdgeInsets.all(
                                  16,
                                ),
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color:
                                    Colors.white,
                                size: 28,
                              ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoComments() {
    if (_localComments.isEmpty) {
      return const Center(
        child: Text(
          'কোনো comment এখনো নেই',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 15,
          ),
        ),
      );
    }

    return ListView.builder(
      padding:
          const EdgeInsets.all(18),
      itemCount:
          _localComments.length,
      itemBuilder:
          (context, index) {
        final comment =
            _localComments[index];

        return ListTile(
          contentPadding:
              EdgeInsets.zero,
          leading:
              const CircleAvatar(
            backgroundColor:
                Color(0xFFFF2D75),
            child: Icon(
              Icons.person,
              color: Colors.white,
            ),
          ),
          title: Text(
            comment['username'] ??
                'You',
            style:
                const TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          subtitle: Text(
            comment['text'] ?? '',
            style:
                const TextStyle(
              color: Colors.white70,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFirestoreComments() {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: FirebaseFirestore
          .instance
          .collection('videos')
          .doc(widget.video.id)
          .collection('comments')
          .orderBy(
            'createdAt',
            descending: true,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Comments load করা যায়নি',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
          );
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(
              color:
                  Color(0xFFFF2D75),
            ),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'কোনো comment এখনো নেই',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
          );
        }

        return ListView.builder(
          padding:
              const EdgeInsets.all(18),
          itemCount: docs.length,
          itemBuilder:
              (context, index) {
            final data =
                docs[index].data();

            return ListTile(
              contentPadding:
                  EdgeInsets.zero,
              leading:
                  const CircleAvatar(
                backgroundColor:
                    Color(0xFFFF2D75),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                ),
              ),
              title: Text(
                data['username']
                        ?.toString() ??
                    'PALOK User',
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              subtitle: Text(
                data['text']
                        ?.toString() ??
                    '',
                style:
                    const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ================================================================
// UPLOAD COMPOSER
// ================================================================

class _UploadComposer
    extends StatefulWidget {
  final File videoFile;
  final TextEditingController
      captionController;
  final VoidCallback onPost;

  const _UploadComposer({
    required this.videoFile,
    required this.captionController,
    required this.onPost,
  });

  @override
  State<_UploadComposer> createState() =>
      _UploadComposerState();
}

class _UploadComposerState
    extends State<_UploadComposer> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final controller =
        VideoPlayerController.file(
      widget.videoFile,
    );

    await controller.initialize();

    await controller.setLooping(true);
    await controller.play();

    if (!mounted) {
      controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.of(context)
            .viewInsets
            .bottom;

    return SafeArea(
      child: SizedBox(
        height:
            MediaQuery.of(context)
                    .size
                    .height *
                .90,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                14,
                10,
                10,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        Navigator.pop(
                      context,
                    ),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'New PALOK Post',
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 48,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  bottom + 100,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      width:
                          double.infinity,
                      height: 410,
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.white10,
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                      clipBehavior:
                          Clip.antiAlias,
                      child: _ready &&
                              _controller !=
                                  null
                          ? FittedBox(
                              fit:
                                  BoxFit.cover,
                              child: SizedBox(
                                width: _controller!
                                    .value
                                    .size
                                    .width,
                                height: _controller!
                                    .value
                                    .size
                                    .height,
                                child:
                                    VideoPlayer(
                                  _controller!,
                                ),
                              ),
                            )
                          : const Center(
                              child:
                                  CircularProgressIndicator(
                                color:
                                    Color(
                                  0xFFFF2D75,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    const Text(
                      'Caption',
                      style:
                          TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    TextField(
                      controller:
                          widget.captionController,
                      maxLines: 4,
                      style:
                          const TextStyle(
                        color: Colors.white,
                      ),
                      decoration:
                          InputDecoration(
                        hintText:
                            'Write a caption...',
                        hintStyle:
                            const TextStyle(
                          color:
                              Colors.white54,
                        ),
                        filled: true,
                        fillColor:
                            const Color(
                          0xFF202020,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                          borderSide:
                              BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    const Text(
                      'Add hashtags like #PALOK #ForYou',
                      style:
                          TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding:
                  EdgeInsets.fromLTRB(
                16,
                8,
                16,
                bottom + 12,
              ),
              child: SizedBox(
                width:
                    double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      _ready
                          ? widget.onPost
                          : null,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(
                      0xFFFF2D75,
                    ),
                    foregroundColor:
                        Colors.white,
                    disabledBackgroundColor:
                        Colors.white12,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Post',
                    style:
                        TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
