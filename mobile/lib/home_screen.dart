import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

import 'edit_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const Color _pink = Color(0xFFFF2D55);
  static const Color _cyan = Color(0xFF00E5FF);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  final PageController _pageController = PageController();

  final List<String> _demoVideos = const [
    'assets/videos/video.mp4',
    'assets/videos/video1.mp4',
    'assets/videos/video2.mp4',
  ];

  final Map<int, VideoPlayerController> _controllers = {};

  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  final Set<String> _followingIds = {};

  final Map<String, int> _likeDeltas = {};
  final Map<String, int> _commentDeltas = {};
  final Map<String, int> _saveDeltas = {};
  final Map<String, int> _shareDeltas = {};

  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  List<VideoPost> _videos = [];

  int _currentIndex = 0;
  int _bottomIndex = 0;
  int _topIndex = 0;

  bool _loading = true;

  String _username = 'PALOK User';
  String _bio = '';
  String _email = '';
  String _profileImage = '';

  int _followersCount = 0;
  int _followingCount = 0;

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

    _loadEverything();
  }

  @override
  void dispose() {
    _logoController.dispose();

    for (final controller in _controllers.values) {
      controller.dispose();
    }

    _controllers.clear();

    _pageController.dispose();

    super.dispose();
  }

  Future<void> _loadEverything() async {
    setState(() {
      _loading = true;
    });

    await Future.wait([
      _loadUserProfile(),
      _loadUserData(),
      _loadVideos(),
    ]);

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (_videos.isNotEmpty) {
      await _prepareVideo(0);
    }
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        if (!mounted) return;

        setState(() {
          _username =
              user.displayName?.trim().isNotEmpty == true
                  ? user.displayName!
                  : 'PALOK User';

          _email = user.email ?? '';
        });

        return;
      }

      final data = doc.data() ?? {};

      final username = (data['username'] ?? '').toString().trim();

      final displayName =
          (data['displayName'] ?? '').toString().trim();

      final firebaseDisplayName =
          user.displayName?.trim() ?? '';

      final resolvedUsername = username.isNotEmpty
          ? username
          : displayName.isNotEmpty
              ? displayName
              : firebaseDisplayName.isNotEmpty
                  ? firebaseDisplayName
                  : 'PALOK User';

      final bio = (data['bio'] ?? '').toString();

      final email = (data['email'] ?? '').toString().trim();

      final profileImage =
          (data['profileImage'] ?? '').toString().trim();

      final followers =
          _toInt(data['followersCount']);

      final following =
          _toInt(data['followingCount']);

      if (!mounted) return;

      setState(() {
        _username = resolvedUsername;
        _bio = bio;
        _email =
            email.isNotEmpty ? email : (user.email ?? '');
        _profileImage = profileImage;
        _followersCount = followers;
        _followingCount = following;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _username =
            user.displayName?.trim().isNotEmpty == true
                ? user.displayName!
                : 'PALOK User';

        _email = user.email ?? '';
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final likedSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .get();

      final savedSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedVideos')
          .get();

      final followingSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();

      if (!mounted) return;

      setState(() {
        _likedIds
          ..clear()
          ..addAll(
            likedSnapshot.docs.map(
              (doc) => doc.id,
            ),
          );

        _savedIds
          ..clear()
          ..addAll(
            savedSnapshot.docs.map(
              (doc) => doc.id,
            ),
          );

        _followingIds
          ..clear()
          ..addAll(
            followingSnapshot.docs.map(
              (doc) => doc.id,
            ),
          );
      });
    } catch (_) {
      // Ignore user-data loading errors.
    }
  }

  Future<void> _loadVideos() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .orderBy(
            'createdAt',
            descending: true,
          )
          .limit(50)
          .get();

      final loadedVideos = <VideoPost>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final videoUrl =
            (data['videoUrl'] ?? '').toString().trim();

        if (videoUrl.isEmpty) {
          continue;
        }

        loadedVideos.add(
          VideoPost(
            id: doc.id,
            videoUrl: videoUrl,
            userId: (data['userId'] ?? '').toString(),
            username:
                (data['username'] ?? 'PALOK User').toString(),
            caption:
                (data['caption'] ?? '').toString(),
            hashtags:
                (data['hashtags'] ?? '').toString(),
            likeCount:
                _toInt(data['likeCount']),
            commentCount:
                _toInt(data['commentCount']),
            saveCount:
                _toInt(data['saveCount']),
            shareCount:
                _toInt(data['shareCount']),
            thumbnailUrl:
                (data['thumbnailUrl'] ?? '').toString(),
          ),
        );
      }

      if (loadedVideos.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _videos = loadedVideos;
        });

        return;
      }
    } catch (_) {
      // Firestore may fail if index/network is unavailable.
    }

    if (!mounted) return;

    setState(() {
      _videos = [
        VideoPost(
          id: 'demo_0',
          videoUrl: _demoVideos[0],
          userId: 'demo_user_0',
          username: '@palok_creator',
          caption: 'Welcome to PALOK ✨',
          hashtags: '#PALOK #ForYou',
          likeCount: 11700,
          commentCount: 234,
          saveCount: 811,
          shareCount: 431,
          thumbnailUrl: '',
        ),
        VideoPost(
          id: 'demo_1',
          videoUrl: _demoVideos[1],
          userId: 'demo_user_1',
          username: '@nature_palok',
          caption: 'Beautiful moments on PALOK 🌿',
          hashtags: '#Nature #PALOK',
          likeCount: 8500,
          commentCount: 128,
          saveCount: 452,
          shareCount: 201,
          thumbnailUrl: '',
        ),
        VideoPost(
          id: 'demo_2',
          videoUrl: _demoVideos[2],
          userId: 'demo_user_2',
          username: '@palok_video',
          caption: 'Create. Share. Connect. 🚀',
          hashtags: '#PALOK #ShortVideo',
          likeCount: 4200,
          commentCount: 75,
          saveCount: 210,
          shareCount: 98,
          thumbnailUrl: '',
        ),
      ];
    });
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  int _countWithDelta(
    int original,
    Map<String, int> deltas,
    String id,
  ) {
    return original + (deltas[id] ?? 0);
  }

  Future<void> _prepareVideo(int index) async {
    if (index < 0 || index >= _videos.length) {
      return;
    }

    if (_controllers.containsKey(index)) {
      final existing = _controllers[index];

      if (existing != null &&
          existing.value.isInitialized) {
        await existing.play();
      }

      return;
    }

    final video = _videos[index];

    VideoPlayerController controller;

    if (video.videoUrl.startsWith('http://') ||
        video.videoUrl.startsWith('https://')) {
      controller = VideoPlayerController.networkUrl(
        Uri.parse(video.videoUrl),
      );
    } else {
      controller = VideoPlayerController.asset(
        video.videoUrl,
      );
    }

    _controllers[index] = controller;

    try {
      await controller.initialize();

      await controller.setLooping(true);

      if (!mounted) {
        controller.dispose();
        _controllers.remove(index);
        return;
      }

      if (index == _currentIndex) {
        await controller.play();
      }

      if (mounted) {
        setState(() {});
      }

      // Preload next video.
      final nextIndex = index + 1;

      if (nextIndex < _videos.length &&
          !_controllers.containsKey(nextIndex)) {
        unawaited(
          _prepareVideo(nextIndex),
        );
      }

      // Preload previous video.
      final previousIndex = index - 1;

      if (previousIndex >= 0 &&
          !_controllers.containsKey(previousIndex)) {
        unawaited(
          _prepareVideo(previousIndex),
        );
      }

      // Keep only current + adjacent controllers.
      final indexesToDispose = _controllers.keys
          .where(
            (key) => (key - index).abs() > 1,
          )
          .toList();

      for (final oldIndex in indexesToDispose) {
        final oldController =
            _controllers.remove(oldIndex);

        await oldController?.dispose();
      }
    } catch (_) {
      _controllers.remove(index);
      await controller.dispose();
    }
  }

  Future<void> _onVideoChanged(int index) async {
    if (index < 0 || index >= _videos.length) {
      return;
    }

    for (final entry in _controllers.entries) {
      if (entry.key != index) {
        try {
          await entry.value.pause();
        } catch (_) {}
      }
    }

    if (!mounted) return;

    setState(() {
      _currentIndex = index;
    });

    await _prepareVideo(index);
  }

  Future<void> _togglePlay() async {
    final controller =
        _controllers[_currentIndex];

    if (controller == null ||
        !controller.value.isInitialized) {
      await _prepareVideo(_currentIndex);
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

  Future<void> _toggleLike(VideoPost video) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Like করতে Login করতে হবে',
      );
      return;
    }

    final isLiked =
        _likedIds.contains(video.id);

    setState(() {
      if (isLiked) {
        _likedIds.remove(video.id);

        _likeDeltas[video.id] =
            (_likeDeltas[video.id] ?? 0) - 1;
      } else {
        _likedIds.add(video.id);

        _likeDeltas[video.id] =
            (_likeDeltas[video.id] ?? 0) + 1;
      }
    });

    try {
      final likeRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .doc(video.id);

      final videoRef = _firestore
          .collection('videos')
          .doc(video.id);

      if (isLiked) {
        await likeRef.delete();

        if (!video.id.startsWith('demo_')) {
          await videoRef.set(
            {
              'likeCount':
                  FieldValue.increment(-1),
            },
            SetOptions(merge: true),
          );
        }
      } else {
        await likeRef.set({
          'videoId': video.id,
          'createdAt':
              FieldValue.serverTimestamp(),
        });

        if (!video.id.startsWith('demo_')) {
          await videoRef.set(
            {
              'likeCount':
                  FieldValue.increment(1),
            },
            SetOptions(merge: true),
          );
        }

        if (video.userId.isNotEmpty &&
            video.userId != user.uid) {
          try {
            await _firestore
                .collection('users')
                .doc(video.userId)
                .collection('notifications')
                .add({
              'type': 'like',
              'fromUserId': user.uid,
              'fromUsername': _username,
              'text':
                  'তোমার ভিডিওটি Like করেছে',
              'videoId': video.id,
              'read': false,
              'createdAt':
                  FieldValue.serverTimestamp(),
            });
          } catch (_) {}
        }
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (isLiked) {
          _likedIds.add(video.id);

          _likeDeltas[video.id] =
              (_likeDeltas[video.id] ?? 0) + 1;
        } else {
          _likedIds.remove(video.id);

          _likeDeltas[video.id] =
              (_likeDeltas[video.id] ?? 0) - 1;
        }
      });

      _showMessage(
        'Like করা যায়নি',
      );
    }
  }

  Future<void> _toggleSave(VideoPost video) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Save করতে Login করতে হবে',
      );
      return;
    }

    final isSaved =
        _savedIds.contains(video.id);

    setState(() {
      if (isSaved) {
        _savedIds.remove(video.id);

        _saveDeltas[video.id] =
            (_saveDeltas[video.id] ?? 0) - 1;
      } else {
        _savedIds.add(video.id);

        _saveDeltas[video.id] =
            (_saveDeltas[video.id] ?? 0) + 1;
      }
    });

    try {
      final saveRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedVideos')
          .doc(video.id);

      final videoRef = _firestore
          .collection('videos')
          .doc(video.id);

      if (isSaved) {
        await saveRef.delete();

        if (!video.id.startsWith('demo_')) {
          await videoRef.set(
            {
              'saveCount':
                  FieldValue.increment(-1),
            },
            SetOptions(merge: true),
          );
        }

        _showMessage(
          'ভিডিওটি Unsave করা হয়েছে',
        );
      } else {
        await saveRef.set({
          'videoId': video.id,
          'createdAt':
              FieldValue.serverTimestamp(),
        });

        if (!video.id.startsWith('demo_')) {
          await videoRef.set(
            {
              'saveCount':
                  FieldValue.increment(1),
            },
            SetOptions(merge: true),
          );
        }

        _showMessage(
          'ভিডিওটি Saved হয়েছে',
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (isSaved) {
          _savedIds.add(video.id);

          _saveDeltas[video.id] =
              (_saveDeltas[video.id] ?? 0) + 1;
        } else {
          _savedIds.remove(video.id);

          _saveDeltas[video.id] =
              (_saveDeltas[video.id] ?? 0) - 1;
        }
      });

      _showMessage(
        'Save করা যায়নি',
      );
    }
  }

  Future<void> _toggleFollow(VideoPost video) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Follow করতে Login করতে হবে',
      );
      return;
    }

    if (video.userId.isEmpty ||
        video.userId == user.uid) {
      return;
    }

    final isFollowing =
        _followingIds.contains(video.userId);

    setState(() {
      if (isFollowing) {
        _followingIds.remove(video.userId);
        _followingCount =
            (_followingCount - 1)
                .clamp(0, 999999999);
      } else {
        _followingIds.add(video.userId);
        _followingCount++;
      }
    });

    try {
      final followingRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(video.userId);

      final currentUserRef = _firestore
          .collection('users')
          .doc(user.uid);

      final targetUserRef = _firestore
          .collection('users')
          .doc(video.userId);

      if (isFollowing) {
        await followingRef.delete();

        await currentUserRef.set(
          {
            'followingCount':
                FieldValue.increment(-1),
          },
          SetOptions(merge: true),
        );

        await targetUserRef.set(
          {
            'followersCount':
                FieldValue.increment(-1),
          },
          SetOptions(merge: true),
        );
      } else {
        await followingRef.set({
          'userId': video.userId,
          'username': video.username,
          'createdAt':
              FieldValue.serverTimestamp(),
        });

        await currentUserRef.set(
          {
            'followingCount':
                FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );

        await targetUserRef.set(
          {
            'followersCount':
                FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );

        try {
          await targetUserRef
              .collection('notifications')
              .add({
            'type': 'follow',
            'fromUserId': user.uid,
            'fromUsername': _username,
            'text': 'তোমাকে Follow করেছে',
            'read': false,
            'createdAt':
                FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (isFollowing) {
          _followingIds.add(video.userId);
          _followingCount++;
        } else {
          _followingIds.remove(video.userId);
          _followingCount =
              (_followingCount - 1)
                  .clamp(0, 999999999);
        }
      });

      _showMessage(
        'Follow পরিবর্তন করা যায়নি',
      );
    }
  }

  Future<void> _shareVideo(VideoPost video) async {
    final link =
        'https://palok.app/video/${video.id}';

    final text =
        'Watch this video on PALOK\n\n$link';

    try {
      await Share.share(text);

      if (!mounted) return;

      setState(() {
        _shareDeltas[video.id] =
            (_shareDeltas[video.id] ?? 0) + 1;
      });

      if (!video.id.startsWith('demo_')) {
        try {
          await _firestore
              .collection('videos')
              .doc(video.id)
              .set(
            {
              'shareCount':
                  FieldValue.increment(1),
            },
            SetOptions(merge: true),
          );
        } catch (_) {}
      }

      final user = _auth.currentUser;

      if (user != null &&
          !video.id.startsWith('demo_')) {
        try {
          await _firestore
              .collection('videos')
              .doc(video.id)
              .collection('shares')
              .add({
            'userId': user.uid,
            'createdAt':
                FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
    } catch (_) {
      // Share cancelled or failed.
    }
  }
