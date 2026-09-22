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

    Future<void> _openComments(VideoPost video) async {
    final added = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      requestFocus: false,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _CommentsSheet(
          videoId: video.id,
          videoOwnerId: video.userId,
          videoOwnerUsername: video.username,
          currentUsername: _username,
          currentUserId: _auth.currentUser?.uid ?? '',
          firestore: _firestore,
        );
      },
    );

    if (added != null && added > 0 && mounted) {
      setState(() {
        _commentDeltas[video.id] =
            (_commentDeltas[video.id] ?? 0) + added;
      });
    }
  }

  Future<void> _openSearch() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      requestFocus: false,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _SearchSheet(
          videos: List<VideoPost>.from(_videos),
          onVideoSelected: (actualIndex) async {
            await _goToVideo(actualIndex);
          },
        );
      },
    );
  }

  Future<void> _goToVideo(int index) async {
    if (!mounted ||
        index < 0 ||
        index >= _videos.length) {
      return;
    }

    if (!_pageController.hasClients) {
      return;
    }

    try {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      if (!_pageController.hasClients) {
        return;
      }

      try {
        _pageController.jumpToPage(index);
      } catch (_) {}
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _pickProfileImage() async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Profile image পরিবর্তন করতে Login করতে হবে',
      );
      return;
    }

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) {
        return;
      }

      _showMessage(
        'Profile image upload করার ব্যবস্থা আপনার profile screen-এ আছে',
      );
    } catch (_) {
      _showMessage(
        'ছবি নির্বাচন করা যায়নি',
      );
    }
  }

  Widget _profileAvatar({
    double size = 44,
    String imageUrl = '',
  }) {
    final resolvedImage =
        imageUrl.trim().isNotEmpty
            ? imageUrl.trim()
            : _profileImage.trim();

    if (resolvedImage.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          resolvedImage,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _defaultAvatar(size);
          },
          loadingBuilder:
              (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }

            return _defaultAvatar(size);
          },
        ),
      );
    }

    return _defaultAvatar(size);
  }

  Widget _defaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            _pink,
            _cyan,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _bottomIndex,
        children: [
          _buildHomeScreen(),
          _buildFriendsScreen(),
          _buildUploadScreen(),
          _buildInboxScreen(),
          _buildProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHomeScreen() {
    final displayedVideos = _topIndex == 0
        ? _videos
        : _videos
            .where(
              (video) =>
                  _followingIds.contains(video.userId),
            )
            .toList();

    return Stack(
      children: [
        Positioned.fill(
          child: displayedVideos.isEmpty
              ? _buildEmptyFollowing()
              : PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: displayedVideos.length,
                  onPageChanged: (displayedIndex) {
                    if (displayedIndex < 0 ||
                        displayedIndex >=
                            displayedVideos.length) {
                      return;
                    }

                    final selectedVideo =
                        displayedVideos[displayedIndex];

                    final actualIndex =
                        _videos.indexWhere(
                      (video) =>
                          video.id == selectedVideo.id,
                    );

                    if (actualIndex >= 0) {
                      unawaited(
                        _onVideoChanged(actualIndex),
                      );
                    }
                  },
                  itemBuilder: (_, index) {
                    final video =
                        displayedVideos[index];

                    final actualIndex =
                        _videos.indexWhere(
                      (item) => item.id == video.id,
                    );

                    return _buildVideoPage(
                      video,
                      actualIndex >= 0
                          ? actualIndex
                          : index,
                    );
                  },
                ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTopBar(),
        ),
      ],
    );
  }

  Widget _buildEmptyFollowing() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.people_outline,
            color: Colors.white54,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Following feed empty',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'যাদের Follow করবে তাদের ভিডিও এখানে দেখা যাবে।',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _topIndex = 0;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'For You দেখুন',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          12,
          8,
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _logoController,
              builder: (_, child) {
                return Transform.scale(
                  scale: _logoScale.value,
                  child: Opacity(
                    opacity: _logoOpacity.value,
                    child: child,
                  ),
                );
              },
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    colors: [
                      _pink,
                      _cyan,
                    ],
                  ).createShader(bounds);
                },
                child: const Text(
                  'PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                setState(() {
                  _topIndex = 0;
                });
              },
              child: _topTab(
                'For You',
                _topIndex == 0,
              ),
            ),
            const SizedBox(width: 18),
            GestureDetector(
              onTap: () {
                setState(() {
                  _topIndex = 1;
                });
              },
              child: _topTab(
                'Following',
                _topIndex == 1,
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _openSearch,
              icon: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topTab(
    String text,
    bool selected,
  ) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 180),
      style: TextStyle(
        color: selected
            ? Colors.white
            : Colors.white54,
        fontSize: selected ? 15 : 14,
        fontWeight: selected
            ? FontWeight.w800
            : FontWeight.w500,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 22 : 0,
            height: 2,
            decoration: BoxDecoration(
              color: _pink,
              borderRadius:
                  BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPage(
    VideoPost video,
    int actualIndex,
  ) {
    final controller =
        _controllers[actualIndex];

    final isLiked =
        _likedIds.contains(video.id);

    final isSaved =
        _savedIds.contains(video.id);

    final isFollowing =
        _followingIds.contains(video.userId);

    final likeCount = _countWithDelta(
      video.likeCount,
      _likeDeltas,
      video.id,
    );

    final commentCount = _countWithDelta(
      video.commentCount,
      _commentDeltas,
      video.id,
    );

    final saveCount = _countWithDelta(
      video.saveCount,
      _saveDeltas,
      video.id,
    );

    final shareCount = _countWithDelta(
      video.shareCount,
      _shareDeltas,
      video.id,
    );

    return GestureDetector(
      onTap: _togglePlay,
      onDoubleTap: () {
        unawaited(
          _toggleLike(video),
        );
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null &&
                controller.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else
              _buildVideoLoading(video),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.48),
                        Colors.transparent,
                        Colors.black.withOpacity(0.76),
                      ],
                      stops: const [
                        0.0,
                        0.45,
                        1.0,
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
            Positioned(
              right: 12,
              bottom: 105,
              child: _buildVideoActions(
                video,
                isLiked,
                isSaved,
                isFollowing,
                likeCount,
                commentCount,
                saveCount,
                shareCount,
              ),
            ),
            Positioned(
              left: 16,
              right: 90,
              bottom: 24,
              child: _buildVideoInfo(
                video,
                isFollowing,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoLoading(VideoPost video) {
    if (video.thumbnailUrl.isNotEmpty) {
      return Image.network(
        video.thumbnailUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          );
        },
      );
    }

    return const Center(
      child: CircularProgressIndicator(
        color: Colors.white,
      ),
    );
  }

  Widget _buildVideoActions(
    VideoPost video,
    bool isLiked,
    bool isSaved,
    bool isFollowing,
    int likeCount,
    int commentCount,
    int saveCount,
    int shareCount,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionButton(
          icon: isFollowing
              ? Icons.person_remove_alt_1_rounded
              : Icons.person_add_alt_1_rounded,
          label: isFollowing
              ? 'Following'
              : 'Follow',
          color: isFollowing
              ? Colors.white
              : _cyan,
          onTap: () {
            unawaited(
              _toggleFollow(video),
            );
          },
        ),
        const SizedBox(height: 18),
        _actionButton(
          icon: isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: _formatCount(likeCount),
          color: isLiked
              ? _pink
              : Colors.white,
          onTap: () {
            unawaited(
              _toggleLike(video),
            );
          },
        ),
        const SizedBox(height: 18),
        _actionButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: _formatCount(commentCount),
          onTap: () {
            unawaited(
              _openComments(video),
            );
          },
        ),
        const SizedBox(height: 18),
        _actionButton(
          icon: isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          label: _formatCount(saveCount),
          color: isSaved
              ? _cyan
              : Colors.white,
          onTap: () {
            unawaited(
              _toggleSave(video),
            );
          },
        ),
        const SizedBox(height: 18),
        _actionButton(
          icon: Icons.share_rounded,
          label: _formatCount(shareCount),
          onTap: () {
            unawaited(
              _shareVideo(video),
            );
          },
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.28),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 27,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInfo(
    VideoPost video,
    bool isFollowing,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _profileAvatar(
              size: 42,
              imageUrl: '',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                video.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      blurRadius: 5,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        if (video.caption.isNotEmpty)
          Text(
            video.caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.3,
              shadows: [
                Shadow(
                  blurRadius: 5,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        if (video.hashtags.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            video.hashtags,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  blurRadius: 5,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      final value = count / 1000000;

      return '${value.toStringAsFixed(
        value >= 10 ? 0 : 1,
      )}M';
    }

    if (count >= 1000) {
      final value = count / 1000;

      return '${value.toStringAsFixed(
        value >= 10 ? 0 : 1,
      )}K';
    }

    return count.toString();
  }

  class _SearchSheet extends StatefulWidget {
  final List<VideoPost> videos;
  final Future<void> Function(int actualIndex)
      onVideoSelected;

  const _SearchSheet({
    required this.videos,
    required this.onVideoSelected,
  });

  @override
  State<_SearchSheet> createState() =>
      _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final TextEditingController _controller =
      TextEditingController();

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _closeSearch() async {
    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final query =
        _controller.text.trim().toLowerCase();

    final results = query.isEmpty
        ? <VideoPost>[]
        : widget.videos.where((video) {
            final text = [
              video.username,
              video.caption,
              video.hashtags,
            ].join(' ').toLowerCase();

            return text.contains(query);
          }).toList();

    return WillPopScope(
      onWillPop: () async {
        _focusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();

        return true;
      },
      child: Container(
        height:
            MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius:
                    BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                10,
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: false,
                textInputAction:
                    TextInputAction.search,
                onChanged: (_) {
                  if (mounted) {
                    setState(() {});
                  }
                },
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Search videos, users...',
                  hintStyle: const TextStyle(
                    color: Colors.white54,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                    ),
                    onPressed: () {
                      _controller.clear();
                      _focusNode.unfocus();

                      if (mounted) {
                        setState(() {});
                      }
                    },
                  ),
                  filled: true,
                  fillColor:
                      Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: query.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search,
                            size: 52,
                            color: Colors.white30,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Search PALOK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Users, captions and hashtags খুঁজুন',
                            style: TextStyle(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    )
                  : results.isEmpty
                      ? const Center(
                          child: Text(
                            'কোনো ফলাফল পাওয়া যায়নি',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior
                                  .onDrag,
                          padding:
                              const EdgeInsets.all(18),
                          itemCount: results.length,
                          separatorBuilder:
                              (_, __) =>
                                  const SizedBox(
                            height: 10,
                          ),
                          itemBuilder: (_, index) {
                            final video =
                                results[index];

                            final actualIndex =
                                widget.videos
                                    .indexWhere(
                              (v) =>
                                  v.id == video.id,
                            );

                            return InkWell(
                              borderRadius:
                                  BorderRadius.circular(
                                16,
                              ),
                              onTap: actualIndex < 0
                                  ? null
                                  : () async {
                                      _focusNode
                                          .unfocus();

                                      FocusManager
                                          .instance
                                          .primaryFocus
                                          ?.unfocus();

                                      if (mounted) {
                                        Navigator.of(
                                          context,
                                        ).pop();
                                      }

                                      await Future<void>
                                          .delayed(
                                        const Duration(
                                          milliseconds: 80,
                                        ),
                                      );

                                      if (actualIndex >=
                                          0) {
                                        await widget
                                            .onVideoSelected(
                                          actualIndex,
                                        );
                                      }
                                    },
                              child: Container(
                                padding:
                                    const EdgeInsets.all(
                                  12,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: Colors.white
                                      .withOpacity(0.06),
                                  borderRadius:
                                      BorderRadius
                                          .circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 76,
                                      decoration:
                                          BoxDecoration(
                                        color:
                                            Colors.white10,
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          12,
                                        ),
                                      ),
                                      child:
                                          const Icon(
                                        Icons
                                            .play_arrow_rounded,
                                        color: Colors
                                            .white70,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 12,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            video.username,
                                            style:
                                                const TextStyle(
                                              color: Colors
                                                  .white,
                                              fontWeight:
                                                  FontWeight
                                                      .w700,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 4,
                                          ),
                                          Text(
                                            video.caption
                                                    .isEmpty
                                                ? video
                                                    .hashtags
                                                : video
                                                    .caption,
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                            style:
                                                const TextStyle(
                                              color: Colors
                                                  .white60,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons
                                          .chevron_right,
                                      color:
                                          Colors.white54,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
