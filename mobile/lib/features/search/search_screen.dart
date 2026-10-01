import 'package:flutter/material.dart';

import 'search_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  final SearchService _searchService = SearchService();

  bool _loading = false;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _videos = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _users = [];
        _videos = [];
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final results = await Future.wait([
        _searchService.searchUsers(query),
        _searchService.searchVideos(query),
      ]);

      if (!mounted) return;

      setState(() {
        _users = results[0];
        _videos = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _users = [];
        _videos = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Search করা যায়নি'),
        ),
      );
    }
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _users = [];
      _videos = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasResults =
        _users.isNotEmpty || _videos.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search videos, users...',
                hintStyle: const TextStyle(
                  color: Colors.white54,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white,
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? IconButton(
                        onPressed: _search,
                        icon: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                        ),
                      )
                    : IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white54,
                        ),
                      ),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
            const SizedBox(height: 18),

            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (!hasResults &&
                _searchController.text.trim().isNotEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'কোনো ফলাফল পাওয়া যায়নি',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else if (!hasResults)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search,
                        color: Colors.white30,
                        size: 52,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Search PALOK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Users এবং videos খুঁজুন',
                        style: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    if (_users.isNotEmpty) ...[
                      const Text(
                        'Users',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._users.map(
                        (user) => _buildUserItem(user),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_videos.isNotEmpty) ...[
                      const Text(
                        'Videos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._videos.map(
                        (video) => _buildVideoItem(video),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserItem(
    Map<String, dynamic> user,
  ) {
    final username =
        user['username']?.toString() ?? '';

    final name =
        user['name']?.toString() ?? '';

    final photoUrl =
        user['photoURL']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white12,
            backgroundImage: photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl.isEmpty
                ? const Icon(
                    Icons.person,
                    color: Colors.white70,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? username : name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (username.isNotEmpty)
                  Text(
                    '@$username',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoItem(
    Map<String, dynamic> video,
  ) {
    final username =
        video['username']?.toString() ?? '';

    final caption =
        video['caption']?.toString() ?? '';

    final thumbnailUrl =
        video['thumbnailUrl']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(10),
              image: thumbnailUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(thumbnailUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: thumbnailUrl.isEmpty
                ? const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white70,
                    size: 30,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  username.isEmpty
                      ? 'PALOK User'
                      : '@$username',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  caption.isEmpty
                      ? 'PALOK Video'
                      : caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
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
