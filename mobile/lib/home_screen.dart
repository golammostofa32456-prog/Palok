import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _bottomIndex = 0;
  int _topIndex = 0;

  late PageController _pageController;

  late AnimationController _logoAnimationController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  final List<String> videoUrls = [
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
  ];

  final List<VideoPlayerController> _videoControllers = [];

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
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();

    _logoAnimationController.dispose();

    for (final controller in _videoControllers) {
      controller.dispose();
    }

    super.dispose();
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // PALOK LOGO - FIXED TOP LEFT
                  // ==================================================
                  AnimatedBuilder(
                    animation: _logoAnimationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScale.value,
                        alignment: Alignment.centerLeft,
                        child: Opacity(
                          opacity: _logoOpacity.value,
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
                  const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 34,
                  ),
                ],
              ),
            ),
          ),

          // ========================================================
          // RIGHT SIDE BUTTONS
          // FIXED POSITION
          // ========================================================
          Positioned(
            right: 10,
            bottom: 116,
            child: _buildRightButtons(),
          ),

          // ========================================================
          // VIDEO INFORMATION
          // FIXED BOTTOM LEFT
          // ========================================================
          Positioned(
            left: 18,
            right: 92,
            bottom: 124,
            child: _buildVideoInformation(),
          ),

          // ========================================================
          // BOTTOM NAVIGATION
          // FIXED POSITION
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
        // P LOGO
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
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

              // PLAY TRIANGLE
              Positioned(
                right: 7,
                top: 12,
                child: Container(
                  width: 0,
                  height: 0,
                  decoration: const BoxDecoration(
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
            fontWeight:
                selected ? FontWeight.w800 : FontWeight.w400,
          ),
        ),

        const SizedBox(height: 7),

        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 42 : 0,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // RIGHT SIDE ACTION BUTTONS
  // ================================================================
  Widget _buildRightButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionButton(
          icon: Icons.favorite_border,
          count: '11.7K',
        ),

        const SizedBox(height: 25),

        _actionButton(
          icon: Icons.chat_bubble_outline,
          count: '234',
        ),

        const SizedBox(height: 25),

        _actionButton(
          icon: Icons.bookmark_border,
          count: '811',
        ),

        const SizedBox(height: 25),

        _actionButton(
          icon: Icons.share_outlined,
          count: '431',
        ),

        const SizedBox(height: 24),

        // ==========================================================
        // FOLLOW PROFILE BUTTON
        // ==========================================================
        GestureDetector(
          onTap: () {},
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
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 29,
                  ),
                ),

                Positioned(
                  right: 0,
                  bottom: 2,
                  child: Container(
                    width: 23,
                    height: 23,
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
        ),
      ],
    );
  }

  // ================================================================
  // SINGLE RIGHT BUTTON
  // ================================================================
  Widget _actionButton({
    required IconData icon,
    required String count,
  }) {
    return GestureDetector(
      onTap: () {},
      child: SizedBox(
        width: 54,
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // USERNAME
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // DESCRIPTION
        const Text(
          'Welcome to PALOK 🎬',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 6),

        // HASHTAGS
        const Text(
          '#Palok #ShortVideo #Bangladesh',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
          ),
        ),

        const SizedBox(height: 12),

        // SOUND
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.48),
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

          // ========================================================
          // CREATE BUTTON
          // ========================================================
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

  // ================================================================
  // VIDEO
  // ================================================================
  Widget _buildVideo(int index) {
    final controller = _videoControllers[index];

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
}
