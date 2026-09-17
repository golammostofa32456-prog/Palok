import 'package:flutter/material.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final List<Map<String, dynamic>> creators = [
    {
      'username': '@palok_creator',
      'likes': '11.7K likes',
      'following': false,
    },
    {
      'username': '@nature_palok',
      'likes': '8.5K likes',
      'following': false,
    },
    {
      'username': '@palok_video',
      'likes': '4.2K likes',
      'following': false,
    },
  ];

  void _toggleFollow(int index) {
    setState(() {
      creators[index]['following'] = !creators[index]['following'];
    });

    final isFollowing = creators[index]['following'] as bool;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFollowing
              ? 'You are now following ${creators[index]['username']}'
              : 'Unfollowed ${creators[index]['username']}',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildCreatorAvatar() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF4F81),
            Color(0xFF00C9E8),
          ],
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF222222),
        ),
        child: const Icon(
          Icons.person,
          color: Colors.white,
          size: 43,
        ),
      ),
    );
  }

  Widget _buildCreatorCard(int index) {
    final creator = creators[index];
    final bool following = creator['following'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          _buildCreatorAvatar(),

          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creator['username'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  creator['likes'],
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          SizedBox(
            width: 150,
            height: 56,
            child: OutlinedButton(
              onPressed: () => _toggleFollow(index),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: following
                      ? Colors.white54
                      : const Color(0xFFFF2D75),
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                following ? 'Following' : 'Follow',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 82,
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: Color(0xFF222222),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _bottomItem(
              icon: Icons.home_filled,
              label: 'Home',
              selected: false,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _bottomItem(
              icon: Icons.people,
              label: 'Friends',
              selected: true,
              onTap: () {},
            ),
            Expanded(
              child: Center(
                child: Container(
                  width: 130,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF00C9E8),
                        Color(0xFFFF2D75),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),
            _bottomItem(
              icon: Icons.chat_bubble_outline,
              label: 'Inbox',
              selected: false,
              onTap: () {},
            ),
            _bottomItem(
              icon: Icons.person_outline,
              label: 'Profile',
              selected: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 27,
              color: selected
                  ? Colors.white
                  : Colors.white54,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white54,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  32,
                  36,
                  32,
                  30,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Friends',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Connect with creators on PALOK',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 20,
                      ),
                    ),

                    const SizedBox(height: 42),

                    const Text(
                      'Suggested creators',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 24),

                    ...List.generate(
                      creators.length,
                      (index) => _buildCreatorCard(index),
                    ),
                  ],
                ),
              ),
            ),

            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }
}
