import 'dart:async';
import 'dart:convert';
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

  final PageController _pageController = PageController();

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

  @override
  void dispose() {
    _logoController.dispose();
    _pageController.dispose();

    for (final controller in _controllers.values) {
      controller.dispose();
    }

    _controllers.clear();

    super.dispose();
  }

  Future<void> _loadEverything() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

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
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      final data = doc.data();

      if (data != null) {
        _username =
            (data['username'] ?? data['displayName'] ?? user.displayName ??
                    'PALOK User')
                .toString();

        _bio = (data['bio'] ?? '').toString();

        _email = (data['email'] ?? user.email ?? '').toString();

        _profileImage = (data['profileImage'] ?? '').toString();

        _followersCount = _toInt(data['followersCount']);

        _followingCount = _toInt(data['followingCount']);
      } else {
        _username = user.displayName ?? 'PALOK User';
        _email = user.email ?? '';
      }
    } catch (_) {
      _username = user.displayName ?? 'PALOK User';
      _email = user.email ?? '';
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

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

      _likedIds
        ..clear()
        ..addAll(likedSnapshot.docs.map((e) => e.id));

      _savedIds
        ..clear()
        ..addAll(savedSnapshot.docs.map((e) => e.id));

      _followingIds
        ..clear()
        ..addAll(followingSnapshot.docs.map((e) => e.id));
    } catch (_) {}
  }

  Future<void> _loadVideos() async {
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
        _videos = snapshot.docs.map((doc) {
          final data = doc.data();

          return VideoPost(
            id: doc.id,
            videoUrl: (data['videoUrl'] ?? '').toString(),
            userId: (data['userId'] ?? '').toString(),
            username: (data['username'] ?? 'PALOK User').toString(),
            caption: (data['caption'] ?? '').toString(),
            hashtags: _hashtagsToString(data['hashtags']),
            likeCount: _toInt(data['likeCount']),
            commentCount: _toInt(data['commentCount']),
            saveCount: _toInt(data['saveCount']),
            shareCount: _toInt(data['shareCount']),
            thumbnailUrl: (data['thumbnailUrl'] ?? '').toString(),
          );
        }).where((video) => video.videoUrl.isNotEmpty).toList();

        if (_videos.isNotEmpty) {
          return;
        }
      }
    } catch (_) {
      // Firebase query may fail if the createdAt index/rules are not ready.
      // Demo videos will be used below.
    }

    _videos = List.generate(
      _demoVideos.length,
      (index) => VideoPost(
        id: 'demo_$index',
        videoUrl: _demoVideos[index],
        userId: 'demo_user_$index',
        username: index == 0
            ? '@palok_creator'
            : index == 1
                ? '@nature_palok'
                : '@palok_video',
        caption: index == 0
            ? 'Welcome to PALOK ✨'
            : index == 1
                ? 'Beautiful moments on PALOK 🌿'
                : 'Create. Share. Connect. 🚀',
        hashtags: index == 0
            ? '#PALOK #ForYou'
            : index == 1
                ? '#Nature #PALOK'
                : '#PALOK #ShortVideo',
        likeCount: index == 0
            ? 11700
            : index == 1
                ? 8500
                : 4200,
        commentCount: index == 0
            ? 234
            : index == 1
                ? 128
                : 75,
        saveCount: index == 0
            ? 811
            : index == 1
                ? 452
                : 210,
        shareCount: index == 0
            ? 431
            : index == 1
                ? 201
                : 98,
      ),
    );
  }

  Future<void> _prepareVideo(int index) async {
    if (!mounted || index < 0 || index >= _videos.length) return;

    if (_controllers.containsKey(index)) {
      final existing = _controllers[index]!;

      if (existing.value.isInitialized) {
        if (index == _currentIndex && _bottomIndex == 0) {
          await existing.play();
        }
        return;
      }
    }

    final video = _videos[index];

    VideoPlayerController controller;

    if (_isNetworkUrl(video.videoUrl)) {
      controller = VideoPlayerController.networkUrl(
        Uri.parse(video.videoUrl),
      );
    } else {
      controller = VideoPlayerController.asset(video.videoUrl);
    }

    _controllers[index] = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);

      if (!mounted) return;

      if (index == _currentIndex && _bottomIndex == 0) {
        await controller.play();
      }

      if (index + 1 < _videos.length) {
        unawaited(_prepareVideo(index + 1));
      }

      if (index - 1 >= 0) {
        unawaited(_prepareVideo(index - 1));
      }

      _disposeFarControllers(index);
    } catch (_) {
      await controller.dispose();
      _controllers.remove(index);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _disposeFarControllers(int centerIndex) {
    final keys = _controllers.keys.toList();

    for (final key in keys) {
      if ((key - centerIndex).abs() > 1) {
        final controller = _controllers.remove(key);
        controller?.dispose();
      }
    }
  }

  bool _isNetworkUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Future<void> _onVideoChanged(int pageIndex, List<VideoPost> feed) async {
    if (pageIndex < 0 || pageIndex >= feed.length) return;

    final selectedVideo = feed[pageIndex];

    final actualIndex = _videos.indexWhere(
      (video) => video.id == selectedVideo.id,
    );

    if (actualIndex < 0) return;

    for (final entry in _controllers.entries) {
      if (entry.key != actualIndex) {
        await entry.value.pause();
      }
    }

    if (!mounted) return;

    setState(() {
      _currentIndex = actualIndex;
    });

    await _prepareVideo(actualIndex);
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
          _likeDeltas[video.id] = (_likeDeltas[video.id] ?? 0) - 1;
        } else {
          _likedIds.add(video.id);
          _likeDeltas[video.id] = (_likeDeltas[video.id] ?? 0) + 1;
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
          {
            'likeCount': FieldValue.increment(wasLiked ? -1 : 1),
          },
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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (wasLiked) {
          _likedIds.add(video.id);
          _likeDeltas[video.id] = (_likeDeltas[video.id] ?? 0) + 1;
        } else {
          _likedIds.remove(video.id);
          _likeDeltas[video.id] = (_likeDeltas[video.id] ?? 0) - 1;
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
          _saveDeltas[video.id] = (_saveDeltas[video.id] ?? 0) - 1;
        } else {
          _savedIds.add(video.id);
          _saveDeltas[video.id] = (_saveDeltas[video.id] ?? 0) + 1;
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
          {
            'saveCount': FieldValue.increment(wasSaved ? -1 : 1),
          },
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
          _saveDeltas[video.id] = (_saveDeltas[video.id] ?? 0) + 1;
        } else {
          _savedIds.remove(video.id);
          _saveDeltas[video.id] = (_saveDeltas[video.id] ?? 0) - 1;
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

      try {
        await _firestore.collection('users').doc(user.uid).set(
          {
            'followingCount':
                FieldValue.increment(wasFollowing ? -1 : 1),
          },
          SetOptions(merge: true),
        );
      } catch (_) {}

      try {
        await _firestore.collection('users').doc(video.userId).set(
          {
            'followersCount':
                FieldValue.increment(wasFollowing ? -1 : 1),
          },
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

      if (mounted) {
        setState(() {
          _followingCount += wasFollowing ? -1 : 1;
        });
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
      await Share.share(
        'Watch this video on PALOK\n\n$link',
      );

      if (mounted) {
        setState(() {
          _shareDeltas[video.id] = (_shareDeltas[video.id] ?? 0) + 1;
        });
      }

      if (!video.id.startsWith('demo_')) {
        try {
          await _firestore.collection('videos').doc(video.id).set(
            {
              'shareCount': FieldValue.increment(1),
            },
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

  Future<void> _openComments(VideoPost video) async {
    final added = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
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
    final controller = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = controller.text.trim().toLowerCase();

            final results = query.isEmpty
                ? <VideoPost>[]
                : _videos.where((video) {
                    final text = [
                      video.username,
                      video.caption,
                      video.hashtags,
                    ].join(' ').toLowerCase();

                    return text.contains(query);
                  }).toList();

            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.78,
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
                        borderRadius: BorderRadius.circular(20),
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
                        controller: controller,
                        autofocus: true,
                        onChanged: (_) {
                          setSheetState(() {});
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search videos, users...',
                          hintStyle:
                              const TextStyle(color: Colors.white54),
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
                              controller.clear();
                              setSheetState(() {});
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: query.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
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
                                      fontWeight: FontWeight.w600,
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
                                  padding: const EdgeInsets.all(18),
                                  itemCount: results.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, index) {
                                    final video = results[index];
                                    final actualIndex = _videos.indexWhere(
                                      (v) => v.id == video.id,
                                    );

                                    return InkWell(
                                      borderRadius:
                                          BorderRadius.circular(16),
                                      onTap: () async {
                                        Navigator.pop(sheetContext);

                                        if (actualIndex >= 0) {
                                          await _goToVideo(actualIndex);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(
                                            0.06,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          children: [
                                            _smallVideoThumbnail(video),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    video.username,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    video.caption.isEmpty
                                                        ? video.hashtags
                                                        : video.caption,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white60,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: Colors.white54,
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
          },
        );
      },
    );

    controller.dispose();
  }

  Widget _smallVideoThumbnail(VideoPost video) {
    return Container(
      width: 58,
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white70,
        size: 30,
      ),
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
                gradient: const LinearGradient(
                  colors: [_pink, _cyan],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 25,
              ),
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
            const Icon(
              Icons.chevron_right,
              color: Colors.white54,
            ),
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

      if (file == null) return;

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return _UploadSheet(
            filePath: file.path,
            username: _username,
            userId: user.uid,
            firestore: _firestore,
            onPosted: () async {
              await _reloadAfterUpload();
            },
          );
        },
      );
    } catch (e) {
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
    }
  }

  Future<void> _openEditProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Profile edit করতে Login করতে হবে');
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const EditProfileScreen(),
        ),
      );

      if (result is Map) {
        if (mounted) {
          setState(() {
            _username =
                (result['username'] ?? _username).toString();
            _bio = (result['bio'] ?? _bio).toString();
            _profileImage =
                (result['profileImage'] ?? _profileImage).toString();
          });
        }
      } else {
        await _loadUserProfile();

        if (mounted) {
          setState(() {});
        }
      }
    } catch (_) {
      _showMessage('Profile edit screen খোলা যায়নি');
    }
  }

  Future<void> _selectBottom(int index) async {
    if (index == _bottomIndex) {
      if (index == 0 && _videos.isNotEmpty) {
        await _prepareVideo(_currentIndex);
      }
      return;
    }

    if (_bottomIndex == 0) {
      for (final controller in _controllers.values) {
        await controller.pause();
      }
    }

    if (!mounted) return;

    if (index == 2) {
      await _openCreateSheet();

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
    if (_topIndex == index) return;

    for (final controller in _controllers.values) {
      await controller.pause();
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
    }
  }

  Widget _buildHomeScreen() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _pink,
        ),
      );
    }

    final feed = _topIndex == 0
        ? _videos
        : _videos
            .where((video) => _followingIds.contains(video.userId))
            .toList();

    if (feed.isEmpty) {
      return _buildEmptyFeed();
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: feed.length,
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        unawaited(_togglePlay(actualIndex));
      },
      onDoubleTap: () {
        if (!_likedIds.contains(video.id)) {
          unawaited(_toggleLike(video));
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),

          if (controller != null && controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),

          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),

          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [
                    Color(0xB8000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),

          _buildTopBar(),

          _buildRightActions(video),

          _buildVideoInfo(video),
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
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _logoController,
                builder: (_, __) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              _pink,
                              _cyan,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: _pink.withOpacity(0.35),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'P',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const Spacer(),
              _topTab(
                title: 'For You',
                selected: _topIndex == 0,
                onTap: () {
                  unawaited(_switchTopTab(0));
                },
              ),
              const SizedBox(width: 18),
              _topTab(
                title: 'Following',
                selected: _topIndex == 1,
                onTap: () {
                  unawaited(_switchTopTab(1));
                },
              ),
              const SizedBox(width: 8),
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
      ),
    );
  }

  Widget _topTab({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 15,
                fontWeight:
                    selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 24 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightActions(VideoPost video) {
    final liked = _likedIds.contains(video.id);
    final saved = _savedIds.contains(video.id);
    final following = _followingIds.contains(video.userId);

    final likeCount =
        video.likeCount + (_likeDeltas[video.id] ?? 0);

    final commentCount =
        video.commentCount + (_commentDeltas[video.id] ?? 0);

    final saveCount =
        video.saveCount + (_saveDeltas[video.id] ?? 0);

    final shareCount =
        video.shareCount + (_shareDeltas[video.id] ?? 0);

    return Positioned(
      right: 10,
      bottom: 116,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (video.userId != _auth.currentUser?.uid)
            _actionButton(
              icon: following
                  ? Icons.person
                  : Icons.person_add_alt_1_rounded,
              label: following ? 'Following' : 'Follow',
              active: following,
              onTap: () {
                unawaited(_toggleFollow(video));
              },
            ),
          const SizedBox(height: 13),
          _actionButton(
            icon: liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: _formatCount(likeCount),
            active: liked,
            onTap: () {
              unawaited(_toggleLike(video));
            },
          ),
          const SizedBox(height: 13),
          _actionButton(
            icon: Icons.mode_comment_outlined,
            label: _formatCount(commentCount),
            onTap: () {
              unawaited(_openComments(video));
            },
          ),
          const SizedBox(height: 13),
          _actionButton(
            icon: saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            label: _formatCount(saveCount),
            active: saved,
            onTap: () {
              unawaited(_toggleSave(video));
            },
          ),
          const SizedBox(height: 13),
          _actionButton(
            icon: Icons.share_rounded,
            label: _formatCount(shareCount),
            onTap: () {
              unawaited(_shareVideo(video));
            },
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
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
              child: Icon(
                icon,
                color: active ? _pink : Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ],
        ),
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
          Row(
            children: [
              _profileAvatar(
                imageUrl: '',
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
                      Shadow(
                        color: Colors.black,
                        blurRadius: 5,
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
                height: 1.25,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 5,
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
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendsScreen() {
    final user = _auth.currentUser;

    final creators = <String, VideoPost>{};

    for (final video in _videos) {
      if (video.userId.isEmpty) continue;
      if (user != null && video.userId == user.uid) continue;

      creators.putIfAbsent(video.userId, () => video);
    }

    final followingCreators = creators.values
        .where((video) => _followingIds.contains(video.userId))
        .toList();

    final suggestedCreators = creators.values
        .where((video) => !_followingIds.contains(video.userId))
        .toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 4),
            child: Text(
              'Friends',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Text(
              'Connect with creators on PALOK',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
              children: [
                if (followingCreators.isNotEmpty) ...[
                  const Text(
                    'Following',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...followingCreators.map(
                    (video) => _creatorCard(video, true),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text(
                  'Suggested creators',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (suggestedCreators.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 35),
                    child: Center(
                      child: Text(
                        'কোনো creator পাওয়া যায়নি',
                        style: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  )
                else
                  ...suggestedCreators.map(
                    (video) => _creatorCard(video, false),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _creatorCard(VideoPost video, bool following) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _profileAvatar(
            imageUrl: '',
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatCount(video.likeCount)} likes',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              unawaited(_toggleFollow(video));
            },
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  following ? Colors.white54 : Colors.white,
              side: BorderSide(
                color: following ? Colors.white24 : _pink,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              following ? 'Following' : 'Follow',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInboxScreen() {
    final user = _auth.currentUser;

    if (user == null) {
      return const Center(
        child: Text(
          'Login করুন Inbox ব্যবহার করতে',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Text(
              'Inbox',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('notifications')
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _pink,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Inbox load করা যায়নি',
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white30,
                          size: 60,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Like, comment বা follow এলে এখানে দেখা যাবে',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final notifications = [...docs];

                notifications.sort((a, b) {
                  final aTime = a.data()['createdAt'];
                  final bTime = b.data()['createdAt'];

                  if (aTime is Timestamp && bTime is Timestamp) {
                    return bTime.compareTo(aTime);
                  }

                  return 0;
                });

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    4,
                    18,
                    100,
                  ),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final data = notifications[index].data();

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _pink.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _notificationIcon(
                                data['type']?.toString() ?? '',
                              ),
                              color: _pink,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        data['fromUsername'] ??
                                            'Someone',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' ${data['text'] ?? ''}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
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
        ],
      ),
    );
  }

  IconData _notificationIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.mode_comment_rounded;
      case 'follow':
        return Icons.person_add_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Widget _buildProfileScreen() {
    final user = _auth.currentUser;

    final ownVideos = user == null
        ? <VideoPost>[]
        : _videos.where((video) => video.userId == user.uid).toList();

    int totalLikes = 0;

    for (final video in ownVideos) {
      totalLikes +=
          video.likeCount + (_likeDeltas[video.id] ?? 0);
    }

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Row(
                children: [
                  _profileAvatar(
                    imageUrl: _profileImage,
                    size: 82,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceAround,
                      children: [
                        _profileStat(
                          value: ownVideos.length.toString(),
                          label: 'Videos',
                        ),
                        _profileStat(
                          value: _formatCount(_followersCount),
                          label: 'Followers',
                        ),
                        _profileStat(
                          value: _formatCount(_followingCount),
                          label: 'Following',
                        ),
                        _profileStat(
                          value: _formatCount(totalLikes),
                          label: 'Likes',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (_email.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      _email,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (_bio.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _bio,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _openEditProfile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Colors.white24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(
                    color: Colors.white12,
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (ownVideos.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 80),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        color: Colors.white30,
                        size: 55,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'তোমার এখনো কোনো ভিডিও নেই',
                        style: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                2,
                0,
                2,
                100,
              ),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final video = ownVideos[index];

                    return GestureDetector(
                      onTap: () async {
                        final actualIndex = _videos.indexWhere(
                          (item) => item.id == video.id,
                        );

                        if (actualIndex >= 0) {
                          await _goToVideo(actualIndex);
                        }
                      },
                      child: Container(
                        color: Colors.white.withOpacity(0.04),
                        child: const Center(
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white70,
                            size: 38,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: ownVideos.length,
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

  Widget _profileStat({
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
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
            colors: [
              _pink,
              _cyan,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white24,
            width: 2,
          ),
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
        border: Border.all(
          color: Colors.white24,
          width: 2,
        ),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
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
          decoration: const BoxDecoration(
            color: Colors.black,
            border: Border(
              top: BorderSide(
                color: Colors.white12,
                width: 0.7,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _bottomItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                ),
              ),
              Expanded(
                child: _bottomItem(
                  icon: Icons.people_alt_outlined,
                  label: 'Friends',
                  index: 1,
                ),
              ),
              SizedBox(
                width: 92,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      unawaited(_selectBottom(2));
                    },
                    child: Container(
                      width: 72,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            _cyan,
                            _pink,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _pink.withOpacity(0.20),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _bottomItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Inbox',
                  index: 3,
                ),
              ),
              Expanded(
                child: _bottomItem(
                  icon: Icons.person_outline_rounded,
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
    required String label,
    required int index,
  }) {
    final selected = _bottomIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        unawaited(_selectBottom(index));
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: selected ? Colors.white : Colors.white54,
            size: 24,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 10,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }

    return value.toString();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _hashtagsToString(dynamic value) {
    if (value == null) return '';

    if (value is List) {
      return value.map((e) => e.toString()).join(' ');
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    switch (_bottomIndex) {
      case 0:
        body = _buildHomeScreen();
        break;

      case 1:
        body = _buildFriendsScreen();
        break;

      case 3:
        body = _buildInboxScreen();
        break;

      case 4:
        body = _buildProfileScreen();
        break;

      default:
        body = _buildHomeScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: body,
          ),
          _buildBottomNavigation(),
        ],
      ),
    );
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

  const VideoPost({
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
  final String videoOwnerId;
  final String videoOwnerUsername;
  final String currentUsername;
  final String currentUserId;
  final FirebaseFirestore firestore;

  const _CommentsSheet({
    required this.videoId,
    required this.videoOwnerId,
    required this.videoOwnerUsername,
    required this.currentUsername,
    required this.currentUserId,
    required this.firestore,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _sending) return;

    if (widget.currentUserId.isEmpty) {
      _showError('Comment করতে Login করতে হবে');
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.firestore
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .add({
        'userId': widget.currentUserId,
        'username': widget.currentUsername,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!widget.videoId.startsWith('demo_')) {
        await widget.firestore
            .collection('videos')
            .doc(widget.videoId)
            .set(
          {
            'commentCount': FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );
      }

      if (widget.videoOwnerId.isNotEmpty &&
          widget.videoOwnerId != widget.currentUserId) {
        try {
          await widget.firestore
              .collection('users')
              .doc(widget.videoOwnerId)
              .collection('notifications')
              .add({
            'type': 'comment',
            'fromUserId': widget.currentUserId,
            'fromUsername': widget.currentUsername,
            'text': 'তোমার ভিডিওতে Comment করেছে',
            'videoId': widget.videoId,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

      _controller.clear();

      if (mounted) {
        Navigator.pop(context, 1);
      }
    } catch (_) {
      if (mounted) {
        _showError('Comment করা যায়নি');
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.62,
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
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 18),
                const Text(
                  'Comments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const Divider(
              color: Colors.white10,
              height: 1,
            ),
            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.firestore
                    .collection('videos')
                    .doc(widget.videoId)
                    .collection('comments')
                    .limit(100)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet',
                        style: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    );
                  }

                  final comments = [...docs];

                  comments.sort((a, b) {
                    final aTime = a.data()['createdAt'];
                    final bTime = b.data()['createdAt'];

                    if (aTime is Timestamp &&
                        bTime is Timestamp) {
                      return aTime.compareTo(bTime);
                    }

                    return 0;
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      12,
                      18,
                      12,
                    ),
                    itemCount: comments.length,
                    itemBuilder: (_, index) {
                      final data = comments[index].data();

                      final username =
                          (data['username'] ?? 'PALOK User').toString();

                      final text =
                          (data['text'] ?? '').toString();

                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: 17),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFF2D55),
                                    Color(0xFF00E5FF),
                                  ],
                                ),
                              ),
                              child: const Icon(
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
                                    username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    text,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      height: 1.25,
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
            Container(
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                10,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF151515),
                border: Border(
                  top: BorderSide(
                    color: Colors.white10,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        unawaited(_sendComment());
                      },
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.07),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      unawaited(_sendComment());
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF2D55),
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
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

class _UploadSheet extends StatefulWidget {
  final String filePath;
  final String username;
  final String userId;
  final FirebaseFirestore firestore;
  final Future<void> Function() onPosted;

  const _UploadSheet({
    required this.filePath,
    required this.username,
    required this.userId,
    required this.firestore,
    required this.onPosted,
  });

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  static const String _cloudName = 'u0jufmrl';
  static const String _uploadPreset = 'palok_video_upload';

  final TextEditingController _captionController =
      TextEditingController();

  VideoPlayerController? _previewController;

  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  Future<void> _initializePreview() async {
    final controller =
        VideoPlayerController.file(File(widget.filePath));

    _previewController = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _captionController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _postVideo() async {
    if (_uploading) return;

    final file = File(widget.filePath);

    if (!await file.exists()) {
      _showError('ভিডিও file পাওয়া যায়নি');
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
        ),
      );

      request.fields['upload_preset'] = _uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          widget.filePath,
        ),
      );

      final streamedResponse = await request.send();

      final responseBody =
          await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        String message = 'Cloudinary upload failed';

        try {
          final errorJson = jsonDecode(responseBody);

          message = errorJson['error']?['message']?.toString() ??
              message;
        } catch (_) {}

        throw Exception(message);
      }

      final json = jsonDecode(responseBody);

      final secureUrl =
          (json['secure_url'] ?? '').toString();

      if (secureUrl.isEmpty) {
        throw Exception('Video URL পাওয়া যায়নি');
      }

      final caption = _captionController.text.trim();

      final hashtags = _extractHashtags(caption);

      await widget.firestore.collection('videos').add({
        'videoUrl': secureUrl,
        'userId': widget.userId,
        'username': widget.username,
        'caption': caption,
        'hashtags': hashtags,
        'likeCount': 0,
        'commentCount': 0,
        'saveCount': 0,
        'shareCount': 0,
        'thumbnailUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await widget.onPosted();

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে 🎉'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        _showError(
          'Upload failed: ${_cleanUploadError(e)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  List<String> _extractHashtags(String text) {
    final matches = RegExp(r'#[A-Za-z0-9_\u0980-\u09FF]+')
        .allMatches(text);

    return matches
        .map((match) => match.group(0) ?? '')
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  String _cleanUploadError(Object error) {
    final text = error.toString();

    if (text.contains('Upload preset')) {
      return 'Cloudinary upload preset check করো';
    }

    if (text.contains('401')) {
      return 'Cloudinary authentication/configuration সমস্যা';
    }

    if (text.contains('413')) {
      return 'ভিডিও file অনেক বড়';
    }

    return text
        .replaceFirst('Exception: ', '')
        .replaceFirst('Error: ', '');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
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
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Create Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: double.infinity,
                        height: 360,
                        color: Colors.black,
                        child: _previewController != null &&
                                _previewController!
                                    .value
                                    .isInitialized
                            ? FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _previewController!
                                      .value
                                      .size
                                      .width,
                                  height: _previewController!
                                      .value
                                      .size
                                      .height,
                                  child: VideoPlayer(
                                    _previewController!,
                                  ),
                                ),
                              )
                            : const Center(
                                child:
                                    CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _captionController,
                      maxLines: 4,
                      enabled: !_uploading,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Write a caption... #PALOK',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor:
                            Colors.white.withOpacity(0.07),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ভিডিও সর্বোচ্চ ৩ মিনিট পর্যন্ত',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
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
                18,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _uploading ? null : _postVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2D55),
                    disabledBackgroundColor:
                        Colors.white12,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _uploading
                      ? const Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 21,
                              height: 21,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Uploading...',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Post to PALOK',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
