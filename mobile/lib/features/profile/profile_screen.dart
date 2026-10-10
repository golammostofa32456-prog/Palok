import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import 'profile_actions_service.dart';
import 'profile_notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';

import 'profile_service.dart';
import 'profile_model.dart';
import 'profile_video_service.dart';
import '../video/video_post.dart';
import '../video/video_player_widget.dart';

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
            body: Center(child: CircularProgressIndicator()),
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
              onPressed: () => Navigator.maybePop(context),
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
    tooltip: 'নোটিফিকেশন',
    icon: const Icon(
      Icons.notifications_none,
      color: Colors.white,
    ),
    onPressed: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('নোটিফিকেশন ফিচার পরে যুক্ত করা হবে'),
        ),
      );
    },
  ),
  IconButton(
    tooltip: 'শেয়ার',
    icon: const Icon(
      Icons.share_outlined,
      color: Colors.white,
    ),
    onPressed: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('প্রোফাইল শেয়ার ফিচার পরে যুক্ত করা হবে'),
        ),
      );
    },
  ),
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
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.cyan, Colors.pink, Colors.purple],
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF1E1E1E),
                      backgroundImage: profile.profileImageUrl.isNotEmpty
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
                    _buildStatItem('${profile.likesCount}', 'Likes'),
                  ],
                ),
                const SizedBox(height: 18),
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
                _buildVideos(targetUserId),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideos(String targetUserId) {
    return FutureBuilder<List<VideoPost>>(
      future: ProfileVideoService().getUserVideos(targetUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'ভিডিও লোড করা যায়নি',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final videos = snapshot.data;
        if (videos == null || videos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 60, bottom: 40),
            child: Column(
              children: [
                Icon(
                  Icons.video_collection_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 12),
                Text(
                  'এখনো কোনো ভিডিও নেই',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.68,
          ),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            final thumbnail = video.thumbnailUrl.trim();

            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _ProfileVideoPlayerScreen(video: video),
                  ),
                );
              },
              child: Container(
                color: const Color(0xFF1E1E1E),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnail.isNotEmpty)
                      Image.network(
                        thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Colors.white70,
                            size: 36,
                          ),
                        ),
                      )
                    else
                      const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          color: Colors.white70,
                          size: 36,
                        ),
                      ),
                    Positioned(
                      left: 6,
                      bottom: 5,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.play_arrow,
                            size: 16,
                            color: Colors.white,
                          ),
                          Text(
                            '${video.viewCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
          style: const TextStyle(color: Colors.grey, fontSize: 12),
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

class _ProfileVideoPlayerScreen extends StatefulWidget {
  final VideoPost video;

  const _ProfileVideoPlayerScreen({
    required this.video,
  });

  @override
  State<_ProfileVideoPlayerScreen> createState() =>
      _ProfileVideoPlayerScreenState();
}

class _ProfileVideoPlayerScreenState
    extends State<_ProfileVideoPlayerScreen> {
  VideoPlayerController? _controller;
  String? _errorMessage;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final url = widget.video.videoUrl.trim();

    if (url.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'এই ভিডিওর লিংক পাওয়া যায়নি';
        });
      }
      return;
    }

    VideoPlayerController? controller;

    try {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(true);
      await controller.play();

      if (!mounted) return;

      setState(() {
        _isPlaying = true;
      });
    } catch (_) {
      if (controller != null) {
        await controller.dispose();
      }

      if (!mounted) return;

      setState(() {
        _controller = null;
        _errorMessage = 'ভিডিও চালানো যাচ্ছে না। ইন্টারনেট বা ভিডিও লিংক পরীক্ষা করুন।';
      });
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    } else {
      await controller.play();
      if (mounted) {
        setState(() => _isPlaying = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'ভিডিও',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: _errorMessage != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            : controller == null || !controller.value.isInitialized
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: _togglePlayback,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                    Positioned.fill(
  child: FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(
      width: controller.value.size.width,
      height: controller.value.size.height,
      child: VideoPlayer(controller),
    ),
  ),
),
                        if (!_isPlaying)
                          const Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 64,
                          ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 20,
                          child: Text(
                            widget.video.caption,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
