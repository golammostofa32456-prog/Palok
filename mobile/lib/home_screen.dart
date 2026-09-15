import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> videoUrls = [
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
  ];

  final List<String> usernames = [
    '@palok_user',
    '@palok_creator',
  ];

  final PageController pageController = PageController();

  int currentPage = 0;

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: pageController,
        scrollDirection: Axis.vertical,
        itemCount: videoUrls.length,
        onPageChanged: (index) {
          setState(() {
            currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          return PalokVideoCard(
            key: ValueKey(videoUrls[index]),
            videoUrl: videoUrls[index],
            username: usernames[index],
            isActive: index == currentPage,
          );
        },
      ),
    );
  }
}

class PalokVideoCard extends StatefulWidget {
  final String videoUrl;
  final String username;
  final bool isActive;

  const PalokVideoCard({
    super.key,
    required this.videoUrl,
    required this.username,
    required this.isActive,
  });

  @override
  State<PalokVideoCard> createState() => _PalokVideoCardState();
}

class _PalokVideoCardState extends State<PalokVideoCard> {
  late VideoPlayerController controller;

  bool isLiked = false;
  bool isFollowing = false;
  bool isSaved = false;

  int likeCount = 0;
  int saveCount = 0;

  bool isLoadingData = true;

  String get videoKey {
    return widget.videoUrl.hashCode.toString();
  }

  String get likeKey => 'palok_like_$videoKey';
  String get saveKey => 'palok_save_$videoKey';

  @override
  void initState() {
    super.initState();

    _loadSavedData();

    controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    )..initialize().then((_) {
        if (mounted) {
          setState(() {});
          controller.setLooping(true);

          if (widget.isActive) {
            controller.play();
          }
        }
      });
  }

  // =========================
  // LOAD SAVED DATA
  // =========================

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedLike = prefs.getBool(likeKey) ?? false;
    final savedVideo = prefs.getBool(saveKey) ?? false;

    final savedLikeCount =
        prefs.getInt('${likeKey}_count') ?? 0;

    final savedSaveCount =
        prefs.getInt('${saveKey}_count') ?? 0;

    final savedFollow =
        prefs.getBool('palok_follow_${widget.username}') ?? false;

    if (!mounted) return;

    setState(() {
      isLiked = savedLike;
      isSaved = savedVideo;
      isFollowing = savedFollow;

      likeCount = savedLikeCount;
      saveCount = savedSaveCount;

      isLoadingData = false;
    });
  }

  // =========================
  // LIKE
  // =========================

  Future<void> toggleLike() async {
    final prefs = await SharedPreferences.getInstance();

    final newValue = !isLiked;

    int newCount = likeCount;

    if (newValue) {
      newCount++;
    } else {
      if (newCount > 0) {
        newCount--;
      }
    }

    await prefs.setBool(likeKey, newValue);
    await prefs.setInt('${likeKey}_count', newCount);

    if (!mounted) return;

    setState(() {
      isLiked = newValue;
      likeCount = newCount;
    });
  }

  // =========================
  // SAVE
  // =========================

  Future<void> toggleSave() async {
    final prefs = await SharedPreferences.getInstance();

    final newValue = !isSaved;

    int newCount = saveCount;

    if (newValue) {
      newCount++;
    } else {
      if (newCount > 0) {
        newCount--;
      }
    }

    await prefs.setBool(saveKey, newValue);
    await prefs.setInt('${saveKey}_count', newCount);

    if (!mounted) return;

    setState(() {
      isSaved = newValue;
      saveCount = newCount;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newValue
              ? 'ভিডিওটি Saved হয়েছে'
              : 'ভিডিওটি Unsave করা হয়েছে',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // =========================
  // FOLLOW
  // =========================

  Future<void> toggleFollow() async {
    final prefs = await SharedPreferences.getInstance();

    final newValue = !isFollowing;

    await prefs.setBool(
      'palok_follow_${widget.username}',
      newValue,
    );

    if (!mounted) return;

    setState(() {
      isFollowing = newValue;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newValue
              ? '${widget.username} Follow করা হয়েছে'
              : '${widget.username} Unfollow করা হয়েছে',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // =========================
  // COMMENT
  // =========================

  void openComments() {
    final TextEditingController commentController =
        TextEditingController();

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
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: Column(
              children: [
                const SizedBox(height: 12),

                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    const SizedBox(width: 18),
                    const Expanded(
                      child: Text(
                        'Comments',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
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
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      _CommentItem(
                        username: '@rahim',
                        comment: 'দারুণ ভিডিও! 🔥',
                      ),
                      _CommentItem(
                        username: '@karim',
                        comment: 'PALOK দেখতে সুন্দর হচ্ছে ❤️',
                      ),
                      _CommentItem(
                        username: '@user123',
                        comment: 'Nice video 🎬',
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: MediaQuery.of(context)
                        .viewInsets
                        .bottom,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: const TextStyle(
                              color: Colors.white54,
                            ),
                            filled: true,
                            fillColor: Colors.white12,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      GestureDetector(
                        onTap: () {
                          if (commentController.text
                              .trim()
                              .isEmpty) {
                            return;
                          }

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Comment added'),
                              duration:
                                  Duration(seconds: 1),
                            ),
                          );

                          commentController.clear();
                        },
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.pink,
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
        );
      },
    );
  }

  // =========================
  // SHARE
  // =========================

  void shareVideo() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'PALOK ভিডিও Share করার অপশন প্রস্তুত',
        ),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // =========================
  // VIDEO UPDATE
  // =========================

  @override
  void didUpdateWidget(
    covariant PalokVideoCard oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }

        setState(() {});
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
          ),

          if (controller.value.isInitialized)
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
              ),
            ),

          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black54,
                  Colors.transparent,
                  Colors.black87,
                ],
              ),
            ),
          ),

          // =========================
          // PALOK LOGO
          // =========================

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Text(
                  'PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),

          // =========================
          // RIGHT BUTTONS
          // POSITION UNCHANGED
          // =========================

          Positioned(
            right: 12,
            bottom: 125,
            child: Column(
              children: [
                _profileButton(),

                const SizedBox(height: 24),

                _actionButton(
                  icon: isLiked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: likeCount > 0
                      ? '$likeCount'
                      : 'Like',
                  color:
                      isLiked ? Colors.red : Colors.white,
                  onTap: toggleLike,
                ),

                const SizedBox(height: 24),

                _actionButton(
                  icon: Icons.comment_outlined,
                  label: 'Comment',
                  onTap: openComments,
                ),

                const SizedBox(height: 24),

                _actionButton(
                  icon: isSaved
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  label: saveCount > 0
                      ? '$saveCount'
                      : 'Save',
                  color: isSaved
                      ? Colors.amber
                      : Colors.white,
                  onTap: toggleSave,
                ),

                const SizedBox(height: 24),

                _actionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: shareVideo,
                ),
              ],
            ),
          ),

          // =========================
          // VIDEO INFORMATION
          // POSITION UNCHANGED
          // =========================

          Positioned(
            left: 16,
            right: 80,
            bottom: 35,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(width: 10),

                    GestureDetector(
                      onTap: toggleFollow,
                      child: Text(
                        isFollowing
                            ? 'Following'
                            : 'Follow',
                        style: TextStyle(
                          color: isFollowing
                              ? Colors.white70
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                const Text(
                  'Welcome to PALOK 🎬',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  '#Palok #ShortVideo #Bangladesh',
                  style: TextStyle(
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

  // =========================
  // PROFILE BUTTON
  // =========================

  Widget _profileButton() {
    return GestureDetector(
      onTap: toggleFollow,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              color: Colors.black54,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 30,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            isFollowing ? 'Following' : 'Follow',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // ACTION BUTTON
  // =========================

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black45,
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================
// COMMENT ITEM
// =========================

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
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  comment,
                  style: const TextStyle(
                    color: Colors.white70,
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
