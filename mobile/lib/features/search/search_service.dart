import 'package:cloud_firestore/cloud_firestore.dart';

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Search users by username or name
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final text = query.trim().toLowerCase();

    if (text.isEmpty) {
      return [];
    }

    final snapshot = await _firestore
        .collection('users')
        .limit(50)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();

          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'username': data['username'] ?? '',
            'photoURL': data['photoURL'] ?? '',
          };
        })
        .where((user) {
          final name = user['name'].toString().toLowerCase();
          final username = user['username'].toString().toLowerCase();

          return name.contains(text) || username.contains(text);
        })
        .toList();
  }

  /// Search videos
  Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    final text = query.trim().toLowerCase();

    if (text.isEmpty) {
      return [];
    }

    final snapshot = await _firestore
        .collection('videos')
        .limit(50)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();

          return {
            'id': doc.id,
            'caption': data['caption'] ?? '',
            'username': data['username'] ?? '',
            'videoUrl': data['videoUrl'] ?? '',
            'thumbnailUrl': data['thumbnailUrl'] ?? '',
          };
        })
        .where((video) {
          final caption = video['caption'].toString().toLowerCase();
          final username = video['username'].toString().toLowerCase();

          return caption.contains(text) || username.contains(text);
        })
        .toList();
  }
}

import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  // অন্য যেকোনো স্থান থেকে সার্চ শিট ওপেন করার জন্য সেফ মেথড
  static void open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SearchScreen(),
    );
  }

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    // মেমোরি লিক এবং রেড স্ক্রিন এরর রোধ করতে ডিসপোজ
    _focusNode.unfocus();
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleClose() {
    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 12,
          left: 16,
          right: 16,
        ),
        child: Column(
          children: [
            // টপ ড্র্যাগ হ্যান্ডেল
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // সার্চ বার অ্যান্ড ক্লোজ বাটন
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      cursorColor: Colors.redAccent,
                      decoration: InputDecoration(
                        icon: const Icon(Icons.search, color: Colors.grey, size: 20),
                        hintText: 'Search videos, users...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.grey, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _handleClose,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 60),

            // প্লেসহোল্ডার ইউআই (Search PALOK)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.search_rounded, size: 56, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'Search PALOK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Users, captions and hashtags খুঁজুন',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
