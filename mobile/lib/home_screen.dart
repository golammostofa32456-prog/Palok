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

  final TextEditingController _searchController = TextEditingController();

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
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controllers.add(controller);
      _liked.add(false);
      _saved.add(false);
      _followed.add(false);

      controller.initialize().then((_) {
        if (mounted) {
          setState(() {});
        }
        controller.setLooping(true);
        controller.play();
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleLike(int index) {
    setState(() {
      _liked[index] = !_liked[index];
    });
  }

  void _toggleSave(int index) {
    setState(() {
      _saved[index] = !_saved[index];
    });

    _showMessage(
      _saved[index] ? 'ভিডিও Save করা হয়েছে' : 'ভিডিও থেকে Save সরানো হয়েছে',
    );
  }

  void _toggleFollow(int index) {
    setState(() {
      _followed[index] = !_followed[index];
    });

    _showMessage(
      _followed[index] ? 'Follow করা হয়েছে' : 'Unfollow করা হয়েছে',
    );
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
              const SizedBox(height: 20),
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
                      _showMessage('Comment যোগ করার ব্যবস্থা প্রস্তুত');
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

  void _shareVideo() {
    _showMessage('Share অপশন প্রস্তুত');
  }

  Widget _svgIcon({
    required String path,
    required bool active,
    double size = 29,
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

  String _personSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<circle cx="12" cy="7" r="4" fill="none" stroke="white" stroke-width="2"/>
<path d="M4 21c.7-4.2 3.3-6.5 8-6.5s7.3 2.3 8 6.5"
fill="none" stroke="white" stroke-width="2" stroke-linecap="round"/>
</svg>
''';
  }

  String _heartSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path d="M20.8 8.8c0 5.5-8.8 10.2-8.8 10.2S3.2 14.3 3.2 8.8
C3.2 5.8 5.3 4 8 4c1.6 0 3.1.8 4 2.1C12.9 4.8 14.4 4 16 4
c2.7 0 4.8 1.8 4.8 4.8z"
fill="none" stroke="white" stroke-width="2"
stroke-linejoin="round"/>
</svg>
''';
  }

  String _commentSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path d="M4 5.5A2.5 2.5 0 0 1 6.5 3h11A2.5 2.5 0 0 1 20 5.5v8
a2.5 2.5 0 0 1-2.5 2.5H10l-5.5 4v-4.3A2.5 2.5 0 0 1 4 13.5z"
fill="none" stroke="white" stroke-width="2"
stroke-linejoin="round"/>
</svg>
''';
  }

  String _bookmarkSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path d="M6 4.5A2.5 2.5 0 0 1 8.5 2h7A2.5 2.5 0 0 1 18 4.5V21
l-6-3.7L6 21z"
fill="none" stroke="white" stroke-width="2"
stroke-linejoin="round"/>
</svg>
''';
  }

  String _shareSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<circle cx="18" cy="5" r="2.5" fill="none" stroke="white" stroke-width="2"/>
<circle cx="6" cy="12" r="2.5" fill="none" stroke="white" stroke-width="2"/>
<circle cx="18" cy="19" r="2.5" fill="none" stroke="white" stroke-width="2"/>
<path d="M8.2 10.8l7.5-4.4M8.2 13.2l7.5 4.4"
fill="none" stroke="white" stroke-width="2"/>
</svg>
''';
  }

  Widget _actionButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 21),
        child: Column(
          children: [
            AnimatedScale(
              scale: active ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: icon,
            ),
            const SizedBox(height: 5),
            Text(
              label,
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

  Widget _videoFeed() {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: _videos.length,
      onPageChanged: (index) {
        for (int i = 0; i < _controllers.length; i++) {
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
            Container(color: Colors.black),

            if (controller.value.isInitialized)
              Center(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
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

            // কালো/গ্রেডিয়েন্ট overlay
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(.35),
                        Colors.transparent,
                        Colors.black.withOpacity(.65),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // PALOK logo
            const Positioned(
              top: 48,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                  ),
                ),
              ),
            ),

            // Top tabs
            Positioned(
              top: 105,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _topTab('For You', 0),
                  const SizedBox(width: 28),
                  _topTab('Following', 1),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _topIndex = 2;
                      });
                    },
                    child: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                ],
              ),
            ),

            // Right action buttons
            Positioned(
              right: 14,
              bottom: 145,
              child: Column(
                children: [
                  _actionButton(
                    icon: _svgIcon(
                      path: _personSvg(),
                      active: _followed[index],
                      size: 43,
                    ),
                    label: _followed[index] ? 'Following' : 'Follow',
                    active: _followed[index],
                    onTap: () => _toggleFollow(index),
                  ),

                  _actionButton(
                    icon: _svgIcon(
                      path: _heartSvg(),
                      active: _liked[index],
                      size: 43,
                    ),
                    label: 'Like',
                    active: _liked[index],
                    onTap: () => _toggleLike(index),
                  ),

                  _actionButton(
                    icon: _svgIcon(
                      path: _commentSvg(),
                      active: false,
                      size: 43,
                    ),
                    label: 'Comment',
                    onTap: _showComments,
                  ),

                  _actionButton(
                    icon: _svgIcon(
                      path: _bookmarkSvg(),
                      active: _saved[index],
                      size: 43,
                    ),
                    label: 'Save',
                    active: _saved[index],
                    onTap: () => _toggleSave(index),
                  ),

                  _actionButton(
                    icon: _svgIcon(
                      path: _shareSvg(),
                      active: false,
                      size: 43,
                    ),
                    label: 'Share',
                    onTap: _shareVideo,
                  ),
                ],
              ),
            ),

            // Caption
            Positioned(
              left: 18,
              right: 100,
              bottom: 108,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _toggleFollow(index),
                        child: Text(
                          _followed[index] ? 'Following' : 'Follow',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
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
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 7),
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

  Widget _topTab(String title, int index) {
    final selected = _topIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _topIndex = index;
        });
      },
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: selected ? 35 : 0,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _searchPage() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(18, 55, 18, 20),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _topIndex = 0;
                  });
                },
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search on PALOK',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _simplePage(String title, IconData icon) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 65,
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

  Widget _bottomNav() {
    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: Colors.white12,
            width: .5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, 'Home', 0),
          _navItem(Icons.people_alt_rounded, 'Friends', 1),

          // Upload button
          GestureDetector(
            onTap: () {
              setState(() {
                _bottomIndex = 2;
              });

              _showMessage('Upload screen প্রস্তুত');
            },
            child: Container(
              width: 48,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xff25F4EE),
                    Colors.white,
                    Color(0xffFE2C55),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.add,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ),
          ),

          _navItem(Icons.chat_bubble_rounded, 'Inbox', 3),
          _navItem(Icons.person_rounded, 'Profile', 4),
        ],
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    int index,
  ) {
    final active = _bottomIndex == index;

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
              color: active ? Colors.white : Colors.grey,
              size: 25,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.grey,
                fontSize: 11,
                fontWeight:
                    active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currentPage() {
    if (_bottomIndex == 1) {
      return _simplePage(
        'Friends',
        Icons.people_alt_rounded,
      );
    }

    if (_bottomIndex == 2) {
      return _simplePage(
        'Upload Video',
        Icons.add_circle_outline,
      );
    }

    if (_bottomIndex == 3) {
      return _simplePage(
        'Inbox',
        Icons.chat_bubble_outline,
      );
    }

    if (_bottomIndex == 4) {
      return _simplePage(
        'Profile',
        Icons.person_outline,
      );
    }

    // Home
    if (_topIndex == 2) {
      return _searchPage();
    }

    return _videoFeed();
  }

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
