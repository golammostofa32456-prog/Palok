import 'package:flutter/material.dart';

import 'friend_item.dart';
import 'friends_controller.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final FriendsController _controller;

  @override
  void initState() {
    super.initState();

    _controller = FriendsController();

    _loadFriends();
  }

  Future<void> _loadFriends() async {
    await _controller.loadFriends();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleFollow(friend) async {
    await _controller.toggleFollow(friend);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final following = _controller.following;
    final suggested = _controller.suggestedCreators;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Friends',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.person_add_alt_1_outlined,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.redAccent,
        backgroundColor: const Color(0xFF1E1E1E),
        onRefresh: _loadFriends,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Find Friends
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.contacts_rounded,
                        color: Colors.redAccent,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Find contacts',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'আপনার পরিচিত বন্ধুদের খুঁজুন',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: const Text(
                          'Find',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Following
              if (following.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'Following',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...following.map(
                  (friend) => FriendItem(
                    friend: friend,
                    onFollowTap: () => _toggleFollow(friend),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(
                  color: Colors.white12,
                  height: 1,
                ),
              ],

              // Suggested creators
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  8,
                ),
                child: Text(
                  'Suggested creators',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (_controller.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.redAccent,
                    ),
                  ),
                )
              else if (suggested.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'নতুন কোনো creator পাওয়া যায়নি',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...suggested.map(
                  (friend) => FriendItem(
                    friend: friend,
                    onFollowTap: () => _toggleFollow(friend),
                  ),
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
