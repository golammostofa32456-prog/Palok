import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'profile_actions_service.dart';
import 'profile_model.dart';
import 'profile_notifications_screen.dart';
import 'profile_service.dart';
import 'profile_video_service.dart';
import '../video/video_post.dart';

class ProfileScreen extends StatelessWidget {
  final String? userId;

  const ProfileScreen({
    super.key,
    this.userId,
  });

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
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFE2C55)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _messageScreen('প্রোফাইল লোডের ত্রুটি:\n${snapshot.error}');
        }

        if (snapshot.data == null) {
          return _messageScreen('প্রোফাইলের তথ্য পাওয়া যায়নি');
        }

        final profile = snapshot.data!;
        final isOwnProfile = targetUserId == currentUserId;

        final displayName = profile.displayName.trim().isNotEmpty
            ? profile.displayName.trim()
            : profile.username.trim().isNotEmpty
                ? profile.username.trim()
                : 'ব্যবহারকারী';

        final cleanUsername = profile.username
            .trim()
            .replaceFirst(RegExp(r'^@'), '');

        final username =
            cleanUsername.isNotEmpty ? '@$cleanUsername' : '@${profile.id}';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.maybePop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.black),
                onPressed: () => _shareProfile(
                  context,
                  displayName,
                  username,
                  profile.id,
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              username,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildStatItem('${profile.followingCount}', 'অনুসরণ করছেন'),
                                const SizedBox(width: 15),
                                _buildStatItem('${profile.followersCount}', 'অনুসরণকারীগণ'),
                                const SizedBox(width: 15),
                                _buildStatItem('${profile.likesCount}', 'লাইক'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12, width: 1),
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: profile.profileImageUrl.trim().isNotEmpty
                              ? NetworkImage(profile.profileImageUrl)
                              : null,
                          child: profile.profileImageUrl.trim().isEmpty
                              ? const Icon(Icons.person, size: 50, color: Colors.grey)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: isOwnProfile
                            ? OutlinedButton(
                                onPressed: () {
                                  _showMessage(context, 'Edit Profile স্ক্রিন এখনো যুক্ত করা হয়নি');
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: const Color(0xFFF1F1F2),
                                ),
                                child: const Text(
                                  'প্রোফাইল এডিট করুন',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              )
                            : _TikTokFollowButton(
                                targetUserId: targetUserId,
                              ),
                      ),
                      if (!isOwnProfile) ...[
                        const SizedBox(width: 8),
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F1F2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.person_add_outlined, color: Colors.black),
                            onPressed: () {},
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (profile.bio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      profile.bio,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Colors.black12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        child: const Icon(Icons.menu, color: Colors.black),
                      ),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Icon(Icons.favorite_border, color: Colors.grey),
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

  static Future<void> _shareProfile(
    BuildContext context,
    String displayName,
    String username,
    String profileId,
  ) async {
    try {
      await Share.share(
        'PALOK-এ $displayName-এর প্রোফাইল\n$username\nUser ID: $profileId',
      );
    } catch (_) {}
  }

  Widget _buildVideos(String targetUserId) {
    return FutureBuilder<List<VideoPost>>(
      future: ProfileVideoService().getUserVideos(targetUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFFE2C55)),
            ),
          );
        }

        final videos = snapshot.data;

        if (videos == null || videos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 60, bottom: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.video_collection_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('এখনো কোনো ভিডিও নেই', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
            childAspectRatio: 0.75,
          ),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            final thumbnail = video.thumbnailUrl.trim().isNotEmpty
                ? video.thumbnailUrl.trim()
                : video.videoUrl.trim();

            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _ProfileVideoPlayerScreen(video: video),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.grey.shade200,
                    child: thumbnail.isNotEmpty
                        ? Image.network(
                            thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.play_arrow, color: Colors.black38),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.play_arrow, color: Colors.black38),
                          ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Row(
                      children: [
                        const Icon(Icons.play_arrow_outlined, size: 16, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          '${video.viewCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _messageScreen(String message) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Center(child: Text(message, style: const TextStyle(color: Colors.black))),
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static Widget _buildStatItem(String count, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }
}

class _TikTokFollowButton extends StatefulWidget {
  final String targetUserId;

  const _TikTokFollowButton({required this.targetUserId});

  @override
  State<_TikTokFollowButton> createState() => _TikTokFollowButtonState();
}

class _TikTokFollowButtonState extends State<_TikTokFollowButton> {
  final ProfileActionsService _service = ProfileActionsService();
  bool _following = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final result = await _service.isFollowing(widget.targetUserId);
      if (mounted) setState(() { _following = result; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final result = await _service.toggleFollow(widget.targetUserId);
      if (mounted) setState(() { _following = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: _loading ? null : _toggle,
        style: ElevatedButton.styleFrom(
          backgroundColor: _following ? const Color(0xFFF1F1F2) : const Color(0xFFFE2C55),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                _following ? 'মেসেজ' : 'অনুসরণ করুন',
                style: TextStyle(
                  color: _following ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}

class _ProfileVideoPlayerScreen extends StatefulWidget {
  final VideoPost video;
  const _ProfileVideoPlayerScreen({required this.video});

  @override
  State<_ProfileVideoPlayerScreen> createState() => _ProfileVideoPlayerScreenState();
}

class _ProfileVideoPlayerScreenState extends State<_ProfileVideoPlayerScreen> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl.trim()))
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _controller?.play();
        _controller?.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, leading: const BackButton(color: Colors.white)),
      body: Center(
        child: _controller != null && _controller!.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
