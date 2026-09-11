import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';

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

  @override
  void initState() {
    super.initState();

    controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    controller.initialize().then((_) {
      if (!mounted) return;

      controller.setLooping(true);

      if (widget.isActive) {
        controller.play();
      }

      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant PalokVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!controller.value.isInitialized) return;

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

  void toggleLike() {
    setState(() {
      isLiked = !isLiked;
    });
  }

  void toggleFollow() {
    setState(() {
      isFollowing = !isFollowing;
    });
  }

  void toggleSave() {
    setState(() {
      isSaved = !isSaved;
    });
  }

  void toggleVideo() {
    if (!controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: toggleVideo,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // VIDEO BACKGROUND
          Container(color: Colors.black),

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

          // DARK GRADIENT
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

          // PALOK LOGO
          const SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'PALOK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 5,
                  ),
                ),
              ),
            ),
          ),

          // RIGHT ACTION BUTTONS
          Positioned(
            right: 12,
            bottom: 105,
            child: Column(
              children: [
                // PROFILE
                _profileButton(),

                const SizedBox(height: 21),

                // LIKE
                _svgActionButton(
                  svg: _likeSvg(),
                  label: 'Like',
                  color: isLiked ? Colors.red : Colors.white,
                  onTap: toggleLike,
                ),

                const SizedBox(height: 21),

                // COMMENT
                _svgActionButton(
                  svg: _commentSvg(),
                  label: 'Comment',
                  onTap: () {},
                ),

                const SizedBox(height: 21),

                // SAVE
                _svgActionButton(
                  svg: _saveSvg(),
                  label: 'Save',
                  color: isSaved ? Colors.amber : Colors.white,
                  onTap: toggleSave,
                ),

                const SizedBox(height: 21),

                // SHARE
                _svgActionButton(
                  svg: _shareSvg(),
                  label: 'Share',
                  onTap: () {},
                ),
              ],
            ),
          ),

          // CAPTION
          Positioned(
            left: 16,
            right: 88,
            bottom: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.username,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    GestureDetector(
                      onTap: toggleFollow,
                      child: Text(
                        isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          color: isFollowing
                              ? Colors.white70
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
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
      ),
    );
  }

  // PROFILE BUTTON
  Widget _profileButton() {
    return GestureDetector(
      onTap: toggleFollow,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black54,
              border: Border.all(
                color: Colors.white,
                width: 1.8,
              ),
            ),
            child: Center(
              child: SvgPicture.string(
                _profileSvg(),
                width: 29,
                height: 29,
              ),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            isFollowing ? 'Following' : 'Follow',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // SVG ACTION BUTTON
  Widget _svgActionButton({
    required String svg,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SvgPicture.string(
            svg,
            width: 36,
            height: 36,
            colorFilter: ColorFilter.mode(
              color,
              BlendMode.srcIn,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // PROFILE SVG
  String _profileSvg() {
    return '''
<svg viewBox="0 0 24 24"
xmlns="http://www.w3.org/2000/svg">
<circle
cx="12"
cy="8"
r="3.2"
fill="white"/>
<path
d="M5.5 20c.6-4 3-6 6.5-6s5.9 2 6.5 6"
fill="none"
stroke="white"
stroke-width="1.8"
stroke-linecap="round"/>
</svg>
''';
  }

  // LIKE SVG
  String _likeSvg() {
    if (isLiked) {
      return '''
<svg viewBox="0 0 24 24"
xmlns="http://www.w3.org/2000/svg">
<path
d="M12 21s-7.2-4.7-9.4-9C.8 8.4 2.6 4.5 6.3 4.5
c2.1 0 3.6 1.2 4.7 2.8
1.1-1.6 2.6-2.8 4.7-2.8
3.7 0 5.5 3.9 3.7 7.5C19.2 16.3 12 21 12 21z"
fill="white"/>
</svg>
''';
    }

    return '''
<svg viewBox="0 0 24 24"
xmlns="http://www.w3.org/2000/svg">
<path
d="M20.8 8.7c0 5.1-8.8 10.7-8.8 10.7S3.2 13.8 3.2 8.7
C3.2 6.1 5.1 4 7.7 4
c1.8 0 3.4 1 4.3 2.4
C12.9 5 14.5 4 16.3 4
c2.6 0 4.5 2.1 4.5 4.7z"
fill="none"
stroke="white"
stroke-width="1.8"
stroke-linejoin="round"/>
</svg>
''';
  }

  // COMMENT SVG
  String _commentSvg() {
    return '''
<svg viewBox="0 0 24 24"
xmlns="http://www.w3.org/2000/svg">
<path
d="M4 5.5A2.5 2.5 0 0 1 6.5 3h11A2.5 2.5 0 0 1 20 5.5v8
a2.5 2.5 0 0 1-2.5 2.5H10l-5 4v-4.5A2.5 2.5 0 0 1 3 13.5v-8
A2.5 2.5 0 0 1 4 5.5z"
fill="none"
stroke="white"
stroke-width="1.7"
stroke-linejoin="round"/>
<path
d="M7 8h10M7 11.5h7"
stroke="white"
stroke-width="1.5"
stroke-linecap="round"/>
</svg>
''';
  }

  // SAVE SVG
  String _saveSvg() {
    return '''
<svg viewBox="0 0 24 24"
xmlns="http://www.w3.org/2000/svg">
<path
d="M6 3.5A2.5 2.5 0 0 1 8.5 1h7A2.5 2.5 0 0 1 18 3.5V21l-6-3.8L6 21V3.5z"
fill="none"
stroke="white"
stroke-width="1.8"
stroke-linejoin="round"/>
</svg>
''';
  }

  // SHARE SVG
  String _shareSvg() {
    return '''
<svg viewBox="0 0 24 24"
xmlns="http://www.w3.org/2000/svg">
<circle
cx="18"
cy="5"
r="2.2"
fill="none"
stroke="white"
stroke-width="1.7"/>
<circle
cx="6"
cy="12"
r="2.2"
fill="none"
stroke="white"
stroke-width="1.7"/>
<circle
cx="18"
cy="19"
r="2.2"
fill="none"
stroke="white"
stroke-width="1.7"/>
<path
d="M8 11l7.8-4.5M8 13l7.8 4.5"
fill="none"
stroke="white"
stroke-width="1.7"
stroke-linecap="round"/>
</svg>
''';
  }
}
