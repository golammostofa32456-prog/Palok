import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _bottomIndex = 0;
  int _topIndex = 0;

  final List<String> videoUrls = [
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
  ];

  late PageController _pageController;
  final List<VideoPlayerController> _controllers = [];

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    for (final url in videoUrls) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
      );

      _controllers.add(controller);

      controller.initialize().then((_) {
        if (mounted) {
          setState(() {});
          controller
            ..setLooping(true)
            ..play();
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();

    for (final controller in _controllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _changeVideo(int index) {
    for (int i = 0; i < _controllers.length; i++) {
      if (i == index) {
        if (_controllers[i].value.isInitialized) {
          _controllers[i].play();
        }
      } else {
        _controllers[i].pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ============================================================
          // FULL SCREEN VIDEO
          // ============================================================
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: videoUrls.length,
            onPageChanged: _changeVideo,
            itemBuilder: (context, index) {
              return _buildVideo(index);
            },
          ),

          // ============================================================
          // TOP HEADER
          // ============================================================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 18,
                right: 18,
                top: 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------------- PALOK LOGO ----------------
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'P',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Palok',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ---------------- FOR YOU ----------------
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _topIndex = 0;
                      });
                    },
                    child: Column(
                      children: [
                        Text(
                          'For You',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: _topIndex == 0
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 7),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 3,
                          width: _topIndex == 0 ? 42 : 0,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 28),

                  // ---------------- FOLLOWING ----------------
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _topIndex = 1;
                      });
                    },
                    child: Column(
                      children: [
                        Text(
                          'Following',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: _topIndex == 1
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 7),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 3,
                          width: _topIndex == 1 ? 42 : 0,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 22),

                  // ---------------- SEARCH ----------------
                  const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 34,
                  ),
                ],
              ),
            ),
          ),

          // ============================================================
          // RIGHT SIDE ACTION BUTTONS
          // ============================================================
          Positioned(
            right: 12,
            bottom: 118,
            child: Column(
              children: [
                _actionButton(
                  icon: Icons.favorite_border,
                  text: '11.7K',
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                _actionButton(
                  icon: Icons.chat_bubble_outline,
                  text: '234',
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                _actionButton(
                  icon: Icons.bookmark_border,
                  text: '811',
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                _actionButton(
                  icon: Icons.share_outlined,
                  text: '431',
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                // ---------------- FOLLOW BUTTON ----------------
                GestureDetector(
                  onTap: () {},
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: 29,
                        ),
                      ),

                      Transform.translate(
                        offset: const Offset(13, -14),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
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
              ],
            ),
          ),

          // ============================================================
          // BOTTOM LEFT VIDEO INFORMATION
          // ============================================================
          Positioned(
            left: 18,
            right: 95,
            bottom: 125,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username
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
                      onTap: () {},
                      child: const Text(
                        'Follow',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Description
                const Text(
                  'Welcome to PALOK 🎬',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 6),

                // Hashtags
                const Text(
                  '#Palok #ShortVideo #Bangladesh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 12),

                // Sound
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(25),
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
            ),
          ),

          // ============================================================
          // BOTTOM NAVIGATION
          // ============================================================
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                height: 78,
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
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

                    // CREATE BUTTON
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _bottomIndex = 2;
                        });
                      },
                      child: Container(
                        width: 58,
                        height: 43,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.cyan,
                              offset: Offset(-3, 0),
                              blurRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.pink,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // VIDEO WIDGET
  // ================================================================
  Widget _buildVideo(int index) {
    final controller = _controllers[index];

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
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // RIGHT ACTION BUTTON
  // ================================================================
  Widget _actionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 52,
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 31,
            ),
            const SizedBox(height: 5),
            Text(
              text,
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
  // BOTTOM NAV BUTTON
  // ================================================================
  Widget _bottomButton({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final bool selected = _bottomIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _bottomIndex = index;
        });
      },
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
