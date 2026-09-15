import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const Color _pink = Color(0xFFFF2D75);
  static const Color _cyan = Color(0xFF00E5FF);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  final PageController _pageController = PageController();

  final List<VideoItem> _videos = [];

  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, Future<void>> _initializing = {};

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

  bool _loadingVideos = true;
  bool _isUploading = false;
  bool _isPlaying = true;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _videoSubscription;

  User? get _user => _auth.currentUser;

  VideoItem? get _currentVideo {
    if (_currentIndex < 0 || _currentIndex >= _videos.length) {
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

    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadUserInteractions(),
      _loadFollowing(),
    ]);

    _listenToVideos();
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
        _followingIds
          ..clear()
          ..addAll(snapshot.docs.map((doc) => doc.id));
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

  CollectionReference<Map<String, dynamic>> _interactionCollection(
    String uid,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('videoInteractions');
  }

  Future<void> _loadUserInteractions() async {
    final user = _user;
    if (user == null) return;

    try {
      final interactionSnapshot =
          await _interactionCollection(user.uid).get();

      final savedSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved')
          .get();

      final likedSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .get();

      final liked = <String>{};
      final saved = <String>{};
      final likeDeltas = <String, int>{};
      final saveDeltas = <String, int>{};

      for (final doc in interactionSnapshot.docs) {
        final data = doc.data();

        if (data['liked'] == true) {
          liked.add(doc.id);
        }

        if (data['saved'] == true) {
          saved.add(doc.id);
        }

        final likeDelta = data['likeDelta'];
        if (likeDelta is num && likeDelta != 0) {
          likeDeltas[doc.id] = likeDelta.toInt();
        }

        final saveDelta = data['saveDelta'];
        if (saveDelta is num && saveDelta != 0) {
          saveDeltas[doc.id] = saveDelta.toInt();
        }
      }

      liked.addAll(likedSnapshot.docs.map((doc) => doc.id));
      saved.addAll(savedSnapshot.docs.map((doc) => doc.id));

      if (!mounted) return;

      setState(() {
        _likedIds
          ..clear()
          ..addAll(liked);

        _savedIds
          ..clear()
          ..addAll(saved);

        _demoLikeDeltas
          ..clear()
          ..addAll(likeDeltas);

        _demoSaveDeltas
          ..clear()
          ..addAll(saveDeltas);
      });
    } catch (e) {
      debugPrint('Interaction load error: $e');
    }
  }

  void _listenToVideos() {
    _videoSubscription?.cancel();

    setState(() {
      _loadingVideos = true;
    });

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
              (doc) => VideoItem.fromFirestore(
                doc.id,
                doc.data(),
              ),
            )
            .toList();

        final localVideos = <VideoItem>[
          VideoItem.demo(
            url: 'assets/videos/video.mp4',
            username: '@palok_user',
            caption: 'Welcome to PALOK 🎬',
            hashtags: '#PALOK #ForYou',
            likes: 11700,
            comments: 234,
            saves: 811,
            shares: 431,
          ),
          VideoItem.demo(
            url: 'assets/videos/video1.mp4',
            username: '@palok_creator',
            caption: 'Create. Share. Connect. ✨',
            hashtags: '#PALOK #Creator',
            likes: 8500,
            comments: 128,
            saves: 452,
            shares: 201,
          ),
          VideoItem.demo(
            url: 'assets/videos/video2.mp4',
            username: '@palok_world',
            caption: 'Your short-video world starts here.',
            hashtags: '#PALOK #ShortVideo',
            likes: 6200,
            comments: 96,
            saves: 317,
            shares: 145,
          ),
        ];

        final all = <VideoItem>[
          ...remoteVideos,
          ...localVideos,
        ];

        if (!mounted) return;

        setState(() {
          _videos
            ..clear()
            ..addAll(all);

          _loadingVideos = false;
        });

        _prepareCurrentVideo();
      },
      onError: (Object error) {
        debugPrint('Video stream error: $error');

        if (!mounted) return;

        setState(() {
          _loadingVideos = false;

          if (_videos.isEmpty) {
            _videos.addAll([
              VideoItem.demo(
                url: 'assets/videos/video.mp4',
                username: '@palok_user',
                caption: 'Welcome to PALOK 🎬',
                hashtags: '#PALOK #ForYou',
                likes: 11700,
                comments: 234,
                saves: 811,
                shares: 431,
              ),
              VideoItem.demo(
                url: 'assets/videos/video1.mp4',
                username: '@palok_creator',
                caption: 'Create. Share. Connect. ✨',
                hashtags: '#PALOK #Creator',
                likes: 8500,
                comments: 128,
                saves: 452,
                shares: 201,
              ),
            ]);
          }
        });

        _prepareCurrentVideo();
      },
    );
  }

  Future<void> _prepareCurrentVideo() async {
    if (_videos.isEmpty) return;

    final index = _currentIndex;

    if (_controllers[index] == null) {
      await _initializeVideo(index);
    }

    if (!mounted) return;

    for (final entry in _controllers.entries) {
      if (entry.key == index) {
        await entry.value.play();
        await entry.value.setLooping(true);
      } else {
        await entry.value.pause();
      }
    }

    setState(() {
      _isPlaying = true;
    });
  }

  Future<void> _initializeVideo(int index) async {
    if (_controllers[index] != null) return;

    if (_initializing[index] != null) {
      await _initializing[index];
      return;
    }

    final video = _videos[index];

    late VideoPlayerController controller;

    if (video.isAsset) {
      controller = VideoPlayerController.asset(video.url);
    } else {
      controller = VideoPlayerController.networkUrl(
        Uri.parse(video.url),
      );
    }

    final future = controller.initialize();

    _initializing[index] = future;

    try {
      await future;

      await controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controllers[index] = controller;

      setState(() {});
    } catch (e) {
      debugPrint(
        'Video initialize error at $index: $e',
      );

      await controller.dispose();
    } finally {
      _initializing.remove(index);
    }
  }

  Future<void> _onPageChanged(int index) async {
    if (index < 0 || index >= _videos.length) return;

    setState(() {
      _currentIndex = index;
      _isPlaying = true;
    });

    await _prepareCurrentVideo();

    _disposeUnusedControllers(index);
  }

  void _disposeUnusedControllers(int currentIndex) {
    final keys = _controllers.keys.toList();

    for (final index in keys) {
      if ((index - currentIndex).abs() > 2) {
        final controller = _controllers.remove(index);
        controller?.dispose();
      }
    }
  }

  Future<void> _togglePlayPause() async {
    final controller = _controllers[_currentIndex];

    if (controller == null ||
        !controller.value.isInitialized) {
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

  Future<User?> _requireLogin() async {
    final user = _user;

    if (user != null) {
      return user;
    }

    if (!mounted) return null;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171717),
          title: const Text(
            'Login required',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'এই কাজটি করতে আগে PALOK-এ login করুন।',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'OK',
                style: TextStyle(color: _pink),
              ),
            ),
          ],
        );
      },
    );

    return null;
  }

  Future<void> _saveInteraction(
    String uid,
    String key, {
    bool? liked,
    bool? saved,
  }) async {
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

    await _interactionCollection(uid).doc(key).set(
          data,
          SetOptions(merge: true),
        );
  }

  Future<void> _toggleLike() async {
    final user = await _requireLogin();
    final video = _currentVideo;

    if (user == null || video == null) return;

    final key = _interactionKey(video);
    final liked = !_likedIds.contains(key);

    final previousLikeDelta =
        _demoLikeDeltas[key] ?? 0;

    setState(() {
      if (liked) {
        _likedIds.add(key);
      } else {
        _likedIds.remove(key);
      }

      if (video.id == null) {
        _demoLikeDeltas[key] = liked ? 1 : 0;
      }
    });

    try {
      final batch = _firestore.batch();

      final interactionRef = _interactionCollection(
        user.uid,
      ).doc(key);

      final likedRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .doc(key);

      final interactionData = <String, dynamic>{
        'videoKey': key,
        'updatedAt': FieldValue.serverTimestamp(),
        'liked': liked,
      };

      if (video.id == null) {
        interactionData['likeDelta'] =
            liked ? 1 : 0;
      }

      batch.set(
        interactionRef,
        interactionData,
        SetOptions(merge: true),
      );

      if (liked) {
        batch.set(
          likedRef,
          {
            'videoKey': key,
            'videoId': video.id,
            'videoUrl': video.url,
            'username': video.username,
            'createdAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        batch.delete(likedRef);
      }

      if (video.id != null) {
        final videoRef = _firestore
            .collection('videos')
            .doc(video.id);

        final likeRef = videoRef
            .collection('likes')
            .doc(user.uid);

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
              'userId': user.uid,
              'createdAt':
                  FieldValue.serverTimestamp(),
            },
          );
        } else {
          batch.delete(likeRef);
        }
      }

      await batch.commit();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (liked) {
          _likedIds.remove(key);
        } else {
          _likedIds.add(key);
        }

        if (video.id == null) {
          if (previousLikeDelta == 0) {
            _demoLikeDeltas.remove(key);
          } else {
            _demoLikeDeltas[key] =
                previousLikeDelta;
          }
        }
      });

      debugPrint('Like save error: $e');

      _showMessage(
        'Like সংরক্ষণ করা যায়নি।',
      );
    }
  }

  Future<void> _toggleSave() async {
    final user = await _requireLogin();
    final video = _currentVideo;

    if (user == null || video == null) return;

    final key = _interactionKey(video);
    final saved = !_savedIds.contains(key);

    final previousSaveDelta =
        _demoSaveDeltas[key] ?? 0;

    setState(() {
      if (saved) {
        _savedIds.add(key);
      } else {
        _savedIds.remove(key);
      }

      if (video.id == null) {
        _demoSaveDeltas[key] = saved ? 1 : 0;
      }
    });

    try {
      final batch = _firestore.batch();

      final interactionRef = _interactionCollection(
        user.uid,
      ).doc(key);

      final savedRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved')
          .doc(key);

      final interactionData = <String, dynamic>{
        'videoKey': key,
        'updatedAt': FieldValue.serverTimestamp(),
        'saved': saved,
      };

      if (video.id == null) {
        interactionData['saveDelta'] =
            saved ? 1 : 0;
      }

      batch.set(
        interactionRef,
        interactionData,
        SetOptions(merge: true),
      );

      if (saved) {
        batch.set(
          savedRef,
          {
            'videoKey': key,
            'videoId': video.id,
            'videoUrl': video.url,
            'username': video.username,
            'caption': video.caption,
            'createdAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        batch.delete(savedRef);
      }

      if (video.id != null) {
        batch.update(
          _firestore
              .collection('videos')
              .doc(video.id),
          {
            'saveCount':
                FieldValue.increment(
              saved ? 1 : -1,
            ),
          },
        );
      }

      await batch.commit();

      _showMessage(
        saved
            ? 'ভিডিওটি সংরক্ষণ করা হয়েছে'
            : 'ভিডিওটি Unsave করা হয়েছে',
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
            if (previousSaveDelta == 0) {
              _demoSaveDeltas.remove(key);
            } else {
              _demoSaveDeltas[key] =
                  previousSaveDelta;
            }
          }
        });
      }

      debugPrint('Save error: $e');

      _showMessage(
        'Save সংরক্ষণ করা যায়নি।',
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
      final batch = _firestore.batch();

      final followingRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(owner);

      final followerRef = _firestore
          .collection('users')
          .doc(owner)
          .collection('followers')
          .doc(user.uid);

      if (following) {
        batch.set(
          followingRef,
          {
            'userId': owner,
            'username': video.username,
            'createdAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        batch.set(
          followerRef,
          {
            'userId': user.uid,
            'username':
                user.displayName
                            ?.trim()
                            .isNotEmpty ==
                        true
                    ? user.displayName!.trim()
                    : '@palok_user',
            'createdAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        batch.delete(followingRef);
        batch.delete(followerRef);
      }

      await batch.commit();

      _showMessage(
        following
            ? 'Following সংরক্ষণ হয়েছে'
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

      debugPrint(
        'Follow save error: $e',
      );

      _showMessage(
        'Follow সংরক্ষণ করা যায়নি।',
      );
    }
  }

  Future<void> _addComment(
    String text,
  ) async {
    final user = await _requireLogin();
    final video = _currentVideo;

    if (user == null ||
        video == null ||
        text.trim().isEmpty) {
      return;
    }

    final commentText = text.trim();
    final key = _interactionKey(video);

    try {
      if (video.id != null) {
        final videoRef = _firestore
            .collection('videos')
            .doc(video.id);

        final commentRef =
            videoRef.collection('comments').doc();

        final batch = _firestore.batch();

        batch.set(
          commentRef,
          {
            'userId': user.uid,
            'username':
                user.displayName
                            ?.trim()
                            .isNotEmpty ==
                        true
                    ? user.displayName!.trim()
                    : '@palok_user',
            'text': commentText,
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
            'username':
                user.displayName
                            ?.trim()
                            .isNotEmpty ==
                        true
                    ? user.displayName!.trim()
                    : '@palok_user',
            'text': commentText,
            'createdAt':
                FieldValue.serverTimestamp(),
          },
        );

        await _saveInteraction(
          user.uid,
          key,
        );

        if (mounted) {
          setState(() {
            _demoCommentCounts[key] =
                (_demoCommentCounts[key] ?? 0) + 1;
          });
        }
      }

      _showMessage(
        'Comment যোগ হয়েছে',
      );
    } catch (e) {
      debugPrint(
        'Comment save error: $e',
      );

      _showMessage(
        'Comment সংরক্ষণ করা যায়নি।',
      );
    }
  }

  Future<void> _shareVideo() async {
    final user = await _requireLogin();
    final video = _currentVideo;

    if (user == null || video == null) return;

    final key = _interactionKey(video);

    try {
      final link = video.id != null
          ? 'https://palok.app/video/${video.id}'
          : 'https://palok.app/video/$key';

      await Share.share(
        'দেখুন PALOK-এ 🎬\n$link',
      );

      final batch = _firestore.batch();

      final interactionRef = _interactionCollection(
        user.uid,
      ).doc(key);

      batch.set(
        interactionRef,
        {
          'videoKey': key,
          'shared': true,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final sharedRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sharedVideos')
          .doc(key);

      batch.set(
        sharedRef,
        {
          'videoKey': key,
          'videoId': video.id,
          'videoUrl': video.url,
          'createdAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (video.id != null) {
        batch.update(
          _firestore
              .collection('videos')
              .doc(video.id),
          {
            'shareCount':
                FieldValue.increment(1),
          },
        );
      } else {
        _demoShareDeltas[key] =
            (_demoShareDeltas[key] ?? 0) + 1;
      }

      await batch.commit();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint(
        'Share error: $e',
      );

      _showMessage(
        'Share সংরক্ষণ করা যায়নি।',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration:
              const Duration(milliseconds: 1800),
        ),
      );
  }

  String _format(int number) {
    if (number >= 1000000) {
      final value = number / 1000000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}M';
    }

    if (number >= 1000) {
      final value = number / 1000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}K';
    }

    return number.toString();
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
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(.38),
              border: Border.all(
                color: Colors.white.withOpacity(.12),
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

  Widget _buildRightButtons() {
    final video = _currentVideo;

    if (video == null) {
      return const SizedBox.shrink();
    }

    final key = _interactionKey(video);

    final liked = _likedIds.contains(key);
    final saved = _savedIds.contains(key);

    final following =
        video.ownerId != null &&
        _followingIds.contains(video.ownerId);

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
          onTap: _toggleFollow,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
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
                  video.ownerId != _user?.uid)
                Positioned(
                  bottom: -5,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration:
                        const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _pink,
                    ),
                    child: const Icon(
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

  Widget _buildLogo() {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
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
            fontWeight: FontWeight.w900,
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
            color:
                active ? Colors.white : Colors.white54,
            fontSize: 14,
            fontWeight:
                active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        AnimatedContainer(
          duration:
              const Duration(milliseconds: 180),
          width: active ? 22 : 0,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(5),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(14, 8, 10, 0),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _logoController,
              builder: (_, child) {
                return Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: child,
                  ),
                );
              },
              child: _buildLogo(),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _selectTop(0),
              child: _topTab(
                'For You',
                _topIndex == 0,
              ),
            ),
            const SizedBox(width: 18),
            GestureDetector(
              onTap: () => _selectTop(1),
              child: _topTab(
                'Following',
                _topIndex == 1,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _openSearch,
              child: const Padding(
                padding: EdgeInsets.all(8),
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

  Widget _buildVideoInformation() {
    final video = _currentVideo;

    if (video == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                video.username,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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
        const SizedBox(height: 8),
        Text(
          video.caption,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
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
        if (video.hashtags.trim().isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            video.hashtags,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
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
      ],
    );
  }

  Widget _buildVideoItem(
    int index,
    VideoItem video,
  ) {
    final controller = _controllers[index];

    if (controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: _pink,
          strokeWidth: 2.5,
        ),
      );
    }

    final size = controller.value.size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
          ),
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(controller),
            ),
          ),
          if (!_isPlaying &&
              index == _currentIndex)
            Center(
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.42),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          if (index == _currentIndex)
            Positioned(
              right: 10,
              bottom: 116,
              child: _buildRightButtons(),
            ),
          Positioned(
            left: 18,
            right: 92,
            bottom: 124,
            child: _buildVideoInformation(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    if (_videos.isEmpty) {
      return const Center(
        child: Text(
          'কোনো ভিডিও পাওয়া যায়নি',
          style: TextStyle(
            color: Colors.white70,
          ),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _videos.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        return _buildVideoItem(
          index,
          _videos[index],
        );
      },
    );
  }

  Widget _bottomButton(
    IconData icon,
    String label,
    int index,
  ) {
    return GestureDetector(
      onTap: () => _selectBottom(index),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: _bottomIndex == index
                  ? Colors.white
                  : Colors.white54,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: _bottomIndex == index
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

  Widget _buildBottomNavigation() {
    return Container(
      height: 78,
      color: Colors.black,
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround,
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

  void _selectTop(int index) {
    setState(() {
      _topIndex = index;
    });

    if (index == 1) {
      _showFollowingInfo();
    }
  }

  void _selectBottom(int index) {
    setState(() {
      _bottomIndex = index;
    });

    if (index == 2) {
      _openCreateSheet();
      return;
    }

    if (index == 1) {
      _showMessage(
        'Friends section শীঘ্রই আসছে।',
      );
      return;
    }

    if (index == 3) {
      _showMessage(
        'Inbox section শীঘ্রই আসছে।',
      );
      return;
    }

    if (index == 4) {
      _showMessage(
        'Profile section শীঘ্রই আসছে।',
      );
    }
  }

  void _showFollowingInfo() {
    if (_followingIds.isEmpty) {
      _showMessage(
        'আপনি এখনো কাউকে Follow করেননি।',
      );
    }
  }

  Future<void> _openSearch() async {
    final controller =
        TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF171717),
          title: const Text(
            'Search PALOK',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration:
                InputDecoration(
              hintText:
                  'Search videos, users...',
              hintStyle:
                  const TextStyle(
                color: Colors.white38,
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide:
                    const BorderSide(
                  color: Colors.white24,
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide:
                    const BorderSide(
                  color: _pink,
                ),
              ),
            ),
            onSubmitted: (value) {
              Navigator.pop(context);

              if (value.trim().isNotEmpty) {
                _showMessage(
                  'Searching for "${value.trim()}"',
                );
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final value =
                    controller.text.trim();

                Navigator.pop(context);

                if (value.isNotEmpty) {
                  _showMessage(
                    'Searching for "$value"',
                  );
                }
              },
              child: const Text(
                'Search',
                style: TextStyle(
                  color: _pink,
                ),
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> _openComments() async {
    final video = _currentVideo;

    if (video == null) return;

    final inputController =
        TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CommentsSheet(
          video: video,
          inputController: inputController,
          onSend: (text) async {
            await _addComment(text);
          },
        );
      },
    );

    inputController.dispose();
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20,
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
                        BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 22),
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
                  Icons.videocam,
                  'Record Video',
                  () {
                    Navigator.pop(context);
                    _pickVideo(
                      ImageSource.camera,
                    );
                  },
                ),
                const SizedBox(height: 10),
                _createOption(
                  Icons.video_library,
                  'Upload Video',
                  () {
                    Navigator.pop(context);
                    _pickVideo(
                      ImageSource.gallery,
                    );
                  },
                ),
                const SizedBox(height: 10),
                _createOption(
                  Icons.music_note,
                  'Add Sound',
                  () {
                    Navigator.pop(context);
                    _showMessage(
                      'Sound feature শীঘ্রই আসছে।',
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

  Widget _createOption(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.07),
          borderRadius:
              BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pink.withOpacity(.15),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(width: 14),
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
              Icons.chevron_right,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideo(
    ImageSource source,
  ) async {
    final user = await _requireLogin();

    if (user == null) return;

    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration:
            const Duration(minutes: 5),
      );

      if (picked == null) return;

      if (!mounted) return;

      await _openPostComposer(picked);
    } catch (e) {
      debugPrint(
        'Pick video error: $e',
      );

      _showMessage(
        'ভিডিও নির্বাচন করা যায়নি।',
      );
    }
  }

  Future<void> _openPostComposer(
    XFile file,
  ) async {
    final captionController =
        TextEditingController();

    final hashtagsController =
        TextEditingController(
      text: '#PALOK',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return _PostComposerSheet(
          file: file,
          captionController:
              captionController,
          hashtagsController:
              hashtagsController,
          onPost: () async {
            final caption =
                captionController.text.trim();

            final hashtags =
                hashtagsController.text.trim();

            Navigator.pop(context);

            await _uploadVideoToCloudinary(
              file,
              caption: caption,
              hashtags: hashtags,
            );
          },
        );
      },
    );

    captionController.dispose();
    hashtagsController.dispose();
  }

  Future<void> _uploadVideoToCloudinary(
    XFile file, {
    required String caption,
    required String hashtags,
  }) async {
    final user = await _requireLogin();

    if (user == null) return;

    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      const cloudName = 'u0jufmrl';
      const uploadPreset =
          'palok_video_upload';

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '$cloudName/video/upload',
      );

      final request =
          http.MultipartRequest(
        'POST',
        uri,
      );

      request.fields['upload_preset'] =
          uploadPreset;

      request.fields['folder'] =
          'palok/videos';

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
        ),
      );

      final response =
          await request.send();

      final responseBody =
          await response.stream.bytesToString();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Cloudinary upload failed: '
          '${response.statusCode} '
          '$responseBody',
        );
      }

      final data =
          jsonDecode(responseBody)
              as Map<String, dynamic>;

      final videoUrl =
          data['secure_url'] as String?;

      if (videoUrl == null ||
          videoUrl.isEmpty) {
        throw Exception(
          'Cloudinary returned no secure_url',
        );
      }

      final publicId =
          data['public_id'] as String?;

      final assetId =
          data['asset_id'] as String?;

      await _firestore
          .collection('videos')
          .add({
        'ownerId': user.uid,
        'username':
            user.displayName
                        ?.trim()
                        .isNotEmpty ==
                    true
                ? user.displayName!.trim()
                : '@palok_user',
        'videoUrl': videoUrl,
        'cloudinaryPublicId': publicId,
        'cloudinaryAssetId': assetId,
        'caption': caption,
        'hashtags': hashtags,
        'likeCount': 0,
        'commentCount': 0,
        'saveCount': 0,
        'shareCount': 0,
        'createdAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage(
        'ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে 🎉',
      );
    } catch (e) {
      debugPrint(
        'Cloudinary upload error: $e',
      );

      if (mounted) {
        _showMessage(
          'ভিডিও upload করা যায়নি।',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _loadingVideos &&
                  _videos.isEmpty
              ? const Center(
                  child:
                      CircularProgressIndicator(
                    color: _pink,
                  ),
                )
              : _buildFeed(),

          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _buildTopBar(),
          ),

          if (_isUploading)
            Positioned(
              left: 20,
              right: 20,
              bottom: 90,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black
                      .withOpacity(.82),
                  borderRadius:
                      BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white12,
                  ),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        color: _pink,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ভিডিও upload হচ্ছে...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

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

  @override
  void dispose() {
    _videoSubscription?.cancel();
    _pageController.dispose();
    _logoController.dispose();

    for (final controller
        in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }
}

class VideoItem {
  final String? id;
  final String url;
  final String username;
  final String caption;
  final String hashtags;
  final int likes;
  final int comments;
  final int saves;
  final int shares;
  final String? ownerId;
  final bool isAsset;

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
    required this.isAsset,
  });

  factory VideoItem.demo({
    required String url,
    required String username,
    required String caption,
    required String hashtags,
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
      isAsset: true,
    );
  }

  factory VideoItem.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return VideoItem(
      id: id,
      url: (data['videoUrl'] ?? '').toString(),
      username:
          (data['username'] ?? '@palok_user')
              .toString(),
      caption:
          (data['caption'] ?? '').toString(),
      hashtags:
          (data['hashtags'] ?? '').toString(),
      likes:
          _number(data['likeCount']),
      comments:
          _number(data['commentCount']),
      saves:
          _number(data['saveCount']),
      shares:
          _number(data['shareCount']),
      ownerId:
          data['ownerId']?.toString(),
      isAsset: false,
    );
  }

  static int _number(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}

class _CommentsSheet extends StatefulWidget {
  final VideoItem video;
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

class _CommentsSheetState
    extends State<_CommentsSheet> {
  bool _sending = false;

  Future<void> _sendComment() async {
    final text =
        widget.inputController.text.trim();

    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    try {
      await widget.onSend(text);

      if (mounted) {
        widget.inputController.clear();
      }
    } catch (e) {
      debugPrint(
        'Comment send error: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Widget _commentItem({
    required String username,
    required String text,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor:
                Color(0xFF333333),
            child: Icon(
              Icons.person,
              color: Colors.white54,
              size: 19,
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
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComments() {
    final video = widget.video;

    if (video.id == null) {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        return const Center(
          child: Text(
            'Login required',
            style: TextStyle(
              color: Colors.white54,
            ),
          ),
        );
      }

      final key = video.url.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );

      return StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('demoComments')
            .doc(key)
            .collection('items')
            .orderBy(
              'createdAt',
              descending: false,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Comments unavailable',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF2D75),
                strokeWidth: 2,
              ),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Be the first to comment',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            );
          }

          return ListView.builder(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              8,
            ),
            itemCount: docs.length,
            itemBuilder: (
              context,
              index,
            ) {
              final data =
                  docs[index].data();

              return _commentItem(
                username:
                    data['username']
                            ?.toString() ??
                        '@user',
                text:
                    data['text']
                            ?.toString() ??
                        '',
              );
            },
          );
        },
      );
    }

    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .doc(video.id)
          .collection('comments')
          .orderBy(
            'createdAt',
            descending: false,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Comments unavailable',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
          );
        }

        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFF2D75),
              strokeWidth: 2,
            ),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Be the first to comment',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
          );
        }

        return ListView.builder(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            8,
          ),
          itemCount: docs.length,
          itemBuilder: (
            context,
            index,
          ) {
            final data =
                docs[index].data();

            return _commentItem(
              username:
                  data['username']
                          ?.toString() ??
                      '@user',
              text:
                  data['text']
                          ?.toString() ??
                      '',
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard =
        MediaQuery.of(context)
            .viewInsets
            .bottom;

    final screenHeight =
        MediaQuery.of(context).size.height;

    return AnimatedPadding(
      duration:
          const Duration(milliseconds: 180),
      padding:
          EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: Container(
          height: screenHeight * .62,
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
                      BorderRadius.circular(10),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  12,
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
              ),

              const Divider(
                color: Colors.white10,
                height: 1,
              ),

              Expanded(
                child: _buildComments(),
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
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller:
                            widget.inputController,
                        textInputAction:
                            TextInputAction.send,
                        onSubmitted: (_) =>
                            _sendComment(),
                        minLines: 1,
                        maxLines: 4,
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration:
                            InputDecoration(
                          hintText:
                              'Add comment...',
                          hintStyle:
                              const TextStyle(
                            color: Colors.white38,
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
                      onTap: _sendComment,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration:
                            const BoxDecoration(
                          shape: BoxShape.circle,
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
                                  strokeWidth: 2,
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
}

class _PostComposerSheet
    extends StatefulWidget {
  final XFile file;
  final TextEditingController
      captionController;
  final TextEditingController
      hashtagsController;
  final VoidCallback onPost;

  const _PostComposerSheet({
    required this.file,
    required this.captionController,
    required this.hashtagsController,
    required this.onPost,
  });

  @override
  State<_PostComposerSheet> createState() =>
      _PostComposerSheetState();
}

class _PostComposerSheetState
    extends State<_PostComposerSheet> {
  VideoPlayerController? _controller;

  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  Future<void> _initializePreview() async {
    try {
      final controller =
          VideoPlayerController.file(
        File(widget.file.path),
      );

      _controller = controller;

      await controller.initialize();

      await controller.setLooping(true);
      await controller.play();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Post preview error: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Widget _buildPreview() {
    if (_loading) {
      return Container(
        height: 340,
        decoration:
            BoxDecoration(
          color: Colors.white10,
          borderRadius:
              BorderRadius.circular(16),
        ),
        child: const Center(
          child:
              CircularProgressIndicator(
            color: Color(0xFFFF2D75),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_failed ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return Container(
        height: 340,
        decoration:
            BoxDecoration(
          color: Colors.white10,
          borderRadius:
              BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white54,
                size: 42,
              ),
              SizedBox(height: 10),
              Text(
                'Video preview unavailable',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller!;

    return Container(
      constraints:
          const BoxConstraints(
        maxHeight: 390,
      ),
      decoration:
          BoxDecoration(
        color: Colors.black,
        borderRadius:
            BorderRadius.circular(16),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: AspectRatio(
        aspectRatio:
            controller.value.aspectRatio,
        child: VideoPlayer(
          controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard =
        MediaQuery.of(context)
            .viewInsets
            .bottom;

    final screenHeight =
        MediaQuery.of(context).size.height;

    return AnimatedPadding(
      duration:
          const Duration(milliseconds: 200),
      padding:
          EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: screenHeight * .88,
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
            const SizedBox(height: 12),

            Container(
              width: 42,
              height: 4,
              decoration:
                  BoxDecoration(
                color: Colors.white24,
                borderRadius:
                    BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Post Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
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
            ),

            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  16,
                ),
                children: [
                  _buildPreview(),

                  const SizedBox(height: 14),

                  TextField(
                    controller:
                        widget.captionController,
                    maxLines: 4,
                    minLines: 2,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration:
                        InputDecoration(
                      hintText:
                          'Write a caption...',
                      hintStyle:
                          const TextStyle(
                        color: Colors.white38,
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
                          const EdgeInsets.all(
                        14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextField(
                    controller:
                        widget.hashtagsController,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration:
                        InputDecoration(
                      hintText:
                          'Hashtags: PALOK ForYou',
                      hintStyle:
                          const TextStyle(
                        color: Colors.white38,
                      ),
                      prefixIcon:
                          const Icon(
                        Icons.tag,
                        color: Colors.white54,
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
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    padding:
                        const EdgeInsets.all(
                      14,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.white10,
                      borderRadius:
                          BorderRadius.circular(
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
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Everyone can view this video',
                            style: TextStyle(
                              color:
                                  Colors.white70,
                              fontSize: 13,
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

                  const SizedBox(height: 20),
                ],
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                6,
                16,
                12,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _loading || _failed
                          ? null
                          : widget.onPost,
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
                    elevation: 0,
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
                      fontSize: 16,
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
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
