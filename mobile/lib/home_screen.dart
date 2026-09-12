import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  late PageController _pageController;

  // ================================================================
  // PALOK LOGO ANIMATION
  // ================================================================
  late AnimationController _logoAnimationController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // ================================================================
  // VIDEOS
  // ================================================================
  final List<String> videoUrls = [
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
  ];

  final List<VideoPlayerController> _videoControllers = [];

  // ================================================================
  // LIKE / SAVE / FOLLOW STATE
  // ================================================================
  final List<bool> _liked = [false, false];
  final List<bool> _saved = [false, false];

  bool _following = false;

  // Base counts
  final List<int> _likeCounts = [11700, 8500];
  final List<int> _commentCounts = [234, 128];
  final List<int> _saveCounts = [811, 452];
  final List<int> _shareCounts = [431, 201];

  // ================================================================
  // COMMENT CONTROLLER
  // ================================================================
  final TextEditingController _commentController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    // ============================================================
    // PALOK LOGO ANIMATION
    // ============================================================
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

    // ============================================================
    // LOAD VIDEOS
    // ============================================================
    for (final url in videoUrls) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
      );

      _videoControllers.add(controller);

      controller.initialize().then((_) {
        if (!mounted) return;

        setState(() {});

        controller
          ..setLooping(true)
          ..play();
      }).catchError((error) {
        debugPrint('Video loading error: $error');
      });
    }
  }

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
    if (_pageController.hasClients &&
        _pageController.page != null) {
      return _pageController.page!.round().clamp(
            0,
            videoUrls.length - 1,
          );
    }

    return 0;
  }

  // ================================================================
  // VIDEO CHANGE
  // ================================================================
  void _onVideoChanged(int index) {
    for (int i = 0; i < _videoControllers.length; i++) {
      if (!_videoControllers[i].value.isInitialized) {
        continue;
      }

      if (i == index) {
        _videoControllers[i].play();
      } else {
        _videoControllers[i].pause();
      }
    }

    setState(() {});
  }

  // ================================================================
  // LIKE
  // ================================================================
  void _toggleLike() {
    final index = _currentVideo;

    setState(() {
      _liked[index] = !_liked[index];

      if (_liked[index]) {
        _likeCounts[index]++;
      } else {
        _likeCounts[index]--;
      }
    });
  }

  // ================================================================
  // SAVE
  // ================================================================
  void _toggleSave() {
    final index = _currentVideo;

    setState(() {
      _saved[index] = !_saved[index];

      if (_saved[index]) {
        _saveCounts[index]++;
      } else {
        _saveCounts[index]--;
      }
    });

    _showMessage(
      _saved[index]
          ? 'ভিডিওটি Saved হয়েছে'
          : 'ভিডিওটি Unsave করা হয়েছে',
    );
  }

  // ================================================================
  // FOLLOW
  // ================================================================
  void _toggleFollow() {
    setState(() {
      _following = !_following;
    });

    _showMessage(
      _following
          ? '@palok_user কে Follow করা হয়েছে'
          : '@palok_user কে Unfollow করা হয়েছে',
    );
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

    await Clipboard.setData(
      ClipboardData(text: shareText),
    );

    if (!mounted) return;

    setState(() {
      _shareCounts[index]++;
    });

    _showMessage(
      'ভিডিওর Share link কপি হয়েছে',
    );
  }

  // ================================================================
  // SEARCH
  // ================================================================
  void _openSearch() {
    final TextEditingController searchController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text(
            'Search PALOK',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: TextField(
            controller: searchController,
            autofocus: true,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'Search videos, users...',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.white54,
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white,
                ),
              ),
            ),
            onSubmitted: (value) {
              Navigator.pop(context);

              if (value.trim().isNotEmpty) {
                _showMessage(
                  'Searching for "$value"',
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
                  color: Colors.white,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final value =
                    searchController.text.trim();

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
                  color: Colors.pinkAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ================================================================
  // COMMENTS
  // ================================================================
  void _openComments() {
    final index = _currentVideo;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context)
                .viewInsets
                .bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: Column(
              children: [
                // HEADER
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
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${_commentCounts[index]}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Icon(
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

                // COMMENTS
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
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
                  ),
                ),

                // COMMENT INPUT
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
                          controller: _commentController,
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
                                  BorderRadius.circular(
                                      25),
                              borderSide:
                                  BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (_commentController
                              .text
                              .trim()
                              .isEmpty) {
                            return;
                          }

                          final comment =
                              _commentController
                                  .text
                                  .trim();

                          _commentController.clear();

                          setState(() {
                            _commentCounts[index]++;
                          });

                          FocusScope.of(context)
                              .unfocus();

                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Comment added: $comment',
                              ),
                              duration:
                                  const Duration(
                                seconds: 2,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration:
                              const BoxDecoration(
                            color: Colors.pink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send,
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
        );
      },
    );
  }

  // ================================================================
  // CREATE VIDEO
  // ================================================================
  void _openCreate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
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
                  icon: Icons.photo_library_outlined,
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
          borderRadius: BorderRadius.circular(14),
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
  // BOTTOM NAV ACTION
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
                  // ==================================================
                  // PALOK LOGO
                  // ==================================================
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

                  // ==================================================
                  // FOR YOU
                  // ==================================================
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

                  // ==================================================
                  // FOLLOWING
                  // ==================================================
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

                  // ==================================================
                  // SEARCH
                  // ==================================================
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
  // PALOK LOGO
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
                  fontWeight:
                      FontWeight.w900,
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
                        color:
                            Color(0xFFFF176B),
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
  // RIGHT SIDE BUTTONS
  // ================================================================
  Widget _buildRightButtons() {
    final index = _currentVideo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // LIKE
        _actionButton(
          icon: _liked[index]
              ? Icons.favorite
              : Icons.favorite_border,
          count: _formatCount(
            _likeCounts[index],
          ),
          active: _liked[index],
          onTap: _toggleLike,
        ),

        const SizedBox(height: 25),

        // COMMENT
        _actionButton(
          icon: Icons.chat_bubble_outline,
          count: _formatCount(
            _commentCounts[index],
          ),
          onTap: _openComments,
        ),

        const SizedBox(height: 25),

        // SAVE
        _actionButton(
          icon: _saved[index]
              ? Icons.bookmark
              : Icons.bookmark_border,
          count: _formatCount(
            _saveCounts[index],
          ),
          active: _saved[index],
          onTap: _toggleSave,
        ),

        const SizedBox(height: 25),

        // SHARE
        _actionButton(
          icon: Icons.share_outlined,
          count: _formatCount(
            _shareCounts[index],
          ),
          onTap: _shareVideo,
        ),

        const SizedBox(height: 24),

        // FOLLOW
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
  // RIGHT ACTION BUTTON
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
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '@palok_user',
              style: TextStyle(
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

        const Text(
          'Welcome to PALOK 🎬',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          '#Palok #ShortVideo #Bangladesh',
          style: TextStyle(
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
            color:
                Colors.black.withOpacity(0.48),
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

          // CREATE
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
    final bool selected =
        _bottomIndex == index;

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
      onTap: () {
        setState(() {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        });
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
            decoration:
                const BoxDecoration(
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
