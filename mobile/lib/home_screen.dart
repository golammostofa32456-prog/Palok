import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  // ------------------------------------------------------------
  // UI STATE
  // ------------------------------------------------------------

  int _bottomIndex = 0;
  int _topIndex = 0;
  int _currentVideoIndex = 0;

  late PageController _pageController;

  late AnimationController _logoAnimationController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // ------------------------------------------------------------
  // FIREBASE
  // ------------------------------------------------------------

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ------------------------------------------------------------
  // VIDEO DATA
  // ------------------------------------------------------------

  final List<String> videoUrls = [
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
  ];

  final List<String> _videoIds = [
    'demo_video_0',
    'demo_video_1',
  ];

  final List<String> _videoOwners = [
    'palok_user',
    'palok_user',
  ];

  final List<String> _videoUsernames = [
    '@palok_user',
    '@palok_user',
  ];

  final List<String> _videoCaptions = [
    'Beautiful moment on PALOK ✨',
    'Nature is always amazing 🌿',
  ];

  final List<String> _videoHashtags = [
    '#palok #foryou #viral',
    '#nature #palok #fyp',
  ];

  final List<String> _videoSounds = [
    'Original sound - PALOK',
    'Original sound - PALOK',
  ];

  final List<VideoPlayerController> _videoControllers = [];

  // ------------------------------------------------------------
  // COUNTS
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // USER ACTION STATES
  // ------------------------------------------------------------

  final List<bool> _liked = [
    false,
    false,
  ];

  final List<bool> _saved = [
    false,
    false,
  ];

  final Set<String> _followingUsers = {};

  // ------------------------------------------------------------
  // COMMENTS
  // ------------------------------------------------------------

  final TextEditingController _commentController =
      TextEditingController();

  final List<List<_LocalComment>> _localComments = [
    [],
    [],
  ];

  // ------------------------------------------------------------
  // UPLOAD STATE
  // ------------------------------------------------------------

  bool _isUploading = false;
  double _uploadProgress = 0;

  // ------------------------------------------------------------
  // INIT
  // ------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

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

    _loadDemoVideos();
    _loadRemoteVideos();
    _loadFirebaseState();
  }

  // ------------------------------------------------------------
  // LOAD DEMO VIDEOS
  // ------------------------------------------------------------

  Future<void> _loadDemoVideos() async {
    for (int i = 0; i < videoUrls.length; i++) {
      try {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrls[i]),
        );

        await controller.initialize();

        controller.setLooping(true);

        _videoControllers.add(controller);

        if (i == 0) {
          await controller.play();
        }

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint('Video loading error: $e');
      }
    }
  }

  // ------------------------------------------------------------
  // LOAD FIREBASE VIDEOS
  // ------------------------------------------------------------

  Future<void> _loadRemoteVideos() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;

      try {
        snapshot = await _firestore
            .collection('videos')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();
      } catch (_) {
        snapshot = await _firestore
            .collection('videos')
            .limit(50)
            .get();
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final String url =
            (data['videoUrl'] ?? '').toString();

        if (url.isEmpty) {
          continue;
        }

        if (_videoIds.contains(doc.id)) {
          continue;
        }

        final String ownerId =
            (data['ownerId'] ?? '').toString();

        final String username =
            (data['username'] ?? '@user').toString();

        final String caption =
            (data['caption'] ?? '').toString();

        final String hashtags =
            (data['hashtags'] ?? '').toString();

        final String sound =
            (data['soundName'] ?? 'Original sound').toString();

        final int likes =
            _toInt(data['likeCount'], 0);

        final int comments =
            _toInt(data['commentCount'], 0);

        final int saves =
            _toInt(data['saveCount'], 0);

        final int shares =
            _toInt(data['shareCount'], 0);

        _videoIds.add(doc.id);
        videoUrls.add(url);
        _videoOwners.add(ownerId);
        _videoUsernames.add(username);
        _videoCaptions.add(caption);
        _videoHashtags.add(hashtags);
        _videoSounds.add(sound);

        _likeCounts.add(likes);
        _commentCounts.add(comments);
        _saveCounts.add(saves);
        _shareCounts.add(shares);

        _liked.add(false);
        _saved.add(false);

        _localComments.add([]);

        final controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
        );

        await controller.initialize();
        controller.setLooping(true);

        _videoControllers.add(controller);

        if (mounted) {
          setState(() {});
        }
      }

      await _loadFirebaseState();
    } catch (e) {
      debugPrint('Remote video loading error: $e');
    }
  }

  // ------------------------------------------------------------
  // FIREBASE USER STATE
  // ------------------------------------------------------------

  Future<void> _loadFirebaseState() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();

      _followingUsers.clear();

      for (final doc in followingSnapshot.docs) {
        _followingUsers.add(doc.id);
      }

      for (int i = 0; i < _videoIds.length; i++) {
        final videoId = _videoIds[i];

        try {
          final videoDoc = await _firestore
              .collection('videos')
              .doc(videoId)
              .get();

          if (videoDoc.exists) {
            final data = videoDoc.data();

            if (data != null) {
              _likeCounts[i] =
                  _toInt(data['likeCount'], _likeCounts[i]);

              _commentCounts[i] =
                  _toInt(data['commentCount'], _commentCounts[i]);

              _saveCounts[i] =
                  _toInt(data['saveCount'], _saveCounts[i]);

              _shareCounts[i] =
                  _toInt(data['shareCount'], _shareCounts[i]);
            }
          }

          final likeDoc = await _firestore
              .collection('videos')
              .doc(videoId)
              .collection('likes')
              .doc(user.uid)
              .get();

          _liked[i] = likeDoc.exists;

          final saveDoc = await _firestore
              .collection('videos')
              .doc(videoId)
              .collection('saves')
              .doc(user.uid)
              .get();

          _saved[i] = saveDoc.exists;
        } catch (e) {
          debugPrint('State loading error: $e');
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Firebase state error: $e');
    }
  }

  // ------------------------------------------------------------
  // ENSURE USER
  // ------------------------------------------------------------

  Future<User?> _ensureUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      return currentUser;
    }

    try {
      final credential =
          await FirebaseAuth.instance.signInAnonymously();

      return credential.user;
    } catch (e) {
      debugPrint('Anonymous login error: $e');

      if (mounted) {
        _showMessage(
          'Please login before uploading a video.',
        );
      }

      return null;
    }
  }

  // ------------------------------------------------------------
  // PAGE / VIDEO
  // ------------------------------------------------------------

  List<int> get _visibleVideoIndexes {
    final indexes = <int>[];

    for (int i = 0; i < videoUrls.length; i++) {
      if (_topIndex == 0) {
        indexes.add(i);
      } else {
        if (_followingUsers.contains(_videoOwners[i])) {
          indexes.add(i);
        }
      }
    }

    return indexes;
  }

  void _onVideoChanged(int visibleIndex) {
    final visible = _visibleVideoIndexes;

    if (visible.isEmpty) {
      return;
    }

    if (visibleIndex >= visible.length) {
      return;
    }

    final realIndex = visible[visibleIndex];

    _currentVideoIndex = realIndex;

    for (int i = 0; i < _videoControllers.length; i++) {
      if (i == realIndex) {
        if (_videoControllers[i].value.isInitialized) {
          _videoControllers[i].play();
        }
      } else {
        _videoControllers[i].pause();
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _toggleVideo(int index) {
    if (index >= _videoControllers.length) {
      return;
    }

    final controller = _videoControllers[index];

    if (!controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }

    setState(() {});
  }

  // ------------------------------------------------------------
  // LIKE
  // ------------------------------------------------------------

  Future<void> _toggleLike() async {
    final index = _currentVideoIndex;

    if (index >= _liked.length) {
      return;
    }

    final bool newValue = !_liked[index];

    setState(() {
      _liked[index] = newValue;

      if (newValue) {
        _likeCounts[index]++;
      } else {
        _likeCounts[index] =
            (_likeCounts[index] - 1).clamp(0, 999999999);
      }
    });

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final videoId = _videoIds[index];

    try {
      final likeRef = _firestore
          .collection('videos')
          .doc(videoId)
          .collection('likes')
          .doc(user.uid);

      final videoRef =
          _firestore.collection('videos').doc(videoId);

      final batch = _firestore.batch();

      if (newValue) {
        batch.set(likeRef, {
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        batch.delete(likeRef);
      }

      batch.set(
        videoRef,
        {
          'likeCount':
              FieldValue.increment(newValue ? 1 : -1),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Like error: $e');
    }
  }

  // ------------------------------------------------------------
  // SAVE
  // ------------------------------------------------------------

  Future<void> _toggleSave() async {
    final index = _currentVideoIndex;

    if (index >= _saved.length) {
      return;
    }

    final bool newValue = !_saved[index];

    setState(() {
      _saved[index] = newValue;

      if (newValue) {
        _saveCounts[index]++;
      } else {
        _saveCounts[index] =
            (_saveCounts[index] - 1).clamp(0, 999999999);
      }
    });

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        newValue
            ? 'ভিডিওটি Saved হয়েছে'
            : 'ভিডিওটি Unsave করা হয়েছে',
      );
      return;
    }

    final videoId = _videoIds[index];

    try {
      final saveRef = _firestore
          .collection('videos')
          .doc(videoId)
          .collection('saves')
          .doc(user.uid);

      final videoRef =
          _firestore.collection('videos').doc(videoId);

      final batch = _firestore.batch();

      if (newValue) {
        batch.set(saveRef, {
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        batch.delete(saveRef);
      }

      batch.set(
        videoRef,
        {
          'saveCount':
              FieldValue.increment(newValue ? 1 : -1),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (mounted) {
        _showMessage(
          newValue
              ? 'ভিডিওটি Saved হয়েছে'
              : 'ভিডিওটি Unsave করা হয়েছে',
        );
      }
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  // ------------------------------------------------------------
  // FOLLOW
  // ------------------------------------------------------------

  Future<void> _toggleFollow() async {
    final index = _currentVideoIndex;

    if (index >= _videoOwners.length) {
      return;
    }

    final ownerId = _videoOwners[index];

    final user = FirebaseAuth.instance.currentUser;

    if (user != null && ownerId == user.uid) {
      _showMessage('নিজের account Follow করা যাবে না');
      return;
    }

    final bool following =
        _followingUsers.contains(ownerId);

    setState(() {
      if (following) {
        _followingUsers.remove(ownerId);
      } else {
        _followingUsers.add(ownerId);
      }
    });

    if (user == null) {
      return;
    }

    try {
      final followingRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(ownerId);

      if (following) {
        await followingRef.delete();
      } else {
        await followingRef.set({
          'userId': ownerId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        _showMessage(
          following
              ? 'Unfollow করা হয়েছে'
              : 'Following করা হয়েছে',
        );
      }
    } catch (e) {
      debugPrint('Follow error: $e');
    }
  }

  // ------------------------------------------------------------
  // SHARE
  // ------------------------------------------------------------

  Future<void> _shareVideo() async {
    final index = _currentVideoIndex;

    if (index >= videoUrls.length) {
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Watch this video on PALOK 🎬\n\n${videoUrls[index]}',
        ),
      );

      setState(() {
        _shareCounts[index]++;
      });

      final videoId = _videoIds[index];

      try {
        await _firestore
            .collection('videos')
            .doc(videoId)
            .set(
          {
            'shareCount': FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint('Share count error: $e');
      }
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  // ------------------------------------------------------------
  // COMMENTS
  // ------------------------------------------------------------

  Future<void> _addComment(
    int index,
    String text,
  ) async {
    final comment = text.trim();

    if (comment.isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    final username =
        user?.displayName != null &&
                user!.displayName!.trim().isNotEmpty
            ? '@${user.displayName!.trim()}'
            : '@palok_user';

    setState(() {
      _localComments[index].insert(
        0,
        _LocalComment(
          username: username,
          text: comment,
        ),
      );

      _commentCounts[index]++;
    });

    _commentController.clear();

    final videoId = _videoIds[index];

    if (user == null) {
      return;
    }

    try {
      final batch = _firestore.batch();

      final commentRef = _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc();

      final videoRef =
          _firestore.collection('videos').doc(videoId);

      batch.set(commentRef, {
        'uid': user.uid,
        'username': username,
        'text': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        videoRef,
        {
          'commentCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Comment error: $e');
    }
  }

  void _openComments() {
    final index = _currentVideoIndex;

    if (index >= _videoIds.length) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext)
                  .viewInsets
                  .bottom,
            ),
            child: Container(
              height:
                  MediaQuery.of(sheetContext).size.height *
                      0.62,
              decoration: const BoxDecoration(
                color: Colors.black,
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
                      color: Colors.white30,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const SizedBox(width: 20),

                      Text(
                        '${_commentCounts[index]} comments',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Spacer(),

                      IconButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
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
                    child: StreamBuilder<
                        QuerySnapshot<Map<String, dynamic>>>(
                      stream: _firestore
                          .collection('videos')
                          .doc(_videoIds[index])
                          .collection('comments')
                          .orderBy(
                            'createdAt',
                            descending: true,
                          )
                          .snapshots(),
                      builder: (context, snapshot) {
                        final docs =
                            snapshot.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return ListView(
                            padding:
                                const EdgeInsets.only(
                              top: 8,
                              bottom: 10,
                            ),
                            children: [
                              _CommentItem(
                                username: '@rahim',
                                text:
                                    'দারুণ ভিডিও! 🔥',
                              ),
                              _CommentItem(
                                username: '@karim',
                                text:
                                    'PALOK দেখতে সুন্দর হচ্ছে ❤️',
                              ),
                              _CommentItem(
                                username: '@user123',
                                text:
                                    'আরও ভিডিও চাই!',
                              ),
                              ..._localComments[index]
                                  .map(
                                (comment) => _CommentItem(
                                  username:
                                      comment.username,
                                  text: comment.text,
                                ),
                              ),
                            ],
                          );
                        }

                        return ListView.builder(
                          padding:
                              const EdgeInsets.only(
                            top: 8,
                            bottom: 10,
                          ),
                          itemCount: docs.length,
                          itemBuilder:
                              (context, commentIndex) {
                            final data =
                                docs[commentIndex].data();

                            return _CommentItem(
                              username:
                                  (data['username'] ??
                                          '@user')
                                      .toString(),
                              text:
                                  (data['text'] ?? '')
                                      .toString(),
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
                      color: Colors.black,
                      border: Border(
                        top: BorderSide(
                          color: Colors.white12,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller:
                                _commentController,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            textInputAction:
                                TextInputAction.send,
                            onSubmitted: (value) {
                              _addComment(index, value);
                            },
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
                                    BorderRadius.circular(
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
                          onTap: () {
                            _addComment(
                              index,
                              _commentController.text,
                            );
                          },
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration:
                                const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFF1493),
                                  Color(0xFF00C6FF),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.send,
                              color: Colors.white,
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
      },
    );
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (searchContext) {
        return _SearchSheet(
          videoUrls: videoUrls,
          usernames: _videoUsernames,
          captions: _videoCaptions,
          hashtags: _videoHashtags,
          onVideoSelected: (index) {
            Navigator.pop(searchContext);

            Future.delayed(
              const Duration(milliseconds: 150),
              () {
                if (!mounted) return;

                final visible =
                    _visibleVideoIndexes;

                final position =
                    visible.indexOf(index);

                if (position >= 0) {
                  _pageController.animateToPage(
                    position,
                    duration: const Duration(
                      milliseconds: 350,
                    ),
                    curve: Curves.easeOut,
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------
  // TOP TAB
  // ------------------------------------------------------------

  void _switchTopTab(int index) {
    if (_topIndex == index) {
      return;
    }

    for (final controller in _videoControllers) {
      controller.pause();
    }

    setState(() {
      _topIndex = index;
    });

    final visible = _visibleVideoIndexes;

    if (visible.isNotEmpty) {
      _currentVideoIndex = visible.first;

      Future.delayed(
        const Duration(milliseconds: 50),
        () {
          if (!mounted) return;

          if (_pageController.hasClients) {
            _pageController.jumpToPage(0);
          }

          if (_currentVideoIndex <
              _videoControllers.length) {
            _videoControllers[_currentVideoIndex]
                .play();
          }
        },
      );
    }
  }

  // ------------------------------------------------------------
  // CREATE MENU
  // ------------------------------------------------------------

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.only(
            top: 18,
            bottom: 24,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF171717),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 20),

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
                icon: Icons.videocam,
                title: 'Record Video',
                subtitle:
                    'Record a new video',
                onTap: () {
                  Navigator.pop(sheetContext);

                  _showMessage(
                    'Camera recording will be added next.',
                  );
                },
              ),

              _createOption(
                icon: Icons.video_library,
                title: 'Upload Video',
                subtitle:
                    'Choose a video from your phone',
                onTap: () {
                  Navigator.pop(sheetContext);

                  Future.delayed(
                    const Duration(milliseconds: 150),
                    _pickAndUploadVideo,
                  );
                },
              ),

              _createOption(
                icon: Icons.music_note,
                title: 'Add Sound',
                subtitle:
                    'Choose music for your video',
                onTap: () {
                  Navigator.pop(sheetContext);

                  _showMessage(
                    'Sound library will be added next.',
                  );
                },
              ),
            ],
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
        horizontal: 22,
        vertical: 4,
      ),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius:
              BorderRadius.circular(15),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 26,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
        ),
      ),
      onTap: onTap,
    );
  }

  // ------------------------------------------------------------
  // PICK VIDEO
  // ------------------------------------------------------------

  Future<void> _pickAndUploadVideo() async {
    try {
      final picker = ImagePicker();

      final XFile? pickedVideo =
          await picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedVideo == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      final VideoPostDraft? draft =
          await showModalBottomSheet<VideoPostDraft>(
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

      if (mounted) {
        _showMessage(
          'ভিডিও নির্বাচন করা যায়নি।',
        );
      }
    }
  }

  // ------------------------------------------------------------
  // UPLOAD VIDEO TO FIREBASE STORAGE
  // ------------------------------------------------------------

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

      final videoId =
          _firestore.collection('videos').doc().id;

      String extension = 'mp4';

      final originalPath =
          pickedVideo.path.toLowerCase();

      if (originalPath.contains('.')) {
        extension =
            originalPath.split('.').last;
      }

      if (extension.length > 5) {
        extension = 'mp4';
      }

      final storagePath =
          'videos/${user.uid}/$videoId.$extension';

      final storageRef =
          _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: 'video/$extension',
      );

      final uploadTask =
          storageRef.putFile(
        file,
        metadata,
      );

      StreamSubscription<TaskSnapshot>?
          progressSubscription;

      progressSubscription =
          uploadTask.snapshotEvents.listen(
        (snapshot) {
          if (!mounted) return;

          final total = snapshot.totalBytes;

          if (total > 0) {
            setState(() {
              _uploadProgress =
                  snapshot.bytesTransferred /
                      total;
            });
          }
        },
      );

      await uploadTask;

      await progressSubscription.cancel();

      final downloadUrl =
          await storageRef.getDownloadURL();

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
        'storagePath': storagePath,
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

      await _firestore
          .collection('videos')
          .doc(videoId)
          .set(videoData);

      final controller =
          VideoPlayerController.networkUrl(
        Uri.parse(downloadUrl),
      );

      await controller.initialize();
      controller.setLooping(true);

      final newIndex = videoUrls.length;

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

        _videoControllers.add(controller);

        _followingUsers.add(user.uid);

        _isUploading = false;
        _uploadProgress = 1;
      });

      await Future.delayed(
        const Duration(milliseconds: 100),
      );

      if (!mounted) return;

      await _pageController.animateToPage(
        newIndex,
        duration:
            const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );

      _currentVideoIndex = newIndex;

      await controller.play();

      if (mounted) {
        setState(() {});
        _showMessage(
          '🎉 ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে!',
        );
      }
    } catch (e) {
      debugPrint('Video upload error: $e');

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });

        _showMessage(
          'ভিডিও upload করা যায়নি। আবার চেষ্টা করো।',
        );
      }
    }
  }

  // ------------------------------------------------------------
  // VIDEO INFO
  // ------------------------------------------------------------

  Widget _buildVideoInformation() {
    if (videoUrls.isEmpty ||
        _currentVideoIndex >=
            videoUrls.length) {
      return const SizedBox();
    }

    final index = _currentVideoIndex;

    final owner =
        _videoOwners[index];

    final isFollowing =
        _followingUsers.contains(owner);

    final currentUser =
        FirebaseAuth.instance.currentUser;

    final isOwnVideo =
        currentUser != null &&
            owner == currentUser.uid;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
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

            const SizedBox(width: 10),

            if (!isOwnVideo)
              GestureDetector(
                onTap: _toggleFollow,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isFollowing
                        ? Colors.white12
                        : Colors.white,
                    borderRadius:
                        BorderRadius.circular(7),
                  ),
                  child: Text(
                    isFollowing
                        ? 'Following'
                        : 'Follow',
                    style: TextStyle(
                      color: isFollowing
                          ? Colors.white
                          : Colors.black,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 9),

        if (_videoCaptions[index].isNotEmpty)
          Text(
            _videoCaptions[index],
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
            ),
          ),

        if (_videoHashtags[index].isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            _videoHashtags[index],
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

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius:
                BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.music_note,
                color: Colors.white,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                _videoSounds[index],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // RIGHT BUTTONS
  // ------------------------------------------------------------

  Widget _buildRightButtons() {
    if (videoUrls.isEmpty ||
        _currentVideoIndex >=
            videoUrls.length) {
      return const SizedBox();
    }

    final index = _currentVideoIndex;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionButton(
          icon: Icons.favorite,
          count: _likeCounts[index],
          active: _liked[index],
          onTap: _toggleLike,
        ),

        const SizedBox(height: 25),

        _actionButton(
          icon: Icons.chat_bubble,
          count: _commentCounts[index],
          onTap: _openComments,
        ),

        const SizedBox(height: 25),

        _actionButton(
          icon: Icons.bookmark,
          count: _saveCounts[index],
          active: _saved[index],
          onTap: _toggleSave,
        ),

        const SizedBox(height: 25),

        _actionButton(
          icon: Icons.share,
          count: _shareCounts[index],
          onTap: _shareVideo,
        ),

        const SizedBox(height: 24),

        GestureDetector(
          onTap: _toggleFollow,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration:
                    const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF00C6FF),
                      Color(0xFFFF1493),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 28,
                ),
              ),

              if (!_followingUsers.contains(
                _videoOwners[index],
              ))
                Positioned(
                  bottom: -4,
                  right: -3,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration:
                        const BoxDecoration(
                      color: Color(0xFFFF1744),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 17,
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
    required int count,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white12,
              ),
            ),
            child: Icon(
              icon,
              color: active
                  ? Colors.redAccent
                  : Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            _formatCount(count),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
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
    );
  }

  // ------------------------------------------------------------
  // PALOK LOGO
  // ------------------------------------------------------------

  Widget _buildPalokLogo() {
    return AnimatedBuilder(
      animation: _logoAnimationController,
      builder: (context, child) {
        return Opacity(
          opacity: _logoOpacity.value,
          child: Transform.scale(
            scale: _logoScale.value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(13),
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(0xFF00C6FF),
                        Color(0xFFFF1493),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.blueAccent,
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'P',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 7),

                const Text(
                  'Palok',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // TOP HEADER
  // ------------------------------------------------------------

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        10,
        10,
        0,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildPalokLogo(),

          const Spacer(),

          _topTab(
            title: 'For You',
            index: 0,
          ),

          const SizedBox(width: 22),

          _topTab(
            title: 'Following',
            index: 1,
          ),

          const SizedBox(width: 8),

          IconButton(
            onPressed: _openSearch,
            icon: const Icon(
              Icons.search,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topTab({
    required String title,
    required int index,
  }) {
    final selected = _topIndex == index;

    return GestureDetector(
      onTap: () {
        _switchTopTab(index);
      },
      child: Padding(
        padding:
            const EdgeInsets.only(top: 9),
        child: Column(
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

            const SizedBox(height: 6),

            AnimatedContainer(
              duration:
                  const Duration(milliseconds: 200),
              width: selected ? 30 : 0,
              height: 2,
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BOTTOM NAVIGATION
  // ------------------------------------------------------------

  Widget _buildBottomNavigation() {
    return Container(
      height: 78,
      color: Colors.black,
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
            icon: Icons.people_alt_outlined,
            label: 'Friends',
            index: 1,
          ),

          GestureDetector(
            onTap: _openCreate,
            child: Container(
              width: 58,
              height: 43,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(13),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFF00C6FF),
                    blurRadius: 12,
                    offset: Offset(-3, 0),
                  ),
                  BoxShadow(
                    color: Color(0xFFFF1493),
                    blurRadius: 12,
                    offset: Offset(3, 0),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add,
                color: Colors.black,
                size: 31,
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
    final selected = _bottomIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _bottomIndex = index;
        });

        if (index != 0) {
          _showMessage(
            '$label section will be added next.',
          );
        }
      },
      child: SizedBox(
        width: 60,
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

            const SizedBox(height: 3),

            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white60,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // VIDEO WIDGET
  // ------------------------------------------------------------

  Widget _buildVideo(int index) {
    if (index >=
        _videoControllers.length) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    final controller =
        _videoControllers[index];

    if (!controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _toggleVideo(index);
      },
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width:
                controller.value.size.width,
            height:
                controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY FOLLOWING
  // ------------------------------------------------------------

  Widget _buildFollowingEmpty() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              color: Colors.white,
              size: 55,
            ),
            SizedBox(height: 14),
            Text(
              'Follow creators to see their videos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Follow someone from For You',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final visible =
        _visibleVideoIndexes;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (visible.isEmpty)
            _buildFollowingEmpty()
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: visible.length,
              onPageChanged:
                  _onVideoChanged,
              itemBuilder:
                  (context, visibleIndex) {
                final realIndex =
                    visible[visibleIndex];

                return _buildVideo(
                  realIndex,
                );
              },
            ),

          // TOP HEADER
          SafeArea(
            child: _buildTopHeader(),
          ),

          // RIGHT BUTTONS
          if (visible.isNotEmpty)
            Positioned(
              right: 10,
              bottom: 116,
              child: _buildRightButtons(),
            ),

          // VIDEO INFORMATION
          if (visible.isNotEmpty)
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
              child: _buildBottomNavigation(),
            ),
          ),

          // UPLOAD PROGRESS
          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(
                  0.78,
                ),
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
                          const Color(0xFF171717),
                      borderRadius:
                          BorderRadius.circular(
                        22,
                      ),
                    ),
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_upload,
                          color: Colors.white,
                          size: 48,
                        ),

                        const SizedBox(height: 15),

                        const Text(
                          'Uploading video...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 18),

                        LinearProgressIndicator(
                          value:
                              _uploadProgress,
                          minHeight: 7,
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          '${(_uploadProgress * 100).toInt()}%',
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

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  int _toInt(
    dynamic value,
    int fallback,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return fallback;
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }

    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }

    return count.toString();
  }

  void _showMessage(String message) {
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

  // ------------------------------------------------------------
  // DISPOSE
  // ------------------------------------------------------------

  @override
  void dispose() {
    _pageController.dispose();

    _logoAnimationController.dispose();

    _commentController.dispose();

    for (final controller
        in _videoControllers) {
      controller.dispose();
    }

    super.dispose();
  }
}

// ==================================================================
// LOCAL COMMENT MODEL
// ==================================================================

class _LocalComment {
  final String username;
  final String text;

  _LocalComment({
    required this.username,
    required this.text,
  });
}

// ==================================================================
// COMMENT ITEM
// ==================================================================

class _CommentItem extends StatelessWidget {
  final String username;
  final String text;

  const _CommentItem({
    required this.username,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 9,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFF00C6FF),
                  Color(0xFFFF1493),
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
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// VIDEO POST DRAFT
// ==================================================================

class VideoPostDraft {
  final String caption;
  final String hashtags;

  VideoPostDraft({
    required this.caption,
    required this.hashtags,
  });
}

// ==================================================================
// VIDEO UPLOAD SHEET
// ==================================================================

class _VideoUploadSheet extends StatefulWidget {
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
      _hashtagController =
      TextEditingController();

  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    _previewController =
        VideoPlayerController.file(
      File(widget.videoFile.path),
    );

    _initializePreview();
  }

  Future<void> _initializePreview() async {
    try {
      await _previewController
          .initialize();

      _previewController.setLooping(true);

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

  @override
  void dispose() {
    _previewController.dispose();

    _captionController.dispose();

    _hashtagController.dispose();

    super.dispose();
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
                0.88,
        decoration:
            const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius:
              BorderRadius.vertical(
            top: Radius.circular(26),
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
                color: Colors.white30,
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
                12,
                10,
                10,
              ),
              child: Row(
                children: [
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

                  const Expanded(
                    child: Text(
                      'Post Video',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
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

            // VIDEO PREVIEW
            Container(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      0.42,
              margin:
                  const EdgeInsets.symmetric(
                horizontal: 18,
              ),
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
              child: _initialized
                  ? GestureDetector(
                      onTap: () {
                        if (_previewController
                            .value
                            .isPlaying) {
                          _previewController
                              .pause();
                        } else {
                          _previewController
                              .play();
                        }

                        setState(() {});
                      },
                      child: Center(
                        child: AspectRatio(
                          aspectRatio:
                              _previewController
                                  .value
                                  .aspectRatio,
                          child: VideoPlayer(
                            _previewController,
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child:
                          CircularProgressIndicator(
                        color: Colors.white,
                      ),
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
                  children: [
                    TextField(
                      controller:
                          _captionController,
                      style:
                          const TextStyle(
                        color: Colors.white,
                      ),
                      maxLines: 3,
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
                            14,
                          ),
                          borderSide:
                              BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller:
                          _hashtagController,
                      style:
                          const TextStyle(
                        color: Colors.white,
                      ),
                      decoration:
                          InputDecoration(
                        hintText:
                            '#palok #foryou #viral',
                        hintStyle:
                            const TextStyle(
                          color:
                              Colors.white54,
                        ),
                        prefixIcon:
                            const Icon(
                          Icons.tag,
                          color:
                              Colors.white70,
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

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            _initialized
                                ? _postVideo
                                : null,
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              Colors.white,
                          foregroundColor:
                              Colors.black,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _postVideo() {
    Navigator.pop(
      context,
      VideoPostDraft(
        caption:
            _captionController.text.trim(),
        hashtags:
            _hashtagController.text.trim(),
      ),
    );
  }
}

// ==================================================================
// SEARCH SHEET
// ==================================================================

class _SearchSheet extends StatefulWidget {
  final List<String> videoUrls;
  final List<String> usernames;
  final List<String> captions;
  final List<String> hashtags;

  final Function(int index)
      onVideoSelected;

  const _SearchSheet({
    required this.videoUrls,
    required this.usernames,
    required this.captions,
    required this.hashtags,
    required this.onVideoSelected,
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

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<int> get _results {
    if (_query.trim().isEmpty) {
      return List.generate(
        widget.videoUrls.length,
        (index) => index,
      );
    }

    final q =
        _query.toLowerCase().trim();

    final result = <int>[];

    for (int i = 0;
        i < widget.videoUrls.length;
        i++) {
      final username =
          widget.usernames[i]
              .toLowerCase();

      final caption =
          widget.captions[i]
              .toLowerCase();

      final hashtags =
          widget.hashtags[i]
              .toLowerCase();

      if (username.contains(q) ||
          caption.contains(q) ||
          hashtags.contains(q)) {
        result.add(i);
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              10,
              12,
              10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration:
                        BoxDecoration(
                      color: Colors.white10,
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: TextField(
                      controller:
                          _searchController,
                      autofocus: true,
                      style:
                          const TextStyle(
                        color: Colors.white,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Search PALOK...',
                        hintStyle:
                            TextStyle(
                          color:
                              Colors.white54,
                        ),
                        prefixIcon:
                            Icon(
                          Icons.search,
                          color:
                              Colors.white70,
                        ),
                        border:
                            InputBorder.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'No results found',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        _results.length,
                    itemBuilder:
                        (context, resultIndex) {
                      final index =
                          _results[
                              resultIndex];

                      return ListTile(
                        contentPadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading:
                            Container(
                          width: 55,
                          height: 55,
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.white10,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons.play_arrow,
                            color:
                                Colors.white,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          widget.usernames[
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
                          widget.captions[
                              index],
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Colors.white60,
                          ),
                        ),
                        onTap: () {
                          widget
                              .onVideoSelected(
                            index,
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
}
