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
    // তোমার ভিডিও URL এখানে দাও
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
        controller
          ..setLooping(true)
          ..play();

        if (mounted) {
          setState(() {});
        }
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
    return Scaffold(
      backgroundColor: Colors.black,

      // ভিডিওকে bottom navigation-এর নিচ পর্যন্ত যেতে দিচ্ছি
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

              if (controller == null || !controller.value.isInitialized) {
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
            top: MediaQuery.of(context).padding.top + 15,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),

          // =========================================================
          // RIGHT SIDE BUTTONS
          // =========================================================
          Positioned(
            right: 10,
            bottom: MediaQuery.of(context).padding.bottom + 105,
            child: _buildRightButtons(),
          ),

          // =========================================================
          // USERNAME + CAPTION
          // =========================================================
          Positioned(
            left: 18,
            right: 90,
            bottom: MediaQuery.of(context).padding.bottom + 100,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _topIndex = 0;
            });
          },
          child: Text(
            'For You',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight:
                  _topIndex == 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),

        const SizedBox(width: 28),

        GestureDetector(
          onTap: () {
            setState(() {
              _topIndex = 1;
            });
          },
          child: Text(
            'Following',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight:
                  _topIndex == 1 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),

        const SizedBox(width: 25),

        // Search
        const Icon(
          Icons.search,
          color: Colors.white,
          size: 34,
        ),
      ],
    );
  }

  // ===============================================================
  // RIGHT SIDE
  // ===============================================================

  Widget _buildRightButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Profile
        _ProfileButton(),

        const SizedBox(height: 20),

        _ActionButton(
          icon: Icons.favorite_border,
          label: '11.7K',
          onTap: () {},
        ),

        const SizedBox(height: 20),

        _ActionButton(
          icon: Icons.chat_bubble_outline,
          label: '234',
          onTap: () {},
        ),

        const SizedBox(height: 20),

        _ActionButton(
          icon: Icons.bookmark_border,
          label: '811',
          onTap: () {},
        ),

        const SizedBox(height: 20),

        _ActionButton(
          icon: Icons.share,
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
        Row(
          children: [
            const Text(
              '@palok_user',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
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
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        const Text(
          'Welcome to PALOK 🎬',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          '#Palok #ShortVideo #Bangladesh',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
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
      height: 78,
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
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
                width: 52,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.black,
                  size: 30,
                ),
              ),
            ),

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
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 35,
                ),
              ),
            ),

            Positioned(
              bottom: -10,
              left: 17,
              child: Container(
                width: 25,
                height: 25,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 13),

        const Text(
          'Follow',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 42,
          ),

          const SizedBox(height: 3),

          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
        width: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color: Colors.white,
              size: 27,
            ),

            const SizedBox(height: 3),

            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey,
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
