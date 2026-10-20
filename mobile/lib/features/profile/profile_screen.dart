
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _black = Color(0xFF111111);
  static const Color _grey = Color(0xFF888888);
  static const Color _pink = Color(0xFFFF2D75);
  static const Color _cyan = Color(0xFF20D7E8);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _showLikedVideos = false;

  User? get _currentUser => _auth.currentUser;

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _firestore.collection('users').doc(_currentUser!.uid);

  String _text(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _username(Map<String, dynamic> data) {
    final name = _text(data['username']);
    if (name.isNotEmpty) return name;

    final email = _currentUser?.email ?? '';
    if (email.contains('@')) return email.split('@').first;

    return 'palok_user';
  }

  String _displayName(Map<String, dynamic> data) {
    final name = _text(data['displayName']).trim();
    if (name.isNotEmpty) return name;

    final nameFromUser = _text(_currentUser?.displayName).trim();
    if (nameFromUser.isNotEmpty) return nameFromUser;

    return _username(data);
  }

  int _followers(Map<String, dynamic> data) {
    return _number(data['followersCount'] ?? data['followers']);
  }

  int _following(Map<String, dynamic> data) {
    return _number(data['followingCount'] ?? data['following']);
  }

  int _likes(Map<String, dynamic> data) {
    return _number(data['likesCount'] ?? data['totalLikes']);
  }

  Future<void> _editProfile(Map<String, dynamic> data) async {
    final nameController =
        TextEditingController(text: _displayName(data));
    final usernameController =
        TextEditingController(text: _username(data));
    final bioController =
        TextEditingController(text: _text(data['bio']));
    final imageController =
        TextEditingController(text: _text(data['profileImageUrl']));

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Edit profile',
          style: TextStyle(
            color: _black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _editField(
                  controller: nameController,
                  label: 'Name',
                  required: true,
                ),
                const SizedBox(height: 12),
                _editField(
                  controller: usernameController,
                  label: 'Username',
                  required: true,
                ),
                const SizedBox(height: 12),
                _editField(
                  controller: bioController,
                  label: 'Bio',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _editField(
                  controller: imageController,
                  label: 'Profile image URL',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _black,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    final username = usernameController.text.trim().replaceAll('@', '');

    if (username.isEmpty) return;

    try {
      await _userRef.set({
        'displayName': nameController.text.trim(),
        'username': username,
        'bio': bioController.text.trim(),
        'profileImageUrl': imageController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (nameController.text.trim().isNotEmpty) {
        await _currentUser?.updateDisplayName(
          nameController.text.trim(),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile: $error')),
      );
    }
  }

  Widget _editField({
    required TextEditingController controller,
    required String label,
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: _black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _pink),
        ),
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }
              return null;
            }
          : null,
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Do you want to log out of PALOK?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _auth.signOut();

    if (!mounted) return;

    // Your app's existing authentication flow should handle
    // the signed-out state.
  }

  Widget _avatar(String imageUrl, {double size = 86}) {
    final validUrl = imageUrl.trim();

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_pink, _cyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFFF4F4F4),
        backgroundImage: validUrl.startsWith('https://') ||
                validUrl.startsWith('http://')
            ? NetworkImage(validUrl)
            : null,
        child: validUrl.isEmpty
            ? const Icon(
                Icons.person,
                color: _grey,
                size: 45,
              )
            : null,
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: const TextStyle(
              color: _black,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: _grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? _black : Colors.grey.shade400,
                size: 25,
              ),
              const SizedBox(height: 7),
              Container(
                height: 2,
                color: selected ? _black : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoGrid(String uid) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('videos')
        .where('ownerId', isEqualTo: uid);

    if (_showLikedVideos) {
      return _emptyGrid(
        'Liked videos need the existing PALOK likedVideos data.',
        Icons.favorite_border,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyGrid(
            'Could not load videos.',
            Icons.error_outline,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: _pink),
            ),
          );
        }

        final docs = snapshot.data?.docs.toList() ?? [];

        docs.sort((a, b) {
          final aDate = a.data()['createdAt'];
          final bDate = b.data()['createdAt'];

          final aMillis = aDate is Timestamp
              ? aDate.millisecondsSinceEpoch
              : 0;
          final bMillis = bDate is Timestamp
              ? bDate.millisecondsSinceEpoch
              : 0;

          return bMillis.compareTo(aMillis);
        });

        if (docs.isEmpty) {
          return _emptyGrid(
            'Your videos will appear here.',
            Icons.video_library_outlined,
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(2),
          itemCount: docs.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.67,
          ),
          itemBuilder: (context, index) {
            final video = docs[index].data();
            final thumbnail = _text(video['thumbnailUrl']);
            final views = _number(video['viewCount']);

            return GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Connect your existing PALOK video player here.',
                    ),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFFF0F0F0)),
                  if (thumbnail.startsWith('https://') ||
                      thumbnail.startsWith('http://'))
                    Image.network(
                      thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.play_arrow,
                          size: 36,
                          color: _grey,
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(
                        Icons.play_arrow,
                        size: 36,
                        color: _grey,
                      ),
                    ),
                  Positioned(
                    left: 7,
                    bottom: 6,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_arrow,
                          size: 16,
                          color: Colors.white,
                        ),
                        Text(
                          views.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black,
                              ),
                            ],
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

  Widget _emptyGrid(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 55,
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Please log in to view your profile.',
            style: TextStyle(color: _black),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userRef.snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? <String, dynamic>{};
            final username = _username(data);
            final displayName = _displayName(data);
            final email = _text(data['email'], user.email ?? '');
            final bio = _text(data['bio']);
            final imageUrl = _text(
              data['profileImageUrl'],
              user.photoURL ?? '',
            );

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Profile',
                              style: TextStyle(
                                color: _black,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Log out',
                              onPressed: _signOut,
                              icon: const Icon(
                                Icons.logout,
                                color: _black,
                              ),
                            ),
                            IconButton(
                              tooltip: 'More options',
                              onPressed: () => _editProfile(data),
                              icon: const Icon(
                                Icons.menu,
                                color: _black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _avatar(imageUrl, size: 92),
                            const SizedBox(width: 12),
                            _stat('Videos', _number(data['videosCount'])),
                            _stat('Followers', _followers(data)),
                            _stat('Following', _following(data)),
                            _stat('Likes', _likes(data)),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: _black,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@$username',
                          style: const TextStyle(
                            color: _grey,
                            fontSize: 15,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            email,
                            style: const TextStyle(
                              color: _grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            bio,
                            style: const TextStyle(
                              color: _black,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () => _editProfile(data),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _black,
                              side: const BorderSide(
                                color: Color(0xFFDDDDDD),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Edit profile',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        Row(
                          children: [
                            _tabButton(
                              icon: Icons.grid_on_outlined,
                              selected: !_showLikedVideos,
                              onTap: () {
                                setState(() => _showLikedVideos = false);
                              },
                            ),
                            _tabButton(
                              icon: Icons.favorite_border,
                              selected: _showLikedVideos,
                              onTap: () {
                                setState(() => _showLikedVideos = true);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _videoGrid(user.uid),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
