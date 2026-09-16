import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'edit_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  static const Color _pink = Color(0xFFFF2D55);
  static const Color _cyan = Color(0xFF00E5FF);

  final List<String> _demoVideos = [
    'assets/videos/video.mp4',
    'assets/videos/video1.mp4',
    'assets/videos/video2.mp4',
  ];

  final List<VideoPlayerController?> _controllers = [];
  final List<bool> _initializing = [];

  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  final Set<String> _followingIds = {};

  final Map<String, int> _likeDeltas = {};
  final Map<String, int> _commentDeltas = {};
  final Map<String, int> _saveDeltas = {};
  final Map<String, int> _shareDeltas = {};

  List<VideoPost> _videos = [];

  int _currentIndex = 0;
  int _bottomIndex = 0;
  int _topIndex = 0;

  bool _loading = true;

  String _username = 'PALOK User';
  String _bio = '';
  String _email = '';
  String _profileImage = '';

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

    _loadEverything();
  }

  Future<void> _loadEverything() async {
    await Future.wait([
      _loadUserProfile(),
      _loadUserData(),
      _loadVideos(),
    ]);

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }

    await _prepareVideo(0);
  }

  Future<void> _loadUserProfile() async {
    final User? user = _auth.currentUser;

    if (user == null) return;

    _email = user.email ?? '';

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      if (data != null) {
        final savedUsername =
            (data['username'] ?? '').toString().trim();

        final savedBio =
            (data['bio'] ?? '').toString();

        final savedImage =
            (data['profileImage'] ?? '').toString();

        if (savedUsername.isNotEmpty) {
          _username = savedUsername;
        } else if ((user.displayName ?? '').isNotEmpty) {
          _username = user.displayName!;
        } else {
          _username = user.email?.split('@').first ?? 'PALOK User';
        }

        _bio = savedBio;
        _profileImage = savedImage;
      } else {
        _username = user.displayName ??
            user.email?.split('@').first ??
            'PALOK User';
      }
    } catch (_) {
      _username = user.displayName ??
          user.email?.split('@').first ??
          'PALOK User';
    }
  }

  Future<void> _loadUserData() async {
    final User? user = _auth.currentUser;

    if (user == null) return;

    try {
      final liked = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .get();

      final saved = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedVideos')
          .get();

      final following = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();

      _likedIds
        ..clear()
        ..addAll(liked.docs.map((e) => e.id));

      _savedIds
        ..clear()
        ..addAll(saved.docs.map((e) => e.id));

      _followingIds
        ..clear()
        ..addAll(following.docs.map((e) => e.id));
    } catch (_) {}
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

      if (snapshot.docs.isNotEmpty) {
        _videos = snapshot.docs.map((doc) {
          final data = doc.data();

          return VideoPost(
            id: doc.id,
            videoUrl: (data['videoUrl'] ?? '').toString(),
            userId: (data['userId'] ?? '').toString(),
            username: (data['username'] ?? 'PALOK User').toString(),
            caption: (data['caption'] ?? '').toString(),
            hashtags: (data['hashtags'] ?? '').toString(),
            likeCount: _toInt(data['likeCount']),
            commentCount: _toInt(data['commentCount']),
            saveCount: _toInt(data['saveCount']),
            shareCount: _toInt(data['shareCount']),
            thumbnailUrl:
                (data['thumbnailUrl'] ?? '').toString(),
          );
        }).toList();
      } else {
        _createDemoVideos();
      }
    } catch (_) {
      _createDemoVideos();
    }

    _controllers.clear();
    _initializing.clear();

    for (int i = 0; i < _videos.length; i++) {
      _controllers.add(null);
      _initializing.add(false);
    }
  }

  void _createDemoVideos() {
    _videos = [
      VideoPost(
        id: 'demo_1',
        videoUrl: _demoVideos[0],
        userId: 'demo_user_1',
        username: 'palok_user',
        caption: 'Welcome to PALOK 🚀',
        hashtags: '#PALOK #ForYou',
        likeCount: 11700,
        commentCount: 234,
        saveCount: 811,
        shareCount: 431,
      ),
      VideoPost(
        id: 'demo_2',
        videoUrl: _demoVideos[1],
        userId: 'demo_user_2',
        username: 'palok_creator',
        caption: 'Create. Share. Connect.',
        hashtags: '#PALOK #Creator',
        likeCount: 8500,
        commentCount: 128,
        saveCount: 452,
        shareCount: 201,
      ),
      VideoPost(
        id: 'demo_3',
        videoUrl: _demoVideos[2],
        userId: 'demo_user_3',
        username: 'palok_daily',
        caption: 'Your next short video is here.',
        hashtags: '#ShortVideo #PALOK',
        likeCount: 6200,
        commentCount: 94,
        saveCount: 310,
        shareCount: 155,
      ),
    ];
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  Future<void> _prepareVideo(int index) async {
    if (index < 0 || index >= _videos.length) return;

    if (_controllers[index] != null) return;
    if (_initializing[index]) return;

    _initializing[index] = true;

    try {
      final video = _videos[index];

      late VideoPlayerController controller;

      if (video.videoUrl.startsWith('http')) {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(video.videoUrl),
        );
      } else {
        controller = VideoPlayerController.asset(
          video.videoUrl,
        );
      }

      await controller.initialize();

      await controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controllers[index] = controller;
      });

      if (index == _currentIndex) {
        await controller.play();
      }
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
    } finally {
      if (index < _initializing.length) {
        _initializing[index] = false;
      }
    }
  }

  Future<void> _onPageChanged(int index) async {
    if (index < 0 || index >= _videos.length) return;

    if (_currentIndex != index &&
        _controllers[_currentIndex] != null) {
      await _controllers[_currentIndex]!.pause();
    }

    setState(() {
      _currentIndex = index;
    });

    await _prepareVideo(index);

    if (index + 1 < _videos.length) {
      _prepareVideo(index + 1);
    }

    if (index - 1 >= 0) {
      _prepareVideo(index - 1);
    }

    _disposeFarControllers(index);
  }

  void _disposeFarControllers(int index) {
    for (int i = 0; i < _controllers.length; i++) {
      if ((i - index).abs() > 1 &&
          _controllers[i] != null) {
        _controllers[i]!.dispose();
        _controllers[i] = null;
      }
    }
  }

  Future<void> _togglePlay(int index) async {
    final controller = _controllers[index];

    if (controller == null) {
      await _prepareVideo(index);
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
    final User? user = _auth.currentUser;
    if (user == null) return;

    final bool isLiked = _likedIds.contains(video.id);

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
      final ref = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .doc(video.id);

      if (isLiked) {
        await ref.delete();
      } else {
        await ref.set({
          'videoId': video.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestore
          .collection('videos')
          .doc(video.id)
          .set(
        {
          'likeCount': FieldValue.increment(
            isLiked ? -1 : 1,
          ),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> _toggleSave(VideoPost video) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    final bool isSaved = _savedIds.contains(video.id);

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
      final ref = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedVideos')
          .doc(video.id);

      if (isSaved) {
        await ref.delete();
      } else {
        await ref.set({
          'videoId': video.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow(VideoPost video) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    if (video.userId.isEmpty || video.userId == user.uid) {
      return;
    }

    final bool following =
        _followingIds.contains(video.userId);

    setState(() {
      if (following) {
        _followingIds.remove(video.userId);
      } else {
        _followingIds.add(video.userId);
      }
    });

    try {
      final ref = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(video.userId);

      if (following) {
        await ref.delete();
      } else {
        await ref.set({
          'userId': video.userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> _shareVideo(VideoPost video) async {
    try {
      await Share.share(
        'Watch this video on PALOK\n\n'
        'https://palok.app/video/${video.id}',
      );

      setState(() {
        _shareDeltas[video.id] =
            (_shareDeltas[video.id] ?? 0) + 1;
      });

      final User? user = _auth.currentUser;

      if (user != null) {
        await _firestore
            .collection('videos')
            .doc(video.id)
            .collection('shares')
            .add({
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> _openComments(VideoPost video) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CommentsSheet(
          videoId: video.id,
          initialCount: video.commentCount +
              (_commentDeltas[video.id] ?? 0),
        );
      },
    );

    if (result != null && result > 0 && mounted) {
      setState(() {
        _commentDeltas[video.id] =
            (_commentDeltas[video.id] ?? 0) + result;
      });
    }
  }

  Future<void> _openSearch() async {
    final controller = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * .78,
          decoration: const BoxDecoration(
            color: Color(0xFF101010),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(22),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                12,
                18,
                10,
              ),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: TextField(
                            controller: controller,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            cursorColor: _pink,
                            decoration:
                                const InputDecoration(
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.white54,
                              ),
                              hintText:
                                  'Search PALOK',
                              hintStyle: TextStyle(
                                color: Colors.white38,
                              ),
                            ),
                            onChanged: (_) {
                              (context as Element)
                                  .markNeedsBuild();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            'Top',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Users',
                            style: TextStyle(
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Videos',
                            style: TextStyle(
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 35),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Search for creators, videos and hashtags',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    controller.dispose();
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Create on PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _createOption(
                  icon: Icons.videocam_outlined,
                  title: 'Record Video',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickVideo(
                      ImageSource.camera,
                    );
                  },
                ),
                _createOption(
                  icon: Icons.photo_library_outlined,
                  title: 'Upload Video',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickVideo(
                      ImageSource.gallery,
                    );
                  },
                ),
                _createOption(
                  icon: Icons.music_note_outlined,
                  title: 'Add Sound',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content:
                            Text('Sound feature coming soon'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _createOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
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
      final XFile? file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );

      if (file == null) return;

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return _UploadSheet(
            filePath: file.path,
            onPosted: () async {
              await _loadVideos();

              if (mounted) {
                setState(() {});
              }

              await _prepareVideo(_currentIndex);
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video select failed: $e'),
        ),
      );
    }
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditProfileScreen(),
      ),
    );

    if (result != null &&
        result is Map<String, dynamic> &&
        mounted) {
      setState(() {
        _username =
            (result['username'] ?? _username).toString();

        _bio = (result['bio'] ?? _bio).toString();

        _profileImage =
            (result['profileImage'] ?? _profileImage)
                .toString();

        _email =
            (result['email'] ?? _email).toString();
      });
    } else {
      await _loadUserProfile();

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _selectBottom(int index) {
    if (index == 2) {
      _openCreateSheet();
      return;
    }

    setState(() {
      _bottomIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          IndexedStack(
            index: _bottomIndex,
            children: [
              _buildHomeScreen(),
              _buildFriendsScreen(),
              const SizedBox.shrink(),
              _buildInboxScreen(),
              _buildProfileScreen(),
            ],
          ),
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildHomeScreen() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _pink,
        ),
      );
    }

    if (_videos.isEmpty) {
      return const Center(
        child: Text(
          'No videos yet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      );
    }

    List<VideoPost> feed = _videos;

    if (_topIndex == 1) {
      feed = _videos.where((video) {
        return _followingIds.contains(video.userId);
      }).toList();

      if (feed.isEmpty) {
        feed = _videos;
      }
    }

    return Stack(
      children: [
        PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: feed.length,
          onPageChanged: (index) {
            final actualIndex =
                _videos.indexOf(feed[index]);

            if (actualIndex >= 0) {
              _onPageChanged(actualIndex);
            }
          },
          itemBuilder: (context, index) {
            final video = feed[index];
            final actualIndex =
                _videos.indexOf(video);

            return _buildVideoPage(
              video,
              actualIndex,
            );
          },
        ),
        _buildTopBar(),
      ],
    );
  }

  Widget _buildVideoPage(
    VideoPost video,
    int index,
  ) {
    final controller =
        index >= 0 && index < _controllers.length
            ? _controllers[index]
            : null;

    return GestureDetector(
      onTap: () {
        _togglePlay(index);
      },
      onDoubleTap: () {
        if (!_likedIds.contains(video.id)) {
          _toggleLike(video);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),

          if (controller != null &&
              controller.value.isInitialized)
            Center(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),

          if (controller != null &&
              controller.value.isInitialized &&
              !controller.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white70,
                size: 74,
              ),
            ),

          _buildVideoInfo(video),

          _buildRightActions(video),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            14,
            12,
            12,
            0,
          ),
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
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            _cyan,
                            _pink,
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(15),
                      ),
                      child: const Center(
                        child: Text(
                          'P',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 29,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'PALOK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
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
                child: _topTab(
                  'For You',
                  _topIndex == 0,
                ),
              ),
              const SizedBox(width: 22),
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
              const SizedBox(width: 13),
              IconButton(
                onPressed: _openSearch,
                icon: const Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 29,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topTab(
    String text,
    bool selected,
  ) {
    return Text(
      text,
      style: TextStyle(
        color: selected
            ? Colors.white
            : Colors.white54,
        fontSize: 16,
        fontWeight: selected
            ? FontWeight.w800
            : FontWeight.w500,
      ),
    );
  }

  Widget _buildRightActions(VideoPost video) {
    final bool liked = _likedIds.contains(video.id);
    final bool saved = _savedIds.contains(video.id);
    final bool following =
        _followingIds.contains(video.userId);

    final int likes = video.likeCount +
        (_likeDeltas[video.id] ?? 0);

    final int comments = video.commentCount +
        (_commentDeltas[video.id] ?? 0);

    final int saves = video.saveCount +
        (_saveDeltas[video.id] ?? 0);

    final int shares = video.shareCount +
        (_shareDeltas[video.id] ?? 0);

    return Positioned(
      right: 10,
      bottom: 116,
      child: Column(
        children: [
          _actionButton(
            icon: Icons.person_add_alt_1,
            label: following ? 'Following' : 'Follow',
            onTap: () => _toggleFollow(video),
          ),
          const SizedBox(height: 15),
          _actionButton(
            icon: liked
                ? Icons.favorite
                : Icons.favorite_border,
            label: _formatCount(likes),
            active: liked,
            onTap: () => _toggleLike(video),
          ),
          const SizedBox(height: 15),
          _actionButton(
            icon: Icons.chat_bubble_outline,
            label: _formatCount(comments),
            onTap: () => _openComments(video),
          ),
          const SizedBox(height: 15),
          _actionButton(
            icon: saved
                ? Icons.bookmark
                : Icons.bookmark_border,
            label: _formatCount(saves),
            active: saved,
            onTap: () => _toggleSave(video),
          ),
          const SizedBox(height: 15),
          _actionButton(
            icon: Icons.share_outlined,
            label: _formatCount(shares),
            onTap: () => _shareVideo(video),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.38),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(.16),
              ),
            ),
            child: Icon(
              icon,
              color: active ? _pink : Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInfo(VideoPost video) {
    return Positioned(
      left: 18,
      right: 92,
      bottom: 124,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '@${video.username}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            video.caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (video.hashtags.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              video.hashtags,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendsScreen() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(
          top: 15,
          bottom: 85,
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Row(
                children: [
                  Text(
                    'Friends',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.search,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Expanded(
              child: _followingIds.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: Colors.white54,
                            size: 55,
                          ),
                          SizedBox(height: 15),
                          Text(
                            'Find friends on PALOK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Follow creators to see them here.',
                            style: TextStyle(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      children: _videos
                          .where(
                            (v) => _followingIds
                                .contains(v.userId),
                          )
                          .map(
                            (video) => ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                vertical: 5,
                              ),
                              leading: const CircleAvatar(
                                backgroundColor: _pink,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                '@${video.username}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text(
                                'Following',
                                style: TextStyle(
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxScreen() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: 85,
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                20,
              ),
              child: Row(
                children: [
                  Text(
                    'Inbox',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.more_horiz,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white70,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No messages yet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Your messages and notifications\nwill appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileScreen() {
    final User? user = _auth.currentUser;

    final String displayName = _username.isNotEmpty
        ? _username
        : user?.displayName ??
            user?.email?.split('@').first ??
            'PALOK User';

    final String email =
        _email.isNotEmpty ? _email : user?.email ?? '';

    final int followingCount =
        _followingIds.length;

    final int likesCount = _videos
        .where((video) =>
            video.userId == user?.uid)
        .fold<int>(
          0,
          (sum, video) =>
              sum +
              video.likeCount +
              (_likeDeltas[video.id] ?? 0),
        );

    final myVideos = _videos
        .where((video) =>
            video.userId == user?.uid)
        .toList();

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          bottom: 100,
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: 22,
                ),
                child: IconButton(
                  onPressed: () {
                    _showProfileMenu();
                  },
                  icon: const Icon(
                    Icons.menu,
                    color: Colors.white,
                    size: 31,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 3),

            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    _cyan,
                    _pink,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: _profileImage.isNotEmpty
                      ? Image.network(
                          _profileImage,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stack) {
                            return const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 58,
                            );
                          },
                        )
                      : const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 58,
                        ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              email,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 15,
              ),
            ),

            if (_bio.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 35,
                ),
                child: Text(
                  _bio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 28),

            Row(
              children: [
                Expanded(
                  child: _profileStat(
                    '$followingCount',
                    'Following',
                  ),
                ),
                Expanded(
                  child: _profileStat(
                    '0',
                    'Followers',
                  ),
                ),
                Expanded(
                  child: _profileStat(
                    _formatCount(likesCount),
                    'Likes',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _openEditProfile,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Colors.white30,
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Edit profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            Container(
              height: 1,
              color: Colors.white12,
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _profileTab(
                    Icons.grid_on,
                    true,
                  ),
                ),
                Expanded(
                  child: _profileTab(
                    Icons.lock_outline,
                    false,
                  ),
                ),
                Expanded(
                  child: _profileTab(
                    Icons.bookmark_border,
                    false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (myVideos.isEmpty)
              SizedBox(
                height: 260,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.video_library_outlined,
                        color: Colors.white38,
                        size: 48,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Your videos will appear here',
                        style: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 3,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: .62,
                ),
                itemCount: myVideos.length,
                itemBuilder: (context, index) {
                  return _profileVideoTile(
                    myVideos[index],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _profileStat(
    String value,
    String label,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _profileTab(
    IconData icon,
    bool selected,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: selected
              ? Colors.white
              : Colors.white38,
          size: 26,
        ),
        const SizedBox(height: 8),
        if (selected)
          Container(
            height: 2,
            width: 48,
            color: Colors.white,
          ),
      ],
    );
  }

  Widget _profileVideoTile(VideoPost video) {
    return GestureDetector(
      onTap: () {
        final index = _videos.indexOf(video);

        if (index >= 0) {
          setState(() {
            _bottomIndex = 0;
            _currentIndex = index;
          });

          _prepareVideo(index);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: const Color(0xFF1A1A1A),
            child: video.thumbnailUrl.isNotEmpty
                ? Image.network(
                    video.thumbnailUrl,
                    fit: BoxFit.cover,
                  )
                : const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Row(
              children: [
                const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 17,
                ),
                const SizedBox(width: 2),
                Text(
                  _formatCount(video.likeCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProfileMenu() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content:
                          Text('Settings coming soon'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Colors.white,
                ),
                title: const Text(
                  'Log out',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  await _auth.signOut();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
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
            color: Colors.black.withOpacity(.94),
            border: const Border(
              top: BorderSide(
                color: Colors.white10,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _bottomItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  index: 0,
                ),
              ),
              Expanded(
                child: _bottomItem(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Friends',
                  index: 1,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectBottom(2),
                  child: Center(
                    child: Container(
                      width: 92,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            _cyan,
                            _pink,
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: _pink.withOpacity(.25),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _bottomItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: 'Inbox',
                  index: 3,
                ),
              ),
              Expanded(
                child: _bottomItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  index: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final bool selected = _bottomIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectBottom(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? activeIcon : icon,
            color: selected
                ? Colors.white
                : Colors.white54,
            size: 26,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white54,
              fontSize: 12,
              fontWeight: selected
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
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

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller?.dispose();
    }

    _logoController.dispose();

    super.dispose();
  }
}

class VideoPost {
  final String id;
  final String videoUrl;
  final String userId;
  final String username;
  final String caption;
  final String hashtags;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final int shareCount;
  final String thumbnailUrl;

  VideoPost({
    required this.id,
    required this.videoUrl,
    required this.userId,
    required this.username,
    required this.caption,
    required this.hashtags,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.shareCount,
    this.thumbnailUrl = '',
  });
}

class _CommentsSheet extends StatefulWidget {
  final String videoId;
  final int initialCount;

  const _CommentsSheet({
    required this.videoId,
    required this.initialCount,
  });

  @override
  State<_CommentsSheet> createState() =>
      _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final TextEditingController _controller =
      TextEditingController();

  int _addedCount = 0;

  Future<void> _sendComment() async {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    final User? user = _auth.currentUser;

    if (user == null) return;

    try {
      await _firestore
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'username':
            user.displayName ??
            user.email?.split('@').first ??
            'PALOK User',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('videos')
          .doc(widget.videoId)
          .set(
        {
          'commentCount':
              FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      _controller.clear();

      setState(() {
        _addedCount++;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final keyboard =
        MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * .68,
      decoration: const BoxDecoration(
        color: Color(0xFF101010),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                22,
                15,
                16,
              ),
              child: Row(
                children: [
                  Text(
                    '${widget.initialCount + _addedCount} Comments',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        _addedCount,
                      );
                    },
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              color: Colors.white10,
            ),
            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('videos')
                    .doc(widget.videoId)
                    .collection('comments')
                    .orderBy(
                      'createdAt',
                      descending: false,
                    )
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Comments',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 18,
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 17,
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();

                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 18,
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 19,
                              backgroundColor:
                                  Color(0xFF252525),
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@${data['username'] ?? 'user'}',
                                    style:
                                        const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${data['text'] ?? ''}',
                                    style:
                                        const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                15,
                10,
                15,
                10 + keyboard,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      cursorColor: const Color(
                        0xFFFF2D55,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor:
                            const Color(0xFF292929),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  GestureDetector(
                    onTap: _sendComment,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration:
                          const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF00E5FF),
                            Color(0xFFFF2D55),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 22,
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _UploadSheet extends StatefulWidget {
  final String filePath;
  final Future<void> Function() onPosted;

  const _UploadSheet({
    required this.filePath,
    required this.onPosted,
  });

  @override
  State<_UploadSheet> createState() =>
      _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  final TextEditingController _captionController =
      TextEditingController();

  final TextEditingController _hashtagsController =
      TextEditingController();

  VideoPlayerController? _controller;

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _controller =
        VideoPlayerController.file(
      File(widget.filePath),
    );

    _controller!.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _controller!.setLooping(true);
        _controller!.play();
      }
    });
  }

  Future<void> _postVideo() async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() {
      _loading = true;
    });

    try {
      /*
       * এখানে তোমার আগের Cloudinary upload system
       * ব্যবহার করতে পারবে।
       *
       * আপাতত selected video-এর local path Firestore-এ
       * দেওয়া হচ্ছে না, কারণ local path অন্য ডিভাইসে
       * কাজ করবে না।
       *
       * তোমার আগের Cloudinary code থাকলে এখানে
       * সেটি বসাতে হবে।
       */

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Upload system-এর Cloudinary step connect করতে হবে',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * .82,
      decoration: const BoxDecoration(
        color: Color(0xFF101010),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                18,
                10,
                10,
              ),
              child: Row(
                children: [
                  const Text(
                    'New post',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius:
                            BorderRadius.circular(15),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _controller != null &&
                              _controller!
                                  .value
                                  .isInitialized
                          ? FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!
                                    .value
                                    .size
                                    .width,
                                height: _controller!
                                    .value
                                    .size
                                    .height,
                                child: VideoPlayer(
                                  _controller!,
                                ),
                              ),
                            )
                          : const Center(
                              child:
                                  CircularProgressIndicator(
                                color: Color(
                                  0xFFFF2D55,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _captionController,
                      maxLines: 4,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Write a caption...',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor:
                            const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(13),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _hashtagsController,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            '#hashtags',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor:
                            const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(13),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                15,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _loading ? null : _postVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFFF2D55),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(13),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w800,
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

  @override
  void dispose() {
    _controller?.dispose();
    _captionController.dispose();
    _hashtagsController.dispose();
    super.dispose();
  }
}
