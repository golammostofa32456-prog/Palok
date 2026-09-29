import 'package:flutter/material.dart';
import '../friends/friends_screen.dart';
import '../inbox/inbox_screen.dart';
import '../profile/profile_screen.dart';
import '../video/video_card.dart';
import '../camera/camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // ভিডিওর জন্য সাময়িক ফেক ডাটা লিস্ট
  final List<Map<String, String>> _videos = [
    {
      'videoUrl': 'https://assets.mixkit.co/videos/preview/mixkit-tree-with-yellow-flowers-1173-large.mp4',
      'username': '@palok_official',
      'caption': 'Welcome to PALOK App! 🚀 #palok #trending #flutter',
      'songName': 'Original Sound - PALOK',
      'likes': '12.5K',
      'comments': '450',
    },
    {
      'videoUrl': 'https://assets.mixkit.co/videos/preview/mixkit-mother-with-her-little-daughter-eating-a-marshmallow-41501-large.mp4',
      'username': '@nature_lover',
      'caption': 'Beautiful moments ❤️ #nature #love',
      'songName': 'Relaxing Music - Nature',
      'likes': '98.2K',
      'comments': '1.2K',
    },
  ];

  // বটম নেভিগেশন বারের ট্যাব পরিবর্তনের লজিক
  void _onItemTapped(int index) {
    if (index == 2) {
      // প্লাস (+) বাটনে চাপ দিলে সরাসরি টিকটক স্টাইল ক্যামেরা স্ক্রিনে নিয়ে যাবে
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TikTokCameraScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ট্যাবের পেজগুলোর লিস্ট
    final List<Widget> _pages = [
      // ০. হোম ফিড (টিকটক ভিডিও ফিড)
      Stack(
        children: [
          PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              final video = _videos[index];
              return VideoCard(
                videoUrl: video['videoUrl']!,
                username: video['username']!,
                caption: video['caption']!,
                songName: video['songName']!,
                likes: video['likes']!,
                comments: video['comments']!,
              );
            },
          ),
          // টপ বার (For You / Following)
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Following',
                    style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const Text('|', style: TextStyle(color: Colors.white38)),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'For You',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ১. ফ্রেন্ডস স্ক্রিন
      const FriendsScreen(),

      // ২. ক্যামেরা পজিশন (হোল্ডার)
      const SizedBox(),

      // ৩. ইনবক্স স্ক্রিন
      const InboxScreen(),

      // ৪. প্রোফাইল স্ক্রিন
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Friends',
          ),
          // প্লাস (+) বাটন আইকন
          BottomNavigationBarItem(
            icon: Container(
              width: 45,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [Colors.cyan, Colors.pinkAccent],
                ),
              ),
              child: Center(
                child: Container(
                  width: 38,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 20),
                ),
              ),
            ),
            label: '',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Inbox',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
