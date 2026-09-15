import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static const String _cloudinaryCloudName = 'u0jufmrl';
  static const String _cloudinaryUploadPreset =
      'palok_video_upload';

  int _bottomIndex = 0;
  int _topIndex = 0;
  int _currentVideoIndex = 0;

  bool _isUploading = false;
  double _uploadProgress = 0;

  bool _following = false;

  final List<String> videoUrls = [
    'assets/videos/video.mp4',
    'assets/videos/video1.mp4',
    'assets/videos/video2.mp4',
  ];

  final List<String> _videoIds = [
    'local_video_1',
    'local_video_2',
    'local_video_3',
  ];

  final List<String> _videoOwners = [
    'palok_demo_1',
    'palok_demo_2',
    'palok_demo_3',
  ];

  final List<String> _videoUsernames = [
    '@palok_user',
    '@palok_creator',
    '@palok_user',
  ];

  final List<String> _videoCaptions = [
    'Welcome to PALOK 🎬',
    'Beautiful moment on PALOK ✨',
    'Create. Share. Enjoy. ❤️',
  ];

  final List<List<String>> _videoHashtags = [
    ['PALOK', 'ForYou'],
    ['PALOK', 'Video'],
    ['PALOK', 'Trending'],
  ];

  final List<String> _videoSounds = [
    'Original sound',
    'Original sound',
    'Original sound',
  ];

  final List<int> _likeCounts = [
    11700,
    8500,
    6200,
  ];

  final List<int> _commentCounts = [
    234,
    128,
    94,
  ];

  final List<int> _saveCounts = [
    811,
    452,
    315,
  ];

  final List<int> _shareCounts = [
    431,
    201,
    177,
  ];

  final List<bool> _liked = [
    false,
    false,
    false,
  ];

  final List<bool> _saved = [
    false,
    false,
    false,
  ];

  final List<List<String>> _localComments = [
    [],
    [],
    [],
  ];

  final List<VideoPlayerController?> _videoControllers = [
    null,
    null,
    null,
  ];

  final Set<String> _followingUsers = {};

  late AnimationController _logoAnimationController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

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

    _initializeLocalVideos();
  }

  Future<void> _initializeLocalVideos() async {
    for (int i = 0; i < videoUrls.length; i++) {
      try {
        final controller =
            VideoPlayerController.asset(videoUrls[i]);

        await controller.initialize();
        await controller.setLooping(true);

        _videoControllers[i] = controller;

        if (i == 0 && mounted) {
          await controller.play();
        }

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint(
          'Video initialization error: $e',
        );
      }
    }
  }

  Future<User?> _ensureUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null && mounted) {
      _showMessage('আগে Login করুন!');
    }

    return user;
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

  Future<void> _togglePlayPause(int index) async {
    if (index < 0 ||
        index >= _videoControllers.length) {
      return;
    }

    final controller = _videoControllers[index];

    if (controller == null ||
        !controller.value.isInitialized) {
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

  Future<void> _onPageChanged(int index) async {
    _currentVideoIndex = index;

    for (int i = 0;
        i < _videoControllers.length;
        i++) {
      final controller = _videoControllers[i];

      if (controller == null) continue;

      if (i == index) {
        if (controller.value.isInitialized) {
          await controller.play();
        }
      } else {
        await controller.pause();
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleLike(int index) async {
    final user = await _ensureUser();
    if (user == null) return;

    if (_liked[index]) {
      _likeCounts[index]--;
      _liked[index] = false;
    } else {
      _likeCounts[index]++;
      _liked[index] = true;
    }

    if (mounted) {
      setState(() {});
    }

    final videoId = _videoIds[index];

    if (!videoId.startsWith('local_')) {
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

  Future<void> _toggleSave(int index) async {
    final user = await _ensureUser();
    if (user == null) return;

    if (_saved[index]) {
      _saveCounts[index]--;
      _saved[index] = false;

      _showMessage(
        'ভিডিওটি Unsave করা হয়েছে',
      );
    } else {
      _saveCounts[index]++;
      _saved[index] = true;

      _showMessage(
        'ভিডিওটি Saved হয়েছে',
      );
    }

    if (mounted) {
      setState(() {});
    }

    final videoId = _videoIds[index];

    if (!videoId.startsWith('local_')) {
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
  }

  Future<void> _toggleFollow() async {
    final user = await _ensureUser();
    if (user == null) return;

    setState(() {
      _following = !_following;
    });

    if (_following) {
      _showMessage('Following @palok_user');
    } else {
      _showMessage('Unfollowed @palok_user');
    }
  }

  Future<void> _shareVideo(int index) async {
    final user = await _ensureUser();
    if (user == null) return;

    final videoUrl = videoUrls[index];

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Watch this video on PALOK 🎬\n\n$videoUrl',
        ),
      );

      _shareCounts[index]++;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  void _openComments(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CommentsSheet(
          commentCount: _commentCounts[index],
          comments: _localComments[index],
          onSend: (comment) async {
            final user = await _ensureUser();

            if (user == null) return;

            if (comment.trim().isEmpty) return;

            setState(() {
              _localComments[index].add(
                comment.trim(),
              );

              _commentCounts[index]++;
            });

            Navigator.of(context).pop();

            _showMessage('Comment added');

            final videoId = _videoIds[index];

            if (!videoId.startsWith('local_')) {
              try {
                await _firestore
                    .collection('videos')
                    .doc(videoId)
                    .update({
                  'commentCount':
                      _commentCounts[index],
                });
              } catch (e) {
                debugPrint(
                  'Comment update error: $e',
                );
              }
            }
          },
        );
      },
    );
  }

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SearchSheet(
          videos: videoUrls,
          usernames: _videoUsernames,
          captions: _videoCaptions,
          hashtags: _videoHashtags,
          onSelect: (index) {
            Navigator.of(context).pop();

            if (_pageController.hasClients) {
              _pageController.animateToPage(
                index,
                duration: const Duration(
                  milliseconds: 450,
                ),
                curve: Curves.easeOut,
              );
            }
          },
        );
      },
    );
  }

  void _selectBottom(int index) {
    setState(() {
      _bottomIndex = index;
    });

    if (index == 0) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          0,
          duration: const Duration(
            milliseconds: 350,
          ),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    if (index == 2) {
      _openCreate();
      return;
    }

    if (index == 1) {
      _showMessage(
        'Friends section will be added next.',
      );
      return;
    }

    if (index == 3) {
      _showMessage(
        'Inbox section will be added next.',
      );
      return;
    }

    if (index == 4) {
      _showMessage(
        'Profile section will be added next.',
      );
    }
  }

  void _openCreate() {
    showModalBottomSheet(
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
              16,
              20,
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
                    borderRadius:
                        BorderRadius.circular(10),
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
                const SizedBox(height: 18),
                _createOption(
                  icon: Icons.videocam_outlined,
                  title: 'Record Video',
                  onTap: () {
                    Navigator.pop(context);
                    _showMessage(
                      'Camera recording will be added next.',
                    );
                  },
                ),
                _createOption(
                  icon: Icons.video_library_outlined,
                  title: 'Upload Video',
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadVideo();
                  },
                ),
                _createOption(
                  icon: Icons.music_note_outlined,
                  title: 'Add Sound',
                  onTap: () {
                    Navigator.pop(context);
                    _showMessage(
                      'Sound library will be added next.',
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
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 25,
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

  Future<void> _pickAndUploadVideo() async {
    final user = await _ensureUser();
    if (user == null) return;

    final picker = ImagePicker();

    try {
      final XFile? picked =
          await picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (picked == null) return;

      final draft = await showModalBottomSheet<
          VideoPostDraft>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return _VideoUploadSheet(
            videoFile: File(picked.path),
          );
        },
      );

      if (draft == null) return;

      await _uploadVideo(
        picked,
        draft,
      );
    } catch (e) {
      debugPrint('Video picker error: $e');

      _showMessage(
        'ভিডিও নির্বাচন করা যায়নি।',
      );
    }
  }

  Future<void> _uploadVideo(
    XFile pickedVideo,
    VideoPostDraft draft,
  ) async {
    final user = await _ensureUser();
    if (user == null) return;

    if (!mounted) return;

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

      final fileLength = await file.length();

      const maxBytes =
          100 * 1024 * 1024;

      if (fileLength > maxBytes) {
        throw Exception(
          'Video must be 100 MB or smaller.',
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
      )
            ..fields['upload_preset'] =
                _cloudinaryUploadPreset
            ..files.add(
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
          await response.stream
              .bytesToString();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Cloudinary upload failed '
          '(${response.statusCode})',
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
          'Cloudinary did not return secure_url.',
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
        'soundName':
            'Original sound',
        'likeCount': 0,
        'commentCount': 0,
        'saveCount': 0,
        'shareCount': 0,
        'createdAt':
            FieldValue.serverTimestamp(),
      };

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
          user.uid,
        );

        _isUploading = false;
        _uploadProgress = 1;
      });

      await Future.delayed(
        const Duration(
          milliseconds: 100,
        ),
      );

      if (!mounted) return;

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
        'Video upload error: $e',
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

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 14,
          right: 12,
          top: 10,
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
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(13),
                  gradient:
                      const LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF2D75),
                      Color(0xFF8A35FF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFFF2D75,
                      ).withOpacity(0.25),
                      blurRadius: 15,
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
                  'Following feed',
                );
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
                Icons.search,
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
    String title,
    bool selected,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: selected
                ? Colors.white
                : Colors.white60,
            fontSize: 15,
            fontWeight: selected
                ? FontWeight.bold
                : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        AnimatedContainer(
          duration:
              const Duration(milliseconds: 200),
          width: selected ? 24 : 0,
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

  Widget _buildRightButtons() {
    final index =
        _currentVideoIndex.clamp(
      0,
      _liked.length - 1,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionButton(
          icon: Icons.person_add_alt_1,
          label: 'Follow',
          onTap: _toggleFollow,
        ),
        const SizedBox(height: 14),
        _actionButton(
          icon: _liked[index]
              ? Icons.favorite
              : Icons.favorite_border,
          label: _formatCount(
            _likeCounts[index],
          ),
          iconColor: _liked[index]
              ? const Color(0xFFFF2D75)
              : Colors.white,
          onTap: () {
            _toggleLike(index);
          },
        ),
        const SizedBox(height: 14),
        _actionButton(
          icon: Icons.chat_bubble_outline,
          label: _formatCount(
            _commentCounts[index],
          ),
          onTap: () {
            _openComments(index);
          },
        ),
        const SizedBox(height: 14),
        _actionButton(
          icon: _saved[index]
              ? Icons.bookmark
              : Icons.bookmark_border,
          label: _formatCount(
            _saveCounts[index],
          ),
          iconColor: _saved[index]
              ? const Color(0xFFFFD43B)
              : Colors.white,
          onTap: () {
            _toggleSave(index);
          },
        ),
        const SizedBox(height: 14),
        _actionButton(
          icon: Icons.share_outlined,
          label: _formatCount(
            _shareCounts[index],
          ),
          onTap: () {
            _shareVideo(index);
          },
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _toggleFollow,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              color: Colors.black45,
            ),
            child: const Center(
              child: Text(
                'P',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(
                0.35,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(
                  0.12,
                ),
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
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
    final index =
        _currentVideoIndex.clamp(
      0,
      _videoUsernames.length - 1,
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              _videoUsernames[index],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _toggleFollow,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white70,
                  ),
                  borderRadius:
                      BorderRadius.circular(5),
                ),
                child: Text(
                  _following
                      ? 'Following'
                      : 'Follow',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _videoCaptions[index],
          maxLines: 3,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 3,
          children: _videoHashtags[index]
              .map(
                (tag) => Text(
                  '#$tag',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const Icon(
              Icons.music_note,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _videoSounds[index],
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

  Widget _buildBottomNavigation() {
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(
          0.92,
        ),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(
              0.06,
            ),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround,
        children: [
          _bottomButton(
            icon: Icons.home_filled,
            label: 'Home',
            index: 0,
          ),
          _bottomButton(
            icon: Icons.people_outline,
            label: 'Friends',
            index: 1,
          ),
          GestureDetector(
            onTap: () {
              _selectBottom(2);
            },
            child: Container(
              width: 50,
              height: 36,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(10),
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xFF25F4EE),
                    Color(0xFFFF2D75),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ),
          ),
          _bottomButton(
            icon: Icons.chat_bubble_outline,
            label: 'Inbox',
            index: 3,
          ),
          _bottomButton(
            icon: Icons.person_outline,
            label: 'Profile',
            index: 4,
          ),
        ],
      ),
    );
  }

  Widget _bottomButton({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final selected =
        _bottomIndex == index;

    return GestureDetector(
      onTap: () {
        _selectBottom(index);
      },
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected
                  ? Colors.white
                  : Colors.white60,
              size: 25,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white60,
                fontSize: 10,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: videoUrls.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final controller =
                  _videoControllers[index];

              return GestureDetector(
                onTap: () {
                  _togglePlayPause(index);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (controller != null &&
                        controller
                            .value
                            .isInitialized)
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller
                              .value
                              .size
                              .width,
                          height: controller
                              .value
                              .size
                              .height,
                          child: VideoPlayer(
                            controller,
                          ),
                        ),
                      )
                    else
                      const Center(
                        child:
                            CircularProgressIndicator(
                          color: Color(
                            0xFFFF2D75,
                          ),
                        ),
                      ),
                    Container(
                      decoration:
                          const BoxDecoration(
                        gradient:
                            LinearGradient(
                          begin:
                              Alignment.topCenter,
                          end:
                              Alignment.bottomCenter,
                          colors: [
                            Colors.black38,
                            Colors.transparent,
                            Colors.black54,
                          ],
                          stops: [
                            0.0,
                            0.42,
                            1.0,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // TOP
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _buildTopBar(),
          ),

          // RIGHT BUTTONS
          Positioned(
            right: 10,
            bottom: 116,
            child: _buildRightButtons(),
          ),

          // VIDEO INFORMATION
          Positioned(
            left: 18,
            right: 92,
            bottom: 124,
            child: _buildVideoInformation(),
          ),

          // BOTTOM NAVIGATION
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

          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black
                    .withOpacity(0.72),
                child: Center(
                  child: Container(
                    width:
                        MediaQuery.of(context)
                                .size
                                .width *
                            0.82,
                    padding:
                        const EdgeInsets.all(
                      24,
                    ),
                    decoration:
                        BoxDecoration(
                      color: const Color(
                        0xFF171717,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_upload_outlined,
                          color: Colors.white,
                          size: 46,
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        const Text(
                          'Uploading video...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 18,
                        ),
                        LinearProgressIndicator(
                          value:
                              _uploadProgress,
                          minHeight: 7,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
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
                            fontSize: 14,
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

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();

    for (final controller
        in _videoControllers) {
      controller?.dispose();
    }

    _logoAnimationController.dispose();

    super.dispose();
  }
}

class VideoPostDraft {
  final String caption;
  final List<String> hashtags;

  const VideoPostDraft({
    required this.caption,
    required this.hashtags,
  });
}

class _VideoUploadSheet
    extends StatefulWidget {
  final File videoFile;

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

  bool _initialized = false;

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
      await _previewController
          .initialize();

      await _previewController
          .setLooping(true);

      await _previewController.play();

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      debugPrint(
        'Preview error: $e',
      );
    }
  }

  void _submit() {
    final caption =
        _captionController.text.trim();

    final hashtags = _hashtagsController
        .text
        .split(RegExp(r'[\s,]+'))
        .where(
          (tag) => tag.trim().isNotEmpty,
        )
        .map(
          (tag) => tag
              .replaceFirst('#', '')
              .trim(),
        )
        .where(
          (tag) => tag.isNotEmpty,
        )
        .toList();

    Navigator.of(context).pop(
      VideoPostDraft(
        caption: caption,
        hashtags: hashtags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard =
        MediaQuery.of(context)
            .viewInsets
            .bottom;

    return Container(
      height:
          MediaQuery.of(context).size.height *
              0.82,
      padding: EdgeInsets.fromLTRB(
        18,
        16,
        18,
        18 + keyboard,
      ),
      decoration:
          const BoxDecoration(
        color: Color(0xFF101010),
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Post Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(16),
              child: _initialized
                  ? AspectRatio(
                      aspectRatio:
                          _previewController
                              .value
                              .aspectRatio,
                      child: VideoPlayer(
                        _previewController,
                      ),
                    )
                  : const Center(
                      child:
                          CircularProgressIndicator(
                        color:
                            Color(0xFFFF2D75),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller:
                _captionController,
            style: const TextStyle(
              color: Colors.white,
            ),
            maxLines: 2,
            decoration:
                _inputDecoration(
              'Write a caption...',
              Icons.edit_outlined,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller:
                _hashtagsController,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration:
                _inputDecoration(
              'Hashtags e.g. PALOK ForYou',
              Icons.tag,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFFF2D75),
                foregroundColor:
                    Colors.white,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              child: const Text(
                'Post to PALOK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData icon,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.white38,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.white54,
      ),
      filled: true,
      fillColor: Colors.white
          .withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide: BorderSide.none,
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

class _CommentsSheet
    extends StatefulWidget {
  final int commentCount;
  final List<String> comments;
  final Future<void> Function(
    String comment,
  ) onSend;

  const _CommentsSheet({
    required this.commentCount,
    required this.comments,
    required this.onSend,
  });

  @override
  State<_CommentsSheet> createState() =>
      _CommentsSheetState();
}

class _CommentsSheetState
    extends State<_CommentsSheet> {
  final TextEditingController
      _controller =
      TextEditingController();

  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final keyboard =
        MediaQuery.of(context)
            .viewInsets
            .bottom;

    return Container(
      height:
          MediaQuery.of(context).size.height *
              0.62,
      padding: EdgeInsets.only(
        bottom: keyboard,
      ),
      decoration:
          const BoxDecoration(
        color: Color(0xFF080808),
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  '${widget.commentCount} comments',
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                  );
                },
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Divider(
            color: Colors.white12,
            height: 1,
          ),
          Expanded(
            child: widget.comments.isEmpty
                ? const Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(
                        color:
                            Colors.white54,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    itemCount:
                        widget.comments.length,
                    itemBuilder:
                        (context, index) {
                      return Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 9,
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  Color(
                                0xFF292929,
                              ),
                              child: Icon(
                                Icons.person,
                                color: Colors
                                    .white70,
                                size: 20,
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Text(
                                widget.comments[
                                    index],
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white,
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
              10,
              14,
              10,
            ),
            decoration:
                const BoxDecoration(
              color: Color(0xFF111111),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller:
                        _controller,
                    style:
                        const TextStyle(
                      color: Colors.white,
                    ),
                    decoration:
                        InputDecoration(
                      hintText:
                          'Add a comment...',
                      hintStyle:
                          const TextStyle(
                        color:
                            Colors.white38,
                      ),
                      filled: true,
                      fillColor:
                          Colors.white
                              .withOpacity(
                        0.07,
                      ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          24,
                        ),
                        borderSide:
                            BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending
                      ? null
                      : () async {
                          final text =
                              _controller
                                  .text
                                  .trim();

                          if (text.isEmpty) {
                            return;
                          }

                          setState(() {
                            _sending = true;
                          });

                          await widget
                              .onSend(text);
                        },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration:
                        const BoxDecoration(
                      color: Color(
                        0xFFFF2D75,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const Padding(
                            padding:
                                EdgeInsets.all(
                              12,
                            ),
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color:
                                Colors.white,
                            size: 20,
                          ),
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _SearchSheet
    extends StatefulWidget {
  final List<String> videos;
  final List<String> usernames;
  final List<String> captions;
  final List<List<String>> hashtags;
  final void Function(int index) onSelect;

  const _SearchSheet({
    required this.videos,
    required this.usernames,
    required this.captions,
    required this.hashtags,
    required this.onSelect,
  });

  @override
  State<_SearchSheet> createState() =>
      _SearchSheetState();
}

class _SearchSheetState
    extends State<_SearchSheet> {
  final TextEditingController
      _controller =
      TextEditingController();

  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results =
        <int>[];

    for (int i = 0;
        i < widget.videos.length;
        i++) {
      final text =
          '${widget.usernames[i]} '
          '${widget.captions[i]} '
          '${widget.hashtags[i].join(' ')}'
              .toLowerCase();

      if (_query.trim().isEmpty ||
          text.contains(
            _query.trim().toLowerCase(),
          )) {
        results.add(i);
      }
    }

    return Container(
      height:
          MediaQuery.of(context)
                  .size
                  .height *
              0.70,
      decoration:
          const BoxDecoration(
        color: Color(0xFF090909),
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            14,
            18,
            10,
          ),
          child: Column(
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          _controller,
                      autofocus: true,
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
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
                              Colors.white38,
                        ),
                        prefixIcon:
                            const Icon(
                          Icons.search,
                          color:
                              Colors.white60,
                        ),
                        filled: true,
                        fillColor:
                            Colors.white
                                .withOpacity(
                          0.07,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                          borderSide:
                              BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: results.isEmpty
                    ? const Center(
                        child: Text(
                          'No results found',
                          style:
                              TextStyle(
                            color:
                                Colors.white54,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount:
                            results.length,
                        itemBuilder:
                            (context, item) {
                          final index =
                              results[item];

                          return ListTile(
                            onTap: () {
                              widget.onSelect(
                                index,
                              );
                            },
                            contentPadding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 5,
                            ),
                            leading:
                                Container(
                              width: 58,
                              height: 70,
                              decoration:
                                  BoxDecoration(
                                color: Colors
                                    .white
                                    .withOpacity(
                                  0.08,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  9,
                                ),
                              ),
                              child:
                                  const Icon(
                                Icons
                                    .play_circle_outline,
                                color: Colors
                                    .white70,
                                size: 30,
                              ),
                            ),
                            title: Text(
                              widget
                                  .usernames[
                                      index],
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                            subtitle: Text(
                              widget
                                  .captions[
                                      index],
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white60,
                              ),
                            ),
                            trailing:
                                const Icon(
                              Icons
                                  .chevron_right,
                              color:
                                  Colors.white54,
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
    _controller.dispose();
    super.dispose();
  }
}
