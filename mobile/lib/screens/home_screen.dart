import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'upload_video_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

import 'edit_profile_screen.dart';
import 'features/video/video_interaction_service.dart';

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

  final VideoInteractionService _interactionService =
      VideoInteractionService();

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
      final doc =
          await _firestore.collection('users').doc(user.uid).get();

      final data = doc.data();

      if (data != null) {
        final username =
            (data['username'] ?? '').toString().trim();

        final displayName =
            (data['displayName'] ?? '').toString().trim();

        _username = username.isNotEmpty
            ? username
            : displayName.isNotEmpty
                ? displayName
                : user.displayName?.trim().isNotEmpty == true
                    ? user.displayName!.trim()
                    : 'PALOK User';

        _bio = (data['bio'] ?? '').toString();

        final email =
            (data['email'] ?? '').toString().trim();

        _email =
            email.isNotEmpty ? email : (user.email ?? '');

        _profileImage =
            (data['profileImage'] ?? '').toString();

        _followersCount =
            _toInt(data['followersCount']);

        _followingCount =
            _toInt(data['followingCount']);
      } else {
        _username =
            user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : 'PALOK User';

        _email = user.email ?? '';
      }
    } catch (_) {
      _username =
          user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'PALOK User';

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
      // User data loading failure should not
      // prevent Home Screen from opening.
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

      final loadedVideos = snapshot.docs
          .map(
            (doc) => VideoPost.fromFirestore(
              doc.id,
              doc.data(),
            ),
          )
          .where(
            (video) => video.videoUrl.trim().isNotEmpty,
          )
          .toList();

      if (loadedVideos.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _videos = loadedVideos;
        });

        return;
      }
    } catch (_) {
      // Firebase failure -> demo videos
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

  Future<void> _prepareVideo(int index) async {
    if (!mounted ||
        index < 0 ||
        index >= _videos.length) {
      return;
    }

    if (_controllers.containsKey(index)) {
      final existing = _controllers[index]!;

      if (existing.value.isInitialized) {
        if (index == _currentIndex &&
            _bottomIndex == 0) {
          await existing.play();
        }

        return;
      }
    }

    final video = _videos[index];

    late VideoPlayerController controller;

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

    try {
      await controller.initialize();

      await controller.setLooping(true);

      if (!mounted) return;

      if (index == _currentIndex &&
          _bottomIndex == 0) {
        await controller.play();
      }

      if (index + 1 < _videos.length) {
        unawaited(
          _prepareVideo(index + 1),
        );
      }

      if (index - 1 >= 0) {
        unawaited(
          _prepareVideo(index - 1),
        );
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

  void _disposeFarControllers(
    int centerIndex,
  ) {
    final keys =
        _controllers.keys.toList();

    for (final key in keys) {
      if ((key - centerIndex).abs() > 1) {
        final controller =
            _controllers.remove(key);

        controller?.dispose();
      }
    }
  }

  bool _isNetworkUrl(String value) {
    return value.startsWith('http://') ||
        value.startsWith('https://');
  }

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

    if (actualIndex < 0) return;

    for (final entry
        in _controllers.entries) {
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

  Future<void> _togglePlay(
    int actualIndex,
  ) async {
    final controller =
        _controllers[actualIndex];

    if (controller == null ||
        !controller.value.isInitialized) {
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

  Future<void> _toggleLike(
    VideoPost video,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Like করতে Login করতে হবে',
      );
      return;
    }

    final wasLiked =
        _likedIds.contains(video.id);

    setState(() {
      if (wasLiked) {
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
      final isLiked =
          await _interactionService.toggleLike(
        videoId: video.id,
        videoOwnerId: video.userId,
        currentUsername: _username,
      );

      if (isLiked != !wasLiked) {
        throw Exception(
          'Like state mismatch',
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (wasLiked) {
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
        'Like পরিবর্তন করা যায়নি',
      );
    }
  }

  Future<void> _toggleSave(
    VideoPost video,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Save করতে Login করতে হবে',
      );
      return;
    }

    final wasSaved =
        _savedIds.contains(video.id);

    setState(() {
      if (wasSaved) {
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
      final isSaved =
          await _interactionService.toggleSave(
        videoId: video.id,
      );

      if (isSaved != !wasSaved) {
        throw Exception(
          'Save state mismatch',
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

  Future<void> _shareVideo(
    VideoPost video,
  ) async {
    try {
      await _interactionService.shareVideo(
        videoId: video.id,
      );

      if (!mounted) return;

      setState(() {
        _shareDeltas[video.id] =
            (_shareDeltas[video.id] ?? 0) + 1;
      });
    } catch (_) {
      // Share cancelled or failed.
    }
  }

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _hashtagsToString(
    dynamic value,
  ) {
    if (value is List) {
      return value
          .map((e) => e.toString())
          .join(' ');
    }

    return value?.toString() ?? '';
  }

  int _likeCount(
    VideoPost video,
  ) {
    return (video.likeCount +
            (_likeDeltas[video.id] ?? 0))
        .clamp(0, 999999999);
  }

  int _commentCount(
    VideoPost video,
  ) {
    return (video.commentCount +
            (_commentDeltas[video.id] ?? 0))
        .clamp(0, 999999999);
  }

  int _saveCount(
    VideoPost video,
  ) {
    return (video.saveCount +
            (_saveDeltas[video.id] ?? 0))
        .clamp(0, 999999999);
  }

  int _shareCount(
    VideoPost video,
  ) {
    return (video.shareCount +
            (_shareDeltas[video.id] ?? 0))
        .clamp(0, 999999999);
  }

  String _formatCount(
    int count,
  ) {
    if (count >= 1000000) {
      final value =
          count / 1000000;

      return '${value.toStringAsFixed(
        value >= 10 ? 0 : 1,
      )}M';
    }

    if (count >= 1000) {
      final value =
          count / 1000;

      return '${value.toStringAsFixed(
        value >= 10 ? 0 : 1,
      )}K';
    }

    return count.toString();
  }

  Widget _avatar({
    double size = 44,
  }) {
    final image =
        _profileImage.trim();

    if (image.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor:
            Colors.white12,
        child: Icon(
          Icons.person,
          color: Colors.white70,
          size: size * 0.55,
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundImage:
          NetworkImage(image),
      backgroundColor:
          Colors.white12,
    );
  }

  Future<void> _openComments(
    VideoPost video,
  ) async {
    final result =
        await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return _CommentsSheet(
          videoId: video.id,
          ownerId: video.userId,
          ownerUsername:
              video.username,
          currentUsername:
              _username,
          currentUserId:
              _auth.currentUser?.uid ?? '',
        );
      },
    );

    if (!mounted) return;

    if (result != null &&
        result > 0) {
      setState(() {
        _commentDeltas[video.id] =
            (_commentDeltas[video.id] ?? 0) +
                result;
      });
    }
  }

  Future<void> _openSearch() async {
    final queryController =
        TextEditingController();

    final query =
        await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return AnimatedPadding(
          duration:
              const Duration(milliseconds: 180),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context)
                .viewInsets
                .bottom,
          ),
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              28,
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
                    color: Colors.white24,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                TextField(
                  controller:
                      queryController,
                  autofocus: true,
                  style:
                      const TextStyle(
                    color: Colors.white,
                  ),
                  decoration:
                      InputDecoration(
                    hintText:
                        'Search videos, users...',
                    hintStyle:
                        const TextStyle(
                      color:
                          Colors.white54,
                    ),
                    prefixIcon:
                        const Icon(
                      Icons.search,
                      color:
                          Colors.white70,
                    ),
                    filled: true,
                    fillColor:
                        Colors.white10,
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
                    Navigator.pop(
                      context,
                      value.trim(),
                    );
                  },
                ),
                const SizedBox(
                  height: 14,
                ),
                SizedBox(
                  width:
                      double.infinity,
                  child:
                      ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        queryController
                            .text
                            .trim(),
                      );
                    },
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
                      'Search',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    queryController.dispose();

    if (query == null ||
        query.isEmpty) {
      return;
    }

    _showMessage(
      'Search: $query',
    );
  }

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
        .where(
          (video) => _followingIds.contains(video.userId),
        )
        .toList();

    final suggestedCreators = creators.values
        .where(
          (video) => !_followingIds.contains(video.userId),
        )
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
              padding: const EdgeInsets.fromLTRB(
                18,
                4,
                18,
                100,
              ),
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

  Widget _creatorCard(
    VideoPost video,
    bool following,
  ) {
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
              unawaited(
                _toggleFollow(video),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  following
                      ? Colors.white54
                      : Colors.white,
              side: BorderSide(
                color:
                    following
                        ? Colors.white24
                        : _pink,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
            child: Text(
              following
                  ? 'Following'
                  : 'Follow',
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
                    );

                    return ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(
                        18,
                        12,
                        18,
                        18,
                      ),
                      itemCount: comments.length,
                      itemBuilder: (_, index) {
                        final data = comments[index].data();

                        final username =
                            (data['username'] ?? 'PALOK User').toString();

                        final text =
                            (data['text'] ?? '').toString();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 17),
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
                            borderRadius: BorderRadius.circular(22),
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
                                child: CircularProgressIndicator(
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

          message =
              errorJson['error']?['message']?.toString() ??
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

      final caption =
          _captionController.text.trim();

      final hashtags =
          _extractHashtags(caption);

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
        'createdAt':
            FieldValue.serverTimestamp(),
      });

      await widget.onPosted();

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে 🎉'),
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
    final matches =
        RegExp(r'#[A-Za-z0-9_\u0980-\u09FF]+')
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
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration:
          const Duration(milliseconds: 180),
      padding:
          EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height:
            MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius:
              BorderRadius.vertical(
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
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  20,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(18),
                      child: Container(
                        width: double.infinity,
                        height: 360,
                        color: Colors.black,
                        child:
                            _previewController != null &&
                                    _previewController!
                                        .value
                                        .isInitialized
                                ? FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width:
                                          _previewController!
                                              .value
                                              .size
                                              .width,
                                      height:
                                          _previewController!
                                              .value
                                              .size
                                              .height,
                                      child:
                                          VideoPlayer(
                                        _previewController!,
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child:
                                        CircularProgressIndicator(
                                      color:
                                          Colors.white,
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller:
                          _captionController,
                      maxLines: 4,
                      enabled: !_uploading,
                      style:
                          const TextStyle(
                        color: Colors.white,
                      ),
                      decoration:
                          InputDecoration(
                        hintText:
                            'Write a caption... #PALOK',
                        hintStyle:
                            const TextStyle(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor:
                            Colors.white
                                .withOpacity(0.07),
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
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                18,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _uploading
                          ? null
                          : _postVideo,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFFF2D55),
                    disabledBackgroundColor:
                        Colors.white12,
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
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
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Post to PALOK',
                          style: TextStyle(
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
}
