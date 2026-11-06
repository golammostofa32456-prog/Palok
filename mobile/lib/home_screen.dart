import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'features/comments/comments_sheet.dart';
import 'features/create/create_video_screen.dart';
import 'features/feed/following_feed.dart';
import 'features/feed/for_you_feed.dart';
import 'features/friends/friends_screen.dart';
import 'features/home/home_top_bar.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/navigation/bottom_navigator.dart';
import 'features/profile/profile_screen.dart';
import 'features/search/search_screen.dart';
import 'features/upload/upload_sheet.dart';
import 'features/video/video_action_stack.dart';
import 'features/video/video_page.dart';
import 'features/video/video_post.dart';
import 'features/video/video_url.dart';
import 'features/video/video_view_service.dart';

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

  final List<String> _demoVideos = const [
    'assets/videos/video.mp4',
    'assets/videos/video1.mp4',
    'assets/videos/video2.mp4',
  ];

  final Map<int, VideoPlayerController> _controllers = {};

  // একই ভিডিও দুইবার initialize হওয়া আটকাতে।
  final Map<int, Future<void>> _preparingVideos = {};

  // প্রিলোড করা পরের ভিডিওর index (dispose থেকে বাঁচাতে)।
  int? _nextIndex;

  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  final Set<String> _followingIds = {};

  final Map<String, int> _likeDeltas = {};
  final Map<String, int> _commentDeltas = {};
  final Map<String, int> _saveDeltas = {};
  final Map<String, int> _shareDeltas = {};

  final PageController _pageController = PageController();
  final VideoViewService _videoViewService = VideoViewService();

  List<VideoPost> _videos = [];

  int _currentIndex = 0;
  int _bottomIndex = 0;
  int _topIndex = 0;

  bool _loading = true;

  String _username = 'PALOK User';

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

    _logoScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _logoOpacity = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _loadEverything();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pageController.dispose();

    for (final controller in _controllers.values) {
      controller.dispose();
    }

    _controllers.clear();
    _preparingVideos.clear();

    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadEverything() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    await Future.wait([
      _loadUserProfile(),
      _loadUserData(),
      _loadVideos(),
    ]);

    if (!mounted) return;

    setState(() => _loading = false);

    if (_videos.isNotEmpty) {
      unawaited(_registerVideoView(_videos[0]));

      await _prepareVideo(0);

      _preloadNextInFeed(_videos, 0);
    }
  }

  Future<void> _registerVideoView(VideoPost video) async {
    if (video.id.startsWith('demo_')) {
      return;
    }

    try {
      final registered = await _videoViewService.registerView(
        videoId: video.id,
      );

      if (!registered || !mounted) {
        return;
      }

      final index = _videos.indexWhere((item) => item.id == video.id);

      if (index < 0) {
        return;
      }

      setState(() {
        _videos[index] = _videos[index].copyWith(
          viewCount: _videos[index].viewCount + 1,
        );
      });
    } catch (_) {
      // View tracking failure must never stop video playback.
    }
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      final data = doc.data();

      _username = (data?['username'] ??
              data?['displayName'] ??
              user.displayName ??
              'PALOK User')
          .toString();
    } catch (_) {
      _username = user.displayName ?? 'PALOK User';
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final userRef = _firestore.collection('users').doc(user.uid);

      final results = await Future.wait([
        userRef.collection('likedVideos').get(),
        userRef.collection('savedVideos').get(),
        userRef.collection('following').get(),
      ]);

      _likedIds
        ..clear()
        ..addAll(results[0].docs.map((e) => e.id));

      _savedIds
        ..clear()
        ..addAll(results[1].docs.map((e) => e.id));

      _followingIds
        ..clear()
        ..addAll(results[2].docs.map((e) => e.id));
    } catch (_) {}
  }

  Future<void> _loadVideos() async {
    _preparingVideos.clear();
    _nextIndex = null;

    for (final controller in _controllers.values) {
      await controller.dispose();
    }

    _controllers.clear();

    try {
      final snapshot = await _firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _videos = snapshot.docs
            .map((doc) => VideoPost.fromMap(doc.id, doc.data()))
            .where((video) => video.videoUrl.isNotEmpty)
            .toList();

        if (_videos.isNotEmpty) {
          return;
        }
      }
    } catch (_) {
      // Firebase query failed. Demo feed will be used below.
    }

    const names = ['@palok_creator', '@nature_palok', '@palok_video'];
    const captions = [
      'Welcome to PALOK ✨',
      'Beautiful moments on PALOK 🌿',
      'Create. Share. Connect. 🚀',
    ];
    const tags = [
      ['#PALOK', '#ForYou'],
      ['#Nature', '#PALOK'],
      ['#PALOK', '#ShortVideo'],
    ];
    const likes = [11700, 8500, 4200];
    const comments = [234, 128, 75];
    const saves = [811, 452, 210];
    const shares = [431, 201, 98];

    _videos = List.generate(
      _demoVideos.length,
      (index) => VideoPost(
        id: 'demo_$index',
        ownerId: 'demo_user_$index',
        username: names[index],
        videoUrl: _demoVideos[index],
        caption: captions[index],
        hashtags: tags[index],
        thumbnailUrl: '',
        soundName: '',
        likeCount: likes[index],
        commentCount: comments[index],
        saveCount: saves[index],
        shareCount: shares[index],
        viewCount: 0,
        createdAt: null,
      ),
    );
  }

  // ============================================================
  // VIDEO PRELOAD (ডাটা বাঁচাতে: বর্তমান + পরের ভিডিও)
  // ============================================================

  Future<void> _prepareVideo(int index) async {
    if (!mounted || index < 0 || index >= _videos.length) {
      return;
    }

    final existing = _controllers[index];

    // আগে থেকে তৈরি থাকলে আবার initialize করবে না।
    if (existing != null) {
      if (existing.value.isInitialized) {
        if (index == _currentIndex &&
            _bottomIndex == 0 &&
            !existing.value.isPlaying) {
          unawaited(existing.play());
        }
      }

      return;
    }

    // একই ভিডিও ইতিমধ্যে initialize হচ্ছে কি না।
    final preparing = _preparingVideos[index];

    if (preparing != null) {
      await preparing;
      return;
    }

    final future = _initializeVideo(index);

    _preparingVideos[index] = future;

    try {
      await future;
    } finally {
      if (identical(_preparingVideos[index], future)) {
        _preparingVideos.remove(index);
      }
    }
  }

  Future<void> _initializeVideo(int index) async {
    if (!mounted || index < 0 || index >= _videos.length) {
      return;
    }

    final video = _videos[index];

    VideoPlayerController? controller;

    try {
      if (_isNetworkUrl(video.videoUrl)) {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(optimizeVideoUrl(video.videoUrl)),
        );
      } else {
        controller = VideoPlayerController.asset(video.videoUrl);
      }

      _controllers[index] = controller;

      await controller.initialize();

      if (!mounted || !identical(_controllers[index], controller)) {
        try {
          await controller.dispose();
        } catch (_) {}
        return;
      }

      await controller.setLooping(true);

      if (!mounted || !identical(_controllers[index], controller)) {
        return;
      }

      // শুধু current video automatically play হবে।
      if (index == _currentIndex && _bottomIndex == 0) {
        unawaited(controller.play());
      }

      if (mounted) {
        setState(() {});
      }

      _disposeFarControllers(_currentIndex);
    } catch (_) {
      if (controller != null && identical(_controllers[index], controller)) {
        _controllers.remove(index);
      }

      try {
        await controller?.dispose();
      } catch (_) {}

      if (mounted) {
        setState(() {});
      }
    }
  }

  // Current-এর আগে/পরে ১টি এবং প্রিলোড করা পরের ভিডিও ছাড়া বাকিগুলো মুছে দেয়।
  void _disposeFarControllers(int centerIndex) {
    final keys = _controllers.keys.toList();

    for (final key in keys) {
      final isNear = (key - centerIndex).abs() <= 1;

      if (isNear || key == _nextIndex) {
        continue;
      }

      final controller = _controllers.remove(key);

      if (controller != null) {
        unawaited(controller.dispose());
      }
    }
  }

  // ফিডের পরের ভিডিওটা প্রিলোড করে (শুধু ১টা)।
  void _preloadNextInFeed(List<VideoPost> feed, int pageIndex) {
    final next = pageIndex + 1;

    if (next < 0 || next >= feed.length) {
      return;
    }

    final actual = _videos.indexWhere((video) => video.id == feed[next].id);

    if (actual < 0) {
      return;
    }

    _nextIndex = actual;

    unawaited(_prepareVideo(actual));
  }

  bool _isNetworkUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  // ============================================================
  // VIDEO CHANGE
  // ============================================================

  Future<void> _onVideoChanged(
    int pageIndex,
    List<VideoPost> feed,
  ) async {
    if (pageIndex < 0 || pageIndex >= feed.length) {
      return;
    }

    final selectedVideo = feed[pageIndex];

    final actualIndex = _videos.indexWhere(
      (video) => video.id == selectedVideo.id,
    );

    if (actualIndex < 0) {
      return;
    }

    // পুরোনো controller pause করবো, কিন্তু wait করবো না।
    for (final entry in _controllers.entries) {
      if (entry.key != actualIndex) {
        unawaited(entry.value.pause());
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex = actualIndex;
    });

    unawaited(_registerVideoView(_videos[actualIndex]));

    // বর্তমান ভিডিও আগে লোড হবে, তারপর পরেরটা প্রিলোড।
    unawaited(
      _prepareVideo(actualIndex).whenComplete(() {
        if (mounted && _currentIndex == actualIndex) {
          _preloadNextInFeed(feed, pageIndex);
        }
      }),
    );

    _disposeFarControllers(actualIndex);
  }

  Future<void> _togglePlay(int actualIndex) async {
    final controller = _controllers[actualIndex];

    if (controller == null || !controller.value.isInitialized) {
      await _prepareVideo(actualIndex);
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
  // LIKE / SAVE / FOLLOW / SHARE
  // ============================================================

  void _bump(Map<String, int> map, String id, int by) {
    map[id] = (map[id] ?? 0) + by;
  }

  Future<void> _toggleLike(VideoPost video) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Like করতে Login করতে হবে');
      return;
    }

    final wasLiked = _likedIds.contains(video.id);

    if (mounted) {
      setState(() {
        if (wasLiked) {
          _likedIds.remove(video.id);
          _bump(_likeDeltas, video.id, -1);
        } else {
          _likedIds.add(video.id);
          _bump(_likeDeltas, video.id, 1);
        }
      });
    }

    try {
      final likeRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .doc(video.id);

      if (wasLiked) {
        await likeRef.delete();
      } else {
        await likeRef.set({
          'videoId': video.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!video.id.startsWith('demo_')) {
        await _firestore.collection('videos').doc(video.id).set(
          {'likeCount': FieldValue.increment(wasLiked ? -1 : 1)},
          SetOptions(merge: true),
        );
      }

      if (!wasLiked && video.userId.isNotEmpty && video.userId != user.uid) {
        await _createNotification(
          targetUserId: video.userId,
          type: 'like',
          text: 'তোমার ভিডিওটি Like করেছে',
          videoId: video.id,
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (wasLiked) {
          _likedIds.add(video.id);
          _bump(_likeDeltas, video.id, 1);
        } else {
          _likedIds.remove(video.id);
          _bump(_likeDeltas, video.id, -1);
        }
      });

      _showMessage('Like পরিবর্তন করা যায়নি');
    }
  }

  Future<void> _toggleSave(VideoPost video) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Save করতে Login করতে হবে');
      return;
    }

    final wasSaved = _savedIds.contains(video.id);

    if (mounted) {
      setState(() {
        if (wasSaved) {
          _savedIds.remove(video.id);
          _bump(_saveDeltas, video.id, -1);
        } else {
          _savedIds.add(video.id);
          _bump(_saveDeltas, video.id, 1);
        }
      });
    }

    try {
      final saveRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedVideos')
          .doc(video.id);

      if (wasSaved) {
        await saveRef.delete();
      } else {
        await saveRef.set({
          'videoId': video.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!video.id.startsWith('demo_')) {
        await _firestore.collection('videos').doc(video.id).set(
          {'saveCount': FieldValue.increment(wasSaved ? -1 : 1)},
          SetOptions(merge: true),
        );
      }

      if (mounted) {
        _showMessage(
          wasSaved ? 'ভিডিওটি Unsave করা হয়েছে' : 'ভিডিওটি Saved হয়েছে',
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (wasSaved) {
          _savedIds.add(video.id);
          _bump(_saveDeltas, video.id, 1);
        } else {
          _savedIds.remove(video.id);
          _bump(_saveDeltas, video.id, -1);
        }
      });

      _showMessage('Save করা যায়নি');
    }
  }

  Future<void> _toggleFollow(VideoPost video) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Follow করতে Login করতে হবে');
      return;
    }

    if (video.userId.isEmpty || video.userId == user.uid) {
      _showMessage('নিজের Profile Follow করা যাবে না');
      return;
    }

    final wasFollowing = _followingIds.contains(video.userId);

    if (mounted) {
      setState(() {
        if (wasFollowing) {
          _followingIds.remove(video.userId);
        } else {
          _followingIds.add(video.userId);
        }
      });
    }

    try {
      final followingRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(video.userId);

      if (wasFollowing) {
        await followingRef.delete();
      } else {
        await followingRef.set({
          'userId': video.userId,
          'username': video.username,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // অন্যের followers তালিকায় নিজেকে যোগ/বাদ (প্রোফাইলে Followers গোনার জন্য)।
      try {
        final followerRef = _firestore
            .collection('users')
            .doc(video.userId)
            .collection('followers')
            .doc(user.uid);

        if (wasFollowing) {
          await followerRef.delete();
        } else {
          await followerRef.set({
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}

      try {
        await _firestore.collection('users').doc(user.uid).set(
          {'followingCount': FieldValue.increment(wasFollowing ? -1 : 1)},
          SetOptions(merge: true),
        );
      } catch (_) {}

      try {
        await _firestore.collection('users').doc(video.userId).set(
          {'followersCount': FieldValue.increment(wasFollowing ? -1 : 1)},
          SetOptions(merge: true),
        );
      } catch (_) {}

      if (!wasFollowing) {
        await _createNotification(
          targetUserId: video.userId,
          type: 'follow',
          text: 'তোমাকে Follow করেছে',
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (wasFollowing) {
          _followingIds.add(video.userId);
        } else {
          _followingIds.remove(video.userId);
        }
      });

      _showMessage('Follow পরিবর্তন করা যায়নি');
    }
  }

  Future<void> _shareVideo(VideoPost video) async {
    final user = _auth.currentUser;

    final link = 'https://palok.app/video/${video.id}';

    try {
      await Share.share('Watch this video on PALOK\n\n$link');

      if (mounted) {
        setState(() {
          _bump(_shareDeltas, video.id, 1);
        });
      }

      if (!video.id.startsWith('demo_')) {
        try {
          await _firestore.collection('videos').doc(video.id).set(
            {'shareCount': FieldValue.increment(1)},
            SetOptions(merge: true),
          );
        } catch (_) {}
      }

      if (user != null && !video.id.startsWith('demo_')) {
        try {
          await _firestore
              .collection('videos')
              .doc(video.id)
              .collection('shares')
              .add({
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _createNotification({
    required String targetUserId,
    required String type,
    required String text,
    String? videoId,
  }) async {
    final user = _auth.currentUser;

    if (user == null || targetUserId.isEmpty || targetUserId == user.uid) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('notifications')
          .add({
        'type': type,
        'fromUserId': user.uid,
        'fromUsername': _username,
        'text': text,
        'videoId': videoId ?? '',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ============================================================
  // COMMENTS / SEARCH
  // ============================================================

  Future<void> _openComments(VideoPost video) async {
    final added = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return CommentsSheet(
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
        _bump(_commentDeltas, video.id, added);
      });
    }
  }

  Future<void> _openSearch() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SearchScreen(
          videos: _videos,
          onVideoSelected: _goToVideo,
        );
      },
    );
  }

  Future<void> _goToVideo(int actualIndex) async {
    if (!mounted) return;

    await _selectBottom(0);

    if (_topIndex != 0) {
      setState(() {
        _topIndex = 0;
      });
    }

    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        actualIndex,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } else {
      setState(() {
        _currentIndex = actualIndex;
      });

      await _prepareVideo(actualIndex);
    }
  }

  // ============================================================
  // CREATE / UPLOAD
  // ============================================================

  Future<void> _openCreateScreen() async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Video upload করতে Login করতে হবে');
      return;
    }

    final videoPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const CreateVideoScreen(),
      ),
    );

    if (videoPath == null || videoPath.isEmpty || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return UploadSheet(
            filePath: videoPath,
            username: _username,
            userId: user.uid,
            firestore: _firestore,
            onPosted: () async {
              await _reloadAfterUpload();
            },
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    if (_bottomIndex == 0 && _videos.isNotEmpty) {
      await _prepareVideo(_currentIndex);
    }
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            decoration: const BoxDecoration(
              color: Color(0xFF111111),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
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
                const SizedBox(height: 18),
                const Text(
                  'Create on PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _createOption(
                  icon: Icons.videocam_rounded,
                  title: 'Record Video',
                  subtitle: 'Camera দিয়ে নতুন ভিডিও তৈরি করুন',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickVideo(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 10),
                _createOption(
                  icon: Icons.video_library_rounded,
                  title: 'Upload Video',
                  subtitle: 'Gallery থেকে ভিডিও নির্বাচন করুন',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickVideo(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 10),
                _createOption(
                  icon: Icons.music_note_rounded,
                  title: 'Add Sound',
                  subtitle: 'Sound feature পরে যোগ করা যাবে',
                  onTap: () {
                    Navigator.pop(context);
                    _showMessage('Sound feature coming soon');
                  },
                ),
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
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_pink, _cyan]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Video upload করতে Login করতে হবে');
      return;
    }

    try {
      final XFile? file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );

      if (file == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) {
            return UploadSheet(
              filePath: file.path,
              username: _username,
              userId: user.uid,
              firestore: _firestore,
              onPosted: () async {
                await _reloadAfterUpload();
              },
            );
          },
        ),
      );

      if (!mounted) {
        return;
      }

      if (_bottomIndex == 0 && _videos.isNotEmpty) {
        await _prepareVideo(_currentIndex);
      }
    } catch (_) {
      _showMessage('ভিডিও নির্বাচন করা যায়নি');
    }
  }

  Future<void> _reloadAfterUpload() async {
    await _loadUserData();
    await _loadVideos();

    if (!mounted) return;

    setState(() {
      _currentIndex = 0;
      _topIndex = 0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    if (_videos.isNotEmpty) {
      await _prepareVideo(0);
      _preloadNextInFeed(_videos, 0);
    }
  }

  // ============================================================
  // BOTTOM / TOP TABS
  // ============================================================

  Future<void> _selectBottom(int index) async {
    if (index == _bottomIndex) {
      if (index == 0 && _videos.isNotEmpty) {
        await _prepareVideo(_currentIndex);
      }

      return;
    }

    if (_bottomIndex == 0) {
      for (final controller in _controllers.values) {
        unawaited(controller.pause());
      }
    }

    if (!mounted) return;

    if (index == 2) {
      await _openCreateScreen();

      if (!mounted) return;

      if (_bottomIndex == 0) {
        await _prepareVideo(_currentIndex);
      }

      return;
    }

    setState(() {
      _bottomIndex = index;
    });

    if (index == 0) {
      await _prepareVideo(_currentIndex);
    }
  }

  Future<void> _switchTopTab(int index) async {
    if (_topIndex == index) {
      return;
    }

    for (final controller in _controllers.values) {
      unawaited(controller.pause());
    }

    if (!mounted) return;

    setState(() {
      _topIndex = index;
    });

    if (index == 0) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      setState(() {
        _currentIndex = 0;
      });

      await _prepareVideo(0);

      _preloadNextInFeed(_videos, 0);

      return;
    }

    final following = _videos
        .where((video) => _followingIds.contains(video.userId))
        .toList();

    if (following.isNotEmpty) {
      final actualIndex = _videos.indexWhere(
        (video) => video.id == following.first.id,
      );

      setState(() {
        _currentIndex = actualIndex < 0 ? 0 : actualIndex;
      });

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      await _prepareVideo(_currentIndex);

      _preloadNextInFeed(following, 0);
    }
  }

  // ============================================================
  // HOME FEED
  // ============================================================

  Widget _buildHomeScreen() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _pink),
      );
    }

    // FOLLOWING FEED
    if (_topIndex == 1) {
      return FollowingFeed(
        videos: _videos,
        followingIds: _followingIds,
        pageController: _pageController,
        onPageChanged: (index, feed) {
          final typedFeed = feed.cast<VideoPost>();

          unawaited(_onVideoChanged(index, typedFeed));
        },
        itemBuilder: (context, index, feed) {
          final video = feed[index] as VideoPost;

          final actualIndex = _videos.indexWhere(
            (item) => item.id == video.id,
          );

          final controller = _controllers[actualIndex];

          return _buildVideoPage(
            video: video,
            actualIndex: actualIndex,
            controller: controller,
          );
        },
        emptyBuilder: _buildEmptyFeed,
      );
    }

    // FOR YOU FEED
    final feed = _videos;

    if (feed.isEmpty) {
      return _buildEmptyFeed();
    }

    return ForYouFeed(
      videos: feed,
      pageController: _pageController,
      onPageChanged: (index) {
        unawaited(_onVideoChanged(index, feed));
      },
      itemBuilder: (context, index) {
        final video = feed[index];

        final actualIndex = _videos.indexWhere(
          (item) => item.id == video.id,
        );

        final controller = _controllers[actualIndex];

        return _buildVideoPage(
          video: video,
          actualIndex: actualIndex,
          controller: controller,
        );
      },
    );
  }

  Widget _buildEmptyFeed() {
    if (_topIndex == 1) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_outline_rounded,
                color: Colors.white54,
                size: 62,
              ),
              const SizedBox(height: 18),
              const Text(
                'Following feed এখনো খালি',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Creators-কে Follow করলে তাদের ভিডিও এখানে দেখা যাবে।',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _switchTopTab(0);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('For You দেখুন'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.video_collection_outlined,
            color: Colors.white54,
            size: 58,
          ),
          const SizedBox(height: 14),
          const Text(
            'No videos yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _openCreateSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upload Video'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPage({
    required VideoPost video,
    required int actualIndex,
    required VideoPlayerController? controller,
  }) {
    return VideoPage(
      video: video,
      controller: controller,
      onTap: () {
        unawaited(_togglePlay(actualIndex));
      },
      onDoubleTap: () {
        if (!_likedIds.contains(video.id)) {
          unawaited(_toggleLike(video));
        }
      },
      topBar: _buildTopBar(),
      rightActions: _buildRightActions(video),
      videoInfo: _buildVideoInfo(video),
    );
  }

  Widget _buildTopBar() {
    return HomeTopBar(
      logoOpacity: _logoOpacity,
      logoScale: _logoScale,
      topIndex: _topIndex,
      onForYou: () {
        unawaited(_switchTopTab(0));
      },
      onFollowing: () {
        unawaited(_switchTopTab(1));
      },
      onSearch: _openSearch,
      pink: _pink,
      cyan: _cyan,
    );
  }

  Widget _buildRightActions(VideoPost video) {
    final liked = _likedIds.contains(video.id);
    final saved = _savedIds.contains(video.id);
    final following = _followingIds.contains(video.userId);

    final likeCount = video.likeCount + (_likeDeltas[video.id] ?? 0);
    final commentCount = video.commentCount + (_commentDeltas[video.id] ?? 0);
    final saveCount = video.saveCount + (_saveDeltas[video.id] ?? 0);
    final shareCount = video.shareCount + (_shareDeltas[video.id] ?? 0);

    return VideoActionStack(
      isFollowing: following,
      isLiked: liked,
      isSaved: saved,
      likeCount: likeCount,
      commentCount: commentCount,
      saveCount: saveCount,
      shareCount: shareCount,
      profileImageUrl: video.profileImageUrl,
      onProfileTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: video.userId),
          ),
        );
      },
      showFollow: video.userId != _auth.currentUser?.uid,
      onFollow: () {
        unawaited(_toggleFollow(video));
      },
      onLike: () {
        unawaited(_toggleLike(video));
      },
      onComment: () {
        unawaited(_openComments(video));
      },
      onSave: () {
        unawaited(_toggleSave(video));
      },
      onShare: () {
        unawaited(_shareVideo(video));
      },
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
          Row(
            children: [
              _profileAvatar(
                imageUrl: video.profileImageUrl,
                size: 40,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  video.username.startsWith('@')
                      ? video.username
                      : '@${video.username}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 5),
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
                height: 1.25,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 5),
                ],
              ),
            ),
          if (video.hashtags.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              _hashtagsToString(video.hashtags),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 5),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _profileAvatar({
    required String imageUrl,
    required double size,
  }) {
    if (imageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [_pink, _cyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: 34,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

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

  String _hashtagsToString(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is List) {
      return value.map((e) => e.toString()).join(' ');
    }

    return value.toString();
  }

  Widget _buildBottomNavigation() {
    return BottomNavigator(
      selectedIndex: _bottomIndex,
      onSelect: _selectBottom,
      pink: _pink,
      cyan: _cyan,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    switch (_bottomIndex) {
      case 0:
        body = _buildHomeScreen();
        break;

      case 1:
        body = const FriendsScreen();
        break;

      case 3:
        body = const InboxScreen();
        break;

      case 4:
        body = const ProfileScreen();
        break;

      default:
        body = _buildHomeScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: body),
          _buildBottomNavigation(),
        ],
      ),
    );
  }
}
