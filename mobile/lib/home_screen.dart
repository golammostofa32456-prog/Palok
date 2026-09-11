import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _bottomIndex = 0;
  int _topIndex = 0;

  final TextEditingController _searchController =
      TextEditingController();

  final List<String> _videos = [
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
  ];

  final List<VideoPlayerController> _controllers = [];

  final List<bool> _liked = [];
  final List<bool> _saved = [];
  final List<bool> _followed = [];

  @override
  void initState() {
    super.initState();

    for (final url in _videos) {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(url));

      _controllers.add(controller);
      _liked.add(false);
      _saved.add(false);
      _followed.add(false);

      controller.initialize().then((_) {
        if (!mounted) return;

        setState(() {});

        controller.setLooping(true);

        if (_controllers.first == controller &&
            _bottomIndex == 0 &&
            _topIndex == 0) {
          controller.play();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();

    for (final controller in _controllers) {
      controller.dispose();
    }

    super.dispose();
  }

  // ------------------------------------------------------------
  // MESSAGE
  // ------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ------------------------------------------------------------
  // LIKE
  // ------------------------------------------------------------

  void _toggleLike(int index) {
    setState(() {
      _liked[index] = !_liked[index];
    });
  }

  // ------------------------------------------------------------
  // SAVE
  // ------------------------------------------------------------

  void _toggleSave(int index) {
    setState(() {
      _saved[index] = !_saved[index];
    });

    _showMessage(
      _saved[index]
          ? 'ভিডিও Save করা হয়েছে'
          : 'ভিডিও থেকে Save সরানো হয়েছে',
    );
  }

  // ------------------------------------------------------------
  // FOLLOW
  // ------------------------------------------------------------

  void _toggleFollow(int index) {
    setState(() {
      _followed[index] = !_followed[index];
    });

    _showMessage(
      _followed[index]
          ? 'Follow করা হয়েছে'
          : 'Unfollow করা হয়েছে',
    );
  }

  // ------------------------------------------------------------
  // COMMENTS
  // ------------------------------------------------------------

  void _showComments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'এখনও কোনো কমেন্ট নেই',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      Navigator.pop(context);
                      _showMessage(
                        'Comment যোগ করার ব্যবস্থা প্রস্তুত',
                      );
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // SHARE
  // ------------------------------------------------------------

  void _shareVideo() {
    _showMessage('Share অপশন প্রস্তুত');
  }

  // ------------------------------------------------------------
  // SVG ICON
  // ------------------------------------------------------------

  Widget _svgIcon({
    required String path,
    double size = 42,
    bool active = false,
  }) {
    return SvgPicture.string(
      path,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        active ? Colors.white : Colors.white,
        BlendMode.srcIn,
      ),
    );
  }

  // ------------------------------------------------------------
  // PERSON SVG
  // ------------------------------------------------------------

  String _personSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg"
     viewBox="0 0 24 24">
  <circle
    cx="12"
    cy="7"
    r="4"
    fill="none"
    stroke="white"
    stroke-width="2"/>
  <path
    d="M4 21c.7-4.2 3.3-6.5 8-6.5s7.3 2.3 8 6.5"
    fill="none"
    stroke="white"
    stroke-width="2"
    stroke-linecap="round"/>
</svg>
''';
  }

  // ------------------------------------------------------------
  // HEART SVG
  // ------------------------------------------------------------

  String _heartSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg"
     viewBox="0 0 24 24">
  <path
    d="M20.8 8.8c0 5.5-8.8 10.2-8.8 10.2S3.2 14.3 3.2 8.8
    C3.2 5.8 5.3 4 8 4c1.6 0 3.1.8 4 2.1
    C12.9 4.8 14.4 4 16 4c2.7 0 4.8 1.8 4.8 4.8z"
    fill="none"
    stroke="white"
    stroke-width="2"
    stroke-linejoin="round"/>
</svg>
''';
  }

  // ------------------------------------------------------------
  // COMMENT SVG
  // ------------------------------------------------------------

  String _commentSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg"
     viewBox="0 0 24 24">
  <path
    d="M4 5.5A2.5 2.5 0 0 1 6.5 3h11
    A2.5 2.5 0 0 1 20 5.5v8
    a2.5 2.5 0 0 1-2.5 2.5H10l-5.5 4v-4.3
    A2.5 2.5 0 0 1 4 13.5z"
    fill="none"
    stroke="white"
    stroke-width="2"
    stroke-linejoin="round"/>
</svg>
''';
  }

  // ------------------------------------------------------------
  // BOOKMARK SVG
  // ------------------------------------------------------------

  String _bookmarkSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg"
     viewBox="0 0 24 24">
  <path
    d="M6 4.5A2.5 2.5 0 0 1 8.5 2h7
    A2.5 2.5 0 0 1 18 4.5V21
    l-6-3.7L6 21z"
    fill="none"
    stroke="white"
    stroke-width="2"
    stroke-linejoin="round"/>
</svg>
''';
  }

  // ------------------------------------------------------------
  // SHARE SVG
  // ------------------------------------------------------------

  String _shareSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg"
     viewBox="0 0 24 24">
  <circle
    cx="18"
    cy="5"
    r="2.5"
    fill="none"
    stroke="white"
    stroke-width="2"/>

  <circle
    cx="6"
    cy="12"
    r="2.5"
    fill="none"
    stroke="white"
    stroke-width="2"/>

  <circle
    cx="18"
    cy="19"
    r="2.5"
    fill="none"
    stroke="white"
    stroke-width="2"/>

  <path
    d="M8.2 10.8l7.5-4.4
       M8.2 13.2l7.5 4.4"
    fill="none"
    stroke="white"
    stroke-width="2"
    stroke-linecap="round"/>
</svg>
''';
  }

  // ------------------------------------------------------------
  // HOME SVG
  // ------------------------------------------------------------

  String _homeSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg"
     viewBox="0 0 24 24">
  <path
    d="M3 10.5L12 3l9 7.5V21a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"
    fill="none"
    stroke="white"
    stroke-width="2"
    stroke-linejoin="round"/>
</svg>
''';
  }

  // ------------------------------------------------------------
  // FRIENDS SVG
  // ------------------------------------------------------------

  String _friendsSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg"
     viewBox="0 0 24 24">
  <circle
    cx="9"
    cy="8"
    r="3"
    fill="none"
    stroke="white"
    stroke-width="2"/>

  <circle
    cx="17"
    cy="9"
    r="2.5"
    fill="none"
    stroke="white"
    stroke-width="2"/>

  <path
    d="M3.5 20c.5-3.6 2.3-5.5 5.5-5.5
      s5 1.9 5.5 5.5"
    fill="none"
    stroke="white"
    stroke-width="2"
    stroke-linecap="round"/>

  <path
    d="M15 14.5c2.8.2 4.5 1.8 5 4.5"
    fill="none"
    stroke="white"
    stroke-width="2"
    stroke-linecap="round"/>
</svg>
''';
  }

  // ------------------------------------------------------------
  // INBOX SVG
  // ------------------------------------------------------------

  String _inboxSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg"
     viewBox="0 0 24 24">
  <path
    d="M4 5.5A2.5 2.5 0 0 1 6.5 3h11
    A2.5 2.5 0 0 1 20 5.5v10
    A2.5 2.5 0 0 1 17.5 18H14l-2 3-2-3H6.5
    A2.5 2.5 0 0 1 4 15.5z"
    fill="none"
    stroke="white"
    stroke-width="2"
    stroke-linejoin="round"/>
</svg>
''';
  }

  // ------------------------------------------------------------
  // PROFILE SVG
  // ------------------------------------------------------------

  String _profileSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg"
     viewBox="0 0 24 24">
  <circle
    cx="12"
    cy="8"
    r="4"
    fill="none"
    stroke="white"
    stroke-width="2"/>

  <path
    d="M4 21c.7-4.5 3.5-6.8 8-6.8s7.3 2.3 8 6.8"
    fill="none"
    stroke="white"
    stroke-width="2"
    stroke-linecap="round"/>
</svg>
''';
  }

  // ------------------------------------------------------------
  // SEARCH SVG
  // ------------------------------------------------------------

  String _searchSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg"
     viewBox="0 0 24 24">
  <circle
    cx="10.8"
    cy="10.8"
    r="6.5"
    fill="none"
    stroke="white"
    stroke-width="2"/>

  <path
    d="M16 16l5 5"
    fill="none"
    stroke="white"
    stroke-width="2"
    stroke-linecap="round"/>
</svg>
''';
  }

  // ------------------------------------------------------------
  // UPLOAD SVG
  // ------------------------------------------------------------

  String _uploadSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg"
     viewBox="0 0 40 40">

  <rect
    x="5"
    y="4"
    width="30"
    height="32"
    rx="9"
    fill="white"/>

  <path
    d="M20 12v16M12 20h16"
    stroke="black"
    stroke-width="3"
    stroke-linecap="round"/>
</svg>
''';
  }

  // ------------------------------------------------------------
  // ACTION BUTTON
  // ------------------------------------------------------------

  Widget _actionButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          children: [
            AnimatedScale(
              scale: active ? 1.12 : 1.0,
              duration:
                  const Duration(milliseconds: 160),
              child: icon,
            ),

            const SizedBox(height: 4),

            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // VIDEO FEED
  // ------------------------------------------------------------

  Widget _videoFeed() {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: _videos.length,

      onPageChanged: (index) {
        for (int i = 0;
            i < _controllers.length;
            i++) {
          if (i == index) {
            _controllers[i].play();
          } else {
            _controllers[i].pause();
          }
        }
      },

      itemBuilder: (context, index) {
        final controller = _controllers[index];

        return Stack(
          fit: StackFit.expand,
          children: [
            // Background
            Container(
              color: Colors.black,
            ),

            // Video
            if (controller.value.isInitialized)
              Center(
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
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),

            // Gradient
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(.30),
                        Colors.transparent,
                        Colors.black.withOpacity(.78),
                      ],
                      stops: const [
                        0.0,
                        0.45,
                        1.0,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // --------------------------------------------------
            // PALOK LOGO
            // --------------------------------------------------

            const Positioned(
              top: 38,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                  ),
                ),
              ),
            ),

            // --------------------------------------------------
            // TOP TABS
            // --------------------------------------------------

            Positioned(
              top: 88,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  _topTab(
                    'For You',
                    0,
                  ),

                  const SizedBox(width: 28),

                  _topTab(
                    'Following',
                    1,
                  ),

                  const SizedBox(width: 20),

                  GestureDetector(
                    behavior:
                        HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _topIndex = 2;
                      });

                      for (final c
                          in _controllers) {
                        c.pause();
                      }
                    },
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: _svgIcon(
                        path: _searchSvg(),
                        size: 27,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --------------------------------------------------
            // RIGHT ACTIONS
            // --------------------------------------------------

            Positioned(
              right: 10,
              bottom: 125,
              child: Column(
                children: [
                  // Follow
                  _actionButton(
                    icon: _svgIcon(
                      path: _personSvg(),
                      active:
                          _followed[index],
                      size: 43,
                    ),
                    label: _followed[index]
                        ? 'Following'
                        : 'Follow',
                    active:
                        _followed[index],
                    onTap: () =>
                        _toggleFollow(index),
                  ),

                  // Like
                  _actionButton(
                    icon: _svgIcon(
                      path: _heartSvg(),
                      active:
                          _liked[index],
                      size: 43,
                    ),
                    label: 'Like',
                    active:
                        _liked[index],
                    onTap: () =>
                        _toggleLike(index),
                  ),

                  // Comment
                  _actionButton(
                    icon: _svgIcon(
                      path: _commentSvg(),
                      size: 43,
                    ),
                    label: 'Comment',
                    onTap: _showComments,
                  ),

                  // Save
                  _actionButton(
                    icon: _svgIcon(
                      path: _bookmarkSvg(),
                      active:
                          _saved[index],
                      size: 43,
                    ),
                    label: _saved[index]
                        ? 'Saved'
                        : 'Save',
                    active:
                        _saved[index],
                    onTap: () =>
                        _toggleSave(index),
                  ),

                  // Share
                  _actionButton(
                    icon: _svgIcon(
                      path: _shareSvg(),
                      size: 43,
                    ),
                    label: 'Share',
                    onTap: _shareVideo,
                  ),
                ],
              ),
            ),

            // --------------------------------------------------
            // CAPTION
            // --------------------------------------------------

            Positioned(
              left: 16,
              right: 92,
              bottom: 92,
              child: Column(
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
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(width: 8),

                      GestureDetector(
                        onTap: () =>
                            _toggleFollow(index),
                        child: Text(
                          _followed[index]
                              ? 'Following'
                              : 'Follow',
                          style:
                              const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight:
                                FontWeight.bold,
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
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 6),

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
        );
      },
    );
  }

  // ------------------------------------------------------------
  // TOP TAB
  // ------------------------------------------------------------

  Widget _topTab(
    String title,
    int index,
  ) {
    final selected =
        _topIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _topIndex = index;
        });

        if (index == 0 ||
            index == 1) {
          if (_controllers.isNotEmpty) {
            _controllers.first.play();
          }
        }
      },
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: selected
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),

          const SizedBox(height: 5),

          AnimatedContainer(
            duration:
                const Duration(milliseconds: 200),
            height: 2,
            width: selected ? 35 : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SEARCH PAGE
  // ------------------------------------------------------------

  Widget _searchPage() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(
        16,
        35,
        16,
        20,
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _topIndex = 0;
                  });

                  if (_controllers.isNotEmpty) {
                    _controllers.first.play();
                  }
                },
                child: _svgIcon(
                  path: '''
<svg xmlns="http://www.w3.org/2000/svg"
viewBox="0 0 24 24">
<path d="M15 18l-6-6 6-6"
fill="none"
stroke="white"
stroke-width="2"
stroke-linecap="round"
stroke-linejoin="round"/>
</svg>
''',
                  size: 28,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: TextField(
                  controller:
                      _searchController,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                  decoration:
                      InputDecoration(
                    hintText:
                        'Search on PALOK',
                    hintStyle:
                        const TextStyle(
                      color: Colors.grey,
                    ),
                    prefixIcon:
                        Padding(
                      padding:
                          const EdgeInsets.all(12),
                      child: _svgIcon(
                        path:
                            _searchSvg(),
                        size: 22,
                      ),
                    ),
                    filled: true,
                    fillColor:
                        Colors.white12,
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                              30),
                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _showMessage(
                        'Search: $value',
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SIMPLE PAGE
  // ------------------------------------------------------------

  Widget _simplePage(
    String title,
    String svg,
  ) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            _svgIcon(
              path: svg,
              size: 70,
            ),

            const SizedBox(height: 18),

            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold,
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

  Widget _bottomNav() {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: Colors.white12,
            width: .6,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround,
        children: [
          // Home
          _navItem(
            _homeSvg(),
            'Home',
            0,
          ),

          // Friends
          _navItem(
            _friendsSvg(),
            'Friends',
            1,
          ),

          // Upload
          GestureDetector(
            behavior:
                HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _bottomIndex = 2;
              });

              for (final controller
                  in _controllers) {
                controller.pause();
              }
            },
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 48,
                  height: 36,
                  child: _svgIcon(
                    path: _uploadSvg(),
                    size: 48,
                  ),
                ),

                const SizedBox(height: 1),

                const Text(
                  'Upload',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Inbox
          _navItem(
            _inboxSvg(),
            'Inbox',
            3,
          ),

          // Profile
          _navItem(
            _profileSvg(),
            'Profile',
            4,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // BOTTOM NAV ITEM
  // ------------------------------------------------------------

  Widget _navItem(
    String svg,
    String label,
    int index,
  ) {
    final active =
        _bottomIndex == index;

    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _bottomIndex = index;
        });

        if (index != 0) {
          for (final controller
              in _controllers) {
            controller.pause();
          }
        } else {
          if (_controllers.isNotEmpty) {
            _controllers.first.play();
          }
        }
      },
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: active ? 1.08 : 1.0,
              duration:
                  const Duration(milliseconds: 150),
              child: _svgIcon(
                path: svg,
                size: 25,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : Colors.grey,
                fontSize: 11,
                fontWeight: active
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CURRENT PAGE
  // ------------------------------------------------------------

  Widget _currentPage() {
    // Friends
    if (_bottomIndex == 1) {
      return _simplePage(
        'Friends',
        _friendsSvg(),
      );
    }

    // Upload
    if (_bottomIndex == 2) {
      return _simplePage(
        'Upload Video',
        _uploadSvg(),
      );
    }

    // Inbox
    if (_bottomIndex == 3) {
      return _simplePage(
        'Inbox',
        _inboxSvg(),
      );
    }

    // Profile
    if (_bottomIndex == 4) {
      return _simplePage(
        'Profile',
        _profileSvg(),
      );
    }

    // Search
    if (_topIndex == 2) {
      return _searchPage();
    }

    // Home
    return _videoFeed();
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        bottom: false,
        child: _currentPage(),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: _bottomNav(),
      ),
    );
  }
}
