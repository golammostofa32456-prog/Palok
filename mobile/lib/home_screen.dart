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
  static const _pink = Color(0xFFFF2D75);
  static const _cyan = Color(0xFF25F4EE);

  static const _cloudName = 'u0jufmrl';
  static const _uploadPreset = 'palok_video_upload';
  static const _maxVideoBytes = 100 * 1024 * 1024;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();

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

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, Future<void>> _controllerJobs = {};

  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  final Set<String> _followingIds = {};

  final Map<String, int> _demoLikeDeltas = {};
  final Map<String, int> _demoSaveDeltas = {};
  final Map<String, int> _demoShareDeltas = {};
  final Map<String, int> _demoCommentCounts = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _videoSub;

  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  int _bottomIndex = 0;
  int _topIndex = 0;
  int _currentIndex = 0;

  bool _isUploading = false;
  double _uploadProgress = 0;
  String _uploadStatus = '';

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(
      begin: .96,
      end: 1.04,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeInOut,
      ),
    );

    _logoOpacity = Tween<double>(
      begin: .82,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeInOut,
      ),
    );

    _loadFollowing();
    _loadUserInteractions();
    _listenToVideos();

    unawaited(_prepareCurrentVideo());
  }

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
          snapshot.docs.map((doc) => doc.id),
        );
      });
    } catch (e) {
      debugPrint('Following load error: $e');
    }
  }

  String _interactionKey(VideoItem video) {
    final raw = video.id ?? video.url;

    return raw.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
  }

  CollectionReference<Map<String, dynamic>>
      _interactionCollection(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('videoInteractions');
  }

  Future<void> _loadUserInteractions() async {
    final user = _user;

    if (user == null) return;

    try {
      final snapshot = await _interactionCollection(
        user.uid,
      ).get();

      if (!mounted) return;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final key = doc.id;

        if (data['liked'] == true) {
          _likedIds.add(key);
        }

        if (data['saved'] == true) {
          _savedIds.add(key);
        }

        final likeDelta =
            (data['likeDelta'] as num?)?.toInt() ?? 0;

        final saveDelta =
            (data['saveDelta'] as num?)?.toInt() ?? 0;

        final shareDelta =
            (data['shareDelta'] as num?)?.toInt() ?? 0;

        final commentCount =
            (data['demoCommentCount'] as num?)?.toInt() ?? 0;

        if (likeDelta != 0) {
          _demoLikeDeltas[key] = likeDelta;
        }

        if (saveDelta != 0) {
          _demoSaveDeltas[key] = saveDelta;
        }

        if (shareDelta != 0) {
          _demoShareDeltas[key] = shareDelta;
        }

        if (commentCount != 0) {
          _demoCommentCounts[key] = commentCount;
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint('Interaction load error: $e');
    }
  }

  Future<void> _saveInteraction(
    VideoItem video, {
    bool? liked,
    bool? saved,
    int? likeDelta,
    int? saveDelta,
    int? shareDelta,
    int? commentCount,
  }) async {
    final user = _user;

    if (user == null) return;

    final key = _interactionKey(video);

    final ref = _interactionCollection(
      user.uid,
    ).doc(key);

    final data = <String, dynamic>{
      'videoKey': key,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (liked != null) {
      data['liked'] = liked;
    }

    if (saved != null) {
      data['saved'] = saved;
    }

    if (likeDelta != null) {
      data['likeDelta'] = likeDelta;
    }

    if (saveDelta != null) {
      data['saveDelta'] = saveDelta;
    }

    if (shareDelta != null) {
      data['shareDelta'] = shareDelta;
    }

    if (commentCount != null) {
      data['demoCommentCount'] = commentCount;
    }

    await ref.set(
      data,
      SetOptions(merge: true),
    );
  }

  void _listenToVideos() {
    _videoSub = _firestore
        .collection('videos')
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots()
        .listen(
      (snapshot) {
        final remote = snapshot.docs
            .map(VideoItem.fromFirestore)
            .where((video) => video.url.isNotEmpty)
            .toList();

        final oldRemote =
            _videos.where((video) => video.id != null).toList();

        for (final old in oldRemote) {
          if (!remote.any((video) => video.id == old.id)) {
            _controllers[old.url]?.dispose();
            _controllers.remove(old.url);
          }
        }

        if (!mounted) return;

        setState(() {
          _videos.removeWhere(
            (video) => video.id != null,
          );

          _videos.addAll(remote);
        });

        if (_videos.isNotEmpty) {
          unawaited(_prepareCurrentVideo());
        }
      },
      onError: (error) {
        debugPrint('Feed error: $error');
      },
    );
  }

  List<VideoItem> get _visibleVideos {
    if (_topIndex == 0) {
      return List.unmodifiable(_videos);
    }

    return _videos
        .where(
          (video) =>
              video.ownerId != null &&
              _followingIds.contains(video.ownerId),
        )
        .toList();
  }

  VideoItem? get _currentVideo {
    final list = _visibleVideos;

    if (list.isEmpty) return null;

    final index =
        _currentIndex.clamp(0, list.length - 1);

    return list[index];
  }

  Future<void> _prepareCurrentVideo() async {
    final video = _currentVideo;

    if (video == null) return;

    final controller = await _getController(
      video.url,
    );

    if (!mounted) return;

    for (final entry in _controllers.entries) {
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

  Future<VideoPlayerController> _getController(
    String url,
  ) async {
    final existing = _controllers[url];

    if (existing != null) {
      return existing;
    }

    final existingJob = _controllerJobs[url];

    if (existingJob != null) {
      await existingJob;

      return _controllers[url]!;
    }

    final controller = url.startsWith('http')
        ? VideoPlayerController.networkUrl(
            Uri.parse(url),
          )
        : VideoPlayerController.asset(url);

    final future = () async {
      try {
        await controller.initialize();

        await controller.setLooping(true);

        _controllers[url] = controller;

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        await controller.dispose();

        rethrow;
      } finally {
        _controllerJobs.remove(url);
      }
    }();

    _controllerJobs[url] = future;

    try {
      await future;
    } catch (e) {
      debugPrint(
        'Video initialization error: $e',
      );
    }

    return _controllers[url] ?? controller;
  }

  Future<void> _onPageChanged(int index) async {
    _currentIndex = index;

    final list = _visibleVideos;

    if (list.isEmpty || index >= list.length) {
      return;
    }

    final selected = list[index];

    for (final controller in _controllers.values) {
      if (controller.value.isPlaying) {
        await controller.pause();
      }
    }

    final controller = await _getController(
      selected.url,
    );

    if (controller.value.isInitialized) {
      await controller.seekTo(Duration.zero);
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleVideo() async {
    final video = _currentVideo;

    if (video == null) return;

    final controller =
        _controllers[video.url] ??
            await _getController(video.url);

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

  Future<User?> _requireLogin() async {
    final user = _user;

    if (user == null) {
      _showMessage(
        'আগে Login করুন।',
      );
    }

    return user;
  }

  Future<void> _toggleLike() async {
    final user = await _requireLogin();

    final video = _currentVideo;

    if (user == null || video == null) {
      return;
    }

    final key = _interactionKey(video);

    final liked = !_likedIds.contains(key);

    final previousDelta =
        _demoLikeDeltas[key] ?? 0;

    setState(() {
      if (liked) {
        _likedIds.add(key);
      } else {
        _likedIds.remove(key);
      }

      if (video.id == null) {
        _demoLikeDeltas[key] =
            liked ? 1 : 0;
      }
    });

    try {
      await _saveInteraction(
        video,
        liked: liked,
        likeDelta:
            video.id == null
                ? (liked ? 1 : 0)
                : null,
      );

      if (video.id != null) {
        final videoRef = _firestore
            .collection('videos')
            .doc(video.id);

        final likeRef = videoRef
            .collection('likes')
            .doc(user.uid);

        final batch = _firestore.batch();

        batch.update(
          videoRef,
          {
            'likeCount':
                FieldValue.increment(
              liked ? 1 : -1,
            ),
          },
        );

        if (liked) {
          batch.set(
            likeRef,
            {
              'createdAt':
                  FieldValue.serverTimestamp(),
            },
          );
        } else {
          batch.delete(likeRef);
        }

        await batch.commit();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (liked) {
          _likedIds.remove(key);
        } else {
          _likedIds.add(key);
        }

        if (video.id == null) {
          if (previousDelta == 0) {
            _demoLikeDeltas.remove(key);
          } else {
            _demoLikeDeltas[key] =
                previousDelta;
          }
        }
      });

      _showMessage(
        'Like সংরক্ষণ করা যায়নি।',
      );
    }
  }

  Future<void> _toggleSave() async {
    final user = await _requireLogin();

    final video = _currentVideo;

    if (user == null || video == null) {
      return;
    }

    final key = _interactionKey(video);

    final saved = !_savedIds.contains(key);

    final previousDelta =
        _demoSaveDeltas[key] ?? 0;

    setState(() {
      if (saved) {
        _savedIds.add(key);
      } else {
        _savedIds.remove(key);
      }

      if (video.id == null) {
        _demoSaveDeltas[key] =
            saved ? 1 : 0;
      }
    });

    try {
      await _saveInteraction(
        video,
        saved: saved,
        saveDelta:
            video.id == null
                ? (saved ? 1 : 0)
                : null,
      );

      if (video.id != null) {
        final videoRef = _firestore
            .collection('videos')
            .doc(video.id);

        final savedRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('saved')
            .doc(video.id);

        final batch = _firestore.batch();

        batch.update(
          videoRef,
          {
            'saveCount':
                FieldValue.increment(
              saved ? 1 : -1,
            ),
          },
        );

        if (saved) {
          batch.set(
            savedRef,
            {
              'videoId': video.id,
              'createdAt':
                  FieldValue.serverTimestamp(),
            },
          );
        } else {
          batch.delete(savedRef);
        }

        await batch.commit();
      }

      _showMessage(
        saved
            ? 'ভিডিওটি Saved হয়েছে'
            : 'ভিডিওটি Unsave হয়েছে',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          if (saved) {
            _savedIds.remove(key);
          } else {
            _savedIds.add(key);
          }

          if (video.id == null) {
            if (previousDelta == 0) {
              _demoSaveDeltas.remove(key);
            } else {
              _demoSaveDeltas[key] =
                  previousDelta;
            }
          }
        });
      }

      _showMessage(
        'Save করা যায়নি।',
      );
    }
  }

  Future<void> _toggleFollow() async {
    final user = await _requireLogin();

    final video = _currentVideo;

    if (user == null ||
        video == null ||
        video.ownerId == null) {
      return;
    }

    if (video.ownerId == user.uid) {
      _showMessage(
        'এটি আপনার নিজের ভিডিও।',
      );
      return;
    }

    final owner = video.ownerId!;

    final following =
        !_followingIds.contains(owner);

    setState(() {
      if (following) {
        _followingIds.add(owner);
      } else {
        _followingIds.remove(owner);
      }
    });

    try {
      final ref = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(owner);

      if (following) {
        await ref.set(
          {
            'username': video.username,
            'createdAt':
                FieldValue.serverTimestamp(),
          },
        );
      } else {
        await ref.delete();
      }

      _showMessage(
        following
            ? 'Following করা হয়েছে'
            : 'Unfollow করা হয়েছে',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          if (following) {
            _followingIds.remove(owner);
          } else {
            _followingIds.add(owner);
          }
        });
      }

      _showMessage(
        'Follow update করা যায়নি।',
      );
    }
  }

  Future<void> _shareVideo() async {
    final user = await _requireLogin();

    final video = _currentVideo;

    if (user == null || video == null) {
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'দেখুন PALOK-এ ${video.username}-এর ভিডিও 🎬\n${video.url}',
          subject: 'PALOK Video',
        ),
      );

      final key = _interactionKey(video);

      if (video.id == null) {
        final next =
            (_demoShareDeltas[key] ?? 0) + 1;

        setState(() {
          _demoShareDeltas[key] = next;
        });

        await _saveInteraction(
          video,
          shareDelta: next,
        );
      } else {
        await _firestore
            .collection('videos')
            .doc(video.id)
            .update(
          {
            'shareCount':
                FieldValue.increment(1),
          },
        );

        await _saveInteraction(
          video,
          shareDelta: 1,
        );
      }
    } catch (e) {
      _showMessage(
        'Share করা যায়নি।',
      );
    }
  }

  Future<void> _openComments() async {
    final video = _currentVideo;

    if (video == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        video: video,
        onComment: _addComment,
      ),
    );
  }

  Future<void> _addComment(
    VideoItem video,
    String text,
  ) async {
    final user = await _requireLogin();

    if (user == null ||
        text.trim().isEmpty) {
      return;
    }

    final username =
        user.displayName
                    ?.trim()
                    .isNotEmpty ==
                true
            ? '@${user.displayName!.trim()}'
            : '@palok_user';

    try {
      if (video.id != null) {
        final videoRef = _firestore
            .collection('videos')
            .doc(video.id);

        final commentRef = videoRef
            .collection('comments')
            .doc();

        final batch = _firestore.batch();

        batch.set(
          commentRef,
          {
            'userId': user.uid,
            'username': username,
            'text': text.trim(),
            'createdAt':
                FieldValue.serverTimestamp(),
          },
        );

        batch.update(
          videoRef,
          {
            'commentCount':
                FieldValue.increment(1),
          },
        );

        await batch.commit();
      } else {
        final key = _interactionKey(video);

        final commentRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('demoComments')
            .doc(key)
            .collection('items')
            .doc();

        await commentRef.set(
          {
            'userId': user.uid,
            'username': username,
            'text': text.trim(),
            'createdAt':
                FieldValue.serverTimestamp(),
          },
        );

        final next =
            (_demoCommentCounts[key] ?? 0) + 1;

        await _saveInteraction(
          video,
          commentCount: next,
        );

        if (mounted) {
          setState(() {
            _demoCommentCounts[key] = next;
          });
        }
      }
    } catch (e) {
      _showMessage(
        'Comment সংরক্ষণ করা যায়নি।',
      );
    }
  }

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchSheet(
        videos: _visibleVideos,
        onSelect: (video) {
          Navigator.pop(context);

          final index =
              _visibleVideos.indexWhere(
            (item) => item.url == video.url,
          );

          if (index >= 0 &&
              _pageController.hasClients) {
            _pageController.animateToPage(
              index,
              duration:
                  const Duration(milliseconds: 450),
              curve: Curves.easeOut,
            );
          }
        },
      ),
    );
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
      builder: (_) => SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24,
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
              const SizedBox(height: 24),
              const Text(
                'Create on PALOK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              _createOption(
                Icons.videocam_outlined,
                'Record Video',
                () async {
                  Navigator.pop(context);
                  await _pickAndCompose(
                    ImageSource.camera,
                  );
                },
              ),
              _createOption(
                Icons.video_library_outlined,
                'Upload Video',
                () async {
                  Navigator.pop(context);
                  await _pickAndCompose(
                    ImageSource.gallery,
                  );
                },
              ),
              _createOption(
                Icons.music_note_outlined,
                'Add Sound',
                () {
                  Navigator.pop(context);

                  _showMessage(
                    'Sound যোগ করতে আগে একটি ভিডিও Upload করুন।',
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
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius:
              BorderRadius.circular(14),
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
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white38,
      ),
    );
  }

  Future<void> _pickAndCompose(
    ImageSource source,
  ) async {
    final user = await _requireLogin();

    if (user == null) return;

    try {
      final picked =
          await _picker.pickVideo(
        source: source,
        maxDuration:
            const Duration(minutes: 10),
      );

      if (picked == null) return;

      final file = File(picked.path);

      final size = await file.length();

      if (size > _maxVideoBytes) {
        _showMessage(
          'ভিডিও 100 MB বা তার কম হতে হবে।',
        );
        return;
      }

      if (!mounted) return;

      final draft =
          await showModalBottomSheet<VideoPostDraft>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _VideoComposer(
          videoFile: file,
        ),
      );

      if (draft == null) return;

      await _uploadVideo(
        file,
        draft,
      );
    } catch (e) {
      debugPrint(
        'Pick video error: $e',
      );

      _showMessage(
        'ভিডিও নির্বাচন করা যায়নি।',
      );
    }
  }

  Future<void> _uploadVideo(
    File file,
    VideoPostDraft draft,
  ) async {
    final user = await _requireLogin();

    if (user == null) return;

    if (!mounted) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadStatus = 'Preparing video...';
    });

    try {
      final data =
          await _cloudinaryUpload(file);

      final url =
          (data['secure_url'] ?? '').toString();

      if (url.isEmpty) {
        throw Exception(
          'Cloudinary URL পাওয়া যায়নি।',
        );
      }

      if (mounted) {
        setState(() {
          _uploadProgress = .96;
          _uploadStatus = 'Saving post...';
        });
      }

      final ref =
          _firestore.collection('videos').doc();

      final username =
          user.displayName
                      ?.trim()
                      .isNotEmpty ==
                  true
              ? '@${user.displayName!.trim()}'
              : '@palok_user';

      await ref.set(
        {
          'ownerId': user.uid,
          'username': username,
          'videoUrl': url,
          'cloudinaryPublicId':
              (data['public_id'] ?? '')
                  .toString(),
          'cloudinaryAssetId':
              (data['asset_id'] ?? '')
                  .toString(),
          'caption': draft.caption,
          'hashtags': draft.hashtags,
          'soundName': draft.soundName,
          'likeCount': 0,
          'commentCount': 0,
          'saveCount': 0,
          'shareCount': 0,
          'createdAt':
              FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _uploadProgress = 1;
        _uploadStatus = '';
      });

      _showMessage(
        '🎉 ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে!',
      );
    } catch (e) {
      debugPrint(
        'Upload error: $e',
      );

      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
        _uploadStatus = '';
      });

      _showMessage(
        'Upload ব্যর্থ: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<Map<String, dynamic>> _cloudinaryUpload(
    File file,
  ) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '$_cloudName/video/upload',
    );

    final boundary =
        '----PALOK${DateTime.now().microsecondsSinceEpoch}';

    final fileLength =
        await file.length();

    final fileName =
        'palok_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final prefix =
        '--$boundary\r\n'
        'Content-Disposition: form-data; '
        'name="upload_preset"\r\n\r\n'
        '$_uploadPreset\r\n'
        '--$boundary\r\n'
        'Content-Disposition: form-data; '
        'name="file"; '
        'filename="$fileName"\r\n'
        'Content-Type: video/mp4\r\n\r\n';

    final suffix =
        '\r\n--$boundary--\r\n';

    final prefixBytes =
        utf8.encode(prefix);

    final suffixBytes =
        utf8.encode(suffix);

    final total =
        prefixBytes.length +
            fileLength +
            suffixBytes.length;

    var sent = 0;

    final request =
        http.StreamedRequest(
      'POST',
      uri,
    );

    request.headers['Content-Type'] =
        'multipart/form-data; boundary=$boundary';

    request.headers['Accept'] =
        'application/json';

    request.contentLength = total;

    final responseFuture =
        request.send();

    request.sink.add(
      prefixBytes,
    );

    sent += prefixBytes.length;

    _setUploadProgress(
      sent / total,
      'Uploading video...',
    );

    await for (final chunk
        in file.openRead()) {
      request.sink.add(chunk);

      sent += chunk.length;

      _setUploadProgress(
        sent / total,
        'Uploading video...',
      );
    }

    request.sink.add(
      suffixBytes,
    );

    sent += suffixBytes.length;

    _setUploadProgress(
      1,
      'Processing video...',
    );

    await request.sink.close();

    final response =
        await responseFuture;

    final body =
        await response.stream
            .bytesToString();

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      String message =
          'Cloudinary error (${response.statusCode})';

      try {
        final json =
            jsonDecode(body)
                as Map<String, dynamic>;

        if (json['error'] is Map) {
          message =
              ((json['error']
                          as Map)['message'] ??
                      message)
                  .toString();
        }
      } catch (_) {}

      throw Exception(message);
    }

    return jsonDecode(body)
        as Map<String, dynamic>;
  }

  void _setUploadProgress(
    double value,
    String status,
  ) {
    if (!mounted) return;

    setState(() {
      _uploadProgress =
          value.clamp(0, 1);

      _uploadStatus = status;
    });
  }

  void _selectBottom(int index) {
    setState(() {
      _bottomIndex = index;
    });

    if (index == 0) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          0,
          duration:
              const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    } else if (index == 1) {
      _showMessage(
        'Friends feed শীঘ্রই যুক্ত হবে।',
      );
    } else if (index == 2) {
      _openCreate();
    } else if (index == 3) {
      _showInbox();
    } else if (index == 4) {
      _showProfile();
    }
  }

  void _selectTop(int index) {
    setState(() {
      _topIndex = index;
      _currentIndex = 0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    unawaited(
      _prepareCurrentVideo(),
    );
  }

  void _showInbox() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          const Color(0xFF101010),
      builder: (_) => const SafeArea(
        child: SizedBox(
          height: 260,
          child: Center(
            child: Text(
              'Inbox\n\nNo new messages',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showProfile() {
    final user = _user;

    showModalBottomSheet(
      context: context,
      backgroundColor:
          const Color(0xFF101010),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: _pink,
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user?.displayName ??
                    '@palok_user',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              Text(
                user?.email ?? '',
                style: const TextStyle(
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Colors.white,
                ),
                title: const Text(
                  'Log out',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  await FirebaseAuth
                      .instance
                      .signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPage(
    VideoItem video,
  ) {
    final controller =
        _controllers[video.url];

    if (controller == null ||
        !controller.value.isInitialized) {
      unawaited(
        _getController(video.url),
      );

      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: _pink,
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
          child: VideoPlayer(
            controller,
          ),
        ),
      ),
    );
  }

  Widget _buildRightButtons() {
    final video = _currentVideo;

    if (video == null) {
      return const SizedBox.shrink();
    }

    final key =
        _interactionKey(video);

    final liked =
        _likedIds.contains(key);

    final saved =
        _savedIds.contains(key);

    final following =
        video.ownerId != null &&
            _followingIds.contains(
              video.ownerId,
            );

    final likeCount =
        video.likes +
            (video.id == null
                ? (_demoLikeDeltas[key] ?? 0)
                : 0);

    final saveCount =
        video.saves +
            (video.id == null
                ? (_demoSaveDeltas[key] ?? 0)
                : 0);

    final shareCount =
        video.shares +
            (video.id == null
                ? (_demoShareDeltas[key] ?? 0)
                : 0);

    final commentCount =
        video.comments +
            (video.id == null
                ? (_demoCommentCounts[key] ?? 0)
                : 0);

    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        _actionButton(
          Icons.favorite,
          liked
              ? _pink
              : Colors.white,
          _format(likeCount),
          _toggleLike,
        ),
        const SizedBox(height: 13),
        _actionButton(
          Icons.comment,
          Colors.white,
          _format(commentCount),
          _openComments,
        ),
        const SizedBox(height: 13),
        _actionButton(
          Icons.bookmark,
          saved
              ? const Color(0xFFFFC107)
              : Colors.white,
          _format(saveCount),
          _toggleSave,
        ),
        const SizedBox(height: 13),
        _actionButton(
          Icons.share,
          Colors.white,
          _format(shareCount),
          _shareVideo,
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _toggleFollow,
          child: Stack(
            clipBehavior:
                Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white12,
                  border: Border.all(
                    color: Colors.white24,
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              if (!following &&
                  video.ownerId != null &&
                  video.ownerId !=
                      _user?.uid)
                Positioned(
                  bottom: -5,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration:
                        const BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color: _pink,
                    ),
                    child:
                        const Icon(
                      Icons.add,
                      color: Colors.white,
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

  Widget _actionButton(
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
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color: Colors.black
                  .withOpacity(.38),
              border: Border.all(
                color: Colors.white
                    .withOpacity(.12),
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

  Widget _buildVideoInformation() {
    final video = _currentVideo;

    if (video == null) {
      return const SizedBox.shrink();
    }

    final following =
        video.ownerId != null &&
            _followingIds.contains(
              video.ownerId,
            );

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
                video.username,
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
            if (video.ownerId != null &&
                video.ownerId !=
                    _user?.uid) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap:
                    _toggleFollow,
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
                        BorderRadius
                            .circular(
                      7,
                    ),
                    border: Border.all(
                      color:
                          Colors.white54,
                    ),
                  ),
                  child: Text(
                    following
                        ? 'Following'
                        : 'Follow',
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          video.caption,
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
        const SizedBox(height: 7),
        if (video.hashtags.isNotEmpty)
          Text(
            video.hashtags
                .map(
                  (tag) => '#$tag',
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
                video.soundName,
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
            AnimatedBuilder(
              animation:
                  _logoController,
              builder: (
                _,
                child,
              ) {
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
              child:
                  _buildLogo(),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () =>
                  _selectTop(0),
              child: _topTab(
                'For You',
                _topIndex == 0,
              ),
            ),
            const SizedBox(width: 18),
            GestureDetector(
              onTap: () =>
                  _selectTop(1),
              child: _topTab(
                'Following',
                _topIndex == 1,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap:
                  _openSearch,
              child: const Padding(
                padding:
                    EdgeInsets.all(8),
                child: Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ),
          ],
        ),
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
            BorderRadius.circular(14),
        gradient:
            const LinearGradient(
          colors: [
            _pink,
            Color(0xFF8B5CF6),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: _pink,
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
        const SizedBox(height: 5),
        AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),
          width: active ? 22 : 0,
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

  Widget _buildBottomNavigation() {
    return Container(
      height: 78,
      color: Colors.black,
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceAround,
        children: [
          _bottomButton(
            Icons.home_filled,
            'Home',
            0,
          ),
          _bottomButton(
            Icons.people_outline,
            'Friends',
            1,
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
              child: const Center(
                child: Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 29,
                ),
              ),
            ),
          ),
          _bottomButton(
            Icons.chat_bubble_outline,
            'Inbox',
            3,
          ),
          _bottomButton(
            Icons.person_outline,
            'Profile',
            4,
          ),
        ],
      ),
    );
  }

  Widget _bottomButton(
    IconData icon,
    String label,
    int index,
  ) {
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
              color:
                  _bottomIndex == index
                      ? Colors.white
                      : Colors.white54,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color:
                    _bottomIndex ==
                            index
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

  void _showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior:
              SnackBarBehavior.floating,
          duration:
              const Duration(seconds: 2),
        ),
      );
  }

  String _format(int value) {
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
    final list = _visibleVideos;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (list.isEmpty)
            const Center(
              child: Text(
                'Following feed is empty',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            )
          else
            PageView.builder(
              controller:
                  _pageController,
              scrollDirection:
                  Axis.vertical,
              itemCount:
                  list.length,
              onPageChanged:
                  _onPageChanged,
              itemBuilder: (
                _,
                index,
              ) {
                return GestureDetector(
                  onTap:
                      _toggleVideo,
                  child:
                      _buildVideoPage(
                    list[index],
                  ),
                );
              },
            ),

          // LOCKED TOP POSITION
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child:
                _buildTopBar(),
          ),

          // LOCKED RIGHT BUTTON POSITION
          Positioned(
            right: 10,
            bottom: 116,
            child:
                _buildRightButtons(),
          ),

          // LOCKED VIDEO INFORMATION POSITION
          Positioned(
            left: 18,
            right: 92,
            bottom: 124,
            child:
                _buildVideoInformation(),
          ),

          // LOCKED BOTTOM NAVIGATION
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
            Positioned(
              left: 18,
              right: 18,
              bottom: 88,
              child: _UploadProgress(
                progress:
                    _uploadProgress,
                status:
                    _uploadStatus,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoSub?.cancel();

    _logoController.dispose();

    _pageController.dispose();

    for (final controller
        in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }
}

class _UploadProgress
    extends StatelessWidget {
  final double progress;
  final String status;

  const _UploadProgress({
    required this.progress,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color: Colors.black
            .withOpacity(.88),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  status,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(10),
            child:
                LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor:
                  Colors.white12,
              color: _HomeScreenState._pink,
            ),
          ),
        ],
      ),
    );
  }
}

class VideoItem {
  final String url;
  final String? id;
  final String? ownerId;
  final String username;
  final String caption;
  final List<String> hashtags;
  final String soundName;
  final int likes;
  final int comments;
  final int saves;
  final int shares;

  const VideoItem({
    required this.url,
    this.id,
    this.ownerId,
    required this.username,
    required this.caption,
    required this.hashtags,
    this.soundName =
        'Original sound',
    this.likes = 0,
    this.comments = 0,
    this.saves = 0,
    this.shares = 0,
  });

  const VideoItem.demo({
    required this.url,
    required this.username,
    required this.caption,
    required this.hashtags,
    this.likes = 0,
    this.comments = 0,
    this.saves = 0,
    this.shares = 0,
  })  : id = null,
        ownerId = null,
        soundName =
            'Original sound';

  factory VideoItem.fromFirestore(
    QueryDocumentSnapshot<
        Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    int number(
      String key,
    ) {
      return (data[key] as num?)
              ?.toInt() ??
          0;
    }

    return VideoItem(
      id: doc.id,
      ownerId:
          data['ownerId']?.toString(),
      url:
          data['videoUrl']?.toString() ??
              '',
      username:
          data['username']?.toString() ??
              '@palok_user',
      caption:
          data['caption']?.toString() ??
              '',
      hashtags:
          data['hashtags'] is List
              ? List<String>.from(
                  data['hashtags']
                      .map(
                        (e) =>
                            e.toString(),
                      ),
                )
              : const [],
      soundName:
          data['soundName']?.toString() ??
              'Original sound',
      likes:
          number('likeCount'),
      comments:
          number('commentCount'),
      saves:
          number('saveCount'),
      shares:
          number('shareCount'),
    );
  }
}

class VideoPostDraft {
  final String caption;
  final List<String> hashtags;
  final String soundName;

  const VideoPostDraft({
    required this.caption,
    required this.hashtags,
    this.soundName =
        'Original sound',
  });
}

class _VideoComposer
    extends StatefulWidget {
  final File videoFile;

  const _VideoComposer({
    required this.videoFile,
  });

  @override
  State<_VideoComposer> createState() =>
      _VideoComposerState();
}

class _VideoComposerState
    extends State<_VideoComposer> {
  static const _pink =
      Color(0xFFFF2D75);

  late final VideoPlayerController
      _controller;

  final TextEditingController
      _caption =
      TextEditingController();

  final TextEditingController
      _hashtags =
      TextEditingController();

  bool _ready = false;

  @override
  void initState() {
    super.initState();

    _controller =
        VideoPlayerController.file(
      widget.videoFile,
    );

    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await _controller.initialize();

      await _controller.setLooping(
        true,
      );

      await _controller.play();

      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
    } catch (e) {
      debugPrint(
        'Composer preview error: $e',
      );
    }
  }

  void _post() {
    final tags = _hashtags.text
        .trim()
        .split(
          RegExp(r'[\s,#]+'),
        )
        .where(
          (item) => item.isNotEmpty,
        )
        .map(
          (item) => item.replaceFirst(
            RegExp(r'^#'),
            '',
          ),
        )
        .toList();

    Navigator.pop(
      context,
      VideoPostDraft(
        caption:
            _caption.text.trim(),
        hashtags: tags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.of(context)
            .viewInsets
            .bottom;

    final height =
        MediaQuery.of(context)
            .size
            .height;

    return AnimatedPadding(
      duration:
          const Duration(milliseconds: 200),
      padding:
          EdgeInsets.only(
        bottom: bottom,
      ),
      child: Container(
        height: height * .88,
        padding:
            const EdgeInsets.fromLTRB(
          16,
          14,
          16,
          12,
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
              decoration:
                  BoxDecoration(
                color: Colors.white24,
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Post Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  if (_ready)
                    AspectRatio(
                      aspectRatio:
                          _controller
                              .value
                              .aspectRatio,
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                        child:
                            VideoPlayer(
                          _controller,
                        ),
                      ),
                    )
                  else
                    const SizedBox(
                      height: 300,
                      child: Center(
                        child:
                            CircularProgressIndicator(
                          color: _pink,
                        ),
                      ),
                    ),
                  const SizedBox(
                    height: 14,
                  ),
                  TextField(
                    controller:
                        _caption,
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
                            Colors.white38,
                      ),
                      filled: true,
                      fillColor:
                          Colors.white10,
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
                  const SizedBox(
                    height: 10,
                  ),
                  TextField(
                    controller:
                        _hashtags,
                    style:
                        const TextStyle(
                      color: Colors.white,
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
                            BorderRadius
                                .circular(
                          14,
                        ),
                        borderSide:
                            BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                    padding:
                        const EdgeInsets
                            .all(14),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white10,
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
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
                          Icons.chevron_right,
                          color:
                              Colors.white38,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                    _ready ? _post : null,
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      _pink,
                  foregroundColor:
                      Colors.white,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
                child: const Text(
                  'Post to PALOK',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
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
    _caption.dispose();
    _hashtags.dispose();

    super.dispose();
  }
}

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
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.of(context)
            .viewInsets
            .bottom;

    final user =
        FirebaseAuth.instance
            .currentUser;

    final demoKey =
        widget.video.url.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );

    return AnimatedPadding(
      duration:
          const Duration(milliseconds: 180),
      padding:
          EdgeInsets.only(
        bottom: bottom,
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
            color: Color(0xFF101010),
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(22),
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
                          fontSize: 16,
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
                color: Colors.white10,
                height: 1,
              ),
              Expanded(
                child:
                    StreamBuilder<
                        QuerySnapshot<
                            Map<String,
                                dynamic>>>(
                  stream: widget.video.id !=
                          null
                      ? FirebaseFirestore
                          .instance
                          .collection(
                              'videos')
                          .doc(
                            widget.video.id,
                          )
                          .collection(
                              'comments')
                          .orderBy(
                            'createdAt',
                            descending:
                                false,
                          )
                          .snapshots()
                      : user == null
                          ? null
                          : FirebaseFirestore
                              .instance
                              .collection(
                                  'users')
                              .doc(
                                user.uid,
                              )
                              .collection(
                                  'demoComments')
                              .doc(
                                demoKey,
                              )
                              .collection(
                                  'items')
                              .orderBy(
                                'createdAt',
                                descending:
                                    false,
                              )
                              .snapshots(),
                  builder:
                      (_, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Comments unavailable',
                          style:
                              TextStyle(
                            color:
                                Colors.white54,
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child:
                            CircularProgressIndicator(
                          color:
                              Color(
                            0xFFFF2D75,
                          ),
                        ),
                      );
                    }

                    final docs =
                        snapshot
                            .data!
                            .docs;

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
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
                          const EdgeInsets
                              .all(16),
                      itemCount:
                          docs.length,
                      itemBuilder:
                          (_, index) {
                        final data =
                            docs[index]
                                .data();

                        return Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            bottom: 18,
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
                                  0xFF333333,
                                ),
                                child:
                                    Icon(
                                  Icons.person,
                                  color:
                                      Colors.white54,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
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
                                      height: 3,
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
                                BorderRadius
                                    .circular(
                              24,
                            ),
                            borderSide:
                                BorderSide
                                    .none,
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
                    const SizedBox(
                      width: 8,
                    ),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration:
                            const BoxDecoration(
                          shape:
                              BoxShape.circle,
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

  List<VideoItem> _results = [];

  @override
  void initState() {
    super.initState();

    _results = widget.videos;

    _controller.addListener(
      _search,
    );
  }

  void _search() {
    final q =
        _controller.text
            .trim()
            .toLowerCase();

    setState(() {
      if (q.isEmpty) {
        _results =
            widget.videos;
      } else {
        _results =
            widget.videos.where(
          (video) {
            return video.caption
                    .toLowerCase()
                    .contains(q) ||
                video.username
                    .toLowerCase()
                    .contains(q) ||
                video.hashtags
                    .join(' ')
                    .toLowerCase()
                    .contains(q);
          },
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          color: Color(0xFF101010),
          borderRadius:
              BorderRadius.vertical(
            top: Radius.circular(24),
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
                  10,
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.all(16),
              child: TextField(
                controller:
                    _controller,
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
                        BorderRadius
                            .circular(
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
                          (_, index) {
                        final video =
                            _results[index];

                        return ListTile(
                          onTap: () =>
                              widget.onSelect(
                            video,
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
                              Icons.play_arrow,
                              color:
                                  Colors.white,
                            ),
                          ),
                          title: Text(
                            video.username,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            video.caption,
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
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
