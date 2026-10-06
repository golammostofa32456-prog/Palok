import 'features/comments/comments_sheet.dart';
import 'features/upload/upload_sheet.dart';
import 'features/create/create_video_screen.dart';
import 'features/search/search_screen.dart';
import 'features/feed/for_you_feed.dart';
import 'following_feed.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'upload_video_screen.dart';


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

  // Prevent duplicate initialization of the same video.
  final Map<int, Future<void>> _preparingVideos = {};

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
    _preparingVideos.clear();

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
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      if (data != null) {
        _username = (data['username'] ??
                data['displayName'] ??
                user.displayName ??
                'PALOK User')
            .toString();

        _bio = (data['bio'] ?? '').toString();

        _email = (data['email'] ?? user.email ?? '').toString();

        _profileImage =
            (data['profileImage'] ?? '').toString();

        _followersCount =
            _toInt(data['followersCount']);

        _followingCount =
            _toInt(data['followingCount']);
      } else {
        _username =
            user.displayName ?? 'PALOK User';

        _email = user.email ?? '';
      }
    } catch (_) {
      _username =
          user.displayName ?? 'PALOK User';

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
        ..addAll(
          likedSnapshot.docs.map(
            (e) => e.id,
          ),
        );

      _savedIds
        ..clear()
        ..addAll(
          savedSnapshot.docs.map(
            (e) => e.id,
          ),
        );

      _followingIds
        ..clear()
        ..addAll(
          followingSnapshot.docs.map(
            (e) => e.id,
          ),
        );
    } catch (_) {}
  }

  Future<void> _loadVideos() async {
    _preparingVideos.clear();

    for (final controller in _controllers.values) {
      await controller.dispose();
    }

    _controllers.clear();

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
        _videos = snapshot.docs
            .map(
              (doc) {
                final data = doc.data();

                return VideoPost(
                  id: doc.id,
                  videoUrl:
                      (data['videoUrl'] ?? '').toString(),
                  userId:
                      (data['userId'] ?? '').toString(),
                  username:
                      (data['username'] ?? 'PALOK User')
                          .toString(),
                  caption:
                      (data['caption'] ?? '').toString(),
                  hashtags:
                      _hashtagsToString(
                    data['hashtags'],
                  ),
                  likeCount:
                      _toInt(data['likeCount']),
                  commentCount:
                      _toInt(data['commentCount']),
                  saveCount:
                      _toInt(data['saveCount']),
                  shareCount:
                      _toInt(data['shareCount']),
                  thumbnailUrl:
                      (data['thumbnailUrl'] ?? '')
                          .toString(),
                );
              },
            )
            .where(
              (video) =>
                  video.videoUrl.isNotEmpty,
            )
            .toList();

        if (_videos.isNotEmpty) {
          return;
        }
      }
    } catch (_) {
      // Firebase query failed.
      // Demo feed will be used below.
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

  // ============================================================
  // FAST VIDEO PRELOAD
  // ============================================================

  Future<void> _prepareVideo(int index) async {
    if (!mounted ||
        index < 0 ||
        index >= _videos.length) {
      return;
    }

    final existing = _controllers[index];

    // Already initialized হলে আবার initialize করবে না।
    if (existing != null) {
      if (existing.value.isInitialized) {
        if (index == _currentIndex &&
            _bottomIndex == 0 &&
            !existing.value.isPlaying) {
          unawaited(
            existing.play(),
          );
        }
      }

      return;
    }

    // একই video ইতিমধ্যে initialize হচ্ছে কিনা।
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
      if (identical(
        _preparingVideos[index],
        future,
      )) {
        _preparingVideos.remove(index);
      }
    }
  }

  Future<void> _initializeVideo(int index) async {
    if (!mounted ||
        index < 0 ||
        index >= _videos.length) {
      return;
    }

    final video = _videos[index];

    late final VideoPlayerController controller;

    try {
      if (_isNetworkUrl(video.videoUrl)) {
        controller =
            VideoPlayerController.networkUrl(
          Uri.parse(video.videoUrl),
        );
      } else {
        controller =
            VideoPlayerController.asset(
          video.videoUrl,
        );
      }

      _controllers[index] = controller;

      await controller.initialize();

      if (!mounted) {
        return;
      }

      await controller.setLooping(true);

      if (!mounted) {
        return;
      }

      // শুধু current video automatically play হবে।
      if (index == _currentIndex &&
          _bottomIndex == 0) {
        unawaited(
          controller.play(),
        );
      }

      if (mounted) {
        setState(() {});
      }

      // Next video preload.
      if (index + 1 < _videos.length) {
        unawaited(
          _prepareVideo(index + 1),
        );
      }

      // Next +2 video preload.
      if (index + 2 < _videos.length) {
        unawaited(
          _prepareVideo(index + 2),
        );
      }

      // Previous video preload.
      if (index - 1 >= 0) {
        unawaited(
          _prepareVideo(index - 1),
        );
      }

      // Previous -2 video preload.
      if (index - 2 >= 0) {
        unawaited(
          _prepareVideo(index - 2),
        );
      }

      _disposeFarControllers(
        _currentIndex,
      );
    } catch (_) {
      if (_controllers[index] == controller) {
        _controllers.remove(index);
      }

      try {
        await controller.dispose();
      } catch (_) {}

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _disposeFarControllers(
    int centerIndex,
  ) {
    final keys =
        _controllers.keys.toList();

    for (final key in keys) {
      // Current-এর আগে/পরে ২টি পর্যন্ত রাখবো।
      if ((key - centerIndex).abs() > 2) {
        final controller =
            _controllers.remove(key);

        if (controller != null) {
          unawaited(
            controller.dispose(),
          );
        }
      }
    }
  }

  bool _isNetworkUrl(String value) {
    return value.startsWith('http://') ||
        value.startsWith('https://');
  }

  // ============================================================
  // VIDEO CHANGE
  // ============================================================

  Future<void> _onVideoChanged(
    int pageIndex,
    List<VideoPost> feed,
  ) async {
    if (pageIndex < 0 ||
        pageIndex >= feed.length) {
      return;
    }

    final selectedVideo =
        feed[pageIndex];

    final actualIndex =
        _videos.indexWhere(
      (video) =>
          video.id == selectedVideo.id,
    );

    if (actualIndex < 0) {
      return;
    }

    // পুরোনো controller pause করবো,
    // কিন্তু pause শেষ হওয়ার জন্য wait করবো না।
    for (final entry
        in _controllers.entries) {
      if (entry.key != actualIndex) {
        unawaited(
          entry.value.pause(),
        );
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex =
          actualIndex;
    });

    // Current video prepare.
    unawaited(
      _prepareVideo(actualIndex),
    );

    // Next 2 preload.
    if (actualIndex + 1 <
        _videos.length) {
      unawaited(
        _prepareVideo(
          actualIndex + 1,
        ),
      );
    }

    if (actualIndex + 2 <
        _videos.length) {
      unawaited(
        _prepareVideo(
          actualIndex + 2,
        ),
      );
    }

    // Previous 2 preload.
    if (actualIndex - 1 >= 0) {
      unawaited(
        _prepareVideo(
          actualIndex - 1,
        ),
      );
    }

    if (actualIndex - 2 >= 0) {
      unawaited(
        _prepareVideo(
          actualIndex - 2,
        ),
      );
    }

    _disposeFarControllers(
      actualIndex,
    );
  }

  Future<void> _togglePlay(
    int actualIndex,
  ) async {
    final controller =
        _controllers[actualIndex];

    if (controller == null ||
        !controller.value.isInitialized) {
      await _prepareVideo(
        actualIndex,
      );
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

  Future<void> _toggleLike(
    VideoPost video,
  ) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Like করতে Login করতে হবে',
      );
      return;
    }

    final wasLiked =
        _likedIds.contains(
      video.id,
    );

    if (mounted) {
      setState(() {
        if (wasLiked) {
          _likedIds.remove(
            video.id,
          );

          _likeDeltas[video.id] =
              (_likeDeltas[
                          video.id] ??
                      0) -
                  1;
        } else {
          _likedIds.add(
            video.id,
          );

          _likeDeltas[video.id] =
              (_likeDeltas[
                          video.id] ??
                      0) +
                  1;
        }
      });
    }

    try {
      final likeRef =
          _firestore
              .collection('users')
              .doc(user.uid)
              .collection(
                'likedVideos',
              )
              .doc(video.id);

      if (wasLiked) {
        await likeRef.delete();
      } else {
        await likeRef.set({
          'videoId': video.id,
          'createdAt':
              FieldValue.serverTimestamp(),
        });
      }

      if (!video.id.startsWith(
        'demo_',
      )) {
        await _firestore
            .collection('videos')
            .doc(video.id)
            .set(
          {
            'likeCount':
                FieldValue.increment(
              wasLiked ? -1 : 1,
            ),
          },
          SetOptions(
            merge: true,
          ),
        );
      }

      if (!wasLiked &&
          video.userId.isNotEmpty &&
          video.userId != user.uid) {
        await _createNotification(
          targetUserId:
              video.userId,
          type: 'like',
          text:
              'তোমার ভিডিওটি Like করেছে',
          videoId: video.id,
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (wasLiked) {
          _likedIds.add(
            video.id,
          );

          _likeDeltas[video.id] =
              (_likeDeltas[
                          video.id] ??
                      0) +
                  1;
        } else {
          _likedIds.remove(
            video.id,
          );

          _likeDeltas[video.id] =
              (_likeDeltas[
                          video.id] ??
                      0) -
                  1;
        }
      });

      _showMessage(
        'Like পরিবর্তন করা যায়নি',
      );
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _toggleSave(
    VideoPost video,
  ) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Save করতে Login করতে হবে',
      );
      return;
    }

    final wasSaved =
        _savedIds.contains(
      video.id,
    );

    if (mounted) {
      setState(() {
        if (wasSaved) {
          _savedIds.remove(
            video.id,
          );

          _saveDeltas[video.id] =
              (_saveDeltas[
                          video.id] ??
                      0) -
                  1;
        } else {
          _savedIds.add(
            video.id,
          );

          _saveDeltas[video.id] =
              (_saveDeltas[
                          video.id] ??
                      0) +
                  1;
        }
      });
    }

    try {
      final saveRef =
          _firestore
              .collection('users')
              .doc(user.uid)
              .collection(
                'savedVideos',
              )
              .doc(video.id);

      if (wasSaved) {
        await saveRef.delete();
      } else {
        await saveRef.set({
          'videoId': video.id,
          'createdAt':
              FieldValue.serverTimestamp(),
        });
      }

      if (!video.id.startsWith(
        'demo_',
      )) {
        await _firestore
            .collection('videos')
            .doc(video.id)
            .set(
          {
            'saveCount':
                FieldValue.increment(
              wasSaved ? -1 : 1,
            ),
          },
          SetOptions(
            merge: true,
          ),
        );
      }

      if (mounted) {
        _showMessage(
          wasSaved
              ? 'ভিডিওটি Unsave করা হয়েছে'
              : 'ভিডিওটি Saved হয়েছে',
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (wasSaved) {
          _savedIds.add(
            video.id,
          );

          _saveDeltas[video.id] =
              (_saveDeltas[
                          video.id] ??
                      0) +
                  1;
        } else {
          _savedIds.remove(
            video.id,
          );

          _saveDeltas[video.id] =
              (_saveDeltas[
                          video.id] ??
                      0) -
                  1;
        }
      });

      _showMessage(
        'Save করা যায়নি',
      );
    }
  }

  // ============================================================
  // FOLLOW
  // ============================================================

  Future<void> _toggleFollow(
    VideoPost video,
  ) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Follow করতে Login করতে হবে',
      );
      return;
    }

    if (video.userId.isEmpty ||
        video.userId == user.uid) {
      _showMessage(
        'নিজের Profile Follow করা যাবে না',
      );
      return;
    }

    final wasFollowing =
        _followingIds.contains(
      video.userId,
    );

    if (mounted) {
      setState(() {
        if (wasFollowing) {
          _followingIds.remove(
            video.userId,
          );
        } else {
          _followingIds.add(
            video.userId,
          );
        }
      });
    }

    try {
      final followingRef =
          _firestore
              .collection('users')
              .doc(user.uid)
              .collection(
                'following',
              )
              .doc(video.userId);

      if (wasFollowing) {
        await followingRef.delete();
      } else {
        await followingRef.set({
          'userId': video.userId,
          'username': video.username,
          'createdAt':
              FieldValue.serverTimestamp(),
        });
      }

      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(
          {
            'followingCount':
                FieldValue.increment(
              wasFollowing ? -1 : 1,
            ),
          },
          SetOptions(
            merge: true,
          ),
        );
      } catch (_) {}

      try {
        await _firestore
            .collection('users')
            .doc(video.userId)
            .set(
          {
            'followersCount':
                FieldValue.increment(
              wasFollowing ? -1 : 1,
            ),
          },
          SetOptions(
            merge: true,
          ),
        );
      } catch (_) {}

      if (!wasFollowing) {
        await _createNotification(
          targetUserId:
              video.userId,
          type: 'follow',
          text:
              'তোমাকে Follow করেছে',
        );
      }

      if (mounted) {
        setState(() {
          _followingCount +=
              wasFollowing ? -1 : 1;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (wasFollowing) {
          _followingIds.add(
            video.userId,
          );
        } else {
          _followingIds.remove(
            video.userId,
          );
        }
      });

      _showMessage(
        'Follow পরিবর্তন করা যায়নি',
      );
    }
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _shareVideo(
    VideoPost video,
  ) async {
    final user =
        _auth.currentUser;

    final link =
        'https://palok.app/video/${video.id}';

    try {
      await Share.share(
        'Watch this video on PALOK\n\n$link',
      );

      if (mounted) {
        setState(() {
          _shareDeltas[video.id] =
              (_shareDeltas[
                          video.id] ??
                      0) +
                  1;
        });
      }

      if (!video.id.startsWith(
        'demo_',
      )) {
        try {
          await _firestore
              .collection('videos')
              .doc(video.id)
              .set(
            {
              'shareCount':
                  FieldValue.increment(1),
            },
            SetOptions(
              merge: true,
            ),
          );
        } catch (_) {}
      }

      if (user != null &&
          !video.id.startsWith(
            'demo_',
          )) {
        try {
          await _firestore
              .collection('videos')
              .doc(video.id)
              .collection(
                'shares',
              )
              .add({
            'userId': user.uid,
            'createdAt':
                FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ============================================================
  // NOTIFICATION
  // ============================================================

  Future<void> _createNotification({
    required String targetUserId,
    required String type,
    required String text,
    String? videoId,
  }) async {
    final user =
        _auth.currentUser;

    if (user == null ||
        targetUserId.isEmpty ||
        targetUserId == user.uid) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection(
            'notifications',
          )
          .add({
        'type': type,
        'fromUserId': user.uid,
        'fromUsername': _username,
        'text': text,
        'videoId': videoId ?? '',
        'read': false,
        'createdAt':
            FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  Future<void> _openComments(
    VideoPost video,
  ) async {
    final added =
        await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return CommentsSheet(
          videoId: video.id,
          videoOwnerId:
              video.userId,
          videoOwnerUsername:
              video.username,
          currentUsername:
              _username,
          currentUserId:
              _auth.currentUser?.uid ??
                  '',
          firestore:
              _firestore,
        );
      },
    );

    if (added != null &&
        added > 0 &&
        mounted) {
      setState(() {
        _commentDeltas[video.id] =
            (_commentDeltas[
                        video.id] ??
                    0) +
                added;
      });
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<void> _openSearch() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return SearchScreen(
          videos: _videos,
          onVideoSelected:
              _goToVideo,
        );
      },
    );
  }

  Future<void> _goToVideo(
    int actualIndex,
  ) async {
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
        duration:
            const Duration(
          milliseconds: 350,
        ),
        curve: Curves.easeOut,
      );
    } else {
      setState(() {
        _currentIndex =
            actualIndex;
      });

      await _prepareVideo(
        actualIndex,
      );
    }
  }

  // ============================================================
  // CREATE / UPLOAD
  // ============================================================

  Future<void> _openCreateScreen() async {
    final user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Video upload করতে Login করতে হবে',
      );
      return;
    }

    final videoPath =
        await Navigator.of(context)
            .push<String>(
      MaterialPageRoute(
        builder: (_) =>
            const CreateVideoScreen(),
      ),
    );

    if (videoPath == null ||
        videoPath.isEmpty ||
        !mounted) {
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

    if (_bottomIndex == 0 &&
        _videos.isNotEmpty) {
      await _prepareVideo(
        _currentIndex,
      );
    }
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              14,
              18,
              22,
            ),
            decoration:
                const BoxDecoration(
              color: Color(0xFF111111),
              borderRadius:
                  BorderRadius.vertical(
                top: Radius.circular(24),
              ),
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
                    color:
                        Colors.white24,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                const Text(
                  'Create on PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                _createOption(
                  icon: Icons
                      .videocam_rounded,
                  title:
                      'Record Video',
                  subtitle:
                      'Camera দিয়ে নতুন ভিডিও তৈরি করুন',
                  onTap: () async {
                    Navigator.pop(
                      context,
                    );

                    await _pickVideo(
                      ImageSource.camera,
                    );
                  },
                ),
                const SizedBox(
                  height: 10,
                ),
                _createOption(
                  icon: Icons
                      .video_library_rounded,
                  title:
                      'Upload Video',
                  subtitle:
                      'Gallery থেকে ভিডিও নির্বাচন করুন',
                  onTap: () async {
                    Navigator.pop(
                      context,
                    );

                    await _pickVideo(
                      ImageSource.gallery,
                    );
                  },
                ),
                const SizedBox(
                  height: 10,
                ),
                _createOption(
                  icon: Icons
                      .music_note_rounded,
                  title:
                      'Add Sound',
                  subtitle:
                      'Sound feature পরে যোগ করা যাবে',
                  onTap: () {
                    Navigator.pop(
                      context,
                    );

                    _showMessage(
                      'Sound feature coming soon',
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

  Widget _createOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(18),
      child: Container(
        padding:
            const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white
              .withOpacity(0.06),
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    _pink,
                    _cyan,
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(
              width: 14,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(
                      color:
                          Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color:
                  Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideo(
    ImageSource source,
  ) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Video upload করতে Login করতে হবে',
      );
      return;
    }

    try {
      final XFile? file =
          await _picker.pickVideo(
        source: source,
        maxDuration:
            const Duration(
          minutes: 3,
        ),
      );

      if (file == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      await Navigator.of(context)
          .push(
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

      if (_bottomIndex == 0 &&
          _videos.isNotEmpty) {
        await _prepareVideo(
          _currentIndex,
        );
      }
    } catch (_) {
      _showMessage(
        'ভিডিও নির্বাচন করা যায়নি',
      );
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

  // ============================================================
  // PROFILE
  // ============================================================

  Future<void> _openEditProfile() async {
    final user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Profile edit করতে Login করতে হবে',
      );
      return;
    }

    try {
      final result =
          await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const EditProfileScreen(),
        ),
      );

      if (result is Map) {
        if (mounted) {
          setState(() {
            _username =
                (result['username'] ??
                        _username)
                    .toString();

            _bio =
                (result['bio'] ??
                        _bio)
                    .toString();

            _profileImage =
                (result[
                            'profileImage'] ??
                        _profileImage)
                    .toString();
          });
        }
      } else {
        await _loadUserProfile();

        if (mounted) {
          setState(() {});
        }
      }
    } catch (_) {
      _showMessage(
        'Profile edit screen খোলা যায়নি',
      );
    }
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Future<void> _selectBottom(
    int index,
  ) async {
    if (index == _bottomIndex) {
      if (index == 0 &&
          _videos.isNotEmpty) {
        await _prepareVideo(
          _currentIndex,
        );
      }

      return;
    }

    if (_bottomIndex == 0) {
      for (final controller
          in _controllers.values) {
        unawaited(
          controller.pause(),
        );
      }
    }

    if (!mounted) return;

    if (index == 2) {
      await _openCreateScreen();

      if (!mounted) return;

      if (_bottomIndex == 0) {
        await _prepareVideo(
          _currentIndex,
        );
      }

      return;
    }

    setState(() {
      _bottomIndex = index;
    });

    if (index == 0) {
      await _prepareVideo(
        _currentIndex,
      );
    }
  }

  Future<void> _switchTopTab(
    int index,
  ) async {
    if (_topIndex == index) {
      return;
    }

    for (final controller
        in _controllers.values) {
      unawaited(
        controller.pause(),
      );
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
        .where(
          (video) =>
              _followingIds.contains(
            video.userId,
          ),
        )
        .toList();

    if (following.isNotEmpty) {
      final actualIndex =
          _videos.indexWhere(
        (video) =>
            video.id ==
            following.first.id,
      );

      setState(() {
        _currentIndex =
            actualIndex < 0
                ? 0
                : actualIndex;
      });

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      await _prepareVideo(
        _currentIndex,
      );
    }
  }

  // ============================================================
  // HOME FEED
  // ============================================================

  Widget _buildHomeScreen() {
  if (_loading) {
    return const Center(
      child: CircularProgressIndicator(
        color: _pink,
      ),
    );
  }

  // ==============================
  // FOLLOWING FEED
  // ==============================
  if (_topIndex == 1) {
    return FollowingFeed(
      videos: _videos,
      followingIds: _followingIds,
      pageController: _pageController,
      onPageChanged: (index, feed) {
        final typedFeed = feed.cast<VideoPost>();

        unawaited(
          _onVideoChanged(
            index,
            typedFeed,
          ),
        );
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

  // ==============================
  // FOR YOU FEED
  // ==============================
  final feed = _videos;

  if (feed.isEmpty) {
    return _buildEmptyFeed();
  }

  return ForYouFeed(
    videos: feed,
    pageController: _pageController,
    onPageChanged: (index) {
      unawaited(
        _onVideoChanged(
          index,
          feed,
        ),
      );
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
          padding:
              const EdgeInsets.all(30),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .people_outline_rounded,
                color:
                    Colors.white54,
                size: 62,
              ),
              const SizedBox(
                height: 18,
              ),
              const Text(
                'Following feed এখনো খালি',
                style: TextStyle(
                  color:
                      Colors.white,
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              const Text(
                'Creators-কে Follow করলে তাদের ভিডিও এখানে দেখা যাবে।',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              ElevatedButton(
                onPressed: () {
                  _switchTopTab(0);
                },
                style:
                    ElevatedButton
                        .styleFrom(
                  backgroundColor:
                      _pink,
                  foregroundColor:
                      Colors.white,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                  ),
                ),
                child:
                    const Text(
                  'For You দেখুন',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          const Icon(
            Icons
                .video_collection_outlined,
            color:
                Colors.white54,
            size: 58,
          ),
          const SizedBox(
            height: 14,
          ),
          const Text(
            'No videos yet',
            style: TextStyle(
              color:
                  Colors.white,
              fontSize: 18,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          ElevatedButton(
            onPressed:
                _openCreateSheet,
            style:
                ElevatedButton
                    .styleFrom(
              backgroundColor:
                  _pink,
              foregroundColor:
                  Colors.white,
            ),
            child:
                const Text(
              'Upload Video',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPage({
    required VideoPost video,
    required int actualIndex,
    required VideoPlayerController?
        controller,
  }) {
    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap: () {
        unawaited(
          _togglePlay(
            actualIndex,
          ),
        );
      },
      onDoubleTap: () {
        if (!_likedIds.contains(
          video.id,
        )) {
          unawaited(
            _toggleLike(video),
          );
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
          ),

          if (controller != null &&
              controller.value
                  .isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width:
                    controller.value.size.width,
                height:
                    controller.value.size.height,
                child:
                    VideoPlayer(
                  controller,
                ),
              ),
            )
          else
            const Center(
              child:
                  CircularProgressIndicator(
                color:
                    Colors.white,
              ),
            ),

          const IgnorePointer(
            child:
                DecoratedBox(
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topCenter,
                  end:
                      Alignment.center,
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),

          const IgnorePointer(
            child:
                DecoratedBox(
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.bottomCenter,
                  end:
                      Alignment.center,
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

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            10,
            10,
            0,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation:
                    _logoController,
                builder: (_, __) {
                  return Opacity(
                    opacity:
                        _logoOpacity.value,
                    child:
                        Transform.scale(
                      scale:
                          _logoScale.value,
                      child:
                          Container(
                        width: 40,
                        height: 40,
                        decoration:
                            BoxDecoration(
                          gradient:
                              const LinearGradient(
                            colors: [
                              _pink,
                              _cyan,
                            ],
                            begin:
                                Alignment
                                    .topLeft,
                            end:
                                Alignment
                                    .bottomRight,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            13,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _pink
                                  .withOpacity(
                                0.35,
                              ),
                              blurRadius:
                                  15,
                              spreadRadius:
                                  1,
                            ),
                          ],
                        ),
                        alignment:
                            Alignment.center,
                        child:
                            const Text(
                          'P',
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontSize:
                                24,
                            fontWeight:
                                FontWeight.w900,
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
                selected:
                    _topIndex == 0,
                onTap: () {
                  unawaited(
                    _switchTopTab(0),
                  );
                },
              ),
              const SizedBox(
                width: 18,
              ),
              _topTab(
                title: 'Following',
                selected:
                    _topIndex == 1,
                onTap: () {
                  unawaited(
                    _switchTopTab(1),
                  );
                },
              ),
              const SizedBox(
                width: 8,
              ),
              IconButton(
                onPressed:
                    _openSearch,
                icon:
                    const Icon(
                  Icons
                      .search_rounded,
                  color:
                      Colors.white,
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
        padding:
            const EdgeInsets.symmetric(
          vertical: 8,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white60,
                fontSize: 15,
                fontWeight: selected
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 180,
              ),
              width:
                  selected ? 24 : 0,
              height: 2.5,
              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius
                        .circular(
                  10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RIGHT ACTIONS
  // ============================================================

  Widget _buildRightActions(
    VideoPost video,
  ) {
    final liked =
        _likedIds.contains(
      video.id,
    );

    final saved =
        _savedIds.contains(
      video.id,
    );

    final following =
        _followingIds.contains(
      video.userId,
    );

    final likeCount =
        video.likeCount +
            (_likeDeltas[
                    video.id] ??
                0);

    final commentCount =
        video.commentCount +
            (_commentDeltas[
                    video.id] ??
                0);

    final saveCount =
        video.saveCount +
            (_saveDeltas[
                    video.id] ??
                0);

    final shareCount =
        video.shareCount +
            (_shareDeltas[
                    video.id] ??
                0);

    return Positioned(
      right: 10,
      bottom: 116,
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          if (video.userId !=
              _auth.currentUser?.uid)
            _actionButton(
              icon: following
                  ? Icons.person
                  : Icons
                      .person_add_alt_1_rounded,
              label: following
                  ? 'Following'
                  : 'Follow',
              active:
                  following,
              onTap: () {
                unawaited(
                  _toggleFollow(
                    video,
                  ),
                );
              },
            ),
          const SizedBox(
            height: 13,
          ),
          _actionButton(
            icon: liked
                ? Icons
                    .favorite_rounded
                : Icons
                    .favorite_border_rounded,
            label:
                _formatCount(
              likeCount,
            ),
            active: liked,
            onTap: () {
              unawaited(
                _toggleLike(
                  video,
                ),
              );
            },
          ),
          const SizedBox(
            height: 13,
          ),
          _actionButton(
            icon: Icons
                .mode_comment_outlined,
            label:
                _formatCount(
              commentCount,
            ),
            onTap: () {
              unawaited(
                _openComments(
                  video,
                ),
              );
            },
          ),
          const SizedBox(
            height: 13,
          ),
          _actionButton(
            icon: saved
                ? Icons
                    .bookmark_rounded
                : Icons
                    .bookmark_border_rounded,
            label:
                _formatCount(
              saveCount,
            ),
            active: saved,
            onTap: () {
              unawaited(
                _toggleSave(
                  video,
                ),
              );
            },
          ),
          const SizedBox(
            height: 13,
          ),
          _actionButton(
            icon:
                Icons.share_rounded,
            label:
                _formatCount(
              shareCount,
            ),
            onTap: () {
              unawaited(
                _shareVideo(
                  video,
                ),
              );
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
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 43,
              height: 43,
              decoration:
                  BoxDecoration(
                color: Colors.black
                    .withOpacity(
                  0.35,
                ),
                shape:
                    BoxShape.circle,
                border:
                    Border.all(
                  color: Colors.white
                      .withOpacity(
                    0.12,
                  ),
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
            const SizedBox(
              height: 3,
            ),
            Text(
              label,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 10.5,
                fontWeight:
                    FontWeight.w600,
                shadows: [
                  Shadow(
                    color:
                        Colors.black,
                    blurRadius:
                        5,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  

  Widget _buildVideoInfo(
    VideoPost video,
  ) {
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
              _profileAvatar(
                imageUrl: '',
                size: 40,
              ),
              const SizedBox(
                width: 10,
              ),
              Flexible(
                child: Text(
                  video.username
                          .startsWith('@')
                      ? video.username
                      : '@${video.username}',
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w800,
                    shadows: [
                      Shadow(
                        color:
                            Colors.black,
                        blurRadius:
                            5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 9,
          ),
          if (video.caption
              .isNotEmpty)
            Text(
              video.caption,
              maxLines: 3,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 14,
                height: 1.25,
                fontWeight:
                    FontWeight.w500,
                shadows: [
                  Shadow(
                    color:
                        Colors.black,
                    blurRadius:
                        5,
                  ),
                ],
              ),
            ),
          if (video.hashtags
              .isNotEmpty) ...[
            const SizedBox(
              height: 5,
            ),
            Text(
              video.hashtags,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 13,
                fontWeight:
                    FontWeight.w700,
                shadows: [
                  Shadow(
                    color:
                        Colors.black,
                    blurRadius:
                        5,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // FRIENDS
  // ============================================================

  Widget _buildFriendsScreen() {
    final user =
        _auth.currentUser;

    final creators =
        <String, VideoPost>{};

    for (final video
        in _videos) {
      if (video.userId.isEmpty) {
        continue;
      }

      if (user != null &&
          video.userId ==
              user.uid) {
        continue;
      }

      creators.putIfAbsent(
        video.userId,
        () => video,
      );
    }

    final followingCreators =
        creators.values
            .where(
              (video) =>
                  _followingIds
                      .contains(
                video.userId,
              ),
            )
            .toList();

    final suggestedCreators =
        creators.values
            .where(
              (video) =>
                  !_followingIds
                      .contains(
                video.userId,
              ),
            )
            .toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Padding(
            padding:
                EdgeInsets.fromLTRB(
              18,
              16,
              18,
              4,
            ),
            child: Text(
              'Friends',
              style: TextStyle(
                color:
                    Colors.white,
                fontSize: 26,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),
          const Padding(
            padding:
                EdgeInsets.fromLTRB(
              18,
              0,
              18,
              14,
            ),
            child: Text(
              'Connect with creators on PALOK',
              style: TextStyle(
                color:
                    Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                18,
                4,
                18,
                100,
              ),
              children: [
                if (followingCreators
                    .isNotEmpty) ...[
                  const Text(
                    'Following',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  ...followingCreators
                      .map(
                    (video) =>
                        _creatorCard(
                      video,
                      true,
                    ),
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                ],
                const Text(
                  'Suggested creators',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                if (suggestedCreators
                    .isEmpty)
                  const Padding(
                    padding:
                        EdgeInsets.only(
                      top: 35,
                    ),
                    child: Center(
                      child: Text(
                        'কোনো creator পাওয়া যায়নি',
                        style:
                            TextStyle(
                          color:
                              Colors.white54,
                        ),
                      ),
                    ),
                  )
                else
                  ...suggestedCreators
                      .map(
                    (video) =>
                        _creatorCard(
                      video,
                      false,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _creatorCard(
    VideoPost video,
    bool following,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color: Colors.white
            .withOpacity(
          0.06,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child: Row(
        children: [
          _profileAvatar(
            imageUrl: '',
            size: 48,
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
                    color:
                        Colors.white,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  '${_formatCount(video.likeCount)} likes',
                  style:
                      const TextStyle(
                    color:
                        Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              unawaited(
                _toggleFollow(
                  video,
                ),
              );
            },
            style:
                OutlinedButton
                    .styleFrom(
              foregroundColor:
                  following
                      ? Colors.white54
                      : Colors.white,
              side: BorderSide(
                color: following
                    ? Colors.white24
                    : _pink,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
              ),
            ),
            child: Text(
              following
                  ? 'Following'
                  : 'Follow',
              style:
                  const TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INBOX
  // ============================================================

  Widget _buildInboxScreen() {
    final user =
        _auth.currentUser;

    if (user == null) {
      return const Center(
        child: Text(
          'Login করুন Inbox ব্যবহার করতে',
          style: TextStyle(
            color:
                Colors.white54,
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Padding(
            padding:
                EdgeInsets.fromLTRB(
              18,
              16,
              18,
              14,
            ),
            child: Text(
              'Inbox',
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize: 26,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<
                    Map<String,
                        dynamic>>>(
              stream: _firestore
                  .collection(
                    'users',
                  )
                  .doc(user.uid)
                  .collection(
                    'notifications',
                  )
                  .limit(100)
                  .snapshots(),
              builder:
                  (context,
                      snapshot) {
                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(
                      color:
                          _pink,
                    ),
                  );
                }

                if (snapshot
                    .hasError) {
                  return const Center(
                    child: Text(
                      'Inbox load করা যায়নি',
                      style:
                          TextStyle(
                        color:
                            Colors.white54,
                      ),
                    ),
                  );
                }

                final docs =
                    snapshot.data
                            ?.docs ??
                        [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize:
                          MainAxisSize
                              .min,
                      children: [
                        Icon(
                          Icons
                              .notifications_none_rounded,
                          color:
                              Colors.white30,
                          size: 60,
                        ),
                        SizedBox(
                          height: 14,
                        ),
                        Text(
                          'No notifications yet',
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontSize:
                                17,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        Text(
                          'Like, comment বা follow এলে এখানে দেখা যাবে',
                          textAlign:
                              TextAlign
                                  .center,
                          style:
                              TextStyle(
                            color:
                                Colors.white54,
                            fontSize:
                                13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final notifications =
                    [...docs];

                notifications.sort(
                  (a, b) {
                    final aTime =
                        a.data()[
                            'createdAt'];

                    final bTime =
                        b.data()[
                            'createdAt'];

                    if (aTime
                            is Timestamp &&
                        bTime
                            is Timestamp) {
                      return bTime
                          .compareTo(
                        aTime,
                      );
                    }

                    return 0;
                  },
                );

                return ListView
                    .separated(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    18,
                    4,
                    18,
                    100,
                  ),
                  itemCount:
                      notifications
                          .length,
                  separatorBuilder:
                      (_, __) =>
                          const SizedBox(
                    height: 8,
                  ),
                  itemBuilder:
                      (_, index) {
                    final data =
                        notifications[
                                index]
                            .data();

                    return Container(
                      padding:
                          const EdgeInsets
                              .all(
                        14,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors
                            .white
                            .withOpacity(
                          0.06,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration:
                                BoxDecoration(
                              color:
                                  _pink.withOpacity(
                                0.15,
                              ),
                              shape:
                                  BoxShape
                                      .circle,
                            ),
                            child: Icon(
                              _notificationIcon(
                                data['type']
                                        ?.toString() ??
                                    '',
                              ),
                              color:
                                  _pink,
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child:
                                RichText(
                              text:
                                  TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        data['fromUsername'] ??
                                            'Someone',
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white,
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' ${data['text'] ?? ''}',
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white70,
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

  IconData _notificationIcon(
    String type,
  ) {
    switch (type) {
      case 'like':
        return Icons
            .favorite_rounded;

      case 'comment':
        return Icons
            .mode_comment_rounded;

      case 'follow':
        return Icons
            .person_add_rounded;

      default:
        return Icons
            .notifications_rounded;
    }
  }

  // ============================================================
  // PROFILE SCREEN
  // ============================================================

  Widget _buildProfileScreen() {
    final user =
        _auth.currentUser;

    final ownVideos =
        user == null
            ? <VideoPost>[]
            : _videos
                .where(
                  (video) =>
                      video.userId ==
                      user.uid,
                )
                .toList();

    int totalLikes = 0;

    for (final video
        in ownVideos) {
      totalLikes +=
          video.likeCount +
              (_likeDeltas[
                      video.id] ??
                  0);
    }

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                18,
                18,
                18,
                10,
              ),
              child: Row(
                children: [
                  _profileAvatar(
                    imageUrl:
                        _profileImage,
                    size: 82,
                  ),
                  const SizedBox(
                    width: 18,
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceAround,
                      children: [
                        _profileStat(
                          value:
                              ownVideos
                                  .length
                                  .toString(),
                          label:
                              'Videos',
                        ),
                        _profileStat(
                          value:
                              _formatCount(
                            _followersCount,
                          ),
                          label:
                              'Followers',
                        ),
                        _profileStat(
                          value:
                              _formatCount(
                            _followingCount,
                          ),
                          label:
                              'Following',
                        ),
                        _profileStat(
                          value:
                              _formatCount(
                            totalLikes,
                          ),
                          label:
                              'Likes',
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
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 18,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    _username,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 19,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  if (_email
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      _email,
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (_bio
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      _bio,
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(
                    height: 14,
                  ),
                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        OutlinedButton(
                      onPressed:
                          _openEditProfile,
                      style:
                          OutlinedButton
                              .styleFrom(
                        foregroundColor:
                            Colors.white,
                        side:
                            const BorderSide(
                          color:
                              Colors.white24,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            13,
                          ),
                        ),
                      ),
                      child:
                          const Text(
                        'Edit Profile',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  const Divider(
                    color:
                        Colors.white12,
                    height: 1,
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                ],
              ),
            ),
          ),
          if (ownVideos.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding:
                      EdgeInsets.only(
                    bottom: 80,
                  ),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize
                            .min,
                    children: [
                      Icon(
                        Icons
                            .video_library_outlined,
                        color:
                            Colors.white30,
                        size: 55,
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      Text(
                        'তোমার এখনো কোনো ভিডিও নেই',
                        style:
                            TextStyle(
                          color:
                              Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                2,
                0,
                2,
                100,
              ),
              sliver: SliverGrid(
                delegate:
                    SliverChildBuilderDelegate(
                  (context, index) {
                    final video =
                        ownVideos[index];

                    return GestureDetector(
                      onTap: () async {
                        final actualIndex =
                            _videos
                                .indexWhere(
                          (item) =>
                              item.id ==
                              video.id,
                        );

                        if (actualIndex >=
                            0) {
                          await _goToVideo(
                            actualIndex,
                          );
                        }
                      },
                      child: Container(
                        color: Colors
                            .white
                            .withOpacity(
                          0.04,
                        ),
                        child:
                            const Center(
                          child: Icon(
                            Icons
                                .play_arrow_rounded,
                            color:
                                Colors.white70,
                            size: 38,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount:
                      ownVideos.length,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio:
                      0.72,
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
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Text(
          value,
          style:
              const TextStyle(
            color:
                Colors.white,
            fontSize: 15,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        const SizedBox(
          height: 3,
        ),
        Text(
          label,
          style:
              const TextStyle(
            color:
                Colors.white54,
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
        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,
          gradient:
              const LinearGradient(
            colors: [
              _pink,
              _cyan,
            ],
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
          ),
          border:
              Border.all(
            color:
                Colors.white24,
            width: 2,
          ),
        ),
        alignment:
            Alignment.center,
        child:
            const Icon(
          Icons.person_rounded,
          color:
              Colors.white,
          size: 34,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        border:
            Border.all(
          color:
              Colors.white24,
          width: 2,
        ),
        image:
            DecorationImage(
          image:
              NetworkImage(
            imageUrl,
          ),
          fit:
              BoxFit.cover,
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          height: 78,
          decoration:
              const BoxDecoration(
            color: Colors.black,
            border:
                Border(
              top: BorderSide(
                color:
                    Colors.white12,
                width: 0.7,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child:
                    _bottomItem(
                  icon:
                      Icons.home_rounded,
                  label:
                      'Home',
                  index: 0,
                ),
              ),
              Expanded(
                child:
                    _bottomItem(
                  icon: Icons
                      .people_alt_outlined,
                  label:
                      'Friends',
                  index: 1,
                ),
              ),
              SizedBox(
                width: 92,
                child: Center(
                  child:
                      GestureDetector(
                    onTap: () {
                      unawaited(
                        _selectBottom(
                          2,
                        ),
                      );
                    },
                    child:
                        Container(
                      width: 72,
                      height: 48,
                      decoration:
                          BoxDecoration(
                        gradient:
                            const LinearGradient(
                          colors: [
                            _cyan,
                            _pink,
                          ],
                          begin:
                              Alignment
                                  .centerLeft,
                          end:
                              Alignment
                                  .centerRight,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _pink
                                .withOpacity(
                              0.20,
                            ),
                            blurRadius:
                                15,
                          ),
                        ],
                      ),
                      child:
                          const Icon(
                        Icons
                            .add_rounded,
                        color:
                            Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child:
                    _bottomItem(
                  icon: Icons
                      .chat_bubble_outline_rounded,
                  label:
                      'Inbox',
                  index: 3,
                ),
              ),
              Expanded(
                child:
                    _bottomItem(
                  icon: Icons
                      .person_outline_rounded,
                  label:
                      'Profile',
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
    final selected =
        _bottomIndex == index;

    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap: () {
        unawaited(
          _selectBottom(index),
        );
      },
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment
                .center,
        children: [
          Icon(
            icon,
            color: selected
                ? Colors.white
                : Colors.white54,
            size: 24,
          ),
          const SizedBox(
            height: 3,
          ),
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white54,
              fontSize: 10,
              fontWeight: selected
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(message),
          behavior:
              SnackBarBehavior
                  .floating,
          duration:
              const Duration(
            seconds: 2,
          ),
        ),
      );
  }

  String _formatCount(
    int value,
  ) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(
        value % 1000000 == 0 ? 0 : 1,
      )}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(
        value % 1000 == 0 ? 0 : 1,
      )}K';
    }

    return value.toString();
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.round();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _hashtagsToString(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    if (value is List) {
      return value
          .map(
            (e) => e.toString(),
          )
          .join(' ');
    }

    return value.toString();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    Widget body;

    switch (_bottomIndex) {
      case 0:
        body =
            _buildHomeScreen();
        break;

      case 1:
        body =
            _buildFriendsScreen();
        break;

      case 3:
        body =
            _buildInboxScreen();
        break;

      case 4:
        body =
            _buildProfileScreen();
        break;

      default:
        body =
            _buildHomeScreen();
    }

    return Scaffold(
      backgroundColor:
          Colors.black,
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

// ============================================================
// VIDEO POST MODEL
// ============================================================

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
