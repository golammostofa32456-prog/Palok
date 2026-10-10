import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'profile_service.dart';
import 'profile_model.dart';

class ProfileScreen extends StatelessWidget {
  final String? userId;

  const ProfileScreen({
    Key? key,
    this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final targetUserId = userId ?? currentUserId;

    if (targetUserId == null || targetUserId.isEmpty) {
      return _messageScreen('প্রোফাইল দেখতে লগইন করুন');
    }

    return FutureBuilder<ProfileModel?>(
      future: ProfileService().getProfile(targetUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _messageScreen('প্রোফাইল লোড করা যায়নি');
        }

        final profile = snapshot.data;

        if (profile == null) {
          return _messageScreen('এই প্রোফাইল পাওয়া যায়নি');
        }

        final isOwnProfile = targetUserId == currentUserId;
        final displayName = profile.displayName.isNotEmpty
            ? profile.displayName
            : profile.username.isNotEmpty
                ? profile.username
                : 'ব্যবহারকারী';

        final username = profile.username.isNotEmpty
            ? '@${profile.username.replaceFirst(RegExp(r'^@'), '')}'
            : '@${profile.id}';

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),

                // Profile picture
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.cyan,
                          Colors.pink,
                          Colors.purple,
                        ],
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF1E1E1E),
                      backgroundImage:
                          profile.profileImageUrl.isNotEmpty
                              ? NetworkImage(profile.profileImageUrl)
                              : null,
                      child: profile.profileImageUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 55,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 18),

                // Profile statistics
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatItem(
                      '${profile.followingCount}',
                      'Following',
                    ),
                    _buildDivider(),
                    _buildStatItem(
                      '${profile.followersCount}',
                      'Followers',
                    ),
                    _buildDivider(),
                    _buildStatItem(
                      '${profile.likesCount}',
                      'Likes',
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Own profile and other users' profiles are different
                if (isOwnProfile)
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade800),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 12,
                      ),
                      backgroundColor: const Color(0xFF1A1A1A),
                    ),
                    child: const Text(
                      'Edit Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  )
                else
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.pink),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Follow',
                      style: TextStyle(
                        color: Colors.pink,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),

                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    profile.bio,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(color: Colors.white12, height: 1),

                // Profile tabs
                const Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Icon(Icons.grid_on, color: Colors.white),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Icon(
                          Icons.favorite_border,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Icon(
                          Icons.lock_outline,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                const Icon(
                  Icons.video_collection_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                const Text(
                  'এখনো কোনো ভিডিও নেই',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _messageScreen(String message) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: const BackButton(color: Colors.white),
      ),
      body: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  static Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  static Widget _buildDivider() {
    return Container(
      height: 14,
      width: 1,
      color: Colors.grey.shade800,
      margin: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
