import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({
    super.key,
    this.userId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // টিকটক ডার্ক মোডের জন্য কালার প্যালেট
  static const Color _blackBg = Color(0xFF000000); 
  static const Color _pureWhite = Color(0xFFFFFFFF); 
  static const Color _greyText = Color(0xFF868686); 
  static const Color _darkGreyBtn = Color(0xFF161616); 
  static const Color _pink = Color(0xFFFF2D75); 
  static const Color _cyan = Color(0xFF20D7E8); 

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _showLikedVideos = false;

  User? get _currentUser => _auth.currentUser;
  String get _targetId => widget.userId ?? _currentUser?.uid ?? '';
  bool get _isMyProfile => _currentUser != null && _targetId == _currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get _userRef => _db.collection('users').doc(_targetId);

  String _text(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _username(Map<String, dynamic> data) {
    final name = _text(data['username']).trim();
    if (name.isNotEmpty) return name;
    final email = _text(data['email'], _isMyProfile ? _currentUser?.email ?? '' : '');
    if (email.contains('@')) return email.split('@').first;
    return 'palok_user';
  }

  String _displayName(Map<String, dynamic> data) {
    final name = _text(data['displayName']).trim();
    if (name.isNotEmpty) return name;
    if (_isMyProfile) {
      final authName = _text(_currentUser?.displayName).trim();
      if (authName.isNotEmpty) return authName;
    }
    return _username(data);
  }

  int _followers(Map<String, dynamic> data) => _number(data['followersCount'] ?? data['followers']);
  int _following(Map<String, dynamic> data) => _number(data['followingCount'] ?? data['following']);
  int _likes(Map<String, dynamic> data) => _number(data['likesCount'] ?? data['totalLikes']);

  Widget _avatar(String imageUrl, {double size = 96}) {
    final url = imageUrl.trim();
    final validUrl = url.startsWith('https://') || url.startsWith('http://');

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
        backgroundColor: const Color(0xFF1E1E1E),
        backgroundImage: validUrl ? NetworkImage(url) : null,
        child: !validUrl ? const Icon(Icons.person, color: _greyText, size: 48) : null,
      ),
    );
  }

  // টিকটক স্টাইল: উপরে বড় করে সংখ্যা, নিচে ছোট ধূসর টেক্সট
  Widget _stat(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: const TextStyle(color: _pureWhite, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _greyText, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({required IconData icon, required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? _pureWhite : Colors.grey.shade600, size: 24),
              const SizedBox(height: 7),
              Container(height: 2, color: selected ? _pureWhite : Colors.transparent),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_targetId.isEmpty) {
      return const Scaffold(
        backgroundColor: _blackBg,
        body: Center(child: Text('Please log in to view profile.', style: TextStyle(color: _pureWhite))),
      );
    }

    return Scaffold(
      backgroundColor: _blackBg,
      appBar: AppBar(
        backgroundColor: _blackBg,
        elevation: 0,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userRef.snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? <String, dynamic>{};
            return Text(_displayName(data), style: const TextStyle(color: _pureWhite, fontWeight: FontWeight.bold, fontSize: 18));
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.menu, color: _pureWhite), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: _pink));
            }

            final data = snapshot.data?.data() ?? <String, dynamic>{};
            final username = _username(data);
            final bio = _text(data['bio']);
            final imageUrl = _text(data['profileImageUrl']);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _avatar(imageUrl, size: 96),
                      const SizedBox(height: 12),
                      Text('@$username', style: const TextStyle(color: _pureWhite, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 18),
                      
                      // টিকটক লেআউটের ফলোয়িং, ফলোয়ার ও লাইক কাউন্টার রো
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _stat('Following', _following(data)),
                          Container(width: 1, height: 12, color: Colors.grey.shade800),
                          _stat('Followers', _followers(data)),
                          Container(width: 1, height: 12, color: Colors.grey.shade800),
                          _stat('Likes', _likes(data)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      
                      // এডিট প্রোফাইল বোতাম
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _darkGreyBtn,
                              side: const BorderSide(color: Color(0xFF252525)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: const Text('Edit Profile', style: TextStyle(color: _pureWhite, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (bio.isNotEmpty) Text(bio, style: const TextStyle(color: _pureWhite)),
                      const Divider(height: 1, color: Color(0xFF1F1F1F)),
                      
                      // গ্রিড এবং লাভ চিহ্নযুক্ত ট্যাব বাটন
                      Row(
                        children: [
                          _tabButton(
                            icon: Icons.grid_on_outlined,
                            selected: !_showLikedVideos,
                            onTap: () => setState(() => _showLikedVideos = false),
                          ),
                          _tabButton(
                            icon: Icons.favorite_border,
                            selected: _showLikedVideos,
                            onTap: () => setState(() => _showLikedVideos = true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
