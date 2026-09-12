import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'upload_video_screen.dart';

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

  late PageController _pageController;

  // ================================================================
  // PALOK LOGO
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
  // DEMO VIDEOS
  // ================================================================

  final List<String> videoUrls = [
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
  ];

  final List<VideoPlayerController> _videoControllers = [];

  // ================================================================
  // LIKE / SAVE
  // ================================================================

  final List<bool> _liked = [
    false,
    false,
  ];

  final List<bool> _saved = [
    false,
    false,
  ];

  bool _following = false;

  // ================================================================
  // COUNTS
  // ================================================================

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
      duration: const Duration(
        milliseconds: 1800,
      ),
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
    // LOAD VIDEOS
    // --------------------------------------------------------------

    _loadVideos();

    // --------------------------------------------------------------
    // LOAD FIREBASE STATE
    // --------------------------------------------------------------

    _loadFirebaseState();
  }

  // ================================================================
  // LOAD VIDEOS
  // ================================================================

  void _loadVideos() {
    for (final url in videoUrls) {
      final controller =
          VideoPlayerController.networkUrl(
        Uri.parse(url),
      );

      _videoControllers.add(controller);

      controller.initialize().then((_) async {
        if (!mounted) return;

        await controller.setLooping(true);

        if (_videoControllers.indexOf(controller) == 0) {
          await controller.play();
        }

        if (mounted) {
          setState(() {});
        }
      }).catchError((error) {
        debugPrint(
          'Video loading error: $error',
        );
      });
    }
  }

  // ================================================================
  // FIREBASE STATE
  // ================================================================

  Future<void> _loadFirebaseState() async {
    final uid = _uid;

    if (uid == null) return;

    try {
      for (int i = 0;
          i < videoUrls.length;
          i++) {
        final videoId =
            'demo_video_$i';

        final likeDoc =
            await _firestore
                .collection('videos')
                .doc(videoId)
                .collection('likes')
                .doc(uid)
                .get();

        final saveDoc =
            await _firestore
                .collection('videos')
                .doc(videoId)
                .collection('saves')
                .doc(uid)
                .get();

        if (!mounted) return;

        setState(() {
          _liked[i] =
              likeDoc.exists;

          _saved[i] =
              saveDoc.exists;
        });
      }

      final followDoc =
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('following')
              .doc('palok_user')
              .get();

      if (!mounted) return;

      setState(() {
        _following =
            followDoc.exists;
      });
    } catch (e) {
      debugPrint(
        'Firebase state loading error: $e',
      );
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

    for (final controller
        in _videoControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  // ================================================================
  // CURRENT VIDEO
  // ================================================================

  int get _currentVideo {
    if (_pageController.hasClients &&
        _pageController.page != null) {
      return _pageController.page!
          .round()
          .clamp(
            0,
            videoUrls.length - 1,
          );
    }

    return 0;
  }

  // ================================================================
  // VIDEO CHANGED
  // ================================================================

  void _onVideoChanged(int index) {
    for (int i = 0;
        i < _videoControllers.length;
        i++) {
      final controller =
          _videoControllers[i];

      if (!controller
          .value
          .isInitialized) {
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
  // PLAY / PAUSE
  // ================================================================

  void _toggleVideo(int index) {
    if (index >=
        _videoControllers.length) {
      return;
    }

    final controller =
        _videoControllers[index];

    if (!controller
        .value
        .isInitialized) {
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
      _showMessage(
        'Please login first',
      );
      return;
    }

    final videoId =
        'demo_video_$index';

    final wasLiked =
        _liked[index];

    setState(() {
      _liked[index] =
          !wasLiked;

      if (_liked[index]) {
        _likeCounts[index]++;
      } else if (_likeCounts[index] > 0) {
        _likeCounts[index]--;
      }
    });

    try {
      final likeRef =
          _firestore
              .collection('videos')
              .doc(videoId)
              .collection('likes')
              .doc(uid);

      if (!wasLiked) {
        await likeRef.set({
          'uid': uid,
          'createdAt':
              FieldValue.serverTimestamp(),
        });
      } else {
        await likeRef.delete();
      }

      await _firestore
          .collection('videos')
          .doc(videoId)
          .set({
        'likeCount':
            _likeCounts[index],
        'updatedAt':
            FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      setState(() {
        _liked[index] =
            wasLiked;

        if (wasLiked) {
          _likeCounts[index]++;
        } else if (_likeCounts[index] > 0) {
          _likeCounts[index]--;
        }
      });

      debugPrint(
        'Like error: $e',
      );

      _showMessage(
        'Like করতে সমস্যা হয়েছে',
      );
    }
  }

  // ================================================================
  // SAVE
  // ================================================================

  Future<void> _toggleSave() async {
    final index = _currentVideo;

    final uid = _uid;

    if (uid == null) {
      _showMessage(
        'Please login first',
      );
      return;
    }

    final videoId =
        'demo_video_$index';

    final wasSaved =
        _saved[index];

    setState(() {
      _saved[index] =
          !wasSaved;

      if (_saved[index]) {
        _saveCounts[index]++;
      } else if (_saveCounts[index] > 0) {
        _saveCounts[index]--;
      }
    });

    try {
      final saveRef =
          _firestore
              .collection('videos')
              .doc(videoId)
              .collection('saves')
              .doc(uid);

      if (!wasSaved) {
        await saveRef.set({
          'uid': uid,
          'createdAt':
              FieldValue.serverTimestamp(),
        });
      } else {
        await saveRef.delete();
      }

      await _firestore
          .collection('videos')
          .doc(videoId)
          .set({
        'saveCount':
            _saveCounts[index],
        'updatedAt':
            FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showMessage(
        _saved[index]
            ? 'ভিডিওটি Saved হয়েছে'
            : 'ভিডিওটি Unsave করা হয়েছে',
      );
    } catch (e) {
      setState(() {
        _saved[index] =
            wasSaved;

        if (wasSaved) {
          _saveCounts[index]++;
        } else if (_saveCounts[index] > 0) {
          _saveCounts[index]--;
        }
      });

      debugPrint(
        'Save error: $e',
      );

      _showMessage(
        'Save করতে সমস্যা হয়েছে',
      );
    }
  }

  // ================================================================
  // FOLLOW
  // ================================================================

  Future<void> _toggleFollow() async {
    final uid = _uid;

    if (uid == null) {
      _showMessage(
        'Please login first',
      );
      return;
    }

    final wasFollowing =
        _following;

    setState(() {
      _following =
          !wasFollowing;
    });

    try {
      final followRef =
          _firestore
              .collection('users')
              .doc(uid)
              .collection('following')
              .doc('palok_user');

      if (!wasFollowing) {
        await followRef.set({
          'username':
              '@palok_user',
          'createdAt':
              FieldValue.serverTimestamp(),
        });
      } else {
        await followRef.delete();
      }

      _showMessage(
        _following
            ? '@palok_user কে Follow করা হয়েছে'
            : '@palok_user কে Unfollow করা হয়েছে',
      );
    } catch (e) {
      setState(() {
        _following =
            wasFollowing;
      });

      debugPrint(
        'Follow error: $e',
      );

      _showMessage(
        'Follow করতে সমস্যা হয়েছে',
      );
    }
  }

  // ================================================================
  // SHARE
  // ================================================================

  Future<void> _shareVideo() async {
    final index =
        _currentVideo;

    final String shareText =
        'Watch this video on PALOK 🎬\n\n'
        'PALOK Short Video\n'
        '${videoUrls[index]}';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
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
            .doc(
              'demo_video_$index',
            )
            .set({
          'shareCount':
              _shareCounts[index],
          'updatedAt':
              FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint(
        'Share error: $e',
      );
    }
  }

  // ================================================================
  // SEARCH
  // ================================================================

  void _openSearch() {
    final controller =
        TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(sheetContext)
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
              color: Color(0xFF101010),
              borderRadius:
                  BorderRadius.vertical(
                top: Radius.circular(25),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),

                Container(
                  width: 45,
                  height: 5,
                  decoration:
                      BoxDecoration(
                    color: Colors.white30,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    18,
                    18,
                    12,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Search',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(
                            sheetContext,
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

                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 18,
                  ),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    onSubmitted: (value) {
                      _performSearch(
                        value.trim(),
                        sheetContext,
                      );
                    },
                    decoration:
                        InputDecoration(
                      hintText:
                          'Search users...',
                      hintStyle:
                          const TextStyle(
                        color: Colors.white54,
                      ),
                      prefixIcon:
                          const Icon(
                        Icons.search,
                        color: Colors.white,
                      ),
                      filled: true,
                      fillColor:
                          Colors.white10,
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                                28),
                        borderSide:
                            BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search,
                          color: Colors.white30,
                          size: 65,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Search PALOK users',
                          style: TextStyle(
                            color:
                                Colors.white54,
                            fontSize: 16,
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
      },
    ).whenComplete(() {
      controller.dispose();
    });
  }

  // ================================================================
  // PERFORM SEARCH
  // ================================================================

  Future<void> _performSearch(
    String query,
    BuildContext sheetContext,
  ) async {
    if (query.isEmpty) {
      return;
    }

    try {
      final snapshot =
          await _firestore
              .collection('users')
              .where(
                'username',
                isGreaterThanOrEqualTo:
                    query,
              )
              .where(
                'username',
                isLessThanOrEqualTo:
                    '$query\uf8ff',
              )
              .limit(20)
              .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        _showMessage(
          'কোনো user পাওয়া যায়নি',
        );
      } else {
        _showMessage(
          '${snapshot.docs.length} জন user পাওয়া গেছে',
        );
      }
    } catch (e) {
      debugPrint(
        'Search error: $e',
      );

      _showMessage(
        'Search করতে সমস্যা হয়েছে',
      );
    }
  }

  // ================================================================
  // COMMENTS
  // ================================================================

  void _openComments() {
    final index =
        _currentVideo;

    final videoId =
        'demo_video_$index';

    final inputController =
        TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      useSafeArea: false,
      builder: (context) {
        return StatefulBuilder(
          builder:
              (context, setModalState) {
            final keyboardHeight =
                MediaQuery.of(context)
                    .viewInsets
                    .bottom;

            return Container(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      0.82,
              decoration:
                  const BoxDecoration(
                color: Colors.black,
                borderRadius:
                    BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  Container(
                    width: 58,
                    height: 5,
                    decoration:
                        BoxDecoration(
                      color: Colors.white24,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      20,
                      18,
                      16,
                      14,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Comments',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_commentCounts[index]}',
                          style:
                              const TextStyle(
                            color:
                                Colors.white60,
                            fontSize: 17,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                            );
                          },
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 30,
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
                    child:
                        StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('videos')
                          .doc(videoId)
                          .collection('comments')
                          .orderBy(
                            'createdAt',
                            descending: true,
                          )
                          .snapshots(),
                      builder:
                          (context, snapshot) {
                        if (snapshot
                                .connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child:
                                CircularProgressIndicator(
                              color:
                                  Colors.white,
                            ),
                          );
                        }

                        final docs =
                            snapshot.data?.docs ??
                                [];

                        if (docs.isEmpty) {
                          return ListView(
                            padding:
                                const EdgeInsets.all(
                                    18),
                            children: const [
                              _CommentItem(
                                username:
                                    '@rahim',
                                text:
                                    'ভিডিওটা অনেক সুন্দর হয়েছে ❤️',
                              ),
                              _CommentItem(
                                username:
                                    '@karim',
                                text:
                                    'PALOK অনেক ভালো লাগছে 🔥',
                              ),
                              _CommentItem(
                                username:
                                    '@user123',
                                text:
                                    'Nice video!',
                              ),
                            ],
                          );
                        }

                        return ListView.builder(
                          padding:
                              const EdgeInsets.all(
                                  18),
                          itemCount:
                              docs.length,
                          itemBuilder:
                              (context, i) {
                            final data =
                                docs[i].data()
                                    as Map<String,
                                        dynamic>;

                            return _CommentItem(
                              username:
                                  data['username'] ??
                                      '@user',
                              text:
                                  data['text'] ??
                                      '',
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // ------------------------------------------------
                  // COMMENT INPUT
                  // ------------------------------------------------

                  AnimatedPadding(
                    duration:
                        const Duration(
                      milliseconds: 180,
                    ),
                    padding:
                        EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 10,
                      bottom:
                          keyboardHeight > 0
                              ? keyboardHeight +
                                  8
                              : 12,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            constraints:
                                const BoxConstraints(
                              minHeight: 52,
                              maxHeight: 120,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                      0xFF252525),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                          28),
                            ),
                            child: TextField(
                              controller:
                                  inputController,
                              keyboardType:
                                  TextInputType
                                      .multiline,
                              minLines: 1,
                              maxLines: 4,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 16,
                              ),
                              cursorColor:
                                  Colors.pinkAccent,
                              onChanged: (_) {
                                setModalState(
                                  () {},
                                );
                              },
                              decoration:
                                  const InputDecoration(
                                hintText:
                                    'Add a comment...',
                                hintStyle:
                                    TextStyle(
                                  color:
                                      Colors.white54,
                                ),
                                border:
                                    InputBorder.none,
                                contentPadding:
                                    EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      20,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        GestureDetector(
                          onTap: inputController
                                  .text
                                  .trim()
                                  .isEmpty
                              ? null
                              : () {
                                  _addComment(
                                    index,
                                    videoId,
                                    inputController,
                                    context,
                                    setModalState,
                                  );
                                },
                          child:
                              AnimatedContainer(
                            duration:
                                const Duration(
                              milliseconds: 150,
                            ),
                            width: 54,
                            height: 54,
                            decoration:
                                BoxDecoration(
                              shape:
                                  BoxShape.circle,
                              color: inputController
                                      .text
                                      .trim()
                                      .isEmpty
                                  ? Colors.white24
                                  : Colors.pinkAccent,
                            ),
                            child:
                                const Icon(
                              Icons.send_rounded,
                              color:
                                  Colors.white,
                              size: 27,
                            ),
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
    ).whenComplete(() {
      inputController.dispose();
    });
  }

  // ================================================================
  // ADD COMMENT
  // ================================================================

  Future<void> _addComment(
    int index,
    String videoId,
    TextEditingController inputController,
    BuildContext sheetContext,
    StateSetter setModalState,
  ) async {
    final uid = _uid;

    final text =
        inputController.text.trim();

    if (uid == null ||
        text.isEmpty) {
      return;
    }

    try {
      await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .add({
        'uid': uid,
        'username':
            '@palok_user',
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

      inputController.clear();

      setModalState(() {});

      FocusScope.of(
        sheetContext,
      ).unfocus();

      if (!mounted) return;

      setState(() {
        _commentCounts[index]++;
      });
    } catch (e) {
      debugPrint(
        'Comment error: $e',
      );

      _showMessage(
        'Comment যোগ করতে সমস্যা হয়েছে',
      );
    }
  }

  // ================================================================
  // CREATE / UPLOAD VIDEO
  // ================================================================

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
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
                const EdgeInsets.all(24),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration:
                      BoxDecoration(
                    color: Colors.white30,
                    borderRadius:
                        BorderRadius.circular(
                            10),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'Create on PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 25),

                // ------------------------------------------------
                // UPLOAD VIDEO
                // ------------------------------------------------

                ListTile(
                  leading:
                      const CircleAvatar(
                    backgroundColor:
                        Colors.white,
                    child: Icon(
                      Icons.video_library,
                      color:
                          Colors.black,
                    ),
                  ),
                  title:
                      const Text(
                    'Upload Video',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  subtitle:
                      const Text(
                    'Post an original video',
                    style:
                        TextStyle(
                      color:
                          Colors.white54,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(
                      context,
                    );

                    final result =
                        await Navigator.push(
                      this.context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const UploadVideoScreen(),
                      ),
                    );

                    if (result == true &&
                        mounted) {
                      _showMessage(
                        'আপনার ভিডিও PALOK-এ পোস্ট হয়েছে 🎉',
                      );
                    }
                  },
                ),

                const SizedBox(height: 10),

                // ------------------------------------------------
                // ADD SOUND
                // ------------------------------------------------

                ListTile(
                  leading:
                      const CircleAvatar(
                    backgroundColor:
                        Colors.white,
                    child: Icon(
                      Icons.music_note,
                      color:
                          Colors.black,
                    ),
                  ),
                  title:
                      const Text(
                    'Add Sound',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                    );

                    _showMessage(
                      'Sound feature পরে যোগ করা হবে',
                    );
                  },
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
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

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(message),
          duration:
              const Duration(
            seconds: 2,
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  // ================================================================
  // MAIN UI
  // ================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --------------------------------------------------------
          // FULL SCREEN VIDEO
          // --------------------------------------------------------

          PageView.builder(
            controller:
                _pageController,
            scrollDirection:
                Axis.vertical,
            itemCount:
                videoUrls.length,
            onPageChanged:
                _onVideoChanged,
            itemBuilder:
                (context, index) {
              return _buildVideo(
                index,
              );
            },
          ),

          // --------------------------------------------------------
          // TOP HEADER
          // --------------------------------------------------------

          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.only(
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
                    builder:
                        (context, child) {
                      return Transform.scale(
                        scale:
                            _logoScale.value,
                        alignment:
                            Alignment.centerLeft,
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
                        _buildPalokLogo(),
                  ),

                  const Spacer(),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _topIndex = 0;
                      });

                      _showMessage(
                        'For You',
                      );
                    },
                    child:
                        _topTab(
                      title:
                          'For You',
                      selected:
                          _topIndex == 0,
                    ),
                  ),

                  const SizedBox(
                    width: 28,
                  ),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _topIndex = 1;
                      });

                      _showMessage(
                        'Following',
                      );
                    },
                    child:
                        _topTab(
                      title:
                          'Following',
                      selected:
                          _topIndex == 1,
                    ),
                  ),

                  const SizedBox(
                    width: 24,
                  ),

                  GestureDetector(
                    onTap:
                        _openSearch,
                    child:
                        const Icon(
                      Icons.search,
                      color:
                          Colors.white,
                      size: 34,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --------------------------------------------------------
          // RIGHT BUTTONS
          // --------------------------------------------------------

          Positioned(
            right: 10,
            bottom: 116,
            child:
                _buildRightButtons(),
          ),

          // --------------------------------------------------------
          // VIDEO INFORMATION
          // --------------------------------------------------------

          Positioned(
            left: 18,
            right: 92,
            bottom: 124,
            child:
                _buildVideoInformation(),
          ),

          // --------------------------------------------------------
          // BOTTOM NAVIGATION
          // --------------------------------------------------------

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
        ],
      ),
    );
  }

  // ================================================================
  // PALOK LOGO
  // ================================================================

  Widget _buildPalokLogo() {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
                    13),
            gradient:
                const LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFFF3B81),
              ],
            ),
          ),
          child: Stack(
            alignment:
                Alignment.center,
            children: [
              const Text(
                'P',
                style: TextStyle(
                  color:
                      Colors.black,
                  fontSize: 34,
                  fontWeight:
                      FontWeight.w900,
                  height: 1,
                ),
              ),

              Positioned(
                right: 7,
                top: 12,
                child:
                    Container(
                  width: 0,
                  height: 0,
                  decoration:
                      const BoxDecoration(
                    border:
                        Border(
                      left:
                          BorderSide(
                        color:
                            Color(0xFFFF176B),
                        width: 9,
                      ),
                      top:
                          BorderSide(
                        color:
                            Colors.transparent,
                        width: 6,
                      ),
                      bottom:
                          BorderSide(
                        color:
                            Colors.transparent,
                        width: 6,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          width: 7,
        ),

        const Text(
          'Palok',
          style:
              TextStyle(
            color:
                Colors.white,
            fontSize: 24,
            fontWeight:
                FontWeight.w800,
            letterSpacing:
                -0.5,
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
          style:
              TextStyle(
            color:
                Colors.white,
            fontSize: 18,
            fontWeight: selected
                ? FontWeight.w800
                : FontWeight.w400,
          ),
        ),

        const SizedBox(
          height: 7,
        ),

        AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),
          width:
              selected ? 42 : 0,
          height: 3,
          decoration:
              BoxDecoration(
            color:
                Colors.white,
            borderRadius:
                BorderRadius.circular(
                    10),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // RIGHT BUTTONS
  // ================================================================

  Widget _buildRightButtons() {
    final index =
        _currentVideo;

    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        _actionButton(
          icon: _liked[index]
              ? Icons.favorite
              : Icons.favorite_border,
          count:
              _formatCount(
            _likeCounts[index],
          ),
          active:
              _liked[index],
          onTap:
              _toggleLike,
        ),

        const SizedBox(
          height: 25,
        ),

        _actionButton(
          icon:
              Icons.chat_bubble_outline,
          count:
              _formatCount(
            _commentCounts[index],
          ),
          onTap:
              _openComments,
        ),

        const SizedBox(
          height: 25,
        ),

        _actionButton(
          icon: _saved[index]
              ? Icons.bookmark
              : Icons.bookmark_border,
          count:
              _formatCount(
            _saveCounts[index],
          ),
          active:
              _saved[index],
          onTap:
              _toggleSave,
        ),

        const SizedBox(
          height: 25,
        ),

        _actionButton(
          icon:
              Icons.share_outlined,
          count:
              _formatCount(
            _shareCounts[index],
          ),
          onTap:
              _shareVideo,
        ),

        const SizedBox(
          height: 24,
        ),

        GestureDetector(
          onTap:
              _toggleFollow,
          child: SizedBox(
            width: 54,
            height: 62,
            child: Stack(
              alignment:
                  Alignment.topCenter,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    border:
                        Border.all(
                      color:
                          Colors.white,
                      width: 1.8,
                    ),
                  ),
                  child:
                      Icon(
                    _following
                        ? Icons.person
                        : Icons.person_outline,
                    color:
                        Colors.white,
                    size: 29,
                  ),
                ),

                if (!_following)
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child:
                        Container(
                      width: 23,
                      height: 23,
                      decoration:
                          const BoxDecoration(
                        color:
                            Colors.red,
                        shape:
                            BoxShape.circle,
                      ),
                      child:
                          const Icon(
                        Icons.add,
                        color:
                            Colors.white,
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

            const SizedBox(
              height: 5,
            ),

            Text(
              count,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
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
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '@palok_user',
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize: 17,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            GestureDetector(
              onTap:
                  _toggleFollow,
              child:
                  Text(
                _following
                    ? 'Following'
                    : 'Follow',
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 8,
        ),

        const Text(
          'Welcome to PALOK 🎬',
          style:
              TextStyle(
            color:
                Colors.white,
            fontSize: 16,
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        const Text(
          '#Palok #ShortVideo #Bangladesh',
          style:
              TextStyle(
            color:
                Colors.white,
            fontSize: 15,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration:
              BoxDecoration(
            color: Colors.black
                .withOpacity(0.48),
            borderRadius:
                BorderRadius.circular(
                    25),
          ),
          child: const Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note,
                color:
                    Colors.white,
                size: 20,
              ),

              SizedBox(
                width: 7,
              ),

              Text(
                'Original Sound - PALOK',
                style:
                    TextStyle(
                  color:
                      Colors.white,
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
      color:
          Colors.black,
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround,
        children: [
          _bottomButton(
            icon:
                Icons.home_filled,
            label:
                'Home',
            index: 0,
          ),

          _bottomButton(
            icon:
                Icons.people_outline,
            label:
                'Friends',
            index: 1,
          ),

          GestureDetector(
            onTap: () {
              _selectBottom(2);
            },
            child:
                Container(
              width: 58,
              height: 43,
              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius.circular(
                        13),
                boxShadow:
                    const [
                  BoxShadow(
                    color:
                        Color(0xFF00E5FF),
                    offset:
                        Offset(-3, 0),
                    blurRadius:
                        0,
                  ),
                  BoxShadow(
                    color:
                        Color(0xFFFF176B),
                    offset:
                        Offset(3, 0),
                    blurRadius:
                        0,
                  ),
                ],
              ),
              child:
                  const Icon(
                Icons.add,
                color:
                    Colors.black,
                size: 31,
              ),
            ),
          ),

          _bottomButton(
            icon:
                Icons.chat_bubble_outline,
            label:
                'Inbox',
            index: 3,
          ),

          _bottomButton(
            icon:
                Icons.person_outline,
            label:
                'Profile',
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
    final selected =
        _bottomIndex == index;

    return GestureDetector(
      onTap: () {
        _selectBottom(index);
      },
      child:
          SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color:
                  Colors.white,
              size:
                  selected ? 28 : 26,
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              label,
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize: 13,
                fontWeight:
                    selected
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

  Widget _buildVideo(
    int index,
  ) {
    if (index >=
        _videoControllers.length) {
      return const SizedBox();
    }

    final controller =
        _videoControllers[index];

    if (!controller
        .value
        .isInitialized) {
      return const Center(
        child:
            CircularProgressIndicator(
          color:
              Colors.white,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _toggleVideo(
          index,
        );
      },
      child:
          SizedBox.expand(
        child:
            FittedBox(
          fit:
              BoxFit.cover,
          child:
              SizedBox(
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
            child:
                VideoPlayer(
              controller,
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // COUNT FORMAT
  // ================================================================

  String _formatCount(
    int count,
  ) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }

    if (count >= 1000) {
      final value =
          count / 1000;

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

class _CommentItem
    extends StatelessWidget {
  final String username;
  final String text;

  const _CommentItem({
    required this.username,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 20,
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                const BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  Colors.white12,
            ),
            child:
                const Icon(
              Icons.person,
              color:
                  Colors.white,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  text,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
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
