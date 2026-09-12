import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ================================================================
  // CURRENT PAGE
  // ================================================================
  int _bottomIndex = 0;
  int _topIndex = 0;
  int _currentIndex = 0;

  late PageController _pageController;

  // ================================================================
  // PALOK LOGO ANIMATION
  // ================================================================
  late AnimationController _logoAnimationController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // ================================================================
  // FIREBASE
  // ================================================================
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  String? get _uid =>
      FirebaseAuth.instance.currentUser?.uid;

  // ================================================================
  // VIDEO DATA
  // ================================================================
  final List<String> videoUrls = [
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
  ];

  final List<String> videoIds = [
    'demo_video_0',
    'demo_video_1',
  ];

  final List<String> videoUsernames = [
    '@palok_user',
    '@palok_user',
  ];

  final List<String> videoCaptions = [
    'Welcome to PALOK 🎬',
    'PALOK Short Video 🎬',
  ];

  final List<String> videoHashtags = [
    '#Palok #ShortVideo #Bangladesh',
    '#Palok #ShortVideo #Bangladesh',
  ];

  final List<VideoPlayerController> _videoControllers = [];

  // ================================================================
  // LIKE / SAVE / FOLLOW
  // ================================================================
  final List<bool> _liked = [false, false];
  final List<bool> _saved = [false, false];

  bool _following = false;

  // ================================================================
  // COUNTS
  // ================================================================
  final List<int> _likeCounts = [11700, 8500];
  final List<int> _commentCounts = [234, 128];
  final List<int> _saveCounts = [811, 452];
  final List<int> _shareCounts = [431, 203];

  // ================================================================
  // COMMENT
  // ================================================================
  final TextEditingController _commentController =
      TextEditingController();

  // ================================================================
  // INIT
  // ================================================================
  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    // --------------------------------------------------------------
    // LOGO ANIMATION
    // --------------------------------------------------------------
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

    // --------------------------------------------------------------
    // START FIREBASE
    // --------------------------------------------------------------
    _prepareFirebase();

    // --------------------------------------------------------------
    // LOAD VIDEOS
    // --------------------------------------------------------------
    _loadVideos();
  }

  // ================================================================
  // FIREBASE AUTH
  // ================================================================
  Future<void> _prepareFirebase() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      await _loadFirebaseState();
    } catch (e) {
      debugPrint('Firebase Auth error: $e');

      if (mounted) {
        _showMessage(
          'Firebase login চালু নেই। Anonymous Sign-in চালু করুন।',
        );
      }
    }
  }

  // ================================================================
  // LOAD VIDEOS
  // ================================================================
  void _loadVideos() {
    for (int i = 0; i < videoUrls.length; i++) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrls[i]),
      );

      _videoControllers.add(controller);

      controller.initialize().then((_) {
        if (!mounted) return;

        controller.setLooping(true);

        setState(() {});

        // শুধু প্রথম ভিডিও Auto Play
        if (i == 0) {
          controller.play();
        }
      }).catchError((error) {
        debugPrint('Video loading error: $error');
      });
    }
  }

  // ================================================================
  // LOAD FIREBASE STATE
  // ================================================================
  Future<void> _loadFirebaseState() async {
    final uid = _uid;

    if (uid == null) return;

    try {
      for (int i = 0; i < videoIds.length; i++) {
        final videoRef = _firestore
            .collection('videos')
            .doc(videoIds[i]);

        final videoDoc = await videoRef.get();

        if (videoDoc.exists) {
          final data = videoDoc.data();

          if (data != null) {
            final likeCount =
                (data['likeCount'] as num?)?.toInt();

            final commentCount =
                (data['commentCount'] as num?)?.toInt();

            final saveCount =
                (data['saveCount'] as num?)?.toInt();

            final shareCount =
                (data['shareCount'] as num?)?.toInt();

            if (mounted) {
              setState(() {
                if (likeCount != null) {
                  _likeCounts[i] = likeCount;
                }

                if (commentCount != null) {
                  _commentCounts[i] = commentCount;
                }

                if (saveCount != null) {
                  _saveCounts[i] = saveCount;
                }

                if (shareCount != null) {
                  _shareCounts[i] = shareCount;
                }
              });
            }
          }
        }

        final likeDoc = await videoRef
            .collection('likes')
            .doc(uid)
            .get();

        final saveDoc = await videoRef
            .collection('saves')
            .doc(uid)
            .get();

        if (!mounted) return;

        setState(() {
          _liked[i] = likeDoc.exists;
          _saved[i] = saveDoc.exists;
        });
      }

      final followDoc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .doc('palok_user')
          .get();

      if (!mounted) return;

      setState(() {
        _following = followDoc.exists;
      });
    } catch (e) {
      debugPrint('Firebase state error: $e');
    }
  }

  // ================================================================
  // DISPOSE
  // ================================================================
  @override
  void dispose() {
    _pageController.dispose();
    _logoAnimationController.dispose();
    _commentController.dispose();

    for (final controller in _videoControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  // ================================================================
  // CURRENT VIDEO
  // ================================================================
  int get _currentVideo {
    return _currentIndex.clamp(
      0,
      videoUrls.length - 1,
    );
  }

  // ================================================================
  // VIDEO CHANGE
  // ================================================================
  void _onVideoChanged(int index) {
    _currentIndex = index;

    for (int i = 0; i < _videoControllers.length; i++) {
      final controller = _videoControllers[i];

      if (!controller.value.isInitialized) {
        continue;
      }

      if (i == index) {
        controller.play();
      } else {
        controller.pause();
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ================================================================
  // VIDEO PLAY / PAUSE
  // ================================================================
  void _toggleVideo(int index) {
    if (index >= _videoControllers.length) {
      return;
    }

    final controller = _videoControllers[index];

    if (!controller.value.isInitialized) {
      return;
    }

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  // ================================================================
  // LIKE
  // ================================================================
  Future<void> _toggleLike() async {
    final index = _currentVideo;
    final uid = _uid;

    if (uid == null) {
      _showMessage('Firebase login হচ্ছে...');
      return;
    }

    final videoRef = _firestore
        .collection('videos')
        .doc(videoIds[index]);

    final likeRef = videoRef
        .collection('likes')
        .doc(uid);

    final wasLiked = _liked[index];

    // UI instantly update
    setState(() {
      _liked[index] = !wasLiked;

      if (!wasLiked) {
        _likeCounts[index]++;
      } else if (_likeCounts[index] > 0) {
        _likeCounts[index]--;
      }
    });

    try {
      if (!wasLiked) {
        await likeRef.set({
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await videoRef.set({
          'likeCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await likeRef.delete();

        await videoRef.set({
          'likeCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Like error: $e');

      // Firebase fail হলে UI আগের অবস্থায় ফেরত
      if (mounted) {
        setState(() {
          _liked[index] = wasLiked;

          if (!wasLiked) {
            if (_likeCounts[index] > 0) {
              _likeCounts[index]--;
            }
          } else {
            _likeCounts[index]++;
          }
        });
      }

      _showMessage('Like করতে সমস্যা হয়েছে');
    }
  }

  // ================================================================
  // SAVE
  // ================================================================
  Future<void> _toggleSave() async {
    final index = _currentVideo;
    final uid = _uid;

    if (uid == null) {
      _showMessage('Firebase login হচ্ছে...');
      return;
    }

    final videoRef = _firestore
        .collection('videos')
        .doc(videoIds[index]);

    final saveRef = videoRef
        .collection('saves')
        .doc(uid);

    final wasSaved = _saved[index];

    setState(() {
      _saved[index] = !wasSaved;

      if (!wasSaved) {
        _saveCounts[index]++;
      } else if (_saveCounts[index] > 0) {
        _saveCounts[index]--;
      }
    });

    try {
      if (!wasSaved) {
        await saveRef.set({
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await videoRef.set({
          'saveCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await saveRef.delete();

        await videoRef.set({
          'saveCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _showMessage(
        !wasSaved
            ? 'ভিডিওটি Saved হয়েছে 🔖'
            : 'ভিডিওটি Unsave করা হয়েছে',
      );
    } catch (e) {
      debugPrint('Save error: $e');

      if (mounted) {
        setState(() {
          _saved[index] = wasSaved;

          if (!wasSaved) {
            if (_saveCounts[index] > 0) {
              _saveCounts[index]--;
            }
          } else {
            _saveCounts[index]++;
          }
        });
      }

      _showMessage('Save করতে সমস্যা হয়েছে');
    }
  }

  // ================================================================
  // FOLLOW
  // ================================================================
  Future<void> _toggleFollow() async {
    final uid = _uid;

    if (uid == null) {
      _showMessage('Firebase login হচ্ছে...');
      return;
    }

    final wasFollowing = _following;

    setState(() {
      _following = !wasFollowing;
    });

    final followRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc('palok_user');

    try {
      if (!wasFollowing) {
        await followRef.set({
          'username': '@palok_user',
          'createdAt': FieldValue.serverTimestamp(),
        });

        _showMessage('@palok_user Followed ✓');
      } else {
        await followRef.delete();

        _showMessage('@palok_user Unfollowed');
      }
    } catch (e) {
      debugPrint('Follow error: $e');

      if (mounted) {
        setState(() {
          _following = wasFollowing;
        });
      }

      _showMessage('Follow করতে সমস্যা হয়েছে');
    }
  }

  // ================================================================
  // SHARE
  // ================================================================
  Future<void> _shareVideo() async {
    final index = _currentVideo;

    final String shareText =
        'Watch this video on PALOK 🎬\n\n'
        'PALOK Short Video\n'
        '${videoUrls[index]}';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'PALOK Short Video',
        ),
      );

      if (!mounted) return;

      setState(() {
        _shareCounts[index]++;
      });

      final uid = _uid;

      if (uid != null) {
        await _firestore
            .collection('videos')
            .doc(videoIds[index])
            .set({
          'shareCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  // ================================================================
  // SEARCH
  // ================================================================
  void _openSearch() {
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSearchState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.92,
              child: Column(
                children: [
                  // ------------------------------------------------
                  // SEARCH HEADER
                  // ------------------------------------------------
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      12,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(sheetContext);
                          },
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF252525),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: searchController,
                              autofocus: true,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textInputAction:
                                  TextInputAction.search,
                              onChanged: (_) {
                                setSearchState(() {});
                              },
                              onSubmitted: (_) {
                                setSearchState(() {});
                              },
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.white70,
                                ),
                                hintText:
                                    'Search videos, users...',
                                hintStyle: TextStyle(
                                  color: Colors.white54,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(
                    color: Colors.white12,
                    height: 1,
                  ),

                  // ------------------------------------------------
                  // SEARCH RESULTS
                  // ------------------------------------------------
                  Expanded(
                    child: _buildSearchResults(
                      searchController.text,
                      sheetContext,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      searchController.dispose();
    });
  }

  // ================================================================
  // SEARCH RESULTS
  // ================================================================
  Widget _buildSearchResults(
    String query,
    BuildContext sheetContext,
  ) {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      return const Center(
        child: Text(
          'Search PALOK',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 17,
          ),
        ),
      );
    }

    final results = <int>[];

    for (int i = 0; i < videoUrls.length; i++) {
      final username =
          videoUsernames[i].toLowerCase();

      final caption =
          videoCaptions[i].toLowerCase();

      final hashtags =
          videoHashtags[i].toLowerCase();

      if (username.contains(q) ||
          caption.contains(q) ||
          hashtags.contains(q)) {
        results.add(i);
      }
    }

    if (results.isEmpty) {
      return Center(
        child: Text(
          'কোনো ফলাফল পাওয়া যায়নি',
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, position) {
        final index = results[position];

        return GestureDetector(
          onTap: () {
            Navigator.pop(sheetContext);

            _pageController.animateToPage(
              index,
              duration: const Duration(
                milliseconds: 350,
              ),
              curve: Curves.easeInOut,
            );
          },
          child: Container(
            margin: const EdgeInsets.only(
              bottom: 12,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        videoUsernames[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight:
                              FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        videoCaptions[index],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        videoHashtags[index],
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================================================================
  // COMMENTS
  // ================================================================
  void _openComments() {
    final index = _currentVideo;
    final videoId = videoIds[index];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      useSafeArea: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext)
                .viewInsets
                .bottom,
          ),
          child: SizedBox(
            height:
                MediaQuery.of(sheetContext).size.height *
                    0.72,
            child: Column(
              children: [
                // --------------------------------------------------
                // HEADER
                // --------------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Comments',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        _formatCount(
                          _commentCounts[index],
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(
                            sheetContext,
                          );
                        },
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(
                  color: Colors.white12,
                  height: 1,
                ),

                // --------------------------------------------------
                // COMMENTS LIST
                // --------------------------------------------------
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('videos')
                        .doc(videoId)
                        .collection('comments')
                        .orderBy(
                          'createdAt',
                          descending: true,
                        )
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Comments load করতে সমস্যা হয়েছে',
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.pinkAccent,
                          ),
                        );
                      }

                      final docs =
                          snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.all(
                            16,
                          ),
                          children: const [
                            _CommentItem(
                              username: '@rahim',
                              comment:
                                  'ভিডিওটা অনেক সুন্দর হয়েছে ❤️',
                            ),
                            _CommentItem(
                              username: '@karim',
                              comment:
                                  'PALOK অনেক ভালো লাগছে 🔥',
                            ),
                            _CommentItem(
                              username: '@user123',
                              comment:
                                  'Nice video!',
                            ),
                          ],
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(
                          16,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final data =
                              docs[i].data()
                                  as Map<String, dynamic>;

                          return _CommentItem(
                            username:
                                data['username'] ??
                                    '@user',
                            comment:
                                data['text'] ?? '',
                          );
                        },
                      );
                    },
                  ),
                ),

                // --------------------------------------------------
                // COMMENT INPUT
                // --------------------------------------------------
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    14,
                    10,
                    10,
                    10,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF111111),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller:
                              _commentController,
                          textInputAction:
                              TextInputAction.send,
                          onSubmitted: (_) {
                            _addComment(
                              index,
                              videoId,
                              sheetContext,
                            );
                          },
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
                                const Color(0xFF292929),
                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      25),
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
                            videoId,
                            sheetContext,
                          );
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration:
                              const BoxDecoration(
                            color: Colors.pink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
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
      },
    );
  }

  // ================================================================
  // ADD COMMENT
  // ================================================================
  Future<void> _addComment(
    int index,
    String videoId,
    BuildContext sheetContext,
  ) async {
    final uid = _uid;

    final text =
        _commentController.text.trim();

    if (uid == null) {
      _showMessage(
        'Firebase login হচ্ছে...',
      );
      return;
    }

    if (text.isEmpty) {
      return;
    }

    // আগে text রেখে দিচ্ছি
    _commentController.clear();

    FocusScope.of(sheetContext).unfocus();

    try {
      await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .add({
        'uid': uid,
        'username': '@palok_user',
        'text': text,
        'createdAt':
            FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('videos')
          .doc(videoId)
          .set({
        'commentCount':
            FieldValue.increment(1),
        'updatedAt':
            FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _commentCounts[index]++;
      });

      _showMessage('Comment পাঠানো হয়েছে ✓');
    } catch (e) {
      debugPrint('Comment error: $e');

      // Firebase fail করলে text আবার input-এ
      _commentController.text = text;

      _showMessage(
        'Comment পাঠানো যায়নি',
      );
    }
  }

  // ================================================================
  // CREATE
  // ================================================================
  void _openCreate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Create on PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                _createOption(
                  icon: Icons.videocam_outlined,
                  title: 'Record Video',
                  onTap: () {
                    Navigator.pop(context);
                    _showMessage(
                      'Camera option selected',
                    );
                  },
                ),
                const SizedBox(height: 12),
                _createOption(
                  icon:
                      Icons.photo_library_outlined,
                  title: 'Upload Video',
                  onTap: () {
                    Navigator.pop(context);
                    _showMessage(
                      'Gallery option selected',
                    );
                  },
                ),
                const SizedBox(height: 12),
                _createOption(
                  icon: Icons.music_note,
                  title: 'Add Sound',
                  onTap: () {
                    Navigator.pop(context);
                    _showMessage(
                      'Sound option selected',
                    );
                  },
                ),
                const SizedBox(height: 12),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 15),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // BOTTOM NAV
  // ================================================================
  void _selectBottom(int index) {
    setState(() {
      _bottomIndex = index;
    });

    if (index == 2) {
      _openCreate();
      return;
    }

    if (index == 0) {
      _showMessage('Home');
    } else if (index == 1) {
      _showMessage('Friends');
    } else if (index == 3) {
      _showMessage('Inbox');
    } else if (index == 4) {
      _showMessage('Profile');
    }
  }

  // ================================================================
  // MESSAGE
  // ================================================================
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ================================================================
  // MAIN UI
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ========================================================
          // FULL SCREEN VIDEO
          // ========================================================
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: videoUrls.length,
            onPageChanged: _onVideoChanged,
            itemBuilder: (context, index) {
              return _buildVideo(index);
            },
          ),

          // ========================================================
          // TOP HEADER
          // ========================================================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 10,
                left: 18,
                right: 18,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  AnimatedBuilder(
                    animation:
                        _logoAnimationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScale.value,
                        alignment:
                            Alignment.centerLeft,
                        child: Opacity(
                          opacity:
                              _logoOpacity.value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildPalokLogo(),
                  ),

                  const Spacer(),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _topIndex = 0;
                      });

                      _showMessage('For You');
                    },
                    child: _topTab(
                      title: 'For You',
                      selected: _topIndex == 0,
                    ),
                  ),

                  const SizedBox(width: 28),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _topIndex = 1;
                      });

                      _showMessage('Following');
                    },
                    child: _topTab(
                      title: 'Following',
                      selected: _topIndex == 1,
                    ),
                  ),

                  const SizedBox(width: 24),

                  GestureDetector(
                    onTap: _openSearch,
                    child: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ========================================================
          // RIGHT SIDE BUTTONS
          // ========================================================
          Positioned(
            right: 10,
            bottom: 116,
            child: _buildRightButtons(),
          ),

          // ========================================================
          // VIDEO INFORMATION
          // ========================================================
          Positioned(
            left: 18,
            right: 92,
            bottom: 124,
            child: _buildVideoInformation(),
          ),

          // ========================================================
          // BOTTOM NAVIGATION
          // ========================================================
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

  // ================================================================
  // LOGO
  // ================================================================
  Widget _buildPalokLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(13),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFFF3B81),
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Text(
                'P',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Positioned(
                right: 7,
                top: 12,
                child: Container(
                  width: 0,
                  height: 0,
                  decoration:
                      const BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Color(0xFFFF176B),
                        width: 9,
                      ),
                      top: BorderSide(
                        color: Colors.transparent,
                        width: 6,
                      ),
                      bottom: BorderSide(
                        color: Colors.transparent,
                        width: 6,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        const Text(
          'Palok',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // ================================================================
  // TOP TAB
  // ================================================================
  Widget _topTab({
    required String title,
    required bool selected,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: selected
                ? FontWeight.w800
                : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration:
              const Duration(milliseconds: 180),
          width: selected ? 42 : 0,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // RIGHT BUTTONS
  // ================================================================
  Widget _buildRightButtons() {
    final index = _currentVideo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionButton(
          icon: _liked[index]
              ? Icons.favorite
              : Icons.favorite_border,
          count:
              _formatCount(_likeCounts[index]),
          active: _liked[index],
          onTap: _toggleLike,
        ),

        const SizedBox(height: 25),

        _actionButton(
          icon: Icons.chat_bubble_outline,
          count:
              _formatCount(_commentCounts[index]),
          onTap: _openComments,
        ),

        const SizedBox(height: 25),

        _actionButton(
          icon: _saved[index]
              ? Icons.bookmark
              : Icons.bookmark_border,
          count:
              _formatCount(_saveCounts[index]),
          active: _saved[index],
          onTap: _toggleSave,
        ),

        const SizedBox(height: 25),

        _actionButton(
          icon: Icons.share_outlined,
          count:
              _formatCount(_shareCounts[index]),
          onTap: _shareVideo,
        ),

        const SizedBox(height: 24),

        GestureDetector(
          onTap: _toggleFollow,
          child: SizedBox(
            width: 54,
            height: 62,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1.8,
                    ),
                  ),
                  child: Icon(
                    _following
                        ? Icons.person
                        : Icons.person_outline,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
                if (!_following)
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child: Container(
                      width: 23,
                      height: 23,
                      decoration:
                          const BoxDecoration(
                        color: Colors.red,
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
        ),
      ],
    );
  }

  // ================================================================
  // ACTION BUTTON
  // ================================================================
  Widget _actionButton({
    required IconData icon,
    required String count,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 54,
        child: Column(
          children: [
            Icon(
              icon,
              color: active
                  ? Colors.redAccent
                  : Colors.white,
              size: 31,
            ),
            const SizedBox(height: 5),
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // VIDEO INFORMATION
  // ================================================================
  Widget _buildVideoInformation() {
    final index = _currentVideo;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              videoUsernames[index],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _toggleFollow,
              child: Text(
                _following
                    ? 'Following'
                    : 'Follow',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          videoCaptions[index],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          videoHashtags[index],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.48),
            borderRadius:
                BorderRadius.circular(25),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 7),
              Text(
                'Original Sound - PALOK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================================================================
  // BOTTOM NAVIGATION
  // ================================================================
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
            icon: Icons.people_outline,
            label: 'Friends',
            index: 1,
          ),

          GestureDetector(
            onTap: () {
              _selectBottom(2);
            },
            child: Container(
              width: 58,
              height: 43,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(13),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFF00E5FF),
                    offset: Offset(-3, 0),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: Color(0xFFFF176B),
                    offset: Offset(3, 0),
                    blurRadius: 0,
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

  // ================================================================
  // BOTTOM BUTTON
  // ================================================================
  Widget _bottomButton({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final selected = _bottomIndex == index;

    return GestureDetector(
      onTap: () {
        _selectBottom(index);
      },
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: selected ? 28 : 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // VIDEO
  // ================================================================
  Widget _buildVideo(int index) {
    if (index >= _videoControllers.length) {
      return const SizedBox();
    }

    final controller =
        _videoControllers[index];

    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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

  // ================================================================
  // COUNT FORMAT
  // ================================================================
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }

    if (count >= 1000) {
      final value = count / 1000;

      if (value >= 10) {
        return '${value.toStringAsFixed(0)}K';
      }

      return '${value.toStringAsFixed(1)}K';
    }

    return count.toString();
  }
}

// ==================================================================
// COMMENT ITEM
// ==================================================================
class _CommentItem extends StatelessWidget {
  final String username;
  final String comment;

  const _CommentItem({
    required this.username,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white12,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
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
