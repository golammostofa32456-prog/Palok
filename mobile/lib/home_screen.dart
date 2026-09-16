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

  final List<String> _demoVideos = const [
    'assets/videos/video.mp4',
    'assets/videos/video1.mp4',
    'assets/videos/video2.mp4',
  ];

  final List<VideoPost> _videos = [];

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, Future<void>> _initializing = {};

  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  final Set<String> _followingIds = {};

  final Map<String, int> _demoLikeDeltas = {};
  final Map<String, int> _demoSaveDeltas = {};
  final Map<String, int> _demoCommentCounts = {};
  final Map<String, int> _demoShareDeltas = {};

  int _currentIndex = 0;
  int _bottomIndex = 0;
  int _topIndex = 0;

  bool _loading = true;
  bool _isPlaying = true;

  late final AnimationController _logoController;

  VideoPost? get _currentVideo {
    if (_videos.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _videos.length) {
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

    _loadData();
  }

  @override
  void dispose() {
    _logoController.dispose();

    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadUserInteractions();
    await _loadFollowing();
    await _listenToVideos();
  }

  Future<void> _loadUserInteractions() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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

      _likedIds
        ..clear()
        ..addAll(likedSnapshot.docs.map((doc) => doc.id));

      _savedIds
        ..clear()
        ..addAll(savedSnapshot.docs.map((doc) => doc.id));
    } catch (_) {}
  }

  Future<void> _loadFollowing() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();

      _followingIds
        ..clear()
        ..addAll(snapshot.docs.map((doc) => doc.id));
    } catch (_) {}
  }

  Future<void> _listenToVideos() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final remoteVideos = snapshot.docs.map((doc) {
        final data = doc.data();

        return VideoPost(
          id: doc.id,
          videoUrl: data['videoUrl'] as String? ?? '',
          username: data['username'] as String? ?? '@palok_user',
          caption: data['caption'] as String? ?? '',
          hashtags: data['hashtags'] as String? ?? '',
          likes: _toInt(data['likes']),
          comments: _toInt(data['comments']),
          saves: _toInt(data['saves']),
          shares: _toInt(data['shares']),
        );
      }).where((video) => video.videoUrl.isNotEmpty).toList();

      final demos = _demoVideos.asMap().entries.map((entry) {
        final index = entry.key;

        return VideoPost(
          id: null,
          videoUrl: entry.value,
          username: '@palok',
          caption: [
            'Welcome to PALOK 🎬',
            'Create. Share. Discover. ✨',
            'Your short-video world starts here 🚀',
          ][index],
          hashtags: '#PALOK #ShortVideo',
          likes: [11700, 8500, 6200][index],
          comments: [234, 128, 94][index],
          saves: [811, 452, 301][index],
          shares: [431, 201, 146][index],
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _videos
          ..clear()
          ..addAll(remoteVideos)
          ..addAll(demos);

        _loading = false;
      });

      if (_videos.isNotEmpty) {
        await _prepareCurrentVideo();
      }
    } catch (_) {
      final demos = _demoVideos.asMap().entries.map((entry) {
        final index = entry.key;

        return VideoPost(
          id: null,
          videoUrl: entry.value,
          username: '@palok',
          caption: [
            'Welcome to PALOK 🎬',
            'Create. Share. Discover. ✨',
            'Your short-video world starts here 🚀',
          ][index],
          hashtags: '#PALOK #ShortVideo',
          likes: [11700, 8500, 6200][index],
          comments: [234, 128, 94][index],
          saves: [811, 452, 301][index],
          shares: [431, 201, 146][index],
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _videos
          ..clear()
          ..addAll(demos);

        _loading = false;
      });

      await _prepareCurrentVideo();
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  String _interactionKey(VideoPost video) {
    return video.id ?? video.videoUrl;
  }

  Future<void> _prepareCurrentVideo() async {
    if (_videos.isEmpty) return;

    final video = _videos[_currentIndex];
    final key = _interactionKey(video);

    if (_controllers.containsKey(key)) {
      final controller = _controllers[key]!;

      if (controller.value.isInitialized) {
        await controller.play();

        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
      }

      return;
    }

    await _initializeVideo(video);
  }

  Future<void> _initializeVideo(VideoPost video) async {
    final key = _interactionKey(video);

    if (_initializing.containsKey(key)) {
      await _initializing[key];
      return;
    }

    late Future<void> future;

    future = () async {
      VideoPlayerController controller;

      if (video.videoUrl.startsWith('http://') ||
          video.videoUrl.startsWith('https://')) {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(video.videoUrl),
        );
      } else {
        controller = VideoPlayerController.asset(video.videoUrl);
      }

      try {
        await controller.initialize();
        await controller.setLooping(true);

        _controllers[key] = controller;

        if (mounted && key == _interactionKey(_currentVideo ?? video)) {
          await controller.play();

          setState(() {
            _isPlaying = true;
          });
        }
      } catch (_) {
        await controller.dispose();
      } finally {
        _initializing.remove(key);
      }
    }();

    _initializing[key] = future;

    await future;
  }

  Future<void> _onPageChanged(int index) async {
    if (index < 0 || index >= _videos.length) return;

    final oldVideo = _currentVideo;

    if (oldVideo != null) {
      final oldKey = _interactionKey(oldVideo);
      await _controllers[oldKey]?.pause();
    }

    setState(() {
      _currentIndex = index;
      _isPlaying = true;
    });

    await _prepareCurrentVideo();
    _disposeUnusedControllers();
  }

  void _disposeUnusedControllers() {
    final keep = <String>{};

    for (int i = _currentIndex - 1; i <= _currentIndex + 1; i++) {
      if (i >= 0 && i < _videos.length) {
        keep.add(_interactionKey(_videos[i]));
      }
    }

    final keys = _controllers.keys.toList();

    for (final key in keys) {
      if (!keep.contains(key)) {
        _controllers[key]?.dispose();
        _controllers.remove(key);
      }
    }
  }

  Future<void> _togglePlayPause() async {
    final video = _currentVideo;

    if (video == null) return;

    final key = _interactionKey(video);
    final controller = _controllers[key];

    if (controller == null || !controller.value.isInitialized) {
      await _initializeVideo(video);
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();

      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    } else {
      await controller.play();

      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    final video = _currentVideo;

    if (video == null) return;

    final key = _interactionKey(video);
    final wasLiked = _likedIds.contains(key);

    setState(() {
      if (wasLiked) {
        _likedIds.remove(key);
      } else {
        _likedIds.add(key);
      }

      if (video.id == null) {
        _demoLikeDeltas[key] = (_demoLikeDeltas[key] ?? 0) +
            (wasLiked ? -1 : 1);
      }
    });

    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final userLikedRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .doc(key);

      if (wasLiked) {
        await userLikedRef.delete();
      } else {
        await userLikedRef.set({
          'videoId': video.id,
          'videoUrl': video.videoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (video.id != null) {
        await _firestore.collection('videos').doc(video.id).update({
          'likes': FieldValue.increment(wasLiked ? -1 : 1),
        });

        if (wasLiked) {
          await _firestore
              .collection('videos')
              .doc(video.id)
              .collection('likes')
              .doc(user.uid)
              .delete();
        } else {
          await _firestore
              .collection('videos')
              .doc(video.id)
              .collection('likes')
              .doc(user.uid)
              .set({
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    final video = _currentVideo;

    if (video == null) return;

    final key = _interactionKey(video);
    final wasSaved = _savedIds.contains(key);

    setState(() {
      if (wasSaved) {
        _savedIds.remove(key);
      } else {
        _savedIds.add(key);
      }

      if (video.id == null) {
        _demoSaveDeltas[key] = (_demoSaveDeltas[key] ?? 0) +
            (wasSaved ? -1 : 1);
      }
    });

    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final savedRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedVideos')
          .doc(key);

      if (wasSaved) {
        await savedRef.delete();
      } else {
        await savedRef.set({
          'videoId': video.id,
          'videoUrl': video.videoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (video.id != null) {
        await _firestore.collection('videos').doc(video.id).update({
          'saves': FieldValue.increment(wasSaved ? -1 : 1),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 900),
            content: Text(
              wasSaved
                  ? 'ভিডিওটি Unsave করা হয়েছে'
                  : 'ভিডিওটি Saved হয়েছে',
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _shareVideo() async {
    final video = _currentVideo;

    if (video == null) return;

    final key = _interactionKey(video);

    final shareText =
        'Watch this video on PALOK 🎬\n\n${video.caption}\n\nPALOK';

    try {
      await Share.share(shareText);

      setState(() {
        if (video.id == null) {
          _demoShareDeltas[key] = (_demoShareDeltas[key] ?? 0) + 1;
        }
      });

      final user = _auth.currentUser;

      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('sharedVideos')
            .add({
          'videoId': video.id,
          'videoUrl': video.videoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (video.id != null) {
        await _firestore.collection('videos').doc(video.id).update({
          'shares': FieldValue.increment(1),
        });
      }
    } catch (_) {}
  }

  Future<void> _openComments() async {
    final video = _currentVideo;

    if (video == null) return;

    final inputController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CommentsSheet(
          video: video,
          inputController: inputController,
          onSend: (text) async {
            await _addComment(video, text);
          },
        );
      },
    );

    inputController.dispose();
  }

  Future<void> _addComment(VideoPost video, String text) async {
    final value = text.trim();

    if (value.isEmpty) return;

    final key = _interactionKey(video);

    setState(() {
      _demoCommentCounts[key] =
          (_demoCommentCounts[key] ?? 0) + 1;
    });

    final user = _auth.currentUser;

    if (user == null) return;

    try {
      if (video.id != null) {
        await _firestore
            .collection('videos')
            .doc(video.id)
            .collection('comments')
            .add({
          'text': value,
          'uid': user.uid,
          'username': user.displayName ?? user.email ?? '@user',
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _firestore.collection('videos').doc(video.id).update({
          'comments': FieldValue.increment(1),
        });
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('demoComments')
            .add({
          'videoUrl': video.videoUrl,
          'text': value,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> _openSearch() async {
    final controller = TextEditingController();
    int activeTab = 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FractionallySizedBox(
              heightFactor: .88,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF101010),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          14,
                          14,
                          8,
                          12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                                child: TextField(
                                  controller: controller,
                                  autofocus: true,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                  decoration:
                                      const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Search on PALOK',
                                    hintStyle: TextStyle(
                                      color: Colors.white38,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Colors.white54,
                                    ),
                                    contentPadding:
                                        EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setSheetState(
                                  () => activeTab = 0,
                                );
                              },
                              child: _searchTab(
                                'Top',
                                activeTab == 0,
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setSheetState(
                                  () => activeTab = 1,
                                );
                              },
                              child: _searchTab(
                                'Users',
                                activeTab == 1,
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setSheetState(
                                  () => activeTab = 2,
                                );
                              },
                              child: _searchTab(
                                'Videos',
                                activeTab == 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(
                        color: Colors.white10,
                        height: 1,
                      ),
                      Expanded(
                        child:
                            ValueListenableBuilder<
                                TextEditingValue>(
                          valueListenable: controller,
                          builder: (context, value, _) {
                            final query = value.text.trim();

                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    query.isEmpty
                                        ? Icons.search_rounded
                                        : Icons
                                            .manage_search_rounded,
                                    color: Colors.white24,
                                    size: 52,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    query.isEmpty
                                        ? 'Search PALOK'
                                        : 'No results yet',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    query.isEmpty
                                        ? 'Find creators, videos and hashtags'
                                        : 'Search UI is ready',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Widget _searchTab(String title, bool active) {
    return SizedBox(
      height: 46,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: active ? Colors.white : Colors.white45,
              fontSize: 14,
              fontWeight:
                  active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: active ? 24 : 0,
            height: 2,
            decoration: BoxDecoration(
              color: _pink,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              22,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Create on PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                _createOption(
                  icon: Icons.videocam_rounded,
                  title: 'Record Video',
                  subtitle: 'Create a new PALOK video',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickVideo(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 10),
                _createOption(
                  icon: Icons.video_library_rounded,
                  title: 'Upload Video',
                  subtitle: 'Choose a video from your phone',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickVideo(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 10),
                _createOption(
                  icon: Icons.music_note_rounded,
                  title: 'Add Sound',
                  subtitle: 'Sound tools coming soon',
                  onTap: () {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Sound feature is coming soon',
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

  Widget _createOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.055),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(.07),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _pink.withOpacity(.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: _pink,
                size: 23,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5),
      );

      if (file == null) return;

      await _openPostComposer(File(file.path));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video নির্বাচন করা যায়নি: $e'),
        ),
      );
    }
  }

  Future<void> _openPostComposer(File file) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PostComposerSheet(
          videoFile: file,
          onPost: (caption, hashtags) async {
            await _uploadVideoToCloudinary(
              file,
              caption,
              hashtags,
            );
          },
        );
      },
    );
  }

  Future<void> _uploadVideoToCloudinary(
    File file,
    String caption,
    String hashtags,
  ) async {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child: CircularProgressIndicator(
            color: _pink,
          ),
        );
      },
    );

    try {
      const cloudName = 'u0jufmrl';
      const uploadPreset = 'palok_video_upload';

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '$cloudName/video/upload',
      );

      final request = http.MultipartRequest(
        'POST',
        uri,
      );

      request.fields['upload_preset'] = uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Cloudinary upload failed: ${response.statusCode}',
        );
      }

      final data = jsonDecode(responseBody)
          as Map<String, dynamic>;

      final videoUrl = data['secure_url'] as String?;

      if (videoUrl == null || videoUrl.isEmpty) {
        throw Exception('Cloudinary video URL পাওয়া যায়নি');
      }

      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Login required');
      }

      await _firestore.collection('videos').add({
        'videoUrl': videoUrl,
        'caption': caption.trim(),
        'hashtags': hashtags.trim(),
        'uid': user.uid,
        'username': user.displayName ??
            user.email ??
            '@palok_user',
        'likes': 0,
        'comments': 0,
        'saves': 0,
        'shares': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ভিডিও PALOK-এ পোস্ট হয়েছে 🎉',
          ),
        ),
      );

      await _listenToVideos();
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ভিডিও পোস্ট করা যায়নি: $e',
          ),
        ),
      );
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

    if (index == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 900),
          content: Text('Friends'),
        ),
      );
    } else if (index == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 900),
          content: Text('Inbox'),
        ),
      );
    } else if (index == 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 900),
          content: Text('Profile'),
        ),
      );
    }
  }

  void _selectTop(int index) {
    setState(() {
      _topIndex = index;
    });
  }

  String _format(int number) {
    if (number >= 1000000) {
      final value = number / 1000000;
      return '${value.toStringAsFixed(
        value >= 10 ? 0 : 1,
      )}M';
    }

    if (number >= 1000) {
      final value = number / 1000;
      return '${value.toStringAsFixed(
        value >= 10 ? 0 : 1,
      )}K';
    }

    return '$number';
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        final scale = Tween<double>(
          begin: .96,
          end: 1.04,
        ).animate(
          CurvedAnimation(
            parent: _logoController,
            curve: Curves.easeInOut,
          ),
        );

        final opacity = Tween<double>(
          begin: .82,
          end: 1,
        ).animate(
          CurvedAnimation(
            parent: _logoController,
            curve: Curves.easeInOut,
          ),
        );

        return Transform.scale(
          scale: scale.value,
          child: Opacity(
            opacity: opacity.value,
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [
                  _cyan,
                  _pink,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _pink.withOpacity(.28),
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
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            'PALOK',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
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
            10,
            10,
            0,
          ),
          child: Row(
            children: [
              _buildAnimatedLogo(),
              const Spacer(),
              GestureDetector(
                onTap: () => _selectTop(0),
                child: _topTab(
                  'For You',
                  _topIndex == 0,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _selectTop(1),
                child: _topTab(
                  'Following',
                  _topIndex == 1,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openSearch,
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topTab(String title, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Text(
        title,
        style: TextStyle(
          color: active
              ? Colors.white
              : Colors.white54,
          fontSize: 14,
          fontWeight: active
              ? FontWeight.w800
              : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRightButtons() {
    final video = _currentVideo;

    if (video == null) {
      return const SizedBox.shrink();
    }

    final key = _interactionKey(video);
    final liked = _likedIds.contains(key);
    final saved = _savedIds.contains(key);

    final likeCount = video.likes +
        (video.id == null
            ? (_demoLikeDeltas[key] ?? 0)
            : 0);

    final saveCount = video.saves +
        (video.id == null
            ? (_demoSaveDeltas[key] ?? 0)
            : 0);

    final commentCount = video.comments +
        (video.id == null
            ? (_demoCommentCounts[key] ?? 0)
            : 0);

    final shareCount = video.shares +
        (video.id == null
            ? (_demoShareDeltas[key] ?? 0)
            : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          Icons.favorite,
          liked ? _pink : Colors.white,
          _format(likeCount),
          _toggleLike,
        ),
        const SizedBox(height: 13),
        _buildActionButton(
          Icons.comment,
          Colors.white,
          _format(commentCount),
          _openComments,
        ),
        const SizedBox(height: 13),
        _buildActionButton(
          Icons.bookmark,
          saved
              ? const Color(0xFFFFC107)
              : Colors.white,
          _format(saveCount),
          _toggleSave,
        ),
        const SizedBox(height: 13),
        _buildActionButton(
          Icons.share,
          Colors.white,
          _format(shareCount),
          _shareVideo,
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {},
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(.38),
                  border: Border.all(
                    color: Colors.white.withOpacity(.18),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        _cyan,
                        _pink,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _pink,
                    border: Border.all(
                      color: Colors.black,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    String count,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(.38),
              border: Border.all(
                color: Colors.white.withOpacity(.13),
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 23,
            ),
          ),
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
      ),
    );
  }

  Widget _buildVideoInformation() {
    final video = _currentVideo;

    if (video == null) {
      return const SizedBox.shrink();
    }

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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      _cyan,
                      _pink,
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white24,
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                video.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (video.caption.isNotEmpty)
            Text(
              video.caption,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoItem(
    VideoPost video,
    int index,
  ) {
    final key = _interactionKey(video);
    final controller = _controllers[key];

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
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
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          if (!_isPlaying && index == _currentIndex)
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 180,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(.48),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 210,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(.62),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    const labels = [
      'Home',
      'Friends',
      '',
      'Inbox',
      'Profile',
    ];

    const icons = [
      Icons.home_rounded,
      Icons.people_alt_outlined,
      Icons.add,
      Icons.chat_bubble_outline_rounded,
      Icons.person_outline_rounded,
    ];

    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.88),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(.06),
          ),
        ),
      ),
      child: Row(
        children: List.generate(
          5,
          (index) {
            if (index == 2) {
              return Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => _selectBottom(2),
                    child: Container(
                      width: 52,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [
                            _cyan,
                            _pink,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                  ),
                ),
              );
            }

            final active = _bottomIndex == index;

            return Expanded(
              child: GestureDetector(
                onTap: () => _selectBottom(index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      icons[index],
                      color: active
                          ? Colors.white
                          : Colors.white54,
                      size: 23,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : Colors.white54,
                        fontSize: 10,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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
            color: _pink,
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No videos yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: _videos.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return _buildVideoItem(
                _videos[index],
                index,
              );
            },
          ),

          _buildTopBar(),

          Positioned(
            right: 10,
            bottom: 116,
            child: _buildRightButtons(),
          ),

          _buildVideoInformation(),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _buildBottomNavigation(),
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPost {
  final String? id;
  final String videoUrl;
  final String username;
  final String caption;
  final String hashtags;
  final int likes;
  final int comments;
  final int saves;
  final int shares;

  const VideoPost({
    required this.id,
    required this.videoUrl,
    required this.username,
    required this.caption,
    required this.hashtags,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
  });
}

class _CommentsSheet extends StatefulWidget {
  final VideoPost video;
  final TextEditingController inputController;
  final Future<void> Function(String text) onSend;

  const _CommentsSheet({
    required this.video,
    required this.inputController,
    required this.onSend,
  });

  @override
  State<_CommentsSheet> createState() =>
      _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  bool _sending = false;

  final List<Map<String, String>> _comments = const [
    {
      'username': '@rahim',
      'text': 'Nice video 🔥',
    },
    {
      'username': '@karim',
      'text': 'PALOK looks amazing!',
    },
    {
      'username': '@user123',
      'text': 'Love this ❤️',
    },
  ];

  Future<void> _send() async {
    final text = widget.inputController.text.trim();

    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    await widget.onSend(text);

    if (!mounted) return;

    widget.inputController.clear();

    setState(() {
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight =
        MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(
        bottom: keyboardHeight,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * .62,
        decoration: const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(22),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                8,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.video.comments} Comments',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              color: Colors.white10,
              height: 1,
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _comments.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  final comment = _comments[index];

                  return Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
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
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              comment['username']!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              comment['text']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 44,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius:
                            BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller:
                            widget.inputController,
                        textInputAction:
                            TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration:
                            const InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(
                            color: Colors.white38,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            _cyan,
                            _pink,
                          ],
                        ),
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
                              size: 19,
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

class _PostComposerSheet extends StatefulWidget {
  final File videoFile;
  final Future<void> Function(
    String caption,
    String hashtags,
  ) onPost;

  const _PostComposerSheet({
    required this.videoFile,
    required this.onPost,
  });

  @override
  State<_PostComposerSheet> createState() =>
      _PostComposerSheetState();
}

class _PostComposerSheetState
    extends State<_PostComposerSheet> {
  final TextEditingController _captionController =
      TextEditingController();

  final TextEditingController _hashtagController =
      TextEditingController();

  VideoPlayerController? _previewController;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  Future<void> _initializePreview() async {
    final controller =
        VideoPlayerController.file(widget.videoFile);

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _previewController = controller;
      });
    } catch (_) {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      await widget.onPost(
        _captionController.text,
        _hashtagController.text,
      );
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
    final keyboard =
        MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(
        bottom: keyboard,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * .88,
        decoration: const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  12,
                  8,
                  8,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'New PALOK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loading
                          ? null
                          : () =>
                              Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
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
                    16,
                    6,
                    16,
                    18,
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
                          height: 390,
                          color: Colors.black,
                          child: _previewController !=
                                  null &&
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
                                    child: VideoPlayer(
                                      _previewController!,
                                    ),
                                  ),
                                )
                              : const Center(
                                  child:
                                      CircularProgressIndicator(
                                    color: _pink,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Caption',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        child: TextField(
                          controller:
                              _captionController,
                          maxLines: 4,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration:
                              const InputDecoration(
                            hintText:
                                'Write a caption...',
                            hintStyle: TextStyle(
                              color: Colors.white38,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.all(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Hashtags',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        child: TextField(
                          controller:
                              _hashtagController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration:
                              const InputDecoration(
                            hintText:
                                '#PALOK #fyp',
                            hintStyle: TextStyle(
                              color: Colors.white38,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  10,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _post,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pink,
                      disabledBackgroundColor:
                          _pink.withOpacity(.35),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
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
      ),
    );
  }
}
