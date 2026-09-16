import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

const Color _pink = Color(0xFFFF2D55);
const Color _cyan = Color(0xFF00E5FF);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  final PageController _pageController = PageController();

  final List<String> _demoVideos = [
    'assets/videos/video.mp4',
    'assets/videos/video1.mp4',
    'assets/videos/video2.mp4',
  ];

  final List<VideoPost> _videos = [];

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _initializing = {};

  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  final Set<String> _followingIds = {};

  final Map<String, int> _likeDeltas = {};
  final Map<String, int> _saveDeltas = {};
  final Map<String, int> _commentDeltas = {};
  final Map<String, int> _shareDeltas = {};

  int _currentIndex = 0;
  int _bottomIndex = 0;
  int _topIndex = 0;

  bool _loading = true;

  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

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

    _loadHomeData();
  }

  @override
  void dispose() {
    _pageController.dispose();

    for (final controller in _controllers.values) {
      controller.dispose();
    }

    _logoController.dispose();

    super.dispose();
  }

  // ============================================================
  // DATA
  // ============================================================

  Future<void> _loadHomeData() async {
    try {
      await _loadUserData();
      await _loadVideos();
    } catch (_) {
      _loadDemoVideos();
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }

    if (_videos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeVideoForIndex(0);
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final liked = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .get();

      _likedIds
        ..clear()
        ..addAll(liked.docs.map((e) => e.id));
    } catch (_) {}

    try {
      final saved = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedVideos')
          .get();

      _savedIds
        ..clear()
        ..addAll(saved.docs.map((e) => e.id));
    } catch (_) {}

    try {
      final following = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();

      _followingIds
        ..clear()
        ..addAll(following.docs.map((e) => e.id));
    } catch (_) {}
  }

  Future<void> _loadVideos() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      if (snapshot.docs.isEmpty) {
        _loadDemoVideos();
        return;
      }

      _videos.clear();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final videoUrl = _stringValue(
          data['videoUrl'] ??
              data['videoURL'] ??
              data['url'] ??
              data['secureUrl'],
        );

        if (videoUrl.isEmpty) continue;

        final userId = _stringValue(
          data['userId'] ?? data['uid'] ?? data['ownerId'],
        );

        final username = _stringValue(
          data['username'] ??
              data['userName'] ??
              data['displayName'] ??
              data['name'],
        );

        final caption = _stringValue(
          data['caption'] ?? data['description'],
        );

        final likes = _intValue(
          data['likes'] ?? data['likeCount'],
        );

        final comments = _intValue(
          data['comments'] ?? data['commentCount'],
        );

        final saves = _intValue(
          data['saves'] ?? data['saveCount'],
        );

        final shares = _intValue(
          data['shares'] ?? data['shareCount'],
        );

        _videos.add(
          VideoPost(
            id: doc.id,
            videoUrl: videoUrl,
            userId: userId,
            username: username.isEmpty ? '@palok_user' : username,
            caption: caption,
            likes: likes,
            comments: comments,
            saves: saves,
            shares: shares,
            isAsset: false,
          ),
        );
      }

      if (_videos.isEmpty) {
        _loadDemoVideos();
      }
    } catch (_) {
      _loadDemoVideos();
    }
  }

  void _loadDemoVideos() {
    _videos.clear();

    _videos.addAll([
      VideoPost(
        id: 'demo_1',
        videoUrl: _demoVideos[0],
        userId: 'demo_user_1',
        username: '@palok_user',
        caption: 'Welcome to PALOK 🎬',
        likes: 11700,
        comments: 234,
        saves: 811,
        shares: 431,
        isAsset: true,
      ),
      VideoPost(
        id: 'demo_2',
        videoUrl: _demoVideos[1],
        userId: 'demo_user_2',
        username: '@palok_creator',
        caption: 'Create. Share. Connect. ❤️',
        likes: 8500,
        comments: 128,
        saves: 452,
        shares: 201,
        isAsset: true,
      ),
      VideoPost(
        id: 'demo_3',
        videoUrl: _demoVideos[2],
        userId: 'demo_user_3',
        username: '@palok_video',
        caption: 'Discover something new on PALOK ✨',
        likes: 6200,
        comments: 91,
        saves: 300,
        shares: 120,
        isAsset: true,
      ),
    ]);
  }

  String _stringValue(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ============================================================
  // VIDEO
  // ============================================================

  Future<void> _initializeVideoForIndex(int index) async {
    if (index < 0 || index >= _videos.length) return;

    final video = _videos[index];

    if (_controllers.containsKey(video.id)) {
      try {
        await _controllers[video.id]!.play();
      } catch (_) {}
      return;
    }

    if (_initializing[video.id] == true) return;

    _initializing[video.id] = true;

    try {
      late VideoPlayerController controller;

      if (video.isAsset) {
        controller = VideoPlayerController.asset(video.videoUrl);
      } else {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(video.videoUrl),
        );
      }

      _controllers[video.id] = controller;

      await controller.initialize();

      await controller.setLooping(true);
      await controller.setVolume(1.0);

      if (index == _currentIndex && mounted) {
        await controller.play();
      }

      if (mounted) {
        setState(() {});
      }

      _disposeFarControllers(index);
    } catch (_) {
      _controllers.remove(video.id);
    } finally {
      _initializing.remove(video.id);

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _disposeFarControllers(int index) {
    final idsToKeep = <String>{};

    for (int i = index - 1; i <= index + 1; i++) {
      if (i >= 0 && i < _videos.length) {
        idsToKeep.add(_videos[i].id);
      }
    }

    final removeIds = _controllers.keys
        .where((id) => !idsToKeep.contains(id))
        .toList();

    for (final id in removeIds) {
      _controllers[id]?.dispose();
      _controllers.remove(id);
    }
  }

  Future<void> _onPageChanged(int index) async {
    if (index < 0 || index >= _videos.length) return;

    final oldIndex = _currentIndex;

    if (oldIndex >= 0 && oldIndex < _videos.length) {
      final oldVideo = _videos[oldIndex];

      try {
        await _controllers[oldVideo.id]?.pause();
      } catch (_) {}
    }

    setState(() {
      _currentIndex = index;
    });

    await _initializeVideoForIndex(index);
  }

  Future<void> _toggleVideoPlay(VideoPost video) async {
    final controller = _controllers[video.id];

    if (controller == null || !controller.value.isInitialized) {
      await _initializeVideoForIndex(_currentIndex);
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

  Future<void> _toggleLike(VideoPost video) async {
    final user = _auth.currentUser;

    final isLiked = _likedIds.contains(video.id);

    setState(() {
      if (isLiked) {
        _likedIds.remove(video.id);
        _likeDeltas[video.id] = (_likeDeltas[video.id] ?? 0) - 1;
      } else {
        _likedIds.add(video.id);
        _likeDeltas[video.id] = (_likeDeltas[video.id] ?? 0) + 1;
      }
    });

    if (user == null) return;

    try {
      final userLikeRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .doc(video.id);

      final videoRef = _firestore
          .collection('videos')
          .doc(video.id);

      if (isLiked) {
        await userLikeRef.delete();

        if (!video.isAsset) {
          await videoRef.update({
            'likes': FieldValue.increment(-1),
          });
        }
      } else {
        await userLikeRef.set({
          'videoId': video.id,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!video.isAsset) {
          await videoRef.update({
            'likes': FieldValue.increment(1),
          });
        }
      }
    } catch (_) {}
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _toggleSave(VideoPost video) async {
    final user = _auth.currentUser;

    final isSaved = _savedIds.contains(video.id);

    setState(() {
      if (isSaved) {
        _savedIds.remove(video.id);
        _saveDeltas[video.id] = (_saveDeltas[video.id] ?? 0) - 1;
      } else {
        _savedIds.add(video.id);
        _saveDeltas[video.id] = (_saveDeltas[video.id] ?? 0) + 1;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSaved
                ? 'ভিডিওটি Unsave করা হয়েছে'
                : 'ভিডিওটি Saved হয়েছে',
          ),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }

    if (user == null) return;

    try {
      final ref = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedVideos')
          .doc(video.id);

      if (isSaved) {
        await ref.delete();

        if (!video.isAsset) {
          await _firestore.collection('videos').doc(video.id).update({
            'saves': FieldValue.increment(-1),
          });
        }
      } else {
        await ref.set({
          'videoId': video.id,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!video.isAsset) {
          await _firestore.collection('videos').doc(video.id).update({
            'saves': FieldValue.increment(1),
          });
        }
      }
    } catch (_) {}
  }

  // ============================================================
  // FOLLOW
  // ============================================================

  Future<void> _toggleFollow(VideoPost video) async {
    final user = _auth.currentUser;

    if (video.userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This creator cannot be followed in demo mode.'),
        ),
      );
      return;
    }

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login required to follow creators.'),
        ),
      );
      return;
    }

    if (video.userId == user.uid) return;

    final alreadyFollowing = _followingIds.contains(video.userId);

    setState(() {
      if (alreadyFollowing) {
        _followingIds.remove(video.userId);
      } else {
        _followingIds.add(video.userId);
      }
    });

    try {
      final followingRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(video.userId);

      final followerRef = _firestore
          .collection('users')
          .doc(video.userId)
          .collection('followers')
          .doc(user.uid);

      if (alreadyFollowing) {
        await followingRef.delete();
        await followerRef.delete();
      } else {
        await followingRef.set({
          'userId': video.userId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await followerRef.set({
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _shareVideo(VideoPost video) async {
    try {
      final link = 'https://palok.app/video/${video.id}';

      await Share.share(
        'Watch this video on PALOK 🎬\n$link',
      );

      setState(() {
        _shareDeltas[video.id] =
            (_shareDeltas[video.id] ?? 0) + 1;
      });

      final user = _auth.currentUser;

      if (user != null && !video.isAsset) {
        await _firestore
            .collection('videos')
            .doc(video.id)
            .collection('sharedVideos')
            .add({
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _firestore.collection('videos').doc(video.id).update({
          'shares': FieldValue.increment(1),
        });
      }
    } catch (_) {}
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  void _openComments(VideoPost video) {
    final controller = _controllers[video.id];

    controller?.pause();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: false,
      builder: (_) {
        return _CommentsSheet(
          video: video,
          firestore: _firestore,
          auth: _auth,
          onCommentAdded: () {
            setState(() {
              _commentDeltas[video.id] =
                  (_commentDeltas[video.id] ?? 0) + 1;
            });
          },
        );
      },
    ).whenComplete(() {
      if (mounted && _currentIndex < _videos.length) {
        final currentVideo = _videos[_currentIndex];

        final currentController =
            _controllers[currentVideo.id];

        if (currentController != null &&
            currentController.value.isInitialized) {
          currentController.play();
        }
      }
    });
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _openSearch() {
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        int searchTab = 0;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.88,
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search videos, users...',
                          hintStyle: const TextStyle(
                            color: Colors.white54,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white,
                          ),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) {
                          setSheetState(() {});
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        _searchTabButton(
                          'Top',
                          0,
                          searchTab,
                          () {
                            setSheetState(() {
                              searchTab = 0;
                            });
                          },
                        ),
                        _searchTabButton(
                          'Users',
                          1,
                          searchTab,
                          () {
                            setSheetState(() {
                              searchTab = 1;
                            });
                          },
                        ),
                        _searchTabButton(
                          'Videos',
                          2,
                          searchTab,
                          () {
                            setSheetState(() {
                              searchTab = 2;
                            });
                          },
                        ),
                      ],
                    ),

                    const Divider(
                      color: Colors.white12,
                    ),

                    Expanded(
                      child: _buildSearchResults(
                        searchController.text,
                        searchTab,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _searchTabButton(
    String title,
    int index,
    int selected,
    VoidCallback onTap,
  ) {
    final active = index == selected;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : Colors.white54,
              fontWeight:
                  active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    String query,
    int tab,
  ) {
    if (query.trim().isEmpty) {
      return const Center(
        child: Text(
          'Search PALOK',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 17,
          ),
        ),
      );
    }

    final q = query.toLowerCase();

    final results = _videos.where((video) {
      return video.username.toLowerCase().contains(q) ||
          video.caption.toLowerCase().contains(q);
    }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text(
          'No results found',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final video = results[index];

        return ListTile(
          leading: Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _cyan,
                  _pink,
                ],
              ),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
            ),
          ),
          title: Text(
            video.username,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            video.caption.isEmpty
                ? 'PALOK video'
                : video.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // CREATE
  // ============================================================

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              14,
              18,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'Create on PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 22),

                _createOption(
                  Icons.videocam_outlined,
                  'Record Video',
                  () {
                    Navigator.pop(context);
                    _pickVideo(
                      ImageSource.camera,
                    );
                  },
                ),

                _createOption(
                  Icons.video_library_outlined,
                  'Upload Video',
                  () {
                    Navigator.pop(context);
                    _pickVideo(
                      ImageSource.gallery,
                    );
                  },
                ),

                _createOption(
                  Icons.music_note_outlined,
                  'Add Sound',
                  () {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Sound feature will be connected next.',
                        ),
                      ),
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
      contentPadding: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(14),
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
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white54,
      ),
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5),
      );

      if (picked == null) return;

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return _PostComposerSheet(
            videoFile: File(picked.path),
            firestore: _firestore,
            auth: _auth,
          );
        },
      );

      await _loadVideos();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Video select failed: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HOME FEED
  // ============================================================

  Widget _buildHomeContent() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildVideoFeed(),

        _buildTopHeader(),

        _buildVideoInfo(),

        _buildRightActions(),
      ],
    );
  }

  Widget _buildVideoFeed() {
    if (_loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: _pink,
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'No videos yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _videos.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final video = _videos[index];

        return _VideoPage(
          video: video,
          controller: _controllers[video.id],
          initializing: _initializing[video.id] == true,
          liked: _likedIds.contains(video.id),
          onTap: () => _toggleVideoPlay(video),
          onDoubleTap: () {
            if (!_likedIds.contains(video.id)) {
              _toggleLike(video);
            }
          },
        );
      },
    );
  }

  // ============================================================
  // TOP
  // ============================================================

  Widget _buildTopHeader() {
    return Positioned(
      top: 24,
      left: 18,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoScale.value,
                  child: Opacity(
                    opacity: _logoOpacity.value,
                    child: child,
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _cyan,
                          _pink,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _pink.withOpacity(0.20),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'P',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 35,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 9),

                  const Text(
                    'PALOK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            GestureDetector(
              onTap: () {
                setState(() {
                  _topIndex = 0;
                });
              },
              child: Text(
                'For You',
                style: TextStyle(
                  color:
                      _topIndex == 0
                          ? Colors.white
                          : Colors.white54,
                  fontSize: 17,
                  fontWeight:
                      _topIndex == 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                ),
              ),
            ),

            const SizedBox(width: 25),

            GestureDetector(
              onTap: () {
                setState(() {
                  _topIndex = 1;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Following feed selected',
                    ),
                    duration: Duration(milliseconds: 700),
                  ),
                );
              },
              child: Text(
                'Following',
                style: TextStyle(
                  color:
                      _topIndex == 1
                          ? Colors.white
                          : Colors.white54,
                  fontSize: 17,
                  fontWeight:
                      _topIndex == 1
                          ? FontWeight.bold
                          : FontWeight.normal,
                ),
              ),
            ),

            const SizedBox(width: 17),

            GestureDetector(
              onTap: _openSearch,
              child: const Icon(
                Icons.search,
                color: Colors.white,
                size: 31,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // VIDEO INFO
  // ============================================================

  Widget _buildVideoInfo() {
    if (_videos.isEmpty ||
        _currentIndex >= _videos.length) {
      return const SizedBox.shrink();
    }

    final video = _videos[_currentIndex];

    return Positioned(
      left: 18,
      right: 92,
      bottom: 124,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  video.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (video.userId.isNotEmpty &&
                    video.userId != _auth.currentUser?.uid)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 8,
                    ),
                    child: GestureDetector(
                      onTap: () => _toggleFollow(video),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white70,
                          ),
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: Text(
                          _followingIds.contains(
                            video.userId,
                          )
                              ? 'Following'
                              : 'Follow',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            if (video.caption.isNotEmpty)
              Text(
                video.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),

            const SizedBox(height: 7),

            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.music_note,
                  color: Colors.white,
                  size: 15,
                ),
                SizedBox(width: 5),
                Text(
                  'Original sound • PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RIGHT ACTIONS
  // ============================================================

  Widget _buildRightActions() {
    if (_videos.isEmpty ||
        _currentIndex >= _videos.length) {
      return const SizedBox.shrink();
    }

    final video = _videos[_currentIndex];

    final likes =
        video.likes + (_likeDeltas[video.id] ?? 0);

    final comments =
        video.comments + (_commentDeltas[video.id] ?? 0);

    final saves =
        video.saves + (_saveDeltas[video.id] ?? 0);

    final shares =
        video.shares + (_shareDeltas[video.id] ?? 0);

    return Positioned(
      right: 10,
      bottom: 116,
      child: Column(
        children: [
          _ActionButton(
            icon: Icons.person_add_alt_1,
            active: _followingIds.contains(
              video.userId,
            ),
            count: '',
            onTap: () => _toggleFollow(video),
          ),

          const SizedBox(height: 14),

          _ActionButton(
            icon: _likedIds.contains(video.id)
                ? Icons.favorite
                : Icons.favorite_border,
            active: _likedIds.contains(video.id),
            count: _formatCount(likes),
            onTap: () => _toggleLike(video),
          ),

          const SizedBox(height: 14),

          _ActionButton(
            icon: Icons.chat_bubble_outline,
            count: _formatCount(comments),
            onTap: () => _openComments(video),
          ),

          const SizedBox(height: 14),

          _ActionButton(
            icon: _savedIds.contains(video.id)
                ? Icons.bookmark
                : Icons.bookmark_border,
            active: _savedIds.contains(video.id),
            count: _formatCount(saves),
            onTap: () => _toggleSave(video),
          ),

          const SizedBox(height: 14),

          _ActionButton(
            icon: Icons.share_outlined,
            count: _formatCount(shares),
            onTap: () => _shareVideo(video),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }

    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }

    return count.toString();
  }

  // ============================================================
  // FRIENDS
  // ============================================================

  Widget _buildFriendsScreen() {
    return const _SimplePalokScreen(
      icon: Icons.people_outline,
      title: 'Friends',
      subtitle: 'Connect with your friends on PALOK',
    );
  }

  // ============================================================
  // INBOX
  // ============================================================

  Widget _buildInboxScreen() {
    return const _SimplePalokScreen(
      icon: Icons.chat_bubble_outline,
      title: 'Inbox',
      subtitle: 'Your messages and notifications will appear here',
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Widget _buildProfileScreen() {
    final user = _auth.currentUser;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                20,
                18,
                18,
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.menu,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          _cyan,
                          _pink,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    user?.displayName ??
                        user?.email ??
                        '@palok_user',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    user?.email ?? 'PALOK Creator',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                    children: [
                      _profileStat(
                        'Following',
                        _followingIds.length.toString(),
                      ),
                      _profileStat(
                        'Followers',
                        '0',
                      ),
                      _profileStat(
                        'Likes',
                        '0',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Colors.white24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Edit profile',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Divider(
              color: Colors.white12,
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(2),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _videos.length) {
                    return const SizedBox.shrink();
                  }

                  final video = _videos[index];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _bottomIndex = 0;
                        _currentIndex = index;
                      });

                      WidgetsBinding.instance
                          .addPostFrameCallback((_) {
                        if (_pageController.hasClients) {
                          _pageController.jumpToPage(index);
                        }
                      });
                    },
                    child: Container(
                      color: Colors.white10,
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  );
                },
                childCount: _videos.length,
              ),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 0.72,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileStat(
    String title,
    String value,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void _selectBottom(int index) {
    if (index == 2) {
      _openCreateSheet();
      return;
    }

    setState(() {
      _bottomIndex = index;
    });

    if (index != 0) {
      final currentVideo =
          _currentIndex < _videos.length
              ? _videos[_currentIndex]
              : null;

      if (currentVideo != null) {
        _controllers[currentVideo.id]?.pause();
      }
    } else {
      if (_currentIndex < _videos.length) {
        final currentVideo = _videos[_currentIndex];
        _controllers[currentVideo.id]?.play();
      }
    }
  }

  Widget _buildBottomNavigation() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.82),
            border: const Border(
              top: BorderSide(
                color: Colors.white10,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  selected: _bottomIndex == 0,
                  onTap: () => _selectBottom(0),
                ),
              ),

              Expanded(
                child: _BottomNavItem(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Friends',
                  selected: _bottomIndex == 1,
                  onTap: () => _selectBottom(1),
                ),
              ),

              SizedBox(
                width: 74,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _selectBottom(2),
                    child: Container(
                      width: 52,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: [
                            _cyan,
                            _pink,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _pink.withOpacity(0.25),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: _BottomNavItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: 'Inbox',
                  selected: _bottomIndex == 3,
                  onTap: () => _selectBottom(3),
                ),
              ),

              Expanded(
                child: _BottomNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  selected: _bottomIndex == 4,
                  onTap: () => _selectBottom(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _bottomIndex,
            children: [
              _buildHomeContent(),
              _buildFriendsScreen(),
              const ColoredBox(
                color: Colors.black,
              ),
              _buildInboxScreen(),
              _buildProfileScreen(),
            ],
          ),

          _buildBottomNavigation(),
        ],
      ),
    );
  }
}

// =================================================================
// VIDEO PAGE
// =================================================================

class _VideoPage extends StatelessWidget {
  final VideoPost video;
  final VideoPlayerController? controller;
  final bool initializing;
  final bool liked;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _VideoPage({
    required this.video,
    required this.controller,
    required this.initializing,
    required this.liked,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null &&
                controller!.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller!.value.size.width,
                  height: controller!.value.size.height,
                  child: VideoPlayer(controller!),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),

            if (initializing)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),

            if (controller != null &&
                controller!.value.isInitialized &&
                !controller!.value.isPlaying)
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white38,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// ACTION BUTTON
// =================================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String count;
  final VoidCallback onTap;
  final bool active;

  const _ActionButton({
    required this.icon,
    required this.count,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        child: Column(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.16),
                ),
              ),
              child: Icon(
                icon,
                color: active
                    ? _pink
                    : Colors.white,
                size: 23,
              ),
            ),

            if (count.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                count,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =================================================================
// BOTTOM NAV ITEM
// =================================================================

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? activeIcon : icon,
            color: selected
                ? Colors.white
                : Colors.white54,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white54,
              fontSize: 10,
              fontWeight: selected
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// SIMPLE SCREEN
// =================================================================

class _SimplePalokScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SimplePalokScreen({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        _cyan,
                        _pink,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _pink.withOpacity(0.18),
                        blurRadius: 25,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 42,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =================================================================
// COMMENTS SHEET
// =================================================================

class _CommentsSheet extends StatefulWidget {
  final VideoPost video;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final VoidCallback onCommentAdded;

  const _CommentsSheet({
    required this.video,
    required this.firestore,
    required this.auth,
    required this.onCommentAdded,
  });

  @override
  State<_CommentsSheet> createState() =>
      _CommentsSheetState();
}

class _CommentsSheetState
    extends State<_CommentsSheet> {
  final TextEditingController _commentController =
      TextEditingController();

  final FocusNode _focusNode = FocusNode();

  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>?
      _commentsStream() {
    if (widget.video.isAsset) {
      return null;
    }

    return widget.firestore
        .collection('videos')
        .doc(widget.video.id)
        .collection('comments')
        .orderBy(
          'createdAt',
          descending: false,
        )
        .snapshots();
  }

  Future<void> _sendComment() async {
    final text =
        _commentController.text.trim();

    if (text.isEmpty || _sending) return;

    final user = widget.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Login required to comment.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.firestore
          .collection('videos')
          .doc(widget.video.id)
          .collection('comments')
          .add({
        'userId': user.uid,
        'username':
            user.displayName ??
            user.email?.split('@').first ??
            'user',
        'text': text,
        'createdAt':
            FieldValue.serverTimestamp(),
      });

      if (!widget.video.isAsset) {
        await widget.firestore
            .collection('videos')
            .doc(widget.video.id)
            .update({
          'comments': FieldValue.increment(1),
        });
      }

      _commentController.clear();

      widget.onCommentAdded();

      _focusNode.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Comment failed: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Widget _buildDemoComments() {
    final comments = [
      {
        'username': '@rahim',
        'text': 'Nice video! 🔥',
      },
      {
        'username': '@karim',
        'text': 'PALOK looks amazing ❤️',
      },
      {
        'username': '@user123',
        'text': 'Great content!',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        110,
      ),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];

        return _commentTile(
          comment['username']!,
          comment['text']!,
        );
      },
    );
  }

  Widget _buildFirestoreComments() {
    final stream = _commentsStream();

    if (stream == null) {
      return _buildDemoComments();
    }

    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load comments',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No comments yet',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 15,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            110,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();

            final username =
                data['username']?.toString() ??
                    data['userName']?.toString() ??
                    data['displayName']?.toString() ??
                    'user';

            final text =
                data['text']?.toString() ??
                    data['comment']?.toString() ??
                    '';

            return _commentTile(
              username.startsWith('@')
                  ? username
                  : '@$username',
              text,
            );
          },
        );
      },
    );
  }

  Widget _commentTile(
    String username,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 20,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _cyan,
                  _pink,
                ],
              ),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 22,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Like',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight =
        MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(
        milliseconds: 220,
      ),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: keyboardHeight,
      ),
      child: Container(
        height:
            MediaQuery.of(context).size.height * 0.62,
        decoration: const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),

            Container(
              width: 45,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius:
                    BorderRadius.circular(20),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                18,
                12,
                16,
              ),
              child: Row(
                children: [
                  Text(
                    '${widget.video.comments + 0} Comments',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(),

                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const SizedBox(
                      width: 45,
                      height: 45,
                      child: Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 31,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              height: 1,
              color: Colors.white12,
            ),

            Expanded(
              child: Stack(
                children: [
                  _buildFirestoreComments(),

                  Align(
                    alignment:
                        Alignment.bottomCenter,
                    child: SafeArea(
                      top: false,
                      child: Container(
                        padding:
                            const EdgeInsets.fromLTRB(
                          16,
                          10,
                          12,
                          10,
                        ),
                        decoration:
                            const BoxDecoration(
                          color: Color(0xFF101010),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white10,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                constraints:
                                    const BoxConstraints(
                                  minHeight: 48,
                                  maxHeight: 110,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color:
                                      const Color(
                                    0xFF292929,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(
                                    25,
                                  ),
                                ),
                                child: TextField(
                                  controller:
                                      _commentController,
                                  focusNode:
                                      _focusNode,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction:
                                      TextInputAction
                                          .newline,
                                  style:
                                      const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                  decoration:
                                      const InputDecoration(
                                    hintText:
                                        'Add a comment...',
                                    hintStyle:
                                        TextStyle(
                                      color:
                                          Colors.white54,
                                      fontSize: 15,
                                    ),
                                    border:
                                        InputBorder.none,
                                    contentPadding:
                                        EdgeInsets
                                            .symmetric(
                                      horizontal: 18,
                                      vertical: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 9),

                            GestureDetector(
                              onTap: _sendComment,
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration:
                                    const BoxDecoration(
                                  shape:
                                      BoxShape.circle,
                                  gradient:
                                      LinearGradient(
                                    colors: [
                                      _cyan,
                                      _pink,
                                    ],
                                  ),
                                ),
                                child: _sending
                                    ? const Padding(
                                        padding:
                                            EdgeInsets.all(
                                          15,
                                        ),
                                        child:
                                            CircularProgressIndicator(
                                          color:
                                              Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.send,
                                        color:
                                            Colors.white,
                                        size: 24,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// POST COMPOSER
// =================================================================

class _PostComposerSheet extends StatefulWidget {
  final File videoFile;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const _PostComposerSheet({
    required this.videoFile,
    required this.firestore,
    required this.auth,
  });

  @override
  State<_PostComposerSheet> createState() =>
      _PostComposerSheetState();
}

class _PostComposerSheetState
    extends State<_PostComposerSheet> {
  late VideoPlayerController _previewController;

  final TextEditingController _captionController =
      TextEditingController();

  final TextEditingController _hashtagsController =
      TextEditingController();

  bool _initializing = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();

    _previewController =
        VideoPlayerController.file(
      widget.videoFile,
    );

    _initializePreview();
  }

  Future<void> _initializePreview() async {
    try {
      await _previewController.initialize();
      await _previewController.setLooping(true);
      await _previewController.play();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _previewController.dispose();
    _captionController.dispose();
    _hashtagsController.dispose();

    super.dispose();
  }

  Future<void> _uploadVideo() async {
    if (_uploading) return;

    final user = widget.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Login required to upload.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      // ----------------------------------------------------------
      // CLOUDINARY
      // ----------------------------------------------------------

      const cloudName = 'u0jufmrl';
      const uploadPreset =
          'palok_video_upload';

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
          widget.videoFile.path,
        ),
      );

      final response = await request.send();

      final responseBody =
          await response.stream.bytesToString();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Cloudinary upload failed: '
          '${response.statusCode}',
        );
      }

      final json =
          jsonDecode(responseBody)
              as Map<String, dynamic>;

      final secureUrl =
          json['secure_url']?.toString();

      if (secureUrl == null ||
          secureUrl.isEmpty) {
        throw Exception(
          'Video URL not received.',
        );
      }

      // ----------------------------------------------------------
      // FIRESTORE
      // ----------------------------------------------------------

      final caption =
          _captionController.text.trim();

      final hashtags =
          _hashtagsController.text.trim();

      await widget.firestore
          .collection('videos')
          .add({
        'videoUrl': secureUrl,
        'userId': user.uid,
        'uid': user.uid,
        'username':
            user.displayName ??
            user.email?.split('@').first ??
            'palok_user',
        'caption': caption,
        'hashtags': hashtags,
        'likes': 0,
        'comments': 0,
        'saves': 0,
        'shares': 0,
        'createdAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Video successfully posted on PALOK 🎉',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Upload failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard =
        MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration:
          const Duration(milliseconds: 220),
      padding: EdgeInsets.only(
        bottom: keyboard,
      ),
      child: Container(
        height:
            MediaQuery.of(context).size.height * 0.86,
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 44,
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
                  15,
                  18,
                  10,
                ),
                child: Row(
                  children: [
                    const Text(
                      'New PALOK Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                    IconButton(
                      onPressed:
                          _uploading
                              ? null
                              : () =>
                                  Navigator.pop(
                                    context,
                                  ),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    5,
                    18,
                    20,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      if (_initializing)
                        const AspectRatio(
                          aspectRatio: 9 / 16,
                          child: Center(
                            child:
                                CircularProgressIndicator(
                              color: _pink,
                            ),
                          ),
                        )
                      else if (_previewController
                          .value
                          .isInitialized)
                        AspectRatio(
                          aspectRatio: 9 / 16,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(
                              18,
                            ),
                            child: VideoPlayer(
                              _previewController,
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      TextField(
                        controller:
                            _captionController,
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
                            color: Colors.white54,
                          ),
                          filled: true,
                          fillColor:
                              Colors.white10,
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                            borderSide:
                                BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller:
                            _hashtagsController,
                        style:
                            const TextStyle(
                          color: Colors.white,
                        ),
                        decoration:
                            InputDecoration(
                          hintText:
                              '#hashtags',
                          hintStyle:
                              const TextStyle(
                            color: Colors.white54,
                          ),
                          prefixIcon:
                              const Icon(
                            Icons.tag,
                            color: Colors.white54,
                          ),
                          filled: true,
                          fillColor:
                              Colors.white10,
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                            borderSide:
                                BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              _uploading
                                  ? null
                                  : _uploadVideo,
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                _pink,
                            disabledBackgroundColor:
                                Colors.white12,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                            ),
                          ),
                          child: _uploading
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child:
                                      CircularProgressIndicator(
                                    color:
                                        Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Post to PALOK',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================================
// VIDEO POST MODEL
// =================================================================

class VideoPost {
  final String id;
  final String videoUrl;
  final String userId;
  final String username;
  final String caption;

  final int likes;
  final int comments;
  final int saves;
  final int shares;

  final bool isAsset;

  const VideoPost({
    required this.id,
    required this.videoUrl,
    required this.userId,
    required this.username,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
    required this.isAsset,
  });
}
