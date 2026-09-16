import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _username = '';
  String _name = '';
  String _bio = '';
  String _email = '';
  String _profileImage = '';

  int _followingCount = 0;
  int _followersCount = 0;
  int _likesCount = 0;

  bool _loading = true;

  List<Map<String, dynamic>> _videos = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      final Map<String, dynamic>? data = userDoc.data();

      if (data != null) {
        _name = (data['name'] ??
                data['displayName'] ??
                user.displayName ??
                '')
            .toString();

        _username =
            (data['username'] ?? '').toString();

        _bio =
            (data['bio'] ?? '').toString();

        _email =
            (data['email'] ?? user.email ?? '').toString();

        _profileImage =
            (data['profileImage'] ??
                    data['photoUrl'] ??
                    data['profilePhoto'] ??
                    '')
                .toString();
      } else {
        _name = user.displayName ?? '';
        _email = user.email ?? '';
      }

      if (_username.isEmpty) {
        _username = user.displayName ?? '';
      }

      if (_username.isEmpty) {
        _username = user.email?.split('@').first ?? 'PALOK User';
      }

      await _loadFollowingCount(user.uid);
      await _loadFollowersCount(user.uid);
      await _loadVideos(user.uid);

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });

        _showMessage(
          'Profile load failed',
          isError: true,
        );
      }
    }
  }

  Future<void> _loadFollowingCount(String uid) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('following')
              .get();

      _followingCount = snapshot.docs.length;
    } catch (_) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> doc =
            await _firestore.collection('users').doc(uid).get();

        final data = doc.data();

        final dynamic value =
            data?['followingCount'];

        if (value is num) {
          _followingCount = value.toInt();
        }
      } catch (_) {}
    }
  }

  Future<void> _loadFollowersCount(String uid) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('followers')
              .get();

      _followersCount = snapshot.docs.length;
    } catch (_) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> doc =
            await _firestore.collection('users').doc(uid).get();

        final data = doc.data();

        final dynamic value =
            data?['followersCount'];

        if (value is num) {
          _followersCount = value.toInt();
        }
      } catch (_) {}
    }
  }

  Future<void> _loadVideos(String uid) async {
    _videos = [];

    QuerySnapshot<Map<String, dynamic>> snapshot;

    try {
      snapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: uid)
          .get();
    } catch (_) {
      try {
        snapshot = await _firestore
            .collection('videos')
            .where('uid', isEqualTo: uid)
            .get();
      } catch (_) {
        try {
          snapshot = await _firestore
              .collection('videos')
              .where('ownerId', isEqualTo: uid)
              .get();
        } catch (_) {
          return;
        }
      }
    }

    int totalLikes = 0;

    final List<Map<String, dynamic>> loadedVideos = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final dynamic likes =
          data['likesCount'] ??
              data['likeCount'] ??
              data['likes'] ??
              0;

      int likeCount = 0;

      if (likes is num) {
        likeCount = likes.toInt();
      }

      totalLikes += likeCount;

      loadedVideos.add({
        'id': doc.id,
        ...data,
      });
    }

    loadedVideos.sort((a, b) {
      final Timestamp? aTime =
          a['createdAt'] is Timestamp
              ? a['createdAt'] as Timestamp
              : null;

      final Timestamp? bTime =
          b['createdAt'] is Timestamp
              ? b['createdAt'] as Timestamp
              : null;

      if (aTime == null && bTime == null) {
        return 0;
      }

      if (aTime == null) {
        return 1;
      }

      if (bTime == null) {
        return -1;
      }

      return bTime.compareTo(aTime);
    });

    _videos = loadedVideos;
    _likesCount = totalLikes;
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditProfileScreen(),
      ),
    );

    if (result != null) {
      await _loadProfile();
    }
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),

              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 15),

              _menuItem(
                icon: Icons.settings_outlined,
                title: 'Settings and privacy',
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              _menuItem(
                icon: Icons.bookmark_border,
                title: 'Saved videos',
                onTap: () {
                  Navigator.pop(context);
                  _showMessage(
                    'Saved videos will appear here.',
                  );
                },
              ),

              _menuItem(
                icon: Icons.qr_code_2,
                title: 'QR code',
                onTap: () {
                  Navigator.pop(context);
                  _showMessage(
                    'QR code feature coming soon.',
                  );
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: Colors.white,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white38,
      ),
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? const Color(0xFFB00020)
              : const Color(0xFF252525),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }

    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }

    return count.toString();
  }

  Widget _buildProfileAvatar() {
    if (_profileImage.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          _profileImage,
          width: 112,
          height: 112,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _defaultAvatar();
          },
        ),
      );
    }

    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      width: 112,
      height: 112,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color(0xFF00D9FF),
            Color(0xFFFF2D55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 58,
      ),
    );
  }

  Widget _buildStat(
    String number,
    String label,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoThumbnail(
    Map<String, dynamic> video,
  ) {
    final String thumbnail =
        (video['thumbnailUrl'] ??
                video['thumbnail'] ??
                video['coverUrl'] ??
                '')
            .toString();

    final String videoUrl =
        (video['videoUrl'] ??
                video['url'] ??
                video['video'] ??
                '')
            .toString();

    final dynamic likes =
        video['likesCount'] ??
            video['likeCount'] ??
            video['likes'] ??
            0;

    int likeCount = 0;

    if (likes is num) {
      likeCount = likes.toInt();
    }

    return GestureDetector(
      onTap: () {
        _openVideo(video);
      },
      child: Container(
        color: const Color(0xFF181818),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnail.isNotEmpty)
              Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return _videoPlaceholder();
                },
              )
            else
              _videoPlaceholder(),

            // Dark gradient at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x99000000),
                    ],
                  ),
                ),
              ),
            ),

            // Play icon
            const Center(
              child: Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 34,
              ),
            ),

            // Like count
            Positioned(
              left: 12,
              bottom: 10,
              child: Row(
                children: [
                  const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 17,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _formatCount(likeCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoPlaceholder() {
    return Container(
      color: const Color(0xFF191919),
      child: const Center(
        child: Icon(
          Icons.play_arrow,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }

  void _openVideo(Map<String, dynamic> video) {
    final String videoUrl =
        (video['videoUrl'] ??
                video['url'] ??
                video['video'] ??
                '')
            .toString();

    if (videoUrl.isEmpty) {
      _showMessage(
        'Video URL পাওয়া যায়নি।',
        isError: true,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileVideoScreen(
          videoUrl: videoUrl,
          username: _username,
        ),
      ),
    );
  }

  Widget _buildVideoGrid() {
    if (_videos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(
          top: 70,
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.video_library_outlined,
                color: Colors.white38,
                size: 54,
              ),
              const SizedBox(height: 14),
              const Text(
                'No videos yet',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your videos will appear here.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _videos.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.66,
      ),
      itemBuilder: (context, index) {
        return _buildVideoThumbnail(
          _videos[index],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF2D55),
              ),
            )
          : SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: const Color(0xFFFF2D55),
                backgroundColor: const Color(0xFF181818),
                onRefresh: _loadProfile,
                child: CustomScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 12,
                          top: 8,
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: _showMenu,
                              icon: const Icon(
                                Icons.menu,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Profile avatar
                    SliverToBoxAdapter(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF00D9FF),
                                Color(0xFFFF2D55),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                            ),
                            child: _buildProfileAvatar(),
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 15),
                    ),

                    // Username
                    SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          _username.isEmpty
                              ? 'PALOK User'
                              : _username,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    // Name / email
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.only(top: 7),
                        child: Center(
                          child: Text(
                            _email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (_bio.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            30,
                            10,
                            30,
                            0,
                          ),
                          child: Text(
                            _bio,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 25),
                    ),

                    // Stats
                    SliverToBoxAdapter(
                      child: Row(
                        children: [
                          _buildStat(
                            _formatCount(
                              _followingCount,
                            ),
                            'Following',
                          ),
                          _buildStat(
                            _formatCount(
                              _followersCount,
                            ),
                            'Followers',
                          ),
                          _buildStat(
                            _formatCount(
                              _likesCount,
                            ),
                            'Likes',
                          ),
                        ],
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 25),
                    ),

                    // Edit profile button
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _openEditProfile,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.white30,
                                width: 1.2,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Edit profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 30),
                    ),

                    // Profile tabs
                    SliverPersistentHeader(
                      pinned: false,
                      delegate: _ProfileTabsDelegate(),
                    ),

                    // Videos
                    SliverToBoxAdapter(
                      child: _buildVideoGrid(),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ProfileTabsDelegate
    extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 55;

  @override
  double get maxExtent => 55;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: Colors.white12,
            width: 1,
          ),
          bottom: BorderSide(
            color: Colors.white12,
            width: 1,
          ),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Center(
              child: Icon(
                Icons.grid_on,
                color: Colors.white,
                size: 25,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                Icons.lock_outline,
                color: Colors.white38,
                size: 24,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                Icons.bookmark_border,
                color: Colors.white38,
                size: 25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(
    covariant SliverPersistentHeaderDelegate oldDelegate,
  ) {
    return false;
  }
}

class ProfileVideoScreen extends StatefulWidget {
  final String videoUrl;
  final String username;

  const ProfileVideoScreen({
    super.key,
    required this.videoUrl,
    required this.username,
  });

  @override
  State<ProfileVideoScreen> createState() =>
      _ProfileVideoScreenState();
}

class _ProfileVideoScreenState
    extends State<ProfileVideoScreen> {
  // This screen intentionally uses a simple web-video
  // player page placeholder. The main PALOK feed remains
  // responsible for full TikTok-style video playback.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          '@${widget.username}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            widget.videoUrl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
