import 'dart:async';
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
  // ============================================================
  // LOCKED UI
  // ============================================================

  int _bottomIndex = 0;
  int _topIndex = 0;

  final PageController _pageController = PageController();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final ImagePicker _picker = ImagePicker();

  // ============================================================
  // CLOUDINARY
  // ============================================================

  static const String _cloudinaryCloudName = 'u0jufmrl';

  static const String _cloudinaryUploadPreset =
      'palok_video_upload';

  static const int _maxVideoBytes =
      100 * 1024 * 1024;

  // ============================================================
  // VIDEOS
  // ============================================================

  final List<String> videoUrls = [
    'assets/videos/video.mp4',
    'assets/videos/video1.mp4',
    'assets/videos/video2.mp4',
  ];

  final List<VideoPlayerController?> _videoControllers = [];

  final List<String?> _videoIds = [
    null,
    null,
    null,
  ];

  final List<String?> _videoOwners = [
    null,
    null,
    null,
  ];

  final List<String> _videoUsernames = [
    '@palok_user',
    '@palok_user',
    '@palok_user',
  ];

  final List<String> _videoCaptions = [
    'Welcome to PALOK 🎬',
    'Enjoy short videos on PALOK ✨',
    'Create. Share. Connect. 🚀',
  ];

  final List<List<String>> _videoHashtags = [
    ['PALOK', 'ForYou'],
    ['PALOK', 'ShortVideo'],
    ['PALOK', 'Bangladesh'],
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
    96,
  ];

  final List<int> _saveCounts = [
    811,
    452,
    317,
  ];

  final List<int> _shareCounts = [
    431,
    201,
    145,
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

  final List<String?> _followingUsers = [
    null,
    null,
    null,
  ];

  final List<List<String>> _localComments = [
    [
      '@rahim: Nice video! 🔥',
      '@karim: Awesome ❤️',
      '@user123: PALOK looks great!',
    ],
    [
      '@sadia: Very nice!',
      '@rahim: 🔥🔥🔥',
    ],
    [
      '@karim: Great content!',
    ],
  ];

  int _currentVideoIndex = 0;

  // ============================================================
  // UPLOAD STATE
  // ============================================================

  bool _isUploading = false;

  double _uploadProgress = 0;

  String _uploadStatus = '';

  // ============================================================
  // LOGO ANIMATION
  // ============================================================

  late AnimationController _logoController;

  late Animation<double> _logoScale;

  late Animation<double> _logoOpacity;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1800,
      ),
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

    _prepareVideos();
  }

  // ============================================================
  // PREPARE VIDEOS
  // ============================================================

  Future<void> _prepareVideos() async {
    for (int i = 0; i < videoUrls.length; i++) {
      final String url = videoUrls[i];

      final VideoPlayerController controller;

      if (url.startsWith('http')) {
        controller =
            VideoPlayerController.networkUrl(
          Uri.parse(url),
        );
      } else {
        controller =
            VideoPlayerController.asset(url);
      }

      _videoControllers.add(controller);

      try {
        await controller.initialize();

        await controller.setLooping(true);

        if (i == 0) {
          await controller.play();
        }

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint(
          'Video $i initialize error: $e',
        );
      }
    }
  }

  // ============================================================
  // LOGIN CHECK
  // ============================================================

  Future<User?> _ensureUser() async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'আগে Login করুন!',
      );
    }

    return user;
  }

  // ============================================================
  // PAGE CHANGE
  // ============================================================

  Future<void> _onPageChanged(
    int index,
  ) async {
    _currentVideoIndex = index;

    for (
      int i = 0;
      i < _videoControllers.length;
      i++
    ) {
      final controller =
          _videoControllers[i];

      if (controller == null ||
          !controller.value.isInitialized) {
        continue;
      }

      try {
        if (i == index) {
          await controller.seekTo(
            Duration.zero,
          );

          await controller.play();
        } else {
          await controller.pause();
        }
      } catch (e) {
        debugPrint(
          'Page video error: $e',
        );
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // PLAY / PAUSE
  // ============================================================

  Future<void> _toggleVideo(
    int index,
  ) async {
    if (index >=
        _videoControllers.length) {
      return;
    }

    final controller =
        _videoControllers[index];

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint(
        'Play pause error: $e',
      );
    }
  }

  // ============================================================
  // LIKE
  // ============================================================

  Future<void> _toggleLike(
    int index,
  ) async {
    final user =
        await _ensureUser();

    if (user == null) return;

    setState(() {
      _liked[index] =
          !_liked[index];

      if (_liked[index]) {
        _likeCounts[index]++;
      } else if (_likeCounts[index] > 0) {
        _likeCounts[index]--;
      }
    });

    final videoId =
        _videoIds[index];

    if (videoId == null) return;

    try {
      await _firestore
          .collection('videos')
          .doc(videoId)
          .update({
        'likeCount':
            _likeCounts[index],
      });
    } catch (e) {
      debugPrint(
        'Like save error: $e',
      );
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _toggleSave(
    int index,
  ) async {
    final user =
        await _ensureUser();

    if (user == null) return;

    setState(() {
      _saved[index] =
          !_saved[index];

      if (_saved[index]) {
        _saveCounts[index]++;
      } else if (_saveCounts[index] > 0) {
        _saveCounts[index]--;
      }
    });

    _showMessage(
      _saved[index]
          ? 'ভিডিওটি Saved হয়েছে'
          : 'ভিডিওটি Unsave করা হয়েছে',
    );

    final videoId =
        _videoIds[index];

    if (videoId == null) return;

    try {
      await _firestore
          .collection('videos')
          .doc(videoId)
          .update({
        'saveCount':
            _saveCounts[index],
      });
    } catch (e) {
      debugPrint(
        'Save error: $e',
      );
    }
  }

  // ============================================================
  // FOLLOW
  // ============================================================

  Future<void> _toggleFollow(
    int index,
  ) async {
    final user =
        await _ensureUser();

    if (user == null) return;

    final owner =
        _videoOwners[index];

    if (owner == null) {
      _showMessage(
        'এই ভিডিওর owner পাওয়া যায়নি',
      );
      return;
    }

    if (owner == user.uid) {
      _showMessage(
        'এটি আপনার নিজের ভিডিও',
      );
      return;
    }

    setState(() {
      if (_followingUsers[index] ==
          owner) {
        _followingUsers[index] =
            null;
      } else {
        _followingUsers[index] =
            owner;
      }
    });

    _showMessage(
      _followingUsers[index] == owner
          ? 'Following করা হয়েছে'
          : 'Unfollow করা হয়েছে',
    );
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _shareVideo(
    int index,
  ) async {
    final user =
        await _ensureUser();

    if (user == null) return;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'দেখুন PALOK-এ এই ভিডিওটি 🎬\n${videoUrls[index]}',
          subject: 'PALOK Video',
        ),
      );

      if (!mounted) return;

      setState(() {
        _shareCounts[index]++;
      });

      final videoId =
          _videoIds[index];

      if (videoId != null) {
        try {
          await _firestore
              .collection('videos')
              .doc(videoId)
              .update({
            'shareCount':
                _shareCounts[index],
          });
        } catch (e) {
          debugPrint(
            'Share count error: $e',
          );
        }
      }
    } catch (e) {
      _showMessage(
        'Share করা যায়নি',
      );
    }
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  void _openComments(
    int index,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return _CommentsSheet(
          comments:
              _localComments[index],
          count:
              _commentCounts[index],
          onSend: (text) async {
            final user =
                await _ensureUser();

            if (user == null) return;

            final displayName =
                user.displayName
                        ?.trim() ??
                    '';

            final username =
                displayName.isNotEmpty
                    ? '@$displayName'
                    : '@palok_user';

            if (!mounted) return;

            setState(() {
              _localComments[index]
                  .add(
                '$username: $text',
              );

              _commentCounts[index]++;
            });

            final videoId =
                _videoIds[index];

            if (videoId != null) {
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
                  'Comment count error: $e',
                );
              }
            }
          },
        );
      },
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return _SearchSheet(
          usernames:
              _videoUsernames,
          captions:
              _videoCaptions,
          hashtags:
              _videoHashtags,
          onSelect: (index) {
            Navigator.pop(
              context,
            );

            Future.delayed(
              const Duration(
                milliseconds: 100,
              ),
              () {
                if (_pageController
                    .hasClients) {
                  _pageController
                      .animateToPage(
                    index,
                    duration:
                        const Duration(
                      milliseconds: 450,
                    ),
                    curve:
                        Curves.easeOut,
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CREATE MENU
  // ============================================================

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          const Color(0xFF151515),
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24,
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
                  height: 24,
                ),
                const Text(
                  'Create on PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 22,
                ),
                _createOption(
                  icon:
                      Icons.videocam_outlined,
                  title:
                      'Record Video',
                  onTap: () {
                    Navigator.pop(
                      context,
                    );

                    _showMessage(
                      'Camera recording শীঘ্রই আসছে',
                    );
                  },
                ),
                _createOption(
                  icon: Icons
                      .video_library_outlined,
                  title:
                      'Upload Video',
                  onTap: () async {
                    Navigator.pop(
                      context,
                    );

                    await _pickAndUploadVideo();
                  },
                ),
                _createOption(
                  icon:
                      Icons.music_note_outlined,
                  title: 'Add Sound',
                  onTap: () {
                    Navigator.pop(
                      context,
                    );

                    _showMessage(
                      'Sound feature শীঘ্রই আসছে',
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
      leading: Container(
        width: 46,
        height: 46,
        decoration:
            BoxDecoration(
          color: Colors.white10,
          borderRadius:
              BorderRadius.circular(
            14,
          ),
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
          fontWeight:
              FontWeight.w600,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white38,
      ),
    );
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void>
      _pickAndUploadVideo() async {
    final user =
        await _ensureUser();

    if (user == null) return;

    try {
      final XFile? pickedVideo =
          await _picker.pickVideo(
        source:
            ImageSource.gallery,
      );

      if (pickedVideo == null) {
        return;
      }

      final File file =
          File(pickedVideo.path);

      if (!await file.exists()) {
        _showMessage(
          'ভিডিও ফাইল পাওয়া যায়নি',
        );
        return;
      }

      final int fileSize =
          await file.length();

      if (fileSize <= 0) {
        _showMessage(
          'ভিডিও ফাইলটি খালি',
        );
        return;
      }

      if (fileSize >
          _maxVideoBytes) {
        _showMessage(
          'ভিডিও 100 MB বা তার কম হতে হবে।',
        );
        return;
      }

      if (!mounted) return;

      final VideoPostDraft? draft =
          await showModalBottomSheet<
              VideoPostDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor:
            Colors.transparent,
        builder: (context) {
          return _VideoUploadSheet(
            videoFile: file,
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
      debugPrint(
        'Pick video error: $e',
      );

      _showMessage(
        'ভিডিও নির্বাচন করা যায়নি',
      );
    }
  }

  // ============================================================
  // REAL CLOUDINARY UPLOAD
  // ============================================================

  Future<void> _uploadVideo(
    XFile pickedVideo,
    VideoPostDraft draft,
  ) async {
    final user =
        await _ensureUser();

    if (user == null) return;

    if (!mounted) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.01;
      _uploadStatus =
          'ভিডিও প্রস্তুত করা হচ্ছে...';
    });

    try {
      final File file =
          File(pickedVideo.path);

      if (!await file.exists()) {
        throw Exception(
          'ভিডিও ফাইল পাওয়া যায়নি।',
        );
      }

      final int fileLength =
          await file.length();

      if (fileLength <= 0) {
        throw Exception(
          'ভিডিও ফাইল খালি।',
        );
      }

      if (fileLength >
          _maxVideoBytes) {
        throw Exception(
          'ভিডিও 100 MB বা তার কম হতে হবে।',
        );
      }

      final String videoId =
          _firestore
              .collection('videos')
              .doc()
              .id;

      final Uri uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '$_cloudinaryCloudName/video/upload',
      );

      // ----------------------------------------------------------
      // REAL BYTE PROGRESS
      // ----------------------------------------------------------

      int uploadedBytes = 0;

      DateTime lastUpdate =
          DateTime.now();

      final Stream<List<int>>
          fileStream =
          file.openRead().map(
        (chunk) {
          uploadedBytes +=
              chunk.length;

          final now =
              DateTime.now();

          if (now
                      .difference(
                        lastUpdate,
                      )
                      .inMilliseconds >=
                  80 ||
              uploadedBytes >=
                  fileLength) {
            lastUpdate = now;

            final double fileProgress =
                uploadedBytes /
                    fileLength;

            if (mounted) {
              setState(() {
                // Upload section:
                // 1% -> 88%
                _uploadProgress =
                    0.01 +
                        (fileProgress *
                            0.87);

                _uploadStatus =
                    'ভিডিও upload হচ্ছে... '
                    '${(_uploadProgress * 100).round()}%';
              });
            }
          }

          return chunk;
        },
      );

      final multipartFile =
          http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: pickedVideo.name,
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
        multipartFile,
      );

      if (mounted) {
        setState(() {
          _uploadProgress = 0.03;
          _uploadStatus =
              'Cloudinary-তে upload শুরু হয়েছে...';
        });
      }

      // ----------------------------------------------------------
      // CLOUDINARY
      // ----------------------------------------------------------

      final response =
          await request.send().timeout(
        const Duration(
          minutes: 15,
        ),
        onTimeout: () {
          throw TimeoutException(
            'Cloudinary upload timeout',
          );
        },
      );

      if (mounted) {
        setState(() {
          _uploadProgress = 0.91;
          _uploadStatus =
              'Upload শেষ হচ্ছে...';
        });
      }

      final String responseBody =
          await response
              .stream
              .bytesToString();

      if (response.statusCode <
              200 ||
          response.statusCode >=
              300) {
        String message =
            'Cloudinary upload failed '
            '(${response.statusCode})';

        try {
          final decoded =
              jsonDecode(
            responseBody,
          );

          if (decoded
              is Map<String, dynamic>) {
            final error =
                decoded['error'];

            if (error
                is Map<String, dynamic>) {
              final errorMessage =
                  error['message'];

              if (errorMessage !=
                  null) {
                message =
                    errorMessage.toString();
              }
            }
          }
        } catch (_) {}

        throw Exception(
          message,
        );
      }

      final decoded =
          jsonDecode(
        responseBody,
      );

      if (decoded
          is! Map<String, dynamic>) {
        throw Exception(
          'Cloudinary response সঠিক নয়।',
        );
      }

      final Map<String, dynamic>
          data = decoded;

      final String downloadUrl =
          (data['secure_url'] ??
                  '')
              .toString();

      if (downloadUrl.isEmpty) {
        throw Exception(
          'Cloudinary video URL পাওয়া যায়নি।',
        );
      }

      if (mounted) {
        setState(() {
          _uploadProgress = 0.93;
          _uploadStatus =
              'ভিডিও তথ্য সংরক্ষণ করা হচ্ছে...';
        });
      }

      // ----------------------------------------------------------
      // USERNAME
      // ----------------------------------------------------------

      final String displayName =
          user.displayName
                  ?.trim() ??
              '';

      final String username =
          displayName.isNotEmpty
              ? '@$displayName'
              : '@palok_user';

      // ----------------------------------------------------------
      // FIRESTORE
      // ----------------------------------------------------------

      final Map<String, dynamic>
          videoData = {
        'ownerId': user.uid,
        'username': username,
        'videoUrl': downloadUrl,
        'cloudinaryPublicId':
            (data['public_id'] ??
                    '')
                .toString(),
        'cloudinaryAssetId':
            (data['asset_id'] ??
                    '')
                .toString(),
        'caption':
            draft.caption,
        'hashtags':
            draft.hashtags,
        'soundName':
            'Original sound',
        'likeCount': 0,
        'commentCount': 0,
        'saveCount': 0,
        'shareCount': 0,
        'createdAt':
            FieldValue
                .serverTimestamp(),
      };

      await _firestore
          .collection('videos')
          .doc(videoId)
          .set(videoData);

      if (mounted) {
        setState(() {
          _uploadProgress = 0.96;
          _uploadStatus =
              'PALOK feed প্রস্তুত হচ্ছে...';
        });
      }

      // ----------------------------------------------------------
      // PREPARE UPLOADED VIDEO
      // ----------------------------------------------------------

      final controller =
          VideoPlayerController
              .networkUrl(
        Uri.parse(
          downloadUrl,
        ),
      );

      try {
        await controller
            .initialize();

        await controller
            .setLooping(true);
      } catch (e) {
        await controller.dispose();

        throw Exception(
          'Uploaded video playback প্রস্তুত করা যায়নি।',
        );
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      // ----------------------------------------------------------
      // ADD TO PALOK FEED
      // ----------------------------------------------------------

      final int newIndex =
          videoUrls.length;

      setState(() {
        _videoIds.add(
          videoId,
        );

        videoUrls.add(
          downloadUrl,
        );

        _videoOwners.add(
          user.uid,
        );

        _videoUsernames.add(
          username,
        );

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

        _uploadProgress = 1.0;

        _uploadStatus =
            'ভিডিও সফলভাবে পোস্ট হয়েছে!';
      });

      // ----------------------------------------------------------
      // OPEN NEW VIDEO
      // ----------------------------------------------------------

      await Future.delayed(
        const Duration(
          milliseconds: 200,
        ),
      );

      if (!mounted) return;

      if (_pageController
          .hasClients) {
        await _pageController
            .animateToPage(
          newIndex,
          duration:
              const Duration(
            milliseconds: 450,
          ),
          curve:
              Curves.easeOut,
        );
      }

      _currentVideoIndex =
          newIndex;

      await controller.play();

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 1.0;
          _uploadStatus = '';
        });

        _showMessage(
          '🎉 ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে!',
        );
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
        _uploadStatus = '';
      });

      _showMessage(
        'Upload করতে অনেক সময় লাগছে। Internet connection চেক করে আবার চেষ্টা করুন।',
      );
    } catch (e) {
      debugPrint(
        'PALOK upload error: $e',
      );

      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
        _uploadStatus = '';
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

  // ============================================================
  // BOTTOM NAV
  // ============================================================

  void _selectBottom(
    int index,
  ) {
    setState(() {
      _bottomIndex = index;
    });

    if (index == 0) {
      if (_pageController
          .hasClients) {
        _pageController
            .animateToPage(
          0,
          duration:
              const Duration(
            milliseconds: 350,
          ),
          curve:
              Curves.easeOut,
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
        'Friends section শীঘ্রই আসছে',
      );
      return;
    }

    if (index == 3) {
      _showMessage(
        'Inbox section শীঘ্রই আসছে',
      );
      return;
    }

    if (index == 4) {
      _showMessage(
        'Profile section শীঘ্রই আসছে',
      );
    }
  }

  // ============================================================
  // TOP NAV
  // ============================================================

  void _selectTop(
    int index,
  ) {
    setState(() {
      _topIndex = index;
    });

    if (index == 0) {
      _showMessage('For You');
    } else {
      _showMessage('Following');
    }
  }

  // ============================================================
  // RIGHT BUTTONS
  // ============================================================

  Widget _buildRightButtons() {
    final int index =
        _currentVideoIndex;

    if (index < 0 ||
        index >= _liked.length) {
      return const SizedBox();
    }

    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        _actionButton(
          icon:
              Icons.favorite,
          active:
              _liked[index],
          activeColor:
              const Color(
            0xFFFF2D75,
          ),
          count:
              _formatCount(
            _likeCounts[index],
          ),
          onTap: () =>
              _toggleLike(index),
        ),

        const SizedBox(
          height: 13,
        ),

        _actionButton(
          icon:
              Icons.comment,
          count:
              _formatCount(
            _commentCounts[index],
          ),
          onTap: () =>
              _openComments(index),
        ),

        const SizedBox(
          height: 13,
        ),

        _actionButton(
          icon:
              Icons.bookmark,
          active:
              _saved[index],
          activeColor:
              const Color(
            0xFFFFC107,
          ),
          count:
              _formatCount(
            _saveCounts[index],
          ),
          onTap: () =>
              _toggleSave(index),
        ),

        const SizedBox(
          height: 13,
        ),

        _actionButton(
          icon:
              Icons.share,
          count:
              _formatCount(
            _shareCounts[index],
          ),
          onTap: () =>
              _shareVideo(index),
        ),

        const SizedBox(
          height: 24,
        ),

        GestureDetector(
          onTap: () =>
              _toggleFollow(index),
          child: Stack(
            clipBehavior:
                Clip.none,
            alignment:
                Alignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      Colors.white12,
                  border:
                      Border.all(
                    color:
                        Colors.white24,
                  ),
                ),
                child:
                    const Icon(
                  Icons.person,
                  color:
                      Colors.white,
                  size: 25,
                ),
              ),

              if (_videoOwners[
                      index] !=
                  null &&
                  _followingUsers[
                      index] !=
                      _videoOwners[
                          index])
                Positioned(
                  bottom: -5,
                  child:
                      Container(
                    width: 20,
                    height: 20,
                    decoration:
                        const BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          Color(
                        0xFFFF2D75,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons.add,
                      color:
                          Colors.white,
                      size: 15,
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
    Color? activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  Colors.black.withOpacity(
                0.38,
              ),
              border:
                  Border.all(
                color:
                    Colors.white.withOpacity(
                  0.12,
                ),
              ),
            ),
            child: Icon(
              icon,
              color: active
                  ? (activeColor ??
                      Colors.white)
                  : Colors.white,
              size: 23,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            count,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight:
                  FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VIDEO INFORMATION
  // ============================================================

  Widget _buildVideoInformation() {
    final int index =
        _currentVideoIndex;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                _videoUsernames[
                    index],
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight:
                      FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            GestureDetector(
              onTap: () =>
                  _toggleFollow(index),
              child: Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                    7,
                  ),
                  border:
                      Border.all(
                    color:
                        Colors.white54,
                  ),
                ),
                child: Text(
                  _followingUsers[
                              index] ==
                          _videoOwners[
                              index] &&
                      _videoOwners[
                              index] !=
                          null
                      ? 'Following'
                      : 'Follow',
                  style:
                      const TextStyle(
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

        const SizedBox(
          height: 8,
        ),

        Text(
          _videoCaptions[
              index],
          maxLines: 3,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.3,
            shadows: [
              Shadow(
                color: Colors.black,
                blurRadius: 5,
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 7,
        ),

        if (_videoHashtags[
                index]
            .isNotEmpty)
          Text(
            _videoHashtags[
                    index]
                .map(
                  (e) => '#$e',
                )
                .join(' '),
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

        const SizedBox(
          height: 7,
        ),

        Row(
          children: [
            const Icon(
              Icons.music_note,
              color: Colors.white,
              size: 15,
            ),

            const SizedBox(
              width: 4,
            ),

            Expanded(
              child: Text(
                _videoSounds[
                    index],
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
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
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return Container(
      height: 78,
      decoration:
          const BoxDecoration(
        color: Colors.black,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceAround,
        children: [
          _bottomButton(
            icon:
                Icons.home_filled,
            label: 'Home',
            index: 0,
          ),

          _bottomButton(
            icon:
                Icons.people_outline,
            label: 'Friends',
            index: 1,
          ),

          GestureDetector(
            onTap: () =>
                _selectBottom(2),
            child: Container(
              width: 52,
              height: 38,
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(
                      0xFF25F4EE,
                    ),
                    Color(
                      0xFFFF2D75,
                    ),
                  ],
                ),
              ),
              child:
                  const Center(
                child: Icon(
                  Icons.add,
                  color:
                      Colors.white,
                  size: 29,
                ),
              ),
            ),
          ),

          _bottomButton(
            icon:
                Icons.chat_bubble_outline,
            label: 'Inbox',
            index: 3,
          ),

          _bottomButton(
            icon:
                Icons.person_outline,
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
    final bool active =
        _bottomIndex == index;

    return GestureDetector(
      onTap: () =>
          _selectBottom(index),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment
                  .center,
          children: [
            Icon(
              icon,
              color: active
                  ? Colors.white
                  : Colors.white54,
              size: 24,
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ANIMATED PALOK LOGO
  // ============================================================

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation:
          _logoController,
      builder:
          (context, child) {
        return Opacity(
          opacity:
              _logoOpacity.value,
          child:
              Transform.scale(
            scale:
                _logoScale.value,
            child: child,
          ),
        );
      },
      child: Container(
        width: 43,
        height: 43,
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          gradient:
              const LinearGradient(
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
            colors: [
              Color(
                0xFFFF2D75,
              ),
              Color(
                0xFF8B5CF6,
              ),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color:
                  Color(0xFFFF2D75),
              blurRadius: 16,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'P',
            style:
                TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          14,
          8,
          10,
          0,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,
          children: [
            _buildAnimatedLogo(),

            const Spacer(),

            GestureDetector(
              onTap: () =>
                  _selectTop(0),
              child: _topTab(
                'For You',
                _topIndex == 0,
              ),
            ),

            const SizedBox(
              width: 18,
            ),

            GestureDetector(
              onTap: () =>
                  _selectTop(1),
              child: _topTab(
                'Following',
                _topIndex == 1,
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            GestureDetector(
              onTap: _openSearch,
              child: const Padding(
                padding:
                    EdgeInsets.all(8),
                child: Icon(
                  Icons.search,
                  color:
                      Colors.white,
                  size: 27,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topTab(
    String text,
    bool active,
  ) {
    return Column(
      children: [
        Text(
          text,
          style: TextStyle(
            color: active
                ? Colors.white
                : Colors.white54,
            fontSize: 14,
            fontWeight: active
                ? FontWeight.bold
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
              active ? 22 : 0,
          height: 2,
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              5,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // UPLOAD OVERLAY
  // ============================================================

  Widget _buildUploadOverlay() {
    if (!_isUploading) {
      return const SizedBox();
    }

    final int percentage =
        (_uploadProgress * 100)
            .clamp(0, 100)
            .round();

    return Positioned(
      left: 18,
      right: 18,

      // LOCKED NAVIGATION-এর উপরে
      bottom: 88,

      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          14,
          16,
          14,
        ),
        decoration:
            BoxDecoration(
          color: Colors.black
              .withOpacity(
            0.88,
          ),
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          border:
              Border.all(
            color: Colors.white10,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        Color(
                      0xFFFF2D75,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: Text(
                    _uploadStatus
                            .isEmpty
                        ? 'Uploading video...'
                        : _uploadStatus,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 14,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                Text(
                  '$percentage%',
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
              child:
                  LinearProgressIndicator(
                value:
                    _uploadProgress,
                minHeight: 5,
                backgroundColor:
                    Colors.white12,
                color:
                    const Color(
                  0xFFFF2D75,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String text,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior:
              SnackBarBehavior.floating,
          duration:
              const Duration(
            seconds: 2,
          ),
        ),
      );
  }

  // ============================================================
  // FORMAT COUNT
  // ============================================================

  String _formatCount(
    int count,
  ) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }

    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }

    return count.toString();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,
      body: Stack(
        children: [
          // FULL SCREEN VIDEO
          PageView.builder(
            controller:
                _pageController,
            scrollDirection:
                Axis.vertical,
            itemCount:
                videoUrls.length,
            onPageChanged:
                _onPageChanged,
            itemBuilder:
                (context, index) {
              return GestureDetector(
                onTap: () =>
                    _toggleVideo(
                  index,
                ),
                child:
                    _buildVideoPage(
                  index,
                ),
              );
            },
          ),

          // TOP BAR
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child:
                _buildTopBar(),
          ),

          // LOCKED RIGHT POSITION
          Positioned(
            right: 10,
            bottom: 116,
            child:
                _buildRightButtons(),
          ),

          // VIDEO INFORMATION
          Positioned(
            left: 18,
            right: 92,
            bottom: 124,
            child:
                _buildVideoInformation(),
          ),

          // LOCKED BOTTOM NAV
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

          // UPLOAD PROGRESS
          _buildUploadOverlay(),
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
        child: Center(
          child:
              CircularProgressIndicator(
            color:
                Color(0xFFFF2D75),
          ),
        ),
      );
    }

    final controller =
        _videoControllers[index];

    if (controller == null ||
        !controller
            .value
            .isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child:
              CircularProgressIndicator(
            color:
                Color(0xFFFF2D75),
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width:
              controller.value.size.width,
          height:
              controller.value.size.height,
          child:
              VideoPlayer(controller),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _logoController.dispose();

    _pageController.dispose();

    for (
      final controller
          in _videoControllers
    ) {
      controller?.dispose();
    }

    super.dispose();
  }
}

// =================================================================
// VIDEO POST DRAFT
// =================================================================

class VideoPostDraft {
  final String caption;

  final List<String> hashtags;

  const VideoPostDraft({
    required this.caption,
    required this.hashtags,
  });
}

// =================================================================
// VIDEO UPLOAD / POST SHEET
// =================================================================

class _VideoUploadSheet
    extends StatefulWidget {
  final File videoFile;

  const _VideoUploadSheet({
    required this.videoFile,
  });

  @override
  State<_VideoUploadSheet>
      createState() =>
          _VideoUploadSheetState();
}

class _VideoUploadSheetState
    extends State<_VideoUploadSheet> {
  late VideoPlayerController
      _controller;

  final TextEditingController
      _captionController =
      TextEditingController();

  final TextEditingController
      _hashtagController =
      TextEditingController();

  bool _initialized = false;

  bool _isPosting = false;

  @override
  void initState() {
    super.initState();

    _controller =
        VideoPlayerController.file(
      widget.videoFile,
    );

    _prepareVideo();
  }

  Future<void>
      _prepareVideo() async {
    try {
      await _controller
          .initialize();

      await _controller
          .setLooping(true);

      await _controller.play();

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      debugPrint(
        'Upload preview error: $e',
      );
    }
  }

  // ============================================================
  // POST
  // ============================================================

  void _post() {
    if (!_initialized ||
        _isPosting) {
      return;
    }

    FocusManager
        .instance
        .primaryFocus
        ?.unfocus();

    setState(() {
      _isPosting = true;
    });

    final hashtags =
        _hashtagController.text
            .trim()
            .split(
              RegExp(
                r'[\s,#]+',
              ),
            )
            .where(
              (e) => e.isNotEmpty,
            )
            .map(
              (e) => e.startsWith('#')
                  ? e.substring(1)
                  : e,
            )
            .toSet()
            .toList();

    Navigator.pop(
      context,
      VideoPostDraft(
        caption:
            _captionController
                .text
                .trim(),
        hashtags:
            hashtags,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final media =
        MediaQuery.of(context);

    final keyboardHeight =
        media.viewInsets.bottom;

    return AnimatedPadding(
      duration:
          const Duration(
        milliseconds: 220,
      ),
      curve: Curves.easeOut,
      padding:
          EdgeInsets.only(
        bottom:
            keyboardHeight,
      ),
      child: Container(
        height:
            media.size.height *
                0.84,
        decoration:
            const BoxDecoration(
          color:
              Color(0xFF111111),
          borderRadius:
              BorderRadius.vertical(
            top: Radius.circular(
              24,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(
                height: 10,
              ),

              Container(
                width: 42,
                height: 4,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.white24,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  8,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Post Video',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    GestureDetector(
                      onTap: () =>
                          Navigator.pop(
                        context,
                      ),
                      child:
                          const Icon(
                        Icons.close,
                        color:
                            Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child:
                    SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    20,
                  ),
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      // VIDEO PREVIEW
                      AspectRatio(
                        aspectRatio:
                            _initialized
                                ? _controller
                                    .value
                                    .aspectRatio
                                : 9 / 16,
                        child:
                            ClipRRect(
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                          child:
                              _initialized
                                  ? VideoPlayer(
                                      _controller,
                                    )
                                  : const ColoredBox(
                                      color:
                                          Colors.black,
                                      child:
                                          Center(
                                        child:
                                            CircularProgressIndicator(
                                          color:
                                              Color(
                                            0xFFFF2D75,
                                          ),
                                        ),
                                      ),
                                    ),
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      // CAPTION
                      TextField(
                        controller:
                            _captionController,
                        maxLines: 4,
                        maxLength: 2200,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 15,
                        ),
                        decoration:
                            InputDecoration(
                          hintText:
                              'Write a caption...',
                          hintStyle:
                              const TextStyle(
                            color:
                                Colors.white38,
                          ),
                          filled: true,
                          fillColor:
                              Colors.white10,
                          counterStyle:
                              const TextStyle(
                            color:
                                Colors.white38,
                          ),
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                            borderSide:
                                BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.all(
                            16,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      // HASHTAGS
                      TextField(
                        controller:
                            _hashtagController,
                        maxLines: 2,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 15,
                        ),
                        decoration:
                            InputDecoration(
                          hintText:
                              'Hashtags: PALOK ForYou',
                          hintStyle:
                              const TextStyle(
                            color:
                                Colors.white38,
                          ),
                          prefixIcon:
                              const Icon(
                            Icons.tag,
                            color:
                                Colors.white54,
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
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // SOUND
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white10,
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons
                                  .music_note,
                              color:
                                  Colors.white,
                              size: 21,
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Text(
                                'Original sound',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize:
                                      14,
                                  fontWeight:
                                      FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons
                                  .chevron_right,
                              color:
                                  Colors.white38,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // POST BUTTON
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  14,
                ),
                child:
                    SizedBox(
                  width:
                      double.infinity,
                  height: 54,
                  child:
                      ElevatedButton(
                    onPressed:
                        _initialized &&
                                !_isPosting
                            ? _post
                            : null,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFFFF2D75,
                      ),
                      disabledBackgroundColor:
                          Colors.white12,
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: _isPosting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'Post to PALOK',
                            style:
                                TextStyle(
                              fontSize:
                                  16,
                              fontWeight:
                                  FontWeight.bold,
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
    _controller.dispose();

    _captionController.dispose();

    _hashtagController.dispose();

    super.dispose();
  }
}

// =================================================================
// COMMENTS
// =================================================================

class _CommentsSheet
    extends StatefulWidget {
  final List<String> comments;

  final int count;

  final Future<void> Function(
    String text,
  ) onSend;

  const _CommentsSheet({
    required this.comments,
    required this.count,
    required this.onSend,
  });

  @override
  State<_CommentsSheet>
      createState() =>
          _CommentsSheetState();
}

class _CommentsSheetState
    extends State<_CommentsSheet> {
  final TextEditingController
      _controller =
      TextEditingController();

  bool _sending = false;

  Future<void> _send() async {
    final String text =
        _controller.text.trim();

    if (text.isEmpty ||
        _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.onSend(
        text,
      );

      _controller.clear();
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final keyboard =
        MediaQuery.of(context)
            .viewInsets
            .bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        padding:
            EdgeInsets.only(
          bottom:
              keyboard,
        ),
        child: Container(
          height:
              MediaQuery.of(context)
                      .size
                      .height *
                  0.62,
          decoration:
              const BoxDecoration(
            color:
                Color(0xFF101010),
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(
                22,
              ),
            ),
          ),
          child:
              Column(
            children: [
              const SizedBox(
                height: 10,
              ),

              Container(
                width: 42,
                height: 4,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.white24,
                  borderRadius:
                      BorderRadius.circular(
                    10,
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
                    Expanded(
                      child: Text(
                        '${widget.count} Comments',
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed:
                          () =>
                              Navigator.pop(
                        context,
                      ),
                      icon:
                          const Icon(
                        Icons.close,
                        color:
                            Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(
                color:
                    Colors.white10,
                height: 1,
              ),

              Expanded(
                child:
                    widget.comments
                            .isEmpty
                        ? const Center(
                            child:
                                Text(
                              'No comments yet',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white54,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets
                                    .all(
                              16,
                            ),
                            itemCount:
                                widget.comments
                                    .length,
                            itemBuilder:
                                (
                              context,
                              index,
                            ) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(
                                  bottom:
                                      18,
                                ),
                                child:
                                    Text(
                                  widget.comments[
                                      index],
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize:
                                        14,
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child:
                          TextField(
                        controller:
                            _controller,
                        minLines:
                            1,
                        maxLines:
                            3,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                        ),
                        decoration:
                            InputDecoration(
                          hintText:
                              'Add comment...',
                          hintStyle:
                              const TextStyle(
                            color:
                                Colors.white38,
                          ),
                          filled: true,
                          fillColor:
                              Colors.white10,
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              24,
                            ),
                            borderSide:
                                BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                18,
                            vertical:
                                12,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    GestureDetector(
                      onTap: _send,
                      child:
                          Container(
                        width: 46,
                        height: 46,
                        decoration:
                            const BoxDecoration(
                          shape:
                              BoxShape
                                  .circle,
                          color:
                              Color(
                            0xFFFF2D75,
                          ),
                        ),
                        child: _sending
                            ? const Padding(
                                padding:
                                    EdgeInsets.all(
                                  13,
                                ),
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color:
                                    Colors.white,
                                size: 21,
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

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }
}

// =================================================================
// SEARCH
// =================================================================

class _SearchSheet
    extends StatefulWidget {
  final List<String> usernames;

  final List<String> captions;

  final List<List<String>> hashtags;

  final void Function(
    int index,
  ) onSelect;

  const _SearchSheet({
    required this.usernames,
    required this.captions,
    required this.hashtags,
    required this.onSelect,
  });

  @override
  State<_SearchSheet>
      createState() =>
          _SearchSheetState();
}

class _SearchSheetState
    extends State<_SearchSheet> {
  final TextEditingController
      _controller =
      TextEditingController();

  List<int> _results = [];

  @override
  void initState() {
    super.initState();

    _results =
        List.generate(
      widget.captions.length,
      (index) => index,
    );

    _controller.addListener(
      _search,
    );
  }

  void _search() {
    final String query =
        _controller.text
            .trim()
            .toLowerCase();

    if (!mounted) return;

    setState(() {
      if (query.isEmpty) {
        _results =
            List.generate(
          widget.captions.length,
          (index) => index,
        );
      } else {
        _results =
            List.generate(
          widget.captions.length,
          (index) => index,
        ).where(
          (index) {
            final caption =
                widget.captions[
                        index]
                    .toLowerCase();

            final username =
                widget.usernames[
                        index]
                    .toLowerCase();

            final tags =
                widget.hashtags[
                        index]
                    .join(' ')
                    .toLowerCase();

            return caption
                    .contains(
                  query,
                ) ||
                username
                    .contains(
                  query,
                ) ||
                tags.contains(
                  query,
                );
          },
        ).toList();
      }
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return SafeArea(
      top: false,
      child: Container(
        height:
            MediaQuery.of(context)
                    .size
                    .height *
                0.72,
        decoration:
            const BoxDecoration(
          color:
              Color(0xFF101010),
          borderRadius:
              BorderRadius.vertical(
            top: Radius.circular(
              24,
            ),
          ),
        ),
        child:
            Column(
          children: [
            const SizedBox(
              height: 10,
            ),

            Container(
              width: 42,
              height: 4,
              decoration:
                  BoxDecoration(
                color:
                    Colors.white24,
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              child:
                  TextField(
                controller:
                    _controller,
                autofocus: true,
                style:
                    const TextStyle(
                  color:
                      Colors.white,
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
                        Colors.white54,
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
              child:
                  _results.isEmpty
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
                              _results.length,
                          itemBuilder:
                              (
                            context,
                            position,
                          ) {
                            final index =
                                _results[
                                    position];

                            return ListTile(
                              onTap: () =>
                                  widget.onSelect(
                                index,
                              ),
                              leading:
                                  Container(
                                width: 46,
                                height: 46,
                                decoration:
                                    const BoxDecoration(
                                  shape:
                                      BoxShape.circle,
                                  gradient:
                                      LinearGradient(
                                    colors: [
                                      Color(
                                        0xFFFF2D75,
                                      ),
                                      Color(
                                        0xFF8B5CF6,
                                      ),
                                    ],
                                  ),
                                ),
                                child:
                                    const Icon(
                                  Icons
                                      .play_arrow,
                                  color:
                                      Colors.white,
                                ),
                              ),
                              title:
                                  Text(
                                widget
                                    .usernames[
                                        index],
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              subtitle:
                                  Text(
                                widget
                                    .captions[
                                        index],
                                maxLines:
                                    1,
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
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }
}
