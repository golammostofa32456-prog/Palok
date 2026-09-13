import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // PALOK / CLOUDINARY
  // ============================================================

  static const String _cloudinaryCloudName = 'u0jufmrl';
  static const String _cloudinaryUploadPreset = 'palok_video_upload';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final PageController _pageController = PageController();

  late AnimationController _logoAnimationController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // ============================================================
  // UI STATE
  // ============================================================

  int _bottomIndex = 0;
  int _topIndex = 0;
  int _currentVideoIndex = 0;

  bool _isUploading = false;
  double _uploadProgress = 0;

  // ============================================================
  // VIDEO DATA
  // ============================================================

  final List<String> videoUrls = [
    'assets/videos/butterfly.mp4',
    'assets/videos/bee.mp4',
  ];

  final List<String> _videoIds = [
    'demo_butterfly',
    'demo_bee',
  ];

  final List<String> _videoOwners = [
    '',
    '',
  ];

  final List<String> _videoUsernames = [
    '@palok_user',
    '@palok_user',
  ];

  final List<String> _videoCaptions = [
    'Beautiful moment on PALOK ✨',
    'PALOK Short Video 🎬',
  ];

  final List<List<String>> _videoHashtags = [
    ['#palok', '#foryou', '#viral'],
    ['#Palok', '#ShortVideo', '#Bangladesh'],
  ];

  final List<String> _videoSounds = [
    'Original sound - PALOK',
    'Original sound - PALOK',
  ];

  final List<int> _likeCounts = [
    11700,
    8500,
  ];

  final List<int> _commentCounts = [
    234,
    128,
  ];

  final List<int> _saveCounts = [
    811,
    452,
  ];

  final List<int> _shareCounts = [
    431,
    201,
  ];

  final List<bool> _liked = [
    false,
    false,
  ];

  final List<bool> _saved = [
    false,
    false,
  ];

  final List<String> _followingUsers = [];

  final List<List<String>> _localComments = [
    [
      '@rahim: অসাধারণ ভিডিও! 🔥',
      '@karim: অনেক সুন্দর ❤️',
      '@user123: PALOK অনেক ভালো লাগছে!',
    ],
    [
      '@rahim: Nice video 🔥',
      '@karim: Amazing!',
      '@user123: Great content!',
    ],
  ];

  final List<VideoPlayerController?> _videoControllers = [
    null,
    null,
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _logoOpacity = Tween<double>(
      begin: 0.82,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _initializeDemoVideos();
    _loadRemoteVideos();
  }

  // ============================================================
  // USER
  // ============================================================

  Future<User?> _ensureUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      return currentUser;
    }

    _showMessage('আগে Login করুন।');

    return null;
  }

  // ============================================================
  // DEMO VIDEOS
  // ============================================================

  Future<void> _initializeDemoVideos() async {
    for (int i = 0; i < videoUrls.length; i++) {
      try {
        final controller = VideoPlayerController.asset(
          videoUrls[i],
        );

        await controller.initialize();
        await controller.setLooping(true);

        _videoControllers[i] = controller;

        if (i == 0 && mounted) {
          await controller.play();
          setState(() {});
        } else if (mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint('Demo video error: $e');
      }
    }
  }

  // ============================================================
  // LOAD CLOUDINARY VIDEOS FROM FIRESTORE
  // ============================================================

  Future<void> _loadRemoteVideos() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .limit(30)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final url = (data['videoUrl'] ?? '').toString();

        if (url.isEmpty) {
          continue;
        }

        if (videoUrls.contains(url)) {
          continue;
        }

        final username =
            (data['username'] ?? '@palok_user').toString();

        final caption =
            (data['caption'] ?? 'New video on PALOK 🎬')
                .toString();

        final hashtagsRaw = data['hashtags'];

        final List<String> hashtags = hashtagsRaw is List
            ? hashtagsRaw
                .map((e) => e.toString())
                .toList()
            : <String>[];

        final controller =
            VideoPlayerController.networkUrl(
          Uri.parse(url),
        );

        try {
          await controller.initialize();
          await controller.setLooping(true);

          final likes =
              (data['likeCount'] ?? 0) as num;

          final comments =
              (data['commentCount'] ?? 0) as num;

          final saves =
              (data['saveCount'] ?? 0) as num;

          final shares =
              (data['shareCount'] ?? 0) as num;

          if (!mounted) {
            await controller.dispose();
            return;
          }

          setState(() {
            _videoIds.add(doc.id);
            videoUrls.add(url);
            _videoOwners.add(
              (data['ownerId'] ?? '').toString(),
            );
            _videoUsernames.add(username);
            _videoCaptions.add(caption);
            _videoHashtags.add(hashtags);
            _videoSounds.add(
              (data['soundName'] ?? 'Original sound')
                  .toString(),
            );

            _likeCounts.add(likes.toInt());
            _commentCounts.add(comments.toInt());
            _saveCounts.add(saves.toInt());
            _shareCounts.add(shares.toInt());

            _liked.add(false);
            _saved.add(false);
            _localComments.add([]);
            _videoControllers.add(controller);
          });
        } catch (e) {
          debugPrint('Remote video initialize error: $e');
          await controller.dispose();
        }
      }
    } catch (e) {
      debugPrint('Firestore video load error: $e');
    }
  }

  // ============================================================
  // VIDEO PAGE CHANGE
  // ============================================================

  Future<void> _onVideoChanged(int index) async {
    if (index < 0 ||
        index >= _videoControllers.length) {
      return;
    }

    _currentVideoIndex = index;

    for (int i = 0; i < _videoControllers.length; i++) {
      final controller = _videoControllers[i];

      if (controller == null) {
        continue;
      }

      if (i == index) {
        await controller.play();
      } else {
        await controller.pause();
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // PLAY / PAUSE
  // ============================================================

  Future<void> _toggleVideo() async {
    if (_currentVideoIndex >=
        _videoControllers.length) {
      return;
    }

    final controller =
        _videoControllers[_currentVideoIndex];

    if (controller == null) {
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

  Future<void> _toggleLike(int index) async {
    if (index >= _liked.length) return;

    final user = await _ensureUser();
    if (user == null) return;

    final newValue = !_liked[index];

    setState(() {
      _liked[index] = newValue;

      if (newValue) {
        _likeCounts[index]++;
      } else if (_likeCounts[index] > 0) {
        _likeCounts[index]--;
      }
    });

    final videoId = _videoIds[index];

    if (!videoId.startsWith('demo_')) {
      try {
        await _firestore
            .collection('videos')
            .doc(videoId)
            .update({
          'likeCount': _likeCounts[index],
        });
      } catch (e) {
        debugPrint('Like update error: $e');
      }
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _toggleSave(int index) async {
    if (index >= _saved.length) return;

    final user = await _ensureUser();
    if (user == null) return;

    final newValue = !_saved[index];

    setState(() {
      _saved[index] = newValue;

      if (newValue) {
        _saveCounts[index]++;
      } else if (_saveCounts[index] > 0) {
        _saveCounts[index]--;
      }
    });

    final videoId = _videoIds[index];

    if (!videoId.startsWith('demo_')) {
      try {
        await _firestore
            .collection('videos')
            .doc(videoId)
            .update({
          'saveCount': _saveCounts[index],
        });
      } catch (e) {
        debugPrint('Save update error: $e');
      }
    }

    _showMessage(
      newValue
          ? 'ভিডিওটি Saved হয়েছে'
          : 'ভিডিওটি Unsave করা হয়েছে',
    );
  }

  // ============================================================
  // FOLLOW
  // ============================================================

  Future<void> _toggleFollow(int index) async {
    final user = await _ensureUser();
    if (user == null) return;

    if (index >= _videoUsernames.length) {
      return;
    }

    final username = _videoUsernames[index];

    setState(() {
      if (_followingUsers.contains(username)) {
        _followingUsers.remove(username);
      } else {
        _followingUsers.add(username);
      }
    });

    final following =
        _followingUsers.contains(username);

    _showMessage(
      following
          ? '$username Follow করা হয়েছে'
          : '$username Unfollow করা হয়েছে',
    );
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _shareVideo(int index) async {
    if (index >= videoUrls.length) return;

    final videoId = _videoIds[index];

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'দেখুন PALOK-এ এই ভিডিওটি 🎬\n'
              'https://palok.app/video/$videoId',
        ),
      );

      setState(() {
        _shareCounts[index]++;
      });

      if (!videoId.startsWith('demo_')) {
        await _firestore
            .collection('videos')
            .doc(videoId)
            .update({
          'shareCount': _shareCounts[index],
        });
      }
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  Future<void> _openComments(int index) async {
    if (index >= _commentCounts.length) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Comment করতে আগে Login করুন।');
      return;
    }

    final controller = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.of(context)
                          .viewInsets
                          .bottom,
                ),
                child: Container(
                  height:
                      MediaQuery.of(context)
                              .size
                              .height *
                          0.62,
                  decoration: const BoxDecoration(
                    color: Color(0xFF101214),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
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
                              BorderRadius.circular(20),
                        ),
                      ),

                      Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${_commentCounts[index]} Comments',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () =>
                                  Navigator.pop(context),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(
                        color: Colors.white12,
                        height: 1,
                      ),

                      Expanded(
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.all(16),
                          itemCount:
                              _localComments[index]
                                  .length,
                          itemBuilder: (context, i) {
                            final comment =
                                _localComments[index][i];

                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom: 18,
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        Colors.white12,
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 21,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      comment,
                                      style:
                                          const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets.fromLTRB(
                          14,
                          8,
                          14,
                          12,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFF17191C),
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
                                controller: controller,
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                                decoration:
                                    InputDecoration(
                                  hintText:
                                      'Add a comment...',
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
                                        BorderRadius
                                            .circular(24),
                                    borderSide:
                                        BorderSide.none,
                                  ),
                                  contentPadding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                final text =
                                    controller.text.trim();

                                if (text.isEmpty) {
                                  return;
                                }

                                final username =
                                    user.displayName != null &&
                                            user.displayName!
                                                .trim()
                                                .isNotEmpty
                                        ? '@${user.displayName!.trim()}'
                                        : '@palok_user';

                                final newComment =
                                    '$username: $text';

                                setState(() {
                                  _localComments[index]
                                      .add(newComment);
                                  _commentCounts[index]++;
                                });

                                setSheetState(() {});

                                controller.clear();

                                final videoId =
                                    _videoIds[index];

                                if (!videoId
                                    .startsWith('demo_')) {
                                  try {
                                    await _firestore
                                        .collection('videos')
                                        .doc(videoId)
                                        .update({
                                      'commentCount':
                                          _commentCounts[
                                              index],
                                    });
                                  } catch (e) {
                                    debugPrint(
                                      'Comment error: $e',
                                    );
                                  }
                                }
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration:
                                    const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient:
                                      LinearGradient(
                                    colors: [
                                      Color(0xFFFF2D78),
                                      Color(0xFF8A5CFF),
                                    ],
                                  ),
                                ),
                                child: const Icon(
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
          },
        );
      },
    );

    controller.dispose();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<void> _openSearch() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SearchSheet(
          usernames: _videoUsernames,
          captions: _videoCaptions,
          hashtags: _videoHashtags,
        );
      },
    );
  }

  // ============================================================
  // CREATE
  // ============================================================

  Future<void> _openCreate() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101214),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
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
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 22),

                const Text(
                  'Create on PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 20),

                _createOption(
                  icon: Icons.videocam_rounded,
                  title: 'Record Video',
                  onTap: () {
                    Navigator.pop(context);
                    _showMessage(
                      'Record Video feature আসছে।',
                    );
                  },
                ),

                const SizedBox(height: 10),

                _createOption(
                  icon: Icons.video_library_rounded,
                  title: 'Upload Video',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickAndUploadVideo();
                  },
                ),

                const SizedBox(height: 10),

                _createOption(
                  icon: Icons.music_note_rounded,
                  title: 'Add Sound',
                  onTap: () {
                    Navigator.pop(context);
                    _showMessage(
                      'Sound library পরের ধাপে যোগ হবে।',
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 25,
            ),
            const SizedBox(width: 15),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void> _pickAndUploadVideo() async {
    final user = await _ensureUser();

    if (user == null) {
      return;
    }

    try {
      final pickedVideo =
          await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedVideo == null) {
        return;
      }

      final draft = await showModalBottomSheet<
          VideoPostDraft>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return _VideoUploadSheet(
            videoFile: pickedVideo,
          );
        },
      );

      if (draft == null) {
        return;
      }

      await _uploadVideo(
        pickedVideo,
        draft,
      );
    } catch (e) {
      debugPrint('Pick video error: $e');

      _showMessage(
        'ভিডিও নির্বাচন করা যায়নি।',
      );
    }
  }

  // ============================================================
  // CLOUDINARY VIDEO UPLOAD
  // ============================================================

  Future<void> _uploadVideo(
    XFile pickedVideo,
    VideoPostDraft draft,
  ) async {
    final user = await _ensureUser();

    if (user == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final file = File(pickedVideo.path);

      if (!await file.exists()) {
        throw Exception(
          'Selected video file does not exist.',
        );
      }

      // Cloudinary Free plan-এর বর্তমান implementation-এর জন্য
      // 100 MB limit রাখা হয়েছে।
      final fileLength = await file.length();

      const maxBytes =
          100 * 1024 * 1024;

      if (fileLength > maxBytes) {
        throw Exception(
          'ভিডিও 100 MB-এর বেশি হতে পারবে না।',
        );
      }

      final videoId =
          _firestore
              .collection('videos')
              .doc()
              .id;

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '$_cloudinaryCloudName/video/upload',
      );

      final request =
          http.MultipartRequest(
        'POST',
        uri,
      );

      request.fields[
          'upload_preset'] =
          _cloudinaryUploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
        ),
      );

      if (mounted) {
        setState(() {
          _uploadProgress = 0.05;
        });
      }

      final response =
          await request.send();

      if (mounted) {
        setState(() {
          _uploadProgress = 0.90;
        });
      }

      final responseBody =
          await response
              .stream
              .bytesToString();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Cloudinary upload failed '
          '(${response.statusCode}): '
          '$responseBody',
        );
      }

      final data =
          jsonDecode(responseBody)
              as Map<String, dynamic>;

      final downloadUrl =
          (data['secure_url'] ?? '')
              .toString();

      if (downloadUrl.isEmpty) {
        throw Exception(
          'Cloudinary secure_url পাওয়া যায়নি।',
        );
      }

      final username =
          user.displayName != null &&
                  user.displayName!
                      .trim()
                      .isNotEmpty
              ? '@${user.displayName!.trim()}'
              : '@palok_user';

      final videoData = {
        'ownerId': user.uid,
        'username': username,
        'videoUrl': downloadUrl,
        'cloudinaryPublicId':
            (data['public_id'] ?? '')
                .toString(),
        'cloudinaryAssetId':
            (data['asset_id'] ?? '')
                .toString(),
        'caption': draft.caption,
        'hashtags': draft.hashtags,
        'soundName': 'Original sound',
        'likeCount': 0,
        'commentCount': 0,
        'saveCount': 0,
        'shareCount': 0,
        'createdAt':
            FieldValue.serverTimestamp(),
      };

      // Video metadata Firestore-এ যাবে।
      // ভিডিও ফাইল Firebase Storage-এ যাবে না।
      await _firestore
          .collection('videos')
          .doc(videoId)
          .set(videoData);

      if (mounted) {
        setState(() {
          _uploadProgress = 0.96;
        });
      }

      final controller =
          VideoPlayerController.networkUrl(
        Uri.parse(downloadUrl),
      );

      await controller.initialize();
      await controller.setLooping(true);

      final newIndex =
          videoUrls.length;

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoIds.add(videoId);

        videoUrls.add(downloadUrl);

        _videoOwners.add(user.uid);

        _videoUsernames.add(username);

        _videoCaptions.add(
          draft.caption.isEmpty
              ? 'New video on PALOK 🎬'
              : draft.caption,
        );

        _videoHashtags.add(
          draft.hashtags,
        );

        _videoSounds.add(
          'Original sound',
        );

        _likeCounts.add(0);
        _commentCounts.add(0);
        _saveCounts.add(0);
        _shareCounts.add(0);

        _liked.add(false);
        _saved.add(false);

        _localComments.add([]);

        _videoControllers.add(
          controller,
        );

        _followingUsers.add(
          username,
        );

        _isUploading = false;
        _uploadProgress = 1;
      });

      await Future.delayed(
        const Duration(milliseconds: 100),
      );

      if (!mounted) {
        return;
      }

      if (_pageController.hasClients) {
        await _pageController
            .animateToPage(
          newIndex,
          duration:
              const Duration(
            milliseconds: 450,
          ),
          curve: Curves.easeOut,
        );
      }

      _currentVideoIndex =
          newIndex;

      await controller.play();

      if (mounted) {
        setState(() {});

        _showMessage(
          '🎉 ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে!',
        );
      }
    } catch (e) {
      debugPrint(
        'Cloudinary video upload error: $e',
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });

        _showMessage(
          'ভিডিও upload করা যায়নি: '
          '${e.toString().replaceFirst(
            'Exception: ',
            '',
          )}',
        );
      }
    }
  }

  // ============================================================
  // VIDEO INFORMATION
  // ============================================================

  Widget _buildVideoInformation() {
    final index = _currentVideoIndex;

    if (index >= _videoUsernames.length) {
      return const SizedBox();
    }

    final hashtags =
        _videoHashtags[index].join(' ');

    final username =
        _videoUsernames[index];

    final caption =
        _videoCaptions[index];

    final sound =
        _videoSounds[index];

    final following =
        _followingUsers.contains(username);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),

            GestureDetector(
              onTap: () =>
                  _toggleFollow(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: following
                      ? Colors.white24
                      : Colors.white,
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: Text(
                  following
                      ? 'Following'
                      : 'Follow',
                  style: TextStyle(
                    color: following
                        ? Colors.white
                        : Colors.black,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.35,
          ),
        ),

        if (hashtags.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            hashtags,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],

        const SizedBox(height: 9),

        Row(
          children: [
            const Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                sound,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // RIGHT BUTTONS
  // ============================================================

  Widget _buildRightButtons() {
    final index = _currentVideoIndex;

    if (index >= _likeCounts.length) {
      return const SizedBox();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionButton(
          icon: Icons.favorite_rounded,
          count:
              _formatCount(
            _likeCounts[index],
          ),
          active: _liked[index],
          onTap: () =>
              _toggleLike(index),
        ),

        const SizedBox(height: 13),

        _actionButton(
          icon: Icons.chat_bubble_rounded,
          count:
              _formatCount(
            _commentCounts[index],
          ),
          onTap: () =>
              _openComments(index),
        ),

        const SizedBox(height: 13),

        _actionButton(
          icon: Icons.bookmark_rounded,
          count:
              _formatCount(
            _saveCounts[index],
          ),
          active: _saved[index],
          onTap: () =>
              _toggleSave(index),
        ),

        const SizedBox(height: 13),

        _actionButton(
          icon: Icons.share_rounded,
          count:
              _formatCount(
            _shareCounts[index],
          ),
          onTap: () =>
              _shareVideo(index),
        ),

        const SizedBox(height: 24),

        GestureDetector(
          onTap: () =>
              _toggleFollow(index),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      const LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      Color(0xFF8A5CFF),
                      Color(0xFFFF2D78),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),

              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration:
                      const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF2D78),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String count,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  Colors.black.withOpacity(0.38),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white24,
              ),
            ),
            child: Icon(
              icon,
              color: active
                  ? const Color(0xFFFF2D78)
                  : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOP HEADER
  // ============================================================

  Widget _buildTopHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          14,
          10,
          12,
          0,
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation:
                  _logoAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoScale.value,
                  child: Opacity(
                    opacity:
                        _logoOpacity.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(13),
                  gradient:
                      const LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      Color(0xFF8A5CFF),
                      Color(0xFFFF2D78),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(
                        0xFFFF2D78,
                      ).withOpacity(0.28),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'P',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight:
                          FontWeight.w900,
                    ),
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
                _showMessage(
                  'Following feed শীঘ্রই আসছে।',
                );
              },
              child: _topTab(
                'Following',
                _topIndex == 1,
              ),
            ),

            const SizedBox(width: 14),

            GestureDetector(
              onTap: _openSearch,
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topTab(
    String title,
    bool active,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
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
        const SizedBox(height: 5),
        AnimatedContainer(
          duration:
              const Duration(milliseconds: 200),
          width: active ? 24 : 0,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return Container(
      height: 78,
      decoration: const BoxDecoration(
        color: Colors.black,
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
              icon: Icons.people_alt_rounded,
              label: 'Friends',
              index: 1,
            ),
          ),

          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _bottomIndex = 2;
                });
                _openCreate();
              },
              child: Center(
                child: Container(
                  width: 48,
                  height: 38,
                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(12),
                    gradient:
                        const LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.white,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(
                          0xFFFF2D78,
                        ).withOpacity(0.45),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: _bottomItem(
              icon: Icons.chat_bubble_rounded,
              label: 'Inbox',
              index: 3,
            ),
          ),

          Expanded(
            child: _bottomItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              index: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final active =
        _bottomIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _bottomIndex = index;
        });

        if (index != 0) {
          _showMessage(
            '$label section পরের ধাপে যোগ হবে।',
          );
        }
      },
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: active
                ? Colors.white
                : Colors.white54,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
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
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ======================================================
          // FULL SCREEN VIDEO FEED
          // ======================================================

          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: videoUrls.length,
            onPageChanged:
                _onVideoChanged,
            itemBuilder:
                (context, index) {
              return _buildVideoPage(
                index,
              );
            },
          ),

          // ======================================================
          // TOP HEADER
          // ======================================================

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopHeader(),
          ),

          // ======================================================
          // RIGHT BUTTONS
          // IMPORTANT: POSITION LOCKED
          // ======================================================

          Positioned(
            right: 10,
            bottom: 116,
            child: _buildRightButtons(),
          ),

          // ======================================================
          // VIDEO INFORMATION
          // IMPORTANT: POSITION LOCKED
          // ======================================================

          Positioned(
            left: 18,
            right: 92,
            bottom: 124,
            child: _buildVideoInformation(),
          ),

          // ======================================================
          // BOTTOM NAVIGATION
          // IMPORTANT: POSITION LOCKED
          // ======================================================

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child:
                  _buildBottomNavigation(),
            ),
          ),

          // ======================================================
          // UPLOAD PROGRESS
          // ======================================================

          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black
                    .withOpacity(0.78),
                child: Center(
                  child: Container(
                    width:
                        MediaQuery.of(context)
                                .size
                                .width *
                            0.78,
                    padding:
                        const EdgeInsets.all(24),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFF15171A,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        24,
                      ),
                    ),
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons
                              .cloud_upload_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        const Text(
                          'Uploading to PALOK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        const SizedBox(
                          height: 18,
                        ),
                        LinearProgressIndicator(
                          value:
                              _uploadProgress,
                          minHeight: 6,
                          borderRadius:
                              BorderRadius
                                  .circular(20),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Text(
                          '${(_uploadProgress * 100).round()}%',
                          style:
                              const TextStyle(
                            color:
                                Colors.white70,
                            fontSize: 13,
                          ),
                        ),
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

  // ============================================================
  // VIDEO PAGE
  // ============================================================

  Widget _buildVideoPage(
    int index,
  ) {
    if (index >=
        _videoControllers.length) {
      return const ColoredBox(
        color: Colors.black,
      );
    }

    final controller =
        _videoControllers[index];

    return GestureDetector(
      onTap: _toggleVideo,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null &&
              controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width:
                    controller
                        .value
                        .size
                        .width,
                height:
                    controller
                        .value
                        .size
                        .height,
                child: VideoPlayer(
                  controller,
                ),
              ),
            )
          else
            const ColoredBox(
              color: Colors.black,
              child: Center(
                child:
                    CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),

          // subtle bottom gradient
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 250,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.topCenter,
                    end:
                        Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black54,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Pause icon
          if (controller != null &&
              controller.value.isInitialized &&
              !controller.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 72,
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }

    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }

    return count.toString();
  }

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
        duration:
            const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _pageController.dispose();

    for (final controller
        in _videoControllers) {
      controller?.dispose();
    }

    super.dispose();
  }
}

// ================================================================
// VIDEO POST DRAFT
// ================================================================

class VideoPostDraft {
  final String caption;
  final List<String> hashtags;

  const VideoPostDraft({
    required this.caption,
    required this.hashtags,
  });
}

// ================================================================
// VIDEO UPLOAD SHEET
// ================================================================

class _VideoUploadSheet
    extends StatefulWidget {
  final XFile videoFile;

  const _VideoUploadSheet({
    required this.videoFile,
  });

  @override
  State<_VideoUploadSheet> createState() =>
      _VideoUploadSheetState();
}

class _VideoUploadSheetState
    extends State<_VideoUploadSheet> {
  late VideoPlayerController
      _previewController;

  final TextEditingController
      _captionController =
      TextEditingController();

  final TextEditingController
      _hashtagsController =
      TextEditingController();

  bool _ready = false;

  @override
  void initState() {
    super.initState();

    _previewController =
        VideoPlayerController.file(
      File(widget.videoFile.path),
    );

    _preparePreview();
  }

  Future<void> _preparePreview() async {
    try {
      await _previewController
          .initialize();

      await _previewController
          .setLooping(true);

      await _previewController.play();

      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
    } catch (e) {
      debugPrint(
        'Preview error: $e',
      );
    }
  }

  void _post() {
    final caption =
        _captionController.text.trim();

    final raw =
        _hashtagsController.text.trim();

    final hashtags = raw.isEmpty
        ? <String>[]
        : raw
            .split(RegExp(r'[\s,]+'))
            .where(
              (e) => e.trim().isNotEmpty,
            )
            .map(
              (e) => e.startsWith('#')
                  ? e
                  : '#$e',
            )
            .toList();

    Navigator.pop(
      context,
      VideoPostDraft(
        caption: caption,
        hashtags: hashtags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(context)
                  .viewInsets
                  .bottom,
        ),
        child: Container(
          height:
              MediaQuery.of(context)
                      .size
                      .height *
                  0.72,
          decoration:
              const BoxDecoration(
            color: Color(0xFF101214),
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 42,
                height: 4,
                decoration:
                    BoxDecoration(
                  color: Colors.white24,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  14,
                  10,
                  10,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Post Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(
                        context,
                      ),
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
                  padding:
                      const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Container(
                        height: 250,
                        width: double.infinity,
                        clipBehavior:
                            Clip.antiAlias,
                        decoration:
                            BoxDecoration(
                          color: Colors.black,
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                        ),
                        child: _ready
                            ? FittedBox(
                                fit: BoxFit.cover,
                                child:
                                    SizedBox(
                                  width:
                                      _previewController
                                          .value
                                          .size
                                          .width,
                                  height:
                                      _previewController
                                          .value
                                          .size
                                          .height,
                                  child:
                                      VideoPlayer(
                                    _previewController,
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

                      const SizedBox(
                        height: 18,
                      ),

                      TextField(
                        controller:
                            _captionController,
                        maxLines: 3,
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
                            color:
                                Colors.white54,
                          ),
                          filled: true,
                          fillColor:
                              Colors.white10,
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              16,
                            ),
                            borderSide:
                                BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

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
                              '#palok #foryou',
                          hintStyle:
                              const TextStyle(
                            color:
                                Colors.white54,
                          ),
                          filled: true,
                          fillColor:
                              Colors.white10,
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              16,
                            ),
                            borderSide:
                                BorderSide.none,
                          ),
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
                  16,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _ready ? _post : null,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFFFF2D78,
                      ),
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                    ),
                    child: const Text(
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
      ),
    );
  }

  @override
  void dispose() {
    _previewController.dispose();
    _captionController.dispose();
    _hashtagsController.dispose();
    super.dispose();
  }
}

// ================================================================
// SEARCH SHEET
// ================================================================

class _SearchSheet extends StatefulWidget {
  final List<String> usernames;
  final List<String> captions;
  final List<List<String>> hashtags;

  const _SearchSheet({
    required this.usernames,
    required this.captions,
    required this.hashtags,
  });

  @override
  State<_SearchSheet> createState() =>
      _SearchSheetState();
}

class _SearchSheetState
    extends State<_SearchSheet> {
  final TextEditingController
      _searchController =
      TextEditingController();

  List<int> _results = [];

  @override
  void initState() {
    super.initState();

    _results = List.generate(
      widget.usernames.length,
      (index) => index,
    );
  }

  void _search(String value) {
    final query =
        value.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _results = List.generate(
          widget.usernames.length,
          (index) => index,
        );
        return;
      }

      _results = [];

      for (int i = 0;
          i < widget.usernames.length;
          i++) {
        final username =
            widget.usernames[i]
                .toLowerCase();

        final caption =
            widget.captions[i]
                .toLowerCase();

        final tags =
            widget.hashtags[i]
                .join(' ')
                .toLowerCase();

        if (username.contains(query) ||
            caption.contains(query) ||
            tags.contains(query)) {
          _results.add(i);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(context)
                  .viewInsets
                  .bottom,
        ),
        child: Container(
          height:
              MediaQuery.of(context)
                      .size
                      .height *
                  0.72,
          decoration:
              const BoxDecoration(
            color: Color(0xFF101214),
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 42,
                height: 4,
                decoration:
                    BoxDecoration(
                  color: Colors.white24,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.all(18),
                child: TextField(
                  controller:
                      _searchController,
                  autofocus: true,
                  onChanged: _search,
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
                      color: Colors.white54,
                    ),
                    prefixIcon:
                        const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
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
                ),
              ),

              Expanded(
                child: _results.isEmpty
                    ? const Center(
                        child: Text(
                          'No results found',
                          style: TextStyle(
                            color:
                                Colors.white54,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount:
                            _results.length,
                        itemBuilder:
                            (context, i) {
                          final index =
                              _results[i];

                          return ListTile(
                            leading:
                                const CircleAvatar(
                              backgroundColor:
                                  Colors.white12,
                              child: Icon(
                                Icons
                                    .play_arrow_rounded,
                                color:
                                    Colors.white,
                              ),
                            ),
                            title: Text(
                              widget
                                  .usernames[index],
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                            subtitle: Text(
                              widget
                                  .captions[index],
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white54,
                              ),
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
