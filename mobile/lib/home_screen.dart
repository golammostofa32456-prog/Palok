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
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
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

  final Map<String, int> _likeDelta = {};
  final Map<String, int> _saveDelta = {};
  final Map<String, int> _commentDelta = {};
  final Map<String, int> _shareDelta = {};

  int _currentIndex = 0;
  int _bottomIndex = 0;
  int _topIndex = 0;

  bool _loading = true;
  bool _isPlaying = true;

  late AnimationController _logoController;

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

  // =========================================================
  // DATA
  // =========================================================

  Future<void> _loadData() async {
    await _loadUserData();
    await _loadFollowing();
    await _loadVideos();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

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

      _likedIds
        ..clear()
        ..addAll(liked.docs.map((e) => e.id));

      _savedIds
        ..clear()
        ..addAll(saved.docs.map((e) => e.id));
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
        ..addAll(snapshot.docs.map((e) => e.id));
    } catch (_) {}
  }

  Future<void> _loadVideos() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final remote = snapshot.docs.map((doc) {
        final data = doc.data();

        return VideoPost(
          id: doc.id,
          uid: data['uid'] as String?,
          videoUrl: data['videoUrl'] as String? ?? '',
          username:
              data['username'] as String? ?? '@palok_user',
          caption: data['caption'] as String? ?? '',
          hashtags: data['hashtags'] as String? ?? '',
          likes: _toInt(data['likes']),
          comments: _toInt(data['comments']),
          saves: _toInt(data['saves']),
          shares: _toInt(data['shares']),
        );
      }).where((e) => e.videoUrl.isNotEmpty).toList();

      _setVideos(remote);
    } catch (_) {
      _setVideos([]);
    }
  }

  void _setVideos(List<VideoPost> remote) {
    final demos = _demoVideos.asMap().entries.map((entry) {
      final i = entry.key;

      return VideoPost(
        id: null,
        uid: 'palok_demo',
        videoUrl: entry.value,
        username: '@palok',
        caption: [
          'Welcome to PALOK 🎬',
          'Create. Share. Discover. ✨',
          'Your short-video world starts here 🚀',
        ][i],
        hashtags: '#PALOK #ShortVideo',
        likes: [11700, 8500, 6200][i],
        comments: [234, 128, 94][i],
        saves: [811, 452, 301][i],
        shares: [431, 201, 146][i],
      );
    }).toList();

    if (!mounted) return;

    setState(() {
      _videos
        ..clear()
        ..addAll(remote)
        ..addAll(demos);

      _loading = false;
    });

    if (_videos.isNotEmpty) {
      _prepareCurrentVideo();
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  String _key(VideoPost video) {
    return video.id ?? video.videoUrl;
  }

  // =========================================================
  // VIDEO
  // =========================================================

  Future<void> _prepareCurrentVideo() async {
    if (_videos.isEmpty) return;

    await _initializeVideo(_videos[_currentIndex]);
  }

  Future<void> _initializeVideo(VideoPost video) async {
    final key = _key(video);

    if (_controllers.containsKey(key)) {
      final controller = _controllers[key]!;

      if (controller.value.isInitialized) {
        await controller.play();

        if (mounted) {
          setState(() => _isPlaying = true);
        }
      }

      return;
    }

    if (_initializing.containsKey(key)) {
      await _initializing[key];
      return;
    }

    late Future<void> future;

    future = () async {
      late VideoPlayerController controller;

      if (video.videoUrl.startsWith('http')) {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(video.videoUrl),
        );
      } else {
        controller =
            VideoPlayerController.asset(video.videoUrl);
      }

      try {
        await controller.initialize();
        await controller.setLooping(true);

        _controllers[key] = controller;

        if (mounted &&
            _currentVideo != null &&
            _key(_currentVideo!) == key) {
          await controller.play();
          setState(() => _isPlaying = true);
        }
      } catch (_) {
        await controller.dispose();
      }

      _initializing.remove(key);
    }();

    _initializing[key] = future;

    await future;
  }

  Future<void> _onPageChanged(int index) async {
    if (index < 0 || index >= _videos.length) return;

    final old = _currentVideo;

    if (old != null) {
      await _controllers[_key(old)]?.pause();
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

    for (int i = _currentIndex - 1;
        i <= _currentIndex + 1;
        i++) {
      if (i >= 0 && i < _videos.length) {
        keep.add(_key(_videos[i]));
      }
    }

    for (final key in _controllers.keys.toList()) {
      if (!keep.contains(key)) {
        _controllers[key]?.dispose();
        _controllers.remove(key);
      }
    }
  }

  Future<void> _togglePlay() async {
    final video = _currentVideo;

    if (video == null) return;

    final controller = _controllers[_key(video)];

    if (controller == null ||
        !controller.value.isInitialized) {
      await _initializeVideo(video);
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();

      if (mounted) {
        setState(() => _isPlaying = false);
      }
    } else {
      await controller.play();

      if (mounted) {
        setState(() => _isPlaying = true);
      }
    }
  }

  // =========================================================
  // LIKE
  // =========================================================

  Future<void> _toggleLike() async {
    final video = _currentVideo;

    if (video == null) return;

    final key = _key(video);
    final liked = _likedIds.contains(key);

    setState(() {
      if (liked) {
        _likedIds.remove(key);
      } else {
        _likedIds.add(key);
      }

      if (video.id == null) {
        _likeDelta[key] =
            (_likeDelta[key] ?? 0) + (liked ? -1 : 1);
      }
    });

    final user = _auth.currentUser;

    if (user == null || video.id == null) return;

    try {
      final userRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .doc(key);

      final likeRef = _firestore
          .collection('videos')
          .doc(video.id)
          .collection('likes')
          .doc(user.uid);

      if (liked) {
        await userRef.delete();
        await likeRef.delete();
      } else {
        await userRef.set({
          'videoId': video.id,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await likeRef.set({
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestore
          .collection('videos')
          .doc(video.id)
          .update({
        'likes': FieldValue.increment(liked ? -1 : 1),
      });
    } catch (_) {}
  }

  // =========================================================
  // SAVE
  // =========================================================

  Future<void> _toggleSave() async {
    final video = _currentVideo;

    if (video == null) return;

    final key = _key(video);
    final saved = _savedIds.contains(key);

    setState(() {
      if (saved) {
        _savedIds.remove(key);
      } else {
        _savedIds.add(key);
      }

      if (video.id == null) {
        _saveDelta[key] =
            (_saveDelta[key] ?? 0) + (saved ? -1 : 1);
      }
    });

    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final ref = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedVideos')
          .doc(key);

      if (saved) {
        await ref.delete();
      } else {
        await ref.set({
          'videoId': video.id,
          'videoUrl': video.videoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (video.id != null) {
        await _firestore
            .collection('videos')
            .doc(video.id)
            .update({
          'saves': FieldValue.increment(saved ? -1 : 1),
        });
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 700),
          content: Text(
            saved
                ? 'ভিডিওটি Unsave করা হয়েছে'
                : 'ভিডিওটি Saved হয়েছে',
          ),
        ),
      );
    }
  }

  // =========================================================
  // SHARE
  // =========================================================

  Future<void> _shareVideo() async {
    final video = _currentVideo;

    if (video == null) return;

    try {
      await Share.share(
        'Watch this video on PALOK 🎬\n\n'
        '${video.caption}\n\n'
        'PALOK',
      );

      final key = _key(video);

      if (video.id == null) {
        setState(() {
          _shareDelta[key] =
              (_shareDelta[key] ?? 0) + 1;
        });
      }

      if (video.id != null) {
        await _firestore
            .collection('videos')
            .doc(video.id)
            .update({
          'shares': FieldValue.increment(1),
        });
      }
    } catch (_) {}
  }

  // =========================================================
  // COMMENTS
  // =========================================================

  Future<void> _openComments() async {
    final video = _currentVideo;

    if (video == null) return;

    final controller = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        video: video,
        inputController: controller,
        onSend: (text) => _addComment(video, text),
      ),
    );

    controller.dispose();
  }

  Future<void> _addComment(
    VideoPost video,
    String text,
  ) async {
    final value = text.trim();

    if (value.isEmpty) return;

    final key = _key(video);

    setState(() {
      _commentDelta[key] =
          (_commentDelta[key] ?? 0) + 1;
    });

    final user = _auth.currentUser;

    if (user == null || video.id == null) return;

    try {
      await _firestore
          .collection('videos')
          .doc(video.id)
          .collection('comments')
          .add({
        'text': value,
        'uid': user.uid,
        'username':
            user.displayName ?? user.email ?? '@user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('videos')
          .doc(video.id)
          .update({
        'comments': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  // =========================================================
  // CREATE / UPLOAD
  // =========================================================

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              _createOption(
                Icons.videocam_rounded,
                'Record Video',
                'Record a new PALOK video',
                () async {
                  Navigator.pop(context);
                  await _pickVideo(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              _createOption(
                Icons.video_library_rounded,
                'Upload Video',
                'Choose video from phone',
                () async {
                  Navigator.pop(context);
                  await _pickVideo(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
              _createOption(
                Icons.music_note_rounded,
                'Add Sound',
                'Sound tools coming soon',
                () {
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _createOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.055),
          borderRadius: BorderRadius.circular(16),
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
      final file = await _picker.pickVideo(
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
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostComposerSheet(
        videoFile: file,
        onPost: _uploadVideo,
      ),
    );
  }

  Future<void> _uploadVideo(
    File file,
    String caption,
    String hashtags,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          color: _pink,
        ),
      ),
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
      final body =
          await response.stream.bytesToString();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception('Cloudinary upload failed');
      }

      final data =
          jsonDecode(body) as Map<String, dynamic>;

      final videoUrl = data['secure_url'] as String?;

      if (videoUrl == null || videoUrl.isEmpty) {
        throw Exception('Video URL পাওয়া যায়নি');
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
        'username':
            user.displayName ?? user.email ?? '@palok_user',
        'likes': 0,
        'comments': 0,
        'saves': 0,
        'shares': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('ভিডিও PALOK-এ পোস্ট হয়েছে 🎉'),
        ),
      );

      await _loadVideos();
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ভিডিও পোস্ট করা যায়নি: $e'),
        ),
      );
    }
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

  void _selectBottom(int index) {
    if (index == 2) {
      _openCreateSheet();
      return;
    }

    setState(() {
      _bottomIndex = index;
    });
  }

  // =========================================================
  // HOME
  // =========================================================

  Widget _buildHome() {
    List<VideoPost> feed = _videos;

    if (_topIndex == 1) {
      final user = _auth.currentUser;

      feed = _videos.where((video) {
        if (video.uid == null) return false;

        return video.uid == user?.uid ||
            _followingIds.contains(video.uid);
      }).toList();

      if (feed.isEmpty) {
        return _emptyPage(
          Icons.people_outline_rounded,
          'No Following Videos',
          'Follow creators to see their videos here.',
        );
      }
    }

    return Stack(
      children: [
        PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: feed.length,
          onPageChanged: (index) {
            if (_topIndex == 0) {
              _onPageChanged(index);
            }
          },
          itemBuilder: (_, index) {
            final video = feed[index];

            return GestureDetector(
              onDoubleTap: () {
                if (!_likedIds.contains(_key(video))) {
                  _toggleLike();
                }
              },
              onTap: _togglePlay,
              child: _buildVideo(video, index),
            );
          },
        ),
        _buildTopBar(),
        Positioned(
          right: 10,
          bottom: 116,
          child: _buildActions(),
        ),
        _buildVideoInfo(),
      ],
    );
  }

  Widget _buildVideo(
    VideoPost video,
    int index,
  ) {
    final controller = _controllers[_key(video)];

    return Stack(
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
        if (!_isPlaying &&
            index == _currentIndex)
          const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 60,
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 180,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 220,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(.65),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // TOP BAR
  // =========================================================

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(14, 10, 10, 0),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _logoController,
                builder: (_, child) {
                  return Transform.scale(
                    scale: .96 +
                        (_logoController.value * .08),
                    child: child,
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 37,
                      height: 37,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(12),
                        gradient:
                            const LinearGradient(
                          colors: [_cyan, _pink],
                        ),
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
              ),
              const Spacer(),
              _topTab('For You', _topIndex == 0),
              const SizedBox(width: 16),
              _topTab('Following', _topIndex == 1),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _openSearch,
                icon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topTab(String text, bool active) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _topIndex = text == 'For You' ? 0 : 1;
        });
      },
      child: Text(
        text,
        style: TextStyle(
          color:
              active ? Colors.white : Colors.white54,
          fontSize: 14,
          fontWeight:
              active ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }

  // =========================================================
  // ACTION BUTTONS
  // =========================================================

  Widget _buildActions() {
    final video = _currentVideo;

    if (video == null) {
      return const SizedBox.shrink();
    }

    final key = _key(video);

    final likes = video.likes +
        (video.id == null
            ? (_likeDelta[key] ?? 0)
            : 0);

    final saves = video.saves +
        (video.id == null
            ? (_saveDelta[key] ?? 0)
            : 0);

    final comments = video.comments +
        (video.id == null
            ? (_commentDelta[key] ?? 0)
            : 0);

    final shares = video.shares +
        (video.id == null
            ? (_shareDelta[key] ?? 0)
            : 0);

    return Column(
      children: [
        _action(
          Icons.favorite,
          _likedIds.contains(key)
              ? _pink
              : Colors.white,
          _format(likes),
          _toggleLike,
        ),
        const SizedBox(height: 13),
        _action(
          Icons.comment,
          Colors.white,
          _format(comments),
          _openComments,
        ),
        const SizedBox(height: 13),
        _action(
          Icons.bookmark,
          _savedIds.contains(key)
              ? const Color(0xFFFFC107)
              : Colors.white,
          _format(saves),
          _toggleSave,
        ),
        const SizedBox(height: 13),
        _action(
          Icons.share,
          Colors.white,
          _format(shares),
          _shareVideo,
        ),
        const SizedBox(height: 24),
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_cyan, _pink],
            ),
          ),
          child: const Icon(
            Icons.person,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _action(
    IconData icon,
    Color color,
    String count,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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

  String _format(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    }

    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }

    return '$n';
  }

  // =========================================================
  // VIDEO INFO
  // =========================================================

  Widget _buildVideoInfo() {
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_cyan, _pink],
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
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
          const SizedBox(height: 5),
          Text(
            video.hashtags,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Future<void> _openSearch() async {
    final controller = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * .85,
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
                    color: Colors.white24,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search on PALOK',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white54,
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Find creators, videos and hashtags',
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
  }

  // =========================================================
  // FRIENDS
  // =========================================================

  Widget _buildFriends() {
    return SafeArea(
      child: Column(
        children: [
          _pageHeader('Friends'),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.people_alt_rounded,
                    color: Colors.white,
                    size: 58,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Friends on PALOK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Find and connect with people you know.',
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: _openSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pink,
                    ),
                    child: const Text(
                      'Find Friends',
                      style:
                          TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // INBOX
  // =========================================================

  Widget _buildInbox() {
    return SafeArea(
      child: Column(
        children: [
          _pageHeader('Inbox'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _inboxItem(
                  Icons.favorite,
                  'Activity',
                  'Likes, comments and follows',
                ),
                _inboxItem(
                  Icons.person_add,
                  'New Followers',
                  'People who followed you',
                ),
                _inboxItem(
                  Icons.notifications,
                  'Notifications',
                  'Your PALOK notifications',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inboxItem(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _pink.withOpacity(.15),
            ),
            child: Icon(
              icon,
              color: _pink,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PROFILE
  // =========================================================

  Widget _buildProfile() {
    final user = _auth.currentUser;

    final username =
        user?.displayName ??
        user?.email ??
        '@palok_user';

    final myVideos = _videos.where((video) {
      return video.uid == user?.uid;
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          _pageHeader('Profile'),
          const SizedBox(height: 10),
          Container(
            width: 86,
            height: 86,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_cyan, _pink],
              ),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 46,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            username,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceEvenly,
            children: [
              _stat('Following',
                  '${_followingIds.length}'),
              _stat('Videos', '${myVideos.length}'),
              _stat('Likes', '0'),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          Expanded(
            child: myVideos.isEmpty
                ? const Center(
                    child: Text(
                      'Your videos will appear here',
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(2),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: myVideos.length,
                    itemBuilder: (_, index) {
                      return Container(
                        color: Colors.white10,
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
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

  Widget _pageHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        8,
      ),
      child: Row(
        children: [
          const SizedBox(width: 30),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 30),
        ],
      ),
    );
  }

  Widget _emptyPage(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white54,
              size: 55,
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BOTTOM BAR
  // =========================================================

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
        color: Colors.black.withOpacity(.90),
        border: const Border(
          top: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        children: List.generate(5, (index) {
          if (index == 2) {
            return Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _openCreateSheet,
                  child: Container(
                    width: 52,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [_cyan, _pink],
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
        }),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _bottomIndex,
              children: [
                _buildHome(),
                _buildFriends(),
                const SizedBox(),
                _buildInbox(),
                _buildProfile(),
              ],
            ),
          ),

          // Bottom bar সব screen-এ fixed থাকবে
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

// =============================================================
// VIDEO POST
// =============================================================

class VideoPost {
  final String? id;
  final String? uid;
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
    required this.uid,
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

// =============================================================
// COMMENTS SHEET
// =============================================================

class _CommentsSheet extends StatefulWidget {
  final VideoPost video;
  final TextEditingController inputController;
  final Future<void> Function(String) onSend;

  const _CommentsSheet({
    required this.video,
    required this.inputController,
    required this.onSend,
  });

  @override
  State<_CommentsSheet> createState() =>
      _CommentsSheetState();
}

class _CommentsSheetState
    extends State<_CommentsSheet> {
  bool sending = false;

  Future<void> _send() async {
    final text =
        widget.inputController.text.trim();

    if (text.isEmpty || sending) return;

    setState(() => sending = true);

    await widget.onSend(text);

    if (!mounted) return;

    widget.inputController.clear();

    setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard =
        MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height:
            MediaQuery.of(context).size.height * .62,
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
                borderRadius:
                    BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.video.comments} Comments',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
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
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.video.id == null
                    ? null
                    : FirebaseFirestore.instance
                        .collection('videos')
                        .doc(widget.video.id)
                        .collection('comments')
                        .orderBy(
                          'createdAt',
                          descending: true,
                        )
                        .snapshots(),
                builder: (_, snapshot) {
                  if (widget.video.id == null) {
                    return const Center(
                      child: Text(
                        'Comments',
                        style: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _pink,
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

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

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (_, index) {
                      final data =
                          docs[index].data()
                              as Map<String, dynamic>;

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
                              radius: 18,
                              backgroundColor: _pink,
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    data['username']
                                            as String? ??
                                        '@user',
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white70,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(
                                      height: 4),
                                  Text(
                                    data['text']
                                            as String? ??
                                        '',
                                    style:
                                        const TextStyle(
                                      color: Colors.white,
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
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          widget.inputController,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Add a comment...',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(22),
                          borderSide: BorderSide.none,
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
                      decoration:
                          const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_cyan, _pink],
                        ),
                      ),
                      child: sending
                          ? const Padding(
                              padding:
                                  EdgeInsets.all(12),
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
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

// =============================================================
// POST COMPOSER
// =============================================================

class _PostComposerSheet extends StatefulWidget {
  final File videoFile;
  final Future<void> Function(
    File,
    String,
    String,
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
  final captionController =
      TextEditingController();

  final hashtagController =
      TextEditingController();

  VideoPlayerController? preview;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _initPreview();
  }

  Future<void> _initPreview() async {
    final controller =
        VideoPlayerController.file(widget.videoFile);

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        preview = controller;
      });
    } catch (_) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    captionController.dispose();
    hashtagController.dispose();
    preview?.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      await widget.onPost(
        widget.videoFile,
        captionController.text,
        hashtagController.text,
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard =
        MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height:
            MediaQuery.of(context).size.height * .88,
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
                padding: const EdgeInsets.all(16),
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
                      onPressed: loading
                          ? null
                          : () =>
                              Navigator.pop(context),
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
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(18),
                        child: Container(
                          height: 390,
                          width: double.infinity,
                          color: Colors.black,
                          child: preview != null &&
                                  preview!
                                      .value
                                      .isInitialized
                              ? FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: preview!
                                        .value
                                        .size
                                        .width,
                                    height: preview!
                                        .value
                                        .size
                                        .height,
                                    child: VideoPlayer(
                                      preview!,
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller:
                            captionController,
                        maxLines: 4,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Write a caption...',
                          hintStyle:
                              const TextStyle(
                            color: Colors.white38,
                          ),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Hashtags',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller:
                            hashtagController,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              '#PALOK #fyp',
                          hintStyle:
                              const TextStyle(
                            color: Colors.white38,
                          ),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: loading ? null : _post,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor: _pink,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(15),
                      ),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : const Text(
                            'Post',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  FontWeight.w800,
                              fontSize: 16,
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
