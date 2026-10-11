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
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.pink),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _messageScreen('প্রোফাইল লোড করা যায়নি');
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
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              tooltip: 'ফিরে যান',
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                  if (FirebaseAuth.instance.currentUser == null) {
                    _showMessage(context, 'নোটিফিকেশন দেখতে লগইন করুন');
                    return;
                  }

                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfileNotificationsScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'প্রোফাইল শেয়ার',
                icon: const Icon(
                  Icons.share_outlined,
                  color: Colors.white,
                ),
                onPressed: () => _shareProfile(
                  context,
                  displayName,
                  username,
                  profile.id,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'আরও অপশন',
                color: const Color(0xFF242424),
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) async {
                  switch (value) {
                    case 'share':
                      await _shareProfile(
                        context,
                        displayName,
                        username,
                        profile.id,
                      );
                      break;

                    case 'refresh':
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => ProfileScreen(
                            userId: targetUserId,
                          ),
                        ),
                      );
                      break;

                    case 'copy_id':
                      await Share.share(
                        'PALOK User ID: ${profile.id}',
                      );
                      break;

                    case 'report':
                      await _reportProfile(
                        context,
                        targetUserId,
                        displayName,
                      );
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem<String>(
                    value: 'share',
                    child: _MenuItem(
                      icon: Icons.share_outlined,
                      label: 'প্রোফাইল শেয়ার',
                    ),
                  ),
                  if (isOwnProfile)
                    const PopupMenuItem<String>(
                      value: 'refresh',
                      child: _MenuItem(
                        icon: Icons.refresh,
                        label: 'প্রোফাইল রিফ্রেশ',
                      ),
                    )
                  else ...[
                    const PopupMenuItem<String>(
                      value: 'copy_id',
                      child: _MenuItem(
                        icon: Icons.copy,
                        label: 'User ID শেয়ার',
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: _MenuItem(
                        icon: Icons.flag_outlined,
                        label: 'প্রোফাইল রিপোর্ট',
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
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
                    backgroundImage: profile.profileImageUrl.trim().isNotEmpty
                        ? NetworkImage(profile.profileImageUrl)
                        : null,
                    child: profile.profileImageUrl.trim().isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 55,
                            color: Colors.white,
                          )
                        : null,
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
                    _buildStatItem(
                      '${profile.likesCount}',
                      'Likes',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (isOwnProfile)
                  OutlinedButton(
                    onPressed: () {
                      _showMessage(
                        context,
                        'Edit Profile স্ক্রিন এখনো যুক্ত করা হয়নি',
                      );
                    },
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
                  _FollowButton(
                    key: ValueKey(targetUserId),
                    targetUserId: targetUserId,
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

  static Future<void> _shareProfile(
    BuildContext context,
    String displayName,
    String username,
    String profileId,
  ) async {
    try {
      await Share.share(
        'PALOK-এ $displayName-এর প্রোফাইল\n'
        '$username\n'
        'User ID: $profileId',
        subject: '$displayName-এর PALOK প্রোফাইল',
      );
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'প্রোফাইল শেয়ার করা যায়নি');
      }
    }
  }

  static Future<void> _reportProfile(
    BuildContext context,
    String targetUserId,
    String displayName,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage(context, 'রিপোর্ট করতে আগে লগইন করুন');
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          backgroundColor: const Color(0xFF222222),
          title: const Text(
            'প্রোফাইল রিপোর্ট করুন',
            style: TextStyle(color: Colors.white),
          ),
          children: [
            _reportOption(dialogContext, 'spam', 'স্প্যাম'),
            _reportOption(dialogContext, 'abuse', 'হয়রানি বা অপব্যবহার'),
            _reportOption(dialogContext, 'fake', 'ভুয়া প্রোফাইল'),
            _reportOption(dialogContext, 'other', 'অন্যান্য'),
          ],
        );
      },
    );

    if (reason == null) return;

    try {
      await FirebaseFirestore.instance.collection('profileReports').add({
        'reportedUserId': targetUserId,
        'reportedUsername': displayName,
        'reporterUserId': currentUser.uid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (context.mounted) {
        _showMessage(context, 'রিপোর্ট জমা দেওয়া হয়েছে');
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(
          context,
          'রিপোর্ট জমা হয়নি। Firestore Rules পরীক্ষা করুন।',
        );
      }
    }
  }

  static Widget _reportOption(
    BuildContext context,
    String value,
    String label,
  ) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, value),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildVideos(String targetUserId) {
    return FutureBuilder<List<VideoPost>>(
      future: ProfileVideoService().getUserVideos(targetUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(color: Colors.pink),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'ভিডিও লোড করা যায়নি',
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

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 21),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ],
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
          _errorMessage = 'এই ভিডিওর লিংক পাওয়া যায়নি';
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
        _errorMessage =
            'ভিডিও চালানো যাচ্ছে না। ইন্টারনেট বা ভিডিও লিংক পরীক্ষা করুন।';
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

class _FollowButton extends StatefulWidget {
  final String targetUserId;

  const _FollowButton({
    super.key,
    required this.targetUserId,
  });

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
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

      if (!mounted) return;

      setState(() {
        _following = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      // Notification toggleFollow() সার্ভিসের ভেতরেই তৈরি করে।
      final result = await _service.toggleFollow(widget.targetUserId);

      if (!mounted) return;

      setState(() {
        _following = result;
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result ? 'Follow করা হয়েছে' : 'Unfollow করা হয়েছে',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: _loading ? null : _toggle,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: _following ? Colors.grey : Colors.pink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 36,
          vertical: 12,
        ),
      ),
      child: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.pink,
                strokeWidth: 2,
              ),
            )
          : Text(
              _following ? 'Following' : 'Follow',
              style: TextStyle(
                color: _following ? Colors.white : Colors.pink,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
    );
  }
}
