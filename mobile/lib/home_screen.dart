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
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
  ];

  final List<VideoPlayerController?> _controllers = [];

  @override
  void initState() {
    super.initState();

    for (final url in videoUrls) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
      );

      _controllers.add(controller);

      controller.initialize().then((_) {
        if (!mounted) return;

        controller
          ..setLooping(true)
          ..play();

        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller?.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.black,

      // ভিডিও পুরো স্ক্রিনে থাকবে
      extendBody: true,
      extendBodyBehindAppBar: true,

      body: Stack(
        children: [
          // =========================================================
          // FULL SCREEN VIDEO
          // =========================================================
          PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: videoUrls.length,
            onPageChanged: (index) {
              for (int i = 0; i < _controllers.length; i++) {
                if (i == index) {
                  _controllers[i]?.play();
                } else {
                  _controllers[i]?.pause();
                }
              }
            },
            itemBuilder: (context, index) {
              final controller = _controllers[index];

              if (controller == null ||
                  !controller.value.isInitialized) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                );
              }

              return _FullScreenVideo(
                controller: controller,
              );
            },
          ),

          // =========================================================
          // TOP BAR
          // =========================================================
          Positioned(
            top: media.padding.top + 10,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),

          // =========================================================
          // RIGHT SIDE BUTTONS
          // =========================================================
          Positioned(
            right: 8,
            bottom: media.padding.bottom + 92,
            child: _buildRightButtons(),
          ),

          // =========================================================
          // USER INFO / CAPTION
          // =========================================================
          Positioned(
            left: 16,
            right: 92,
            bottom: media.padding.bottom + 88,
            child: _buildVideoInfo(),
          ),

          // =========================================================
          // BOTTOM NAVIGATION
          // =========================================================
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNavigation(),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // TOP BAR
  // ===============================================================

  Widget _buildTopBar() {
    return SizedBox(
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // For You
          GestureDetector(
            onTap: () {
              setState(() {
                _topIndex = 0;
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'For You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: _topIndex == 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 5),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _topIndex == 0 ? 28 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 30),

          // Following
          GestureDetector(
            onTap: () {
              setState(() {
                _topIndex = 1;
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Following',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: _topIndex == 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 5),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _topIndex == 1 ? 28 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 25),

          // Search
          GestureDetector(
            onTap: () {},
            child: const Icon(
              Icons.search,
              color: Colors.white,
              size: 34,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // RIGHT SIDE BUTTONS
  // ===============================================================

  Widget _buildRightButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Profile
        _ProfileButton(
          onTap: () {},
        ),

        const SizedBox(height: 16),

        // Like
        _ActionButton(
          icon: Icons.favorite_border,
          label: '11.7K',
          onTap: () {},
        ),

        const SizedBox(height: 16),

        // Comment
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          label: '234',
          onTap: () {},
        ),

        const SizedBox(height: 16),

        // Bookmark
        _ActionButton(
          icon: Icons.bookmark_border,
          label: '811',
          onTap: () {},
        ),

        const SizedBox(height: 16),

        // Share
        _ActionButton(
          icon: Icons.share_outlined,
          label: '431',
          onTap: () {},
        ),
      ],
    );
  }

  // ===============================================================
  // USER INFO
  // ===============================================================

  Widget _buildVideoInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Username
        Row(
          children: [
            const Flexible(
              child: Text(
                '@palok_user',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10),

            GestureDetector(
              onTap: () {},
              child: const Text(
                'Follow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        // Caption
        const Text(
          'Welcome to PALOK 🎬',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            shadows: [
              Shadow(
                color: Colors.black87,
                blurRadius: 5,
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Hashtags
        const Text(
          '#Palok #ShortVideo #Bangladesh',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            shadows: [
              Shadow(
                color: Colors.black87,
                blurRadius: 5,
              ),
            ],
          ),
        ),

        const SizedBox(height: 7),

        // Original Sound
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note,
                color: Colors.white,
                size: 17,
              ),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Original Sound - PALOK',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===============================================================
  // BOTTOM NAVIGATION
  // ===============================================================

  Widget _buildBottomNavigation() {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home
            _BottomItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              selected: _bottomIndex == 0,
              onTap: () {
                setState(() {
                  _bottomIndex = 0;
                });
              },
            ),

            // Friends
            _BottomItem(
              icon: Icons.people_outline,
              activeIcon: Icons.people,
              label: 'Friends',
              selected: _bottomIndex == 1,
              onTap: () {
                setState(() {
                  _bottomIndex = 1;
                });
              },
            ),

            // Upload
            GestureDetector(
              onTap: () {
                setState(() {
                  _bottomIndex = 2;
                });
              },
              child: Container(
                width: 56,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.black,
                  size: 32,
                ),
              ),
            ),

            // Inbox
            _BottomItem(
              icon: Icons.chat_bubble_outline,
              activeIcon: Icons.chat_bubble,
              label: 'Inbox',
              selected: _bottomIndex == 3,
              onTap: () {
                setState(() {
                  _bottomIndex = 3;
                });
              },
            ),

            // Profile
            _BottomItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
              selected: _bottomIndex == 4,
              onTap: () {
                setState(() {
                  _bottomIndex = 4;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// FULL SCREEN VIDEO
// ===================================================================

class _FullScreenVideo extends StatelessWidget {
  final VideoPlayerController controller;

  const _FullScreenVideo({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final videoSize = controller.value.size;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: videoSize.width,
          height: videoSize.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

// ===================================================================
// PROFILE BUTTON
// ===================================================================

class _ProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfileButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Transparent circular profile
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.90),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 34,
                ),
              ),

              // Red +
              Positioned(
                bottom: -7,
                left: 16,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          const Text(
            'Follow',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// ACTION BUTTON
// ===================================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Transparent circular button
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,

              // Transparent black overlay
              color: Colors.black.withOpacity(0.12),

              // White circular border
              border: Border.all(
                color: Colors.white.withOpacity(0.85),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 29,
            ),
          ),

          const SizedBox(height: 4),

          // Count
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// BOTTOM ITEM
// ===================================================================

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 62,
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color: Colors.white,
              size: 27,
            ),

            const SizedBox(height: 2),

            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey,
                fontSize: 11,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
