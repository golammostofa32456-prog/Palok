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
  // PALOK CONSTANTS
  // ============================================================

  static const Color _pink = Color(0xFFFF2D75);
  static const Color _cyan = Color(0xFF25F4EE);
  static const Color _purple = Color(0xFF8B5CF6);

  static const String _cloudName = 'u0jufmrl';
  static const String _uploadPreset = 'palok_video_upload';

  static const int _maxVideoBytes = 100 * 1024 * 1024;
  static const int _maxVideoDurationSeconds = 600;

  // ============================================================
  // SERVICES
  // ============================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final ImagePicker _picker = ImagePicker();

  final PageController _pageController =
      PageController();

  // ============================================================
  // DEMO VIDEOS
  // ============================================================

  final List<VideoItem> _videos = [
    VideoItem.demo(
      url: 'assets/videos/video.mp4',
      username: '@palok_user',
      caption: 'Welcome to PALOK 🎬',
      hashtags: ['PALOK', 'ForYou'],
      likes: 11700,
      comments: 234,
      saves: 811,
      shares: 431,
    ),
    VideoItem.demo(
      url: 'assets/videos/video1.mp4',
      username: '@palok_user',
      caption: 'Enjoy short videos on PALOK ✨',
      hashtags: ['PALOK', 'ShortVideo'],
      likes: 8500,
      comments: 128,
      saves: 452,
      shares: 201,
    ),
    VideoItem.demo(
      url: 'assets/videos/video2.mp4',
      username: '@palok_user',
      caption: 'Create. Share. Connect. 🚀',
      hashtags: ['PALOK', 'Bangladesh'],
      likes: 6200,
      comments: 96,
      saves: 317,
      shares: 145,
    ),
  ];

  // ============================================================
  // VIDEO CONTROLLERS
  // ============================================================

  final Map<String, VideoPlayerController> _controllers = {};

  final Map<String, Future<void>> _controllerJobs = {};

  // ============================================================
  // USER STATE
  // ============================================================

  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  final Set<String> _followingIds = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _videoSubscription;

  // ============================================================
  // LOGO ANIMATION
  // ============================================================

  late AnimationController _logoController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // ============================================================
  // SCREEN STATE
  // ============================================================

  int _bottomIndex = 0;
  int _topIndex = 0;
  int _currentIndex = 0;

  bool _loadingFeed = true;

  bool _isUploading = false;

  double _uploadProgress = 0;

  String _uploadStatus = '';

  User? get _user =>
      FirebaseAuth.instance.currentUser;

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

    _loadFollowing();
    _listenToVideos();

    unawaited(
      _prepareCurrentVideo(),
    );
  }

  // ============================================================
  // FOLLOWING
  // ============================================================

  Future<void> _loadFollowing() async {
    final user = _user;

    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();

      if (!mounted) return;

      setState(() {
        _followingIds.addAll(
          snapshot.docs.map(
            (doc) => doc.id,
          ),
        );
      });
    } catch (e) {
      debugPrint(
        'Following load error: $e',
      );
    }
  }

  // ============================================================
  // FIRESTORE VIDEO FEED
  // ============================================================

  void _listenToVideos() {
    _videoSubscription = _firestore
        .collection('videos')
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots()
        .listen(
      (snapshot) {
        final remoteVideos = snapshot.docs
            .map(
              VideoItem.fromFirestore,
            )
            .where(
              (video) => video.url.isNotEmpty,
            )
            .toList();

        final oldRemoteVideos = _videos
            .where(
              (video) => video.id != null,
            )
            .toList();

        for (final oldVideo in oldRemoteVideos) {
          final stillExists = remoteVideos.any(
            (video) =>
                video.id == oldVideo.id,
          );

          if (!stillExists) {
            final controller =
                _controllers[oldVideo.url];

            controller?.dispose();

            _controllers.remove(
              oldVideo.url,
            );
          }
        }

        if (!mounted) return;

        setState(() {
          _videos.removeWhere(
            (video) => video.id != null,
          );

          _videos.addAll(
            remoteVideos,
          );

          _loadingFeed = false;
        });

        unawaited(
          _prepareCurrentVideo(),
        );
      },
      onError: (error) {
        debugPrint(
          'Feed error: $error',
        );

        if (mounted) {
          setState(() {
            _loadingFeed = false;
          });
        }
      },
    );
  }

  // ============================================================
  // VISIBLE VIDEOS
  // ============================================================

  List<VideoItem> get _visibleVideos {
    if (_topIndex == 0) {
      return List.unmodifiable(
        _videos,
      );
    }

    return _videos
        .where(
          (video) =>
              video.ownerId != null &&
              _followingIds.contains(
                video.ownerId,
              ),
        )
        .toList();
  }

  VideoItem? get _currentVideo {
    final videos = _visibleVideos;

    if (videos.isEmpty) {
      return null;
    }

    final index = _currentIndex.clamp(
      0,
      videos.length - 1,
    );

    return videos[index];
  }

  // ============================================================
  // VIDEO CONTROLLER
  // ============================================================

  Future<VideoPlayerController> _getController(
    String url,
  ) async {
    final existing =
        _controllers[url];

    if (existing != null) {
      return existing;
    }

    final existingJob =
        _controllerJobs[url];

    if (existingJob != null) {
      await existingJob;

      final loaded =
          _controllers[url];

      if (loaded != null) {
        return loaded;
      }
    }

    final controller = url.startsWith(
      'http',
    )
        ? VideoPlayerController.networkUrl(
            Uri.parse(url),
          )
        : VideoPlayerController.asset(
            url,
          );

    final future = () async {
      try {
        await controller.initialize();

        await controller.setLooping(
          true,
        );

        _controllers[url] =
            controller;

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        await controller.dispose();

        debugPrint(
          'Video initialize error: $e',
        );

        rethrow;
      } finally {
        _controllerJobs.remove(
          url,
        );
      }
    }();

    _controllerJobs[url] = future;

    try {
      await future;
    } catch (_) {}

    return _controllers[url] ??
        controller;
  }

  // ============================================================
  // PREPARE CURRENT VIDEO
  // ============================================================

  Future<void> _prepareCurrentVideo() async {
    final video = _currentVideo;

    if (video == null) return;

    final controller =
        await _getController(
      video.url,
    );

    if (!mounted) return;

    for (final entry
        in _controllers.entries) {
      if (entry.key != video.url &&
          entry.value.value.isPlaying) {
        await entry.value.pause();
      }
    }

    if (controller.value.isInitialized) {
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // PAGE CHANGE
  // ============================================================

  Future<void> _onPageChanged(
    int index,
  ) async {
    _currentIndex = index;

    final videos = _visibleVideos;

    if (videos.isEmpty ||
        index >= videos.length) {
      return;
    }

    for (final controller
        in _controllers.values) {
      if (controller.value.isPlaying) {
        await controller.pause();
      }
    }

    final selected =
        videos[index];

    final controller =
        await _getController(
      selected.url,
    );

    if (controller.value.isInitialized) {
      await controller.seekTo(
        Duration.zero,
      );

      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // PLAY / PAUSE
  // ============================================================

  Future<void> _toggleVideo() async {
    final video =
        _currentVideo;

    if (video == null) return;

    final controller =
        _controllers[video.url] ??
            await _getController(
              video.url,
            );

    if (!controller.value.isInitialized) {
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
  // LOGIN CHECK
  // ============================================================

  Future<User?> _requireLogin() async {
    final user = _user;

    if (user == null) {
      _showMessage(
        'আগে Login করুন।',
      );
    }

    return user;
  }

  // ============================================================
  // LIKE
  // ============================================================

  Future<void> _toggleLike() async {
    final user =
        await _requireLogin();

    final video =
        _currentVideo;

    if (user == null ||
        video == null) {
      return;
    }

    final key =
        video.id ?? video.url;

    final isLiked =
        !_likedIds.contains(
      key,
    );

    setState(() {
      if (isLiked) {
        _likedIds.add(key);
      } else {
        _likedIds.remove(key);
      }
    });

    if (video.id == null) {
      return;
    }

    try {
      final videoRef =
          _firestore
              .collection('videos')
              .doc(video.id);

      await videoRef.update({
        'likeCount':
            FieldValue.increment(
          isLiked ? 1 : -1,
        ),
      });

      final likeRef = videoRef
          .collection('likes')
          .doc(user.uid);

      if (isLiked) {
        await likeRef.set({
          'createdAt':
              FieldValue.serverTimestamp(),
        });
      } else {
        await likeRef.delete();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (isLiked) {
          _likedIds.remove(key);
        } else {
          _likedIds.add(key);
        }
      });

      _showMessage(
        'Like save করা যায়নি।',
      );
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _toggleSave() async {
    final user =
        await _requireLogin();

    final video =
        _currentVideo;

    if (user == null ||
        video == null) {
      return;
    }

    final key =
        video.id ?? video.url;

    final isSaved =
        !_savedIds.contains(
      key,
    );

    setState(() {
      if (isSaved) {
        _savedIds.add(key);
      } else {
        _savedIds.remove(key);
      }
    });

    if (video.id == null) {
      _showMessage(
        isSaved
            ? 'ভিডিওটি Saved হয়েছে'
            : 'ভিডিওটি Unsave হয়েছে',
      );

      return;
    }

    try {
      final videoRef =
          _firestore
              .collection('videos')
              .doc(video.id);

      await videoRef.update({
        'saveCount':
            FieldValue.increment(
          isSaved ? 1 : -1,
        ),
      });

      final savedRef =
          _firestore
              .collection('users')
              .doc(user.uid)
              .collection('saved')
              .doc(video.id);

      if (isSaved) {
        await savedRef.set({
          'videoId': video.id,
          'createdAt':
              FieldValue.serverTimestamp(),
        });
      } else {
        await savedRef.delete();
      }

      _showMessage(
        isSaved
            ? 'ভিডিওটি Saved হয়েছে'
            : 'ভিডিওটি Unsave হয়েছে',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (isSaved) {
          _savedIds.remove(key);
        } else {
          _savedIds.add(key);
        }
      });

      _showMessage(
        'Save করা যায়নি।',
      );
    }
  }

  // ============================================================
  // FOLLOW
  // ============================================================

  Future<void> _toggleFollow() async {
    final user =
        await _requireLogin();

    final video =
        _currentVideo;

    if (user == null ||
        video == null ||
        video.ownerId == null) {
      return;
    }

    if (video.ownerId ==
        user.uid) {
      _showMessage(
        'এটি আপনার নিজের ভিডিও।',
      );

      return;
    }

    final ownerId =
        video.ownerId!;

    final isFollowing =
        !_followingIds.contains(
      ownerId,
    );

    setState(() {
      if (isFollowing) {
        _followingIds.add(
          ownerId,
        );
      } else {
        _followingIds.remove(
          ownerId,
        );
      }
    });

    try {
      final followingRef =
          _firestore
              .collection('users')
              .doc(user.uid)
              .collection('following')
              .doc(ownerId);

      if (isFollowing) {
        await followingRef.set({
          'createdAt':
              FieldValue.serverTimestamp(),
        });
      } else {
        await followingRef.delete();
      }

      _showMessage(
        isFollowing
            ? 'Following করা হয়েছে'
            : 'Unfollow করা হয়েছে',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (isFollowing) {
          _followingIds.remove(
            ownerId,
          );
        } else {
          _followingIds.add(
            ownerId,
          );
        }
      });

      _showMessage(
        'Follow পরিবর্তন করা যায়নি।',
      );
    }
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _shareVideo() async {
    final user =
        await _requireLogin();

    final video =
        _currentVideo;

    if (user == null ||
        video == null) {
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'দেখুন PALOK-এ এই ভিডিওটি 🎬\n${video.url}',
        ),
      );

      if (video.id != null) {
        await _firestore
            .collection('videos')
            .doc(video.id)
            .update({
          'shareCount':
              FieldValue.increment(1),
        });
      }
    } catch (e) {
      debugPrint(
        'Share error: $e',
      );
    }
  }

  // ============================================================
  // COMMENT
  // ============================================================

  Future<void> _addComment(
    VideoItem video,
    String text,
  ) async {
    final user =
        await _requireLogin();

    if (user == null ||
        video.id == null) {
      return;
    }

    final username =
        user.displayName ??
            user.email?.split('@').first ??
            'user';

    final videoRef =
        _firestore
            .collection('videos')
            .doc(video.id);

    await videoRef
        .collection('comments')
        .add({
      'uid': user.uid,
      'username': '@$username',
      'text': text,
      'createdAt':
          FieldValue.serverTimestamp(),
    });

    await videoRef.update({
      'commentCount':
          FieldValue.increment(1),
    });
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _SearchSheet(
          videos:
              List.unmodifiable(
            _videos,
          ),
          onSelect: (video) {
            Navigator.pop(
              context,
            );

            final index =
                _visibleVideos
                    .indexOf(video);

            if (index >= 0) {
              _pageController
                  .animateToPage(
                index,
                duration:
                    const Duration(
                  milliseconds: 350,
                ),
                curve:
                    Curves.easeOut,
              );
            }
          },
        );
      },
    );
  }

  // ============================================================
  // CREATE MENU
  // ============================================================

  void _openCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              24,
            ),
            decoration:
                const BoxDecoration(
              color:
                  Color(0xFF101010),
              borderRadius:
                  BorderRadius.vertical(
                top: Radius.circular(
                  26,
                ),
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
                      10,
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
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                _createOption(
                  icon:
                      Icons.videocam_rounded,
                  title:
                      'Record Video',
                  subtitle:
                      'Record a new video',
                  onTap: () {
                    Navigator.pop(
                      context,
                    );

                    _pickVideo(
                      ImageSource.camera,
                    );
                  },
                ),
                _createOption(
                  icon:
                      Icons.video_library_rounded,
                  title:
                      'Upload Video',
                  subtitle:
                      'Choose a video from your phone',
                  onTap: () {
                    Navigator.pop(
                      context,
                    );

                    _pickVideo(
                      ImageSource.gallery,
                    );
                  },
                ),
                _createOption(
                  icon:
                      Icons.music_note_rounded,
                  title:
                      'Add Sound',
                  subtitle:
                      'Sound library coming next',
                  onTap: () {
                    Navigator.pop(
                      context,
                    );

                    _showMessage(
                      'Sound library শীঘ্রই যোগ করা হবে।',
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
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color:
              Colors.white10,
          borderRadius:
              BorderRadius.circular(
            15,
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
          fontWeight:
              FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.white54,
        ),
      ),
      trailing:
          const Icon(
        Icons.chevron_right,
        color: Colors.white38,
      ),
    );
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void> _pickVideo(
    ImageSource source,
  ) async {
    final user =
        await _requireLogin();

    if (user == null) return;

    try {
      final XFile? picked =
          await _picker.pickVideo(
        source: source,
        maxDuration:
            const Duration(
          seconds:
              _maxVideoDurationSeconds,
        ),
      );

      if (picked == null) {
        return;
      }

      final file =
          File(picked.path);

      final exists =
          await file.exists();

      if (!exists) {
        _showMessage(
          'ভিডিও ফাইল পাওয়া যায়নি।',
        );

        return;
      }

      final size =
          await file.length();

      if (size > _maxVideoBytes) {
        _showMessage(
          'ভিডিও সর্বোচ্চ 100 MB হতে পারবে।',
        );

        return;
      }

      final controller =
          VideoPlayerController.file(
        file,
      );

      await controller.initialize();

      final duration =
          controller.value.duration;

      await controller.dispose();

      if (duration.inSeconds >
          _maxVideoDurationSeconds) {
        _showMessage(
          'ভিডিও সর্বোচ্চ 10 মিনিট হতে পারবে।',
        );

        return;
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _VideoComposer(
            file: file,
            onPost: (
              caption,
              hashtags,
            ) async {
              await _uploadVideo(
                file: file,
                caption: caption,
                hashtags: hashtags,
              );
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'Video picker error: $e',
      );

      _showMessage(
        'ভিডিও নির্বাচন করা যায়নি।',
      );
    }
  }

  // ============================================================
  // CLOUDINARY UPLOAD
  // ============================================================

  Future<void> _uploadVideo({
    required File file,
    required String caption,
    required List<String> hashtags,
  }) async {
    if (_isUploading) {
      return;
    }

    final user =
        await _requireLogin();

    if (user == null) {
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadStatus =
          'Preparing video...';
    });

    try {
      final fileSize =
          await file.length();

      if (fileSize >
          _maxVideoBytes) {
        throw Exception(
          'Video is larger than 100 MB.',
        );
      }

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '$_cloudName/video/upload',
      );

      final boundary =
          '----PALOK${DateTime.now().millisecondsSinceEpoch}';

      final prefix = utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; '
        'name="upload_preset"\r\n\r\n'
        '$_uploadPreset\r\n'
        '--$boundary\r\n'
        'Content-Disposition: form-data; '
        'name="file"; filename="palok_video.mp4"\r\n'
        'Content-Type: video/mp4\r\n\r\n',
      );

      final suffix = utf8.encode(
        '\r\n--$boundary--\r\n',
      );

      final totalBytes =
          prefix.length +
              fileSize +
              suffix.length;

      final request =
          http.StreamedRequest(
        'POST',
        uri,
      );

      request.headers[
              'Content-Type'] =
          'multipart/form-data; '
          'boundary=$boundary';

      request.contentLength =
          totalBytes;

      final responseFuture =
          request.send();

      request.sink.add(
        prefix,
      );

      final randomAccessFile =
          await file.open();

      int sent =
          prefix.length;

      const chunkSize =
          64 * 1024;

      try {
        while (true) {
          final chunk =
              await randomAccessFile
                  .read(
            chunkSize,
          );

          if (chunk.isEmpty) {
            break;
          }

          request.sink.add(
            chunk,
          );

          sent +=
              chunk.length;

          _setUploadProgress(
            sent /
                totalBytes,
            'Uploading video...',
          );
        }
      } finally {
        await randomAccessFile.close();
      }

      request.sink.add(
        suffix,
      );

      sent += suffix.length;

      _setUploadProgress(
        0.98,
        'Finishing upload...',
      );

      await request.sink.close();

      final response =
          await responseFuture;

      final responseBody =
          await response.stream
              .bytesToString();

      if (response.statusCode <
              200 ||
          response.statusCode >=
              300) {
        throw Exception(
          'Cloudinary upload failed: '
          '${response.statusCode} '
          '$responseBody',
        );
      }

      final json =
          jsonDecode(
        responseBody,
      ) as Map<String, dynamic>;

      final secureUrl =
          json['secure_url']
              ?.toString();

      final publicId =
          json['public_id']
              ?.toString();

      final assetId =
          json['asset_id']
              ?.toString();

      if (secureUrl == null ||
          secureUrl.isEmpty) {
        throw Exception(
          'Cloudinary did not return a video URL.',
        );
      }

      _setUploadProgress(
        0.99,
        'Saving PALOK post...',
      );

      await _firestore
          .collection('videos')
          .add({
        'ownerId': user.uid,
        'username':
            _usernameForUser(user),
        'caption': caption,
        'hashtags': hashtags,
        'videoUrl': secureUrl,
        'cloudinaryPublicId':
            publicId,
        'cloudinaryAssetId':
            assetId,
        'likeCount': 0,
        'commentCount': 0,
        'saveCount': 0,
        'shareCount': 0,
        'createdAt':
            FieldValue.serverTimestamp(),
        'visibility': 'public',
      });

      _setUploadProgress(
        1.0,
        'Posted successfully!',
      );

      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      if (mounted) {
        _showMessage(
          'ভিডিও PALOK-এ পোস্ট হয়েছে 🎉',
        );
      }
    } catch (e) {
      debugPrint(
        'Upload error: $e',
      );

      if (mounted) {
        _showMessage(
          'ভিডিও upload হয়নি। আবার চেষ্টা করুন।',
        );
      }

      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
          _uploadStatus = '';
        });
      }
    }
  }

  String _usernameForUser(
    User user,
  ) {
    final name =
        user.displayName;

    if (name != null &&
        name.trim().isNotEmpty) {
      return '@${name.trim()}';
    }

    final email =
        user.email;

    if (email != null &&
        email.contains('@')) {
      return '@${email.split('@').first}';
    }

    return '@palok_user';
  }

  void _setUploadProgress(
    double progress,
    String status,
  ) {
    if (!mounted) return;

    setState(() {
      _uploadProgress =
          progress.clamp(
        0.0,
        1.0,
      );

      _uploadStatus =
          status;
    });
  }

  // ============================================================
  // BOTTOM NAV
  // ============================================================

  void _selectBottom(
    int index,
  ) {
    if (index == 2) {
      _openCreateMenu();
      return;
    }

    setState(() {
      _bottomIndex =
          index;
    });

    if (index == 0) {
      return;
    }

    if (index == 1) {
      _showMessage(
        'Friends section coming soon.',
      );

      return;
    }

    if (index == 3) {
      _showMessage(
        'Inbox section coming soon.',
      );

      return;
    }

    if (index == 4) {
      _showMessage(
        'Profile section coming soon.',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        backgroundColor:
            const Color(0xFF202020),
        behavior:
            SnackBarBehavior.floating,
        margin:
            const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          82,
        ),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
        content: Text(
          message,
          style:
              const TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UI
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
          _buildVideoFeed(),
          _buildTopHeader(),
          _buildUploadProgress(),
          _buildBottomNavigationArea(),
        ],
      ),
    );
  }

  // ============================================================
  // VIDEO FEED
  // ============================================================

  Widget _buildVideoFeed() {
    final videos =
        _visibleVideos;

    if (_loadingFeed &&
        videos.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child:
              CircularProgressIndicator(
            color: _pink,
          ),
        ),
      );
    }

    if (videos.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Following feed is empty',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return PageView.builder(
      controller:
          _pageController,
      scrollDirection:
          Axis.vertical,
      itemCount:
          videos.length,
      onPageChanged:
          _onPageChanged,
      itemBuilder:
          (context, index) {
        return _buildVideoPage(
          videos[index],
          index,
        );
      },
    );
  }

  Widget _buildVideoPage(
    VideoItem video,
    int index,
  ) {
    final controller =
        _controllers[video.url];

    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap:
          _toggleVideo,
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
                color: _pink,
              ),
            ),

          // Dark gradient
          IgnorePointer(
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
                    Colors.black
                        .withOpacity(
                      .18,
                    ),
                    Colors.transparent,
                    Colors.black
                        .withOpacity(
                      .72,
                    ),
                  ],
                  stops: const [
                    0,
                    .48,
                    1,
                  ],
                ),
              ),
            ),
          ),

          // Play icon when paused
          if (controller != null &&
              controller
                  .value
                  .isInitialized &&
              !controller
                  .value
                  .isPlaying)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color:
                    Colors.white70,
                size: 72,
              ),
            ),

          _buildVideoInfo(
            video,
          ),

          _buildRightActions(
            video,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VIDEO INFO
  // ============================================================

  Widget _buildVideoInfo(
    VideoItem video,
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
              Container(
                width: 40,
                height: 40,
                decoration:
                    const BoxDecoration(
                  shape:
                      BoxShape.circle,
                  gradient:
                      LinearGradient(
                    colors: [
                      _pink,
                      _purple,
                    ],
                  ),
                ),
                child:
                    const Icon(
                  Icons.person,
                  color:
                      Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Text(
                video.username,
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize: 16,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 9,
          ),
          Text(
            video.caption,
            maxLines: 3,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          if (video.hashtags.isNotEmpty) ...[
            const SizedBox(
              height: 5,
            ),
            Text(
              video.hashtags
                  .map(
                    (tag) =>
                        '#$tag',
                  )
                  .join(' '),
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // RIGHT ACTIONS
  // LOCKED POSITION
  // ============================================================

  Widget _buildRightActions(
    VideoItem video,
  ) {
    final key =
        video.id ?? video.url;

    final liked =
        _likedIds.contains(
      key,
    );

    final saved =
        _savedIds.contains(
      key,
    );

    final following =
        video.ownerId != null &&
            _followingIds.contains(
              video.ownerId,
            );

    return Positioned(
      right: 10,
      bottom: 116,
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          _actionButton(
            icon: following
                ? Icons.person
                : Icons.person_add_alt_1,
            color: following
                ? _pink
                : Colors.white,
            label: following
                ? 'Following'
                : 'Follow',
            onTap:
                _toggleFollow,
          ),
          const SizedBox(
            height: 10,
          ),
          _actionButton(
            icon:
                liked
                    ? Icons.favorite
                    : Icons.favorite_border,
            color:
                liked
                    ? _pink
                    : Colors.white,
            label:
                _format(video.likes),
            onTap:
                _toggleLike,
          ),
          const SizedBox(
            height: 10,
          ),
          _actionButton(
            icon:
                Icons.comment_outlined,
            color:
                Colors.white,
            label:
                _format(video.comments),
            onTap:
                () => _openComments(
              video,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          _actionButton(
            icon:
                saved
                    ? Icons.bookmark
                    : Icons.bookmark_border,
            color:
                saved
                    ? _pink
                    : Colors.white,
            label:
                _format(video.saves),
            onTap:
                _toggleSave,
          ),
          const SizedBox(
            height: 10,
          ),
          _actionButton(
            icon:
                Icons.share_outlined,
            color:
                Colors.white,
            label:
                _format(video.shares),
            onTap:
                _shareVideo,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
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
              color: Colors.black
                  .withOpacity(.38),
              shape:
                  BoxShape.circle,
              border:
                  Border.all(
                color: Colors.white
                    .withOpacity(.12),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 23,
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          Text(
            label,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight:
                  FontWeight.w600,
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
    return Positioned(
      left: 14,
      right: 12,
      top: 42,
      child: Row(
        children: [
          AnimatedBuilder(
            animation:
                _logoController,
            builder:
                (context, child) {
              return Transform.scale(
                scale:
                    _logoScale.value,
                child:
                    Opacity(
                  opacity:
                      _logoOpacity.value,
                  child:
                      child,
                ),
              );
            },
            child:
                _buildLogo(),
          ),
          const Spacer(),
          _topTab(
            'For You',
            0,
          ),
          const SizedBox(
            width: 18,
          ),
          _topTab(
            'Following',
            1,
          ),
          const SizedBox(
            width: 13,
          ),
          GestureDetector(
            onTap:
                _openSearch,
            child:
                Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(
                color:
                    Colors.black.withOpacity(.28),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons.search,
                color:
                    Colors.white,
                size: 25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
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
          colors: [
            _pink,
            _purple,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _pink
                .withOpacity(.45),
            blurRadius: 16,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'P',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _topTab(
    String text,
    int index,
  ) {
    final selected =
        _topIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _topIndex = index;
          _currentIndex = 0;
        });

        _pageController
            .jumpToPage(0);

        unawaited(
          _prepareCurrentVideo(),
        );
      },
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Text(
            text,
            style:
                TextStyle(
              color:
                  selected
                      ? Colors.white
                      : Colors.white54,
              fontSize: 14,
              fontWeight:
                  selected
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
                selected
                    ? 28
                    : 0,
            height: 2,
            decoration:
                BoxDecoration(
              color:
                  Colors.white,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // LOCKED POSITION
  // ============================================================

  Widget _buildBottomNavigationArea() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child:
            _buildBottomNavigation(),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 68,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      decoration:
          BoxDecoration(
        color: Colors.black
            .withOpacity(.72),
        border: Border(
          top: BorderSide(
            color: Colors.white
                .withOpacity(.06),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceAround,
        children: [
          _bottomButton(
            icon:
                Icons.home_rounded,
            label: 'Home',
            index: 0,
          ),
          _bottomButton(
            icon:
                Icons.people_alt_outlined,
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
                    _cyan,
                    _pink,
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
    final selected =
        _bottomIndex == index;

    return GestureDetector(
      onTap: () =>
          _selectBottom(index),
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
                  : Colors.white54,
              size: 23,
            ),
            const SizedBox(
              height: 3,
            ),
            Text(
              label,
              style:
                  TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white54,
                fontSize: 10,
                fontWeight:
                    selected
                        ? FontWeight.bold
                        : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // UPLOAD PROGRESS
  // ============================================================

  Widget _buildUploadProgress() {
    if (!_isUploading) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 18,
      right: 18,
      bottom: 88,
      child: Container(
        padding:
            const EdgeInsets.all(
          14,
        ),
        decoration:
            BoxDecoration(
          color: Colors.black
              .withOpacity(.88),
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border:
              Border.all(
            color: Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  color: _pink,
                  size: 21,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    _uploadStatus,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${(_uploadProgress * 100).round()}%',
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
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
                valueColor:
                    const AlwaysStoppedAnimation<
                        Color>(
                  _pink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  void _openComments(
    VideoItem video,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true,
      backgroundColor:
          Colors.transparent,
      builder: (_) =>
          _CommentsSheet(
        video: video,
        onComment:
            _addComment,
      ),
    );
  }

  // ============================================================
  // NUMBER FORMAT
  // ============================================================

  String _format(
    int value,
  ) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }

    return value.toString();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _videoSubscription
        ?.cancel();

    _pageController
        .dispose();

    _logoController
        .dispose();

    for (final controller
        in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }
}

// ============================================================================
// VIDEO ITEM
// ============================================================================

class VideoItem {
  final String? id;
  final String url;
  final String username;
  final String caption;
  final List<String> hashtags;
  final int likes;
  final int comments;
  final int saves;
  final int shares;
  final String? ownerId;

  const VideoItem({
    this.id,
    required this.url,
    required this.username,
    required this.caption,
    required this.hashtags,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
    this.ownerId,
  });

  factory VideoItem.demo({
    required String url,
    required String username,
    required String caption,
    required List<String> hashtags,
    required int likes,
    required int comments,
    required int saves,
    required int shares,
  }) {
    return VideoItem(
      url: url,
      username: username,
      caption: caption,
      hashtags: hashtags,
      likes: likes,
      comments: comments,
      saves: saves,
      shares: shares,
    );
  }

  factory VideoItem.fromFirestore(
    QueryDocumentSnapshot<
        Map<String, dynamic>>
        doc,
  ) {
    final data =
        doc.data();

    return VideoItem(
      id: doc.id,
      url: data['videoUrl']
              ?.toString() ??
          '',
      username:
          data['username']
                  ?.toString() ??
              '@palok_user',
      caption:
          data['caption']
                  ?.toString() ??
              '',
      hashtags:
          (data['hashtags']
                      as List?)
                  ?.map(
                    (e) =>
                        e.toString(),
                  )
                  .toList() ??
              const [],
      likes:
          _intValue(
        data['likeCount'],
      ),
      comments:
          _intValue(
        data['commentCount'],
      ),
      saves:
          _intValue(
        data['saveCount'],
      ),
      shares:
          _intValue(
        data['shareCount'],
      ),
      ownerId:
          data['ownerId']
              ?.toString(),
    );
  }

  static int _intValue(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ??
              '',
        ) ??
        0;
  }
}

// ============================================================================
// VIDEO COMPOSER
// ============================================================================

class _VideoComposer
    extends StatefulWidget {
  final File file;

  final Future<void> Function(
    String caption,
    List<String> hashtags,
  ) onPost;

  const _VideoComposer({
    required this.file,
    required this.onPost,
  });

  @override
  State<_VideoComposer> createState() =>
      _VideoComposerState();
}

class _VideoComposerState
    extends State<_VideoComposer> {
  static const Color _pink =
      Color(0xFFFF2D75);

  late VideoPlayerController
      _controller;

  final TextEditingController
      _caption =
      TextEditingController();

  final TextEditingController
      _hashtags =
      TextEditingController();

  bool _ready = false;

  bool _posting = false;

  @override
  void initState() {
    super.initState();

    _controller =
        VideoPlayerController.file(
      widget.file,
    );

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller
          .initialize();

      await _controller
          .setLooping(true);

      await _controller.play();

      if (!mounted) return;

      setState(() {
        _ready = true;
      });
    } catch (e) {
      debugPrint(
        'Composer video error: $e',
      );
    }
  }

  Future<void> _post() async {
    if (!_ready ||
        _posting) {
      return;
    }

    final caption =
        _caption.text.trim();

    final hashtags =
        _hashtags.text
            .trim()
            .split(
              RegExp(
                r'[\s,#]+',
              ),
            )
            .where(
              (item) =>
                  item.isNotEmpty,
            )
            .map(
              (item) => item
                  .replaceFirst(
                '#',
                '',
              ),
            )
            .toList();

    setState(() {
      _posting = true;
    });

    try {
      await widget.onPost(
        caption.isEmpty
            ? 'New video on PALOK 🎬'
            : caption,
        hashtags,
      );

      if (!mounted) return;

      Navigator.pop(
        context,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _posting = false;
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

    return Scaffold(
      backgroundColor:
          Colors.black,
      resizeToAvoidBottomInset:
          true,
      body: SafeArea(
        child: AnimatedPadding(
          duration:
              const Duration(
            milliseconds: 180,
          ),
          padding:
              EdgeInsets.only(
            bottom: keyboard,
          ),
          child: Column(
            children: [
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
                    IconButton(
                      onPressed:
                          _posting
                              ? null
                              : () =>
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
                    const Expanded(
                      child: Text(
                        'Post Video',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 48,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    14,
                  ),
                  children: [
                    if (_ready)
                      AspectRatio(
                        aspectRatio:
                            _controller
                                .value
                                .aspectRatio,
                        child:
                            GestureDetector(
                          onTap: () {
                            if (_controller
                                .value
                                .isPlaying) {
                              _controller
                                  .pause();
                            } else {
                              _controller
                                  .play();
                            }

                            setState(
                              () {},
                            );
                          },
                          child:
                              ClipRRect(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              18,
                            ),
                            child:
                                VideoPlayer(
                              _controller,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 320,
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white10,
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                        ),
                        child:
                            const Center(
                          child:
                              CircularProgressIndicator(
                            color:
                                _pink,
                          ),
                        ),
                      ),

                    const SizedBox(
                      height: 16,
                    ),

                    TextField(
                      controller:
                          _caption,
                      maxLines: 4,
                      enabled:
                          !_posting,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
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
                        filled:
                            true,
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

                    const SizedBox(
                      height: 10,
                    ),

                    TextField(
                      controller:
                          _hashtags,
                      enabled:
                          !_posting,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
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
                        filled:
                            true,
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

                    const SizedBox(
                      height: 12,
                    ),

                    Container(
                      padding:
                          const EdgeInsets.all(
                        14,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.white10,
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.public,
                            color:
                                Colors.white70,
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Text(
                              'Everyone can view this video',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white70,
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

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  12,
                ),
                child:
                    SizedBox(
                  width:
                      double.infinity,
                  height: 54,
                  child:
                      ElevatedButton(
                    onPressed:
                        _ready &&
                                !_posting
                            ? _post
                            : null,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          _pink,
                      disabledBackgroundColor:
                          Colors.white12,
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
                    child: _posting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2.5,
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
    _caption.dispose();
    _hashtags.dispose();
    super.dispose();
  }
}

// ============================================================================
// COMMENTS SHEET
// ============================================================================

class _CommentsSheet
    extends StatefulWidget {
  final VideoItem video;

  final Future<void> Function(
    VideoItem video,
    String text,
  ) onComment;

  const _CommentsSheet({
    required this.video,
    required this.onComment,
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

  Future<void> _send() async {
    final text =
        _controller.text.trim();

    if (text.isEmpty ||
        _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.onComment(
        widget.video,
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

    return AnimatedPadding(
      duration:
          const Duration(
        milliseconds: 180,
      ),
      padding:
          EdgeInsets.only(
        bottom: keyboard,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height:
              MediaQuery.of(context)
                      .size
                      .height *
                  .62,
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
                  18,
                  14,
                  10,
                  10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${widget.video.comments} Comments',
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
                      onPressed: () =>
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
                    widget.video.id ==
                            null
                        ? const Center(
                            child: Text(
                              'Demo video comments are disabled',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white38,
                              ),
                            ),
                          )
                        : StreamBuilder<
                            QuerySnapshot<
                                Map<String,
                                    dynamic>>>(
                            stream:
                                FirebaseFirestore
                                    .instance
                                    .collection(
                                      'videos',
                                    )
                                    .doc(
                                      widget
                                          .video
                                          .id,
                                    )
                                    .collection(
                                      'comments',
                                    )
                                    .orderBy(
                                      'createdAt',
                                      descending:
                                          false,
                                    )
                                    .snapshots(),
                            builder:
                                (
                              context,
                              snapshot,
                            ) {
                              if (snapshot
                                  .hasError) {
                                return const Center(
                                  child:
                                      Text(
                                    'Comments unavailable',
                                    style:
                                        TextStyle(
                                      color:
                                          Colors.white54,
                                    ),
                                  ),
                                );
                              }

                              if (!snapshot
                                  .hasData) {
                                return const Center(
                                  child:
                                      CircularProgressIndicator(
                                    color:
                                        Color(0xFFFF2D75),
                                  ),
                                );
                              }

                              final docs =
                                  snapshot
                                      .data!
                                      .docs;

                              if (docs
                                  .isEmpty) {
                                return const Center(
                                  child:
                                      Text(
                                    'Be the first to comment',
                                    style:
                                        TextStyle(
                                      color:
                                          Colors.white54,
                                    ),
                                  ),
                                );
                              }

                              return ListView
                                  .builder(
                                padding:
                                    const EdgeInsets.all(
                                  16,
                                ),
                                itemCount:
                                    docs.length,
                                itemBuilder:
                                    (
                                  context,
                                  index,
                                ) {
                                  final data =
                                      docs[index]
                                          .data();

                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(
                                      bottom:
                                          18,
                                    ),
                                    child:
                                        Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        const CircleAvatar(
                                          radius:
                                              18,
                                          backgroundColor:
                                              Color(
                                            0xFF333333,
                                          ),
                                          child:
                                              Icon(
                                            Icons.person,
                                            color:
                                                Colors.white54,
                                            size:
                                                19,
                                          ),
                                        ),
                                        const SizedBox(
                                          width:
                                              10,
                                        ),
                                        Expanded(
                                          child:
                                              Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                data['username']
                                                        ?.toString() ??
                                                    '@user',
                                                style:
                                                    const TextStyle(
                                                  color:
                                                      Colors.white,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(
                                                height:
                                                    3,
                                              ),
                                              Text(
                                                data['text']
                                                        ?.toString() ??
                                                    '',
                                                style:
                                                    const TextStyle(
                                                  color:
                                                      Colors.white70,
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
                      child: TextField(
                        controller:
                            _controller,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                        ),
                        textInputAction:
                            TextInputAction.send,
                        onSubmitted:
                            (_) => _send(),
                        decoration:
                            InputDecoration(
                          hintText:
                              'Add comment...',
                          hintStyle:
                              const TextStyle(
                            color:
                                Colors.white38,
                          ),
                          filled:
                              true,
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
                              const EdgeInsets.symmetric(
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
                      onTap:
                          _send,
                      child:
                          Container(
                        width: 46,
                        height: 46,
                        decoration:
                            const BoxDecoration(
                          shape:
                              BoxShape.circle,
                          color:
                              Color(0xFFFF2D75),
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
                                size:
                                    21,
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

// ============================================================================
// SEARCH SHEET
// ============================================================================

class _SearchSheet
    extends StatefulWidget {
  final List<VideoItem> videos;

  final void Function(
    VideoItem video,
  ) onSelect;

  const _SearchSheet({
    required this.videos,
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

  List<VideoItem> _results =
      [];

  @override
  void initState() {
    super.initState();

    _results =
        List.from(
      widget.videos,
    );

    _controller.addListener(
      _search,
    );
  }

  void _search() {
    final query =
        _controller.text
            .trim()
            .toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _results =
            List.from(
          widget.videos,
        );
      } else {
        _results =
            widget.videos
                .where(
                  (video) {
                    final text =
                        '${video.username} '
                        '${video.caption} '
                        '${video.hashtags.join(' ')}'
                            .toLowerCase();

                    return text
                        .contains(
                      query,
                    );
                  },
                )
                .toList();
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
                .72,
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
                  const EdgeInsets.all(
                16,
              ),
              child: TextField(
                controller:
                    _controller,
                autofocus:
                    true,
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
                  filled:
                      true,
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
                          child:
                              Text(
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
                            index,
                          ) {
                            final video =
                                _results[index];

                            return ListTile(
                              onTap: () =>
                                  widget
                                      .onSelect(
                                video,
                              ),
                              leading:
                                  Container(
                                width:
                                    46,
                                height:
                                    46,
                                decoration:
                                    const BoxDecoration(
                                  shape:
                                      BoxShape.circle,
                                  gradient:
                                      LinearGradient(
                                    colors: [
                                      Color(0xFFFF2D75),
                                      Color(0xFF8B5CF6),
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
                                video.username,
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
                                video.caption,
                                maxLines:
                                    1,
                                overflow:
                                    TextOverflow.ellipsis,
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
