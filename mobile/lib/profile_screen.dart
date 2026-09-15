import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _pink = Color(0xFFFF2D75);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get _isOwnProfile =>
      widget.userId == null ||
      widget.userId == FirebaseAuth.instance.currentUser?.uid;

  String get _profileUid =>
      widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _following = false;
  bool _followBusy = false;

  @override
  void initState() {
    super.initState();
    _checkFollowing();
  }

  Future<void> _checkFollowing() async {
    final me = FirebaseAuth.instance.currentUser;

    if (me == null || _isOwnProfile) return;

    final doc = await _firestore
        .collection('users')
        .doc(me.uid)
        .collection('following')
        .doc(_profileUid)
        .get();

    if (mounted) {
      setState(() => _following = doc.exists);
    }
  }

  Future<void> _toggleFollow() async {
    final me = FirebaseAuth.instance.currentUser;

    if (me == null || _isOwnProfile || _followBusy) return;

    setState(() => _followBusy = true);

    final ref = _firestore
        .collection('users')
        .doc(me.uid)
        .collection('following')
        .doc(_profileUid);

    try {
      if (_following) {
        await ref.delete();
      } else {
        await ref.set({
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        setState(() => _following = !_following);
      }
    } finally {
      if (mounted) {
        setState(() => _followBusy = false);
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;

    if (_profileUid.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Login করা নেই',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          _isOwnProfile
              ? (me?.displayName ?? '@palok_user')
              : 'Profile',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isOwnProfile)
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.white),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('users')
            .doc(_profileUid)
            .snapshots(),
        builder: (context, userSnap) {
          final userData = userSnap.data?.data();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(userData),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: const [
                      Icon(Icons.grid_on, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Videos',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildVideoGrid(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic>? userData) {
    final me = FirebaseAuth.instance.currentUser;

    final displayName = _isOwnProfile
        ? (me?.displayName ?? '@palok_user')
        : (userData?['username']?.toString() ?? '@palok_user');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundColor: _pink,
            child: Icon(Icons.person, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_isOwnProfile && me?.email != null) ...[
            const SizedBox(height: 3),
            Text(
              me!.email!,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('users')
                .doc(_profileUid)
                .collection('following')
                .snapshots(),
            builder: (context, followingSnap) {
              final followingCount = followingSnap.data?.docs.length ?? 0;

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('videos')
                    .where('ownerId', isEqualTo: _profileUid)
                    .snapshots(),
                builder: (context, videosSnap) {
                  final videoCount = videosSnap.data?.docs.length ?? 0;

                  final likeCount = (videosSnap.data?.docs ?? [])
                      .fold<int>(
                    0,
                    (sum, doc) =>
                        sum +
                        ((doc.data()['likeCount'] as num?)?.toInt() ?? 0),
                  );

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statColumn('$videoCount', 'Videos'),
                      _statColumn('$followingCount', 'Following'),
                      _statColumn(_format(likeCount), 'Likes'),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          if (!_isOwnProfile)
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: _followBusy ? null : _toggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _following ? Colors.white10 : _pink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: _following
                        ? const BorderSide(color: Colors.white24)
                        : BorderSide.none,
                  ),
                ),
                child: Text(
                  _following ? 'Following' : 'Follow',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  String _format(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toString();
  }

  Widget _buildVideoGrid() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('videos')
          .where('ownerId', isEqualTo: _profileUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'ভিডিও লোড করা যায়নি',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: _pink),
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'এখনো কোনো ভিডিও পোস্ট করা হয়নি',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(2),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 0.6,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final data = docs[index].data();

                return _GridThumbnail(
                  videoUrl: data['videoUrl']?.toString() ?? '',
                  likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
                );
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }
}

class _GridThumbnail extends StatefulWidget {
  final String videoUrl;
  final int likeCount;

  const _GridThumbnail({
    required this.videoUrl,
    required this.likeCount,
  });

  @override
  State<_GridThumbnail> createState() => _GridThumbnailState();
}

class _GridThumbnailState extends State<_GridThumbnail> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    if (widget.videoUrl.isEmpty) return;

    final controller = widget.videoUrl.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        : VideoPlayerController.asset(widget.videoUrl);

    try {
      await controller.initialize();
      await controller.seekTo(Duration.zero);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() => _controller = controller);
    } catch (_) {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _format(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF151515),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            const Center(
              child: Icon(
                Icons.videocam_outlined,
                color: Colors.white24,
                size: 28,
              ),
            ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 13),
                const SizedBox(width: 3),
                Text(
                  _format(widget.likeCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
