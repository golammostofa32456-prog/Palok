import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  final List<String> videos = [
    'Video 1',
    'Video 2',
    'Video 3',
    'Video 4',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: videos.length,
        onPageChanged: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: Colors.black,
                child: Center(
                  child: Text(
                    videos[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'PALOK',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),

              Positioned(
                right: 15,
                bottom: 120,
                child: Column(
                  children: [
                    _actionButton(Icons.favorite_border, 'Like'),
                    const SizedBox(height: 22),
                    _actionButton(Icons.comment_outlined, 'Comment'),
                    const SizedBox(height: 22),
                    _actionButton(Icons.share_outlined, 'Share'),
                    const SizedBox(height: 22),
                    _actionButton(Icons.person_add_alt_1, 'Follow'),
                  ],
                ),
              ),

              Positioned(
                left: 16,
                right: 80,
                bottom: 35,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '@palok_user',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Welcome to PALOK 🎬',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '#Palok #Video #Bangladesh',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _actionButton(IconData icon, String label) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 34,
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
    );
  }
}
