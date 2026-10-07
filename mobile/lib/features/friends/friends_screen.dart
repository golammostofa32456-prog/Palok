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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.person_add_alt_1_outlined,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () {},
        ),
        title: const Text(
          'বন্ধুরা',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 25,
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
              // TikTok-style headline
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  18,
                ),
                child: Text(
                  'আপনার বন্ধুদের ভিডিওগুলো দেখতে\nতাদের অনুসরণ করুন',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              // Find friends / contacts card
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.contacts_rounded,
                          color: Colors.redAccent,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'পরিচিত বন্ধু খুঁজুন',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
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
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(7),
                          ),
                        ),
                        child: const Text(
                          'খুঁজুন',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Following
              if (following.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: Text(
                    'আপনি যাদের অনুসরণ করছেন',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...following.map(
                  (friend) => FriendItem(
                    friend: friend,
                    onFollowTap: () => _toggleFollow(friend),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(
                  color: Colors.white12,
                  height: 1,
                ),
                const SizedBox(height: 20),
              ],

              // Suggested creators
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Text(
                  'আপনার জন্য সাজেস্ট করা',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Text(
                  'নতুন creator এবং বন্ধুদের অনুসরণ করুন',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              if (_controller.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 50,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.redAccent,
                    ),
                  ),
                )
              else if (suggested.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 45,
                    horizontal: 20,
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 52,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'নতুন কোনো creator পাওয়া যায়নি',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'পরে আবার চেষ্টা করুন',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
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

              const SizedBox(height: 35),
            ],
          ),
        ),
      ),
    );
  }
}
