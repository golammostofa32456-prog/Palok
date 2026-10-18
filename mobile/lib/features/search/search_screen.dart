import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  final List<dynamic> videos;
  final Future<void> Function(int actualIndex)? onVideoSelected;

  const SearchScreen({
    super.key,
    required this.videos,
    this.onVideoSelected,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const Color _pink = Color(0xFFFE2C55);
  static const Color _cyan = Color(0xFF25F4EE);

  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _searchTimer;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _firestoreVideos = [];
  bool _searching = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll('@', '').replaceAll('#', '');
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _users = [];
        _firestoreVideos = [];
        _searching = false;
        _lastQuery = '';
      });
      return;
    }

    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final text = _normalize(query);
    if (text.isEmpty) return;

    setState(() {
      _searching = true;
      _lastQuery = text;
    });

    final localResults = _searchLocalVideos(text);
    List<Map<String, dynamic>> users = [];
    List<Map<String, dynamic>> firestoreVideos = [];

    try {
      users = await _searchUsers(text);
    } catch (_) {}

    try {
      firestoreVideos = await _searchVideos(text);
    } catch (_) {}

    if (!mounted || _lastQuery != text) return;

    final localIds = <String>{};
    for (final video in localResults) {
      final id = _readString(video, 'id');
      if (id.isNotEmpty) localIds.add(id);
    }

    firestoreVideos = firestoreVideos.where((video) {
      final id = (video['id'] ?? '').toString();
      return id.isEmpty || !localIds.contains(id);
    }).toList();

    setState(() {
      _users = users;
      _firestoreVideos = firestoreVideos;
      _searching = false;
    });
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    final snapshot = await _firestore.collection('users').limit(200).get();
    final users = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString();
      final username = (data['username'] ?? '').toString();
      final displayName = (data['displayName'] ?? '').toString();
      final email = (data['email'] ?? '').toString();

      final searchText = [name, username, displayName, email].join(' ').toLowerCase();
      if (!_containsSearchText(searchText, query)) continue;

      users.add({
        'id': doc.id,
        'name': name,
        'username': username,
        'displayName': displayName,
        'email': email,
        'photoURL': (data['photoURL'] ?? data['profileImage'] ?? data['photoUrl'] ?? '').toString(),
      });
    }
    return users;
  }

  Future<List<Map<String, dynamic>>> _searchVideos(String query) async {
    final snapshot = await _firestore.collection('videos').limit(200).get();
    final videos = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final username = (data['username'] ?? '').toString();
      final caption = (data['caption'] ?? '').toString();
      final hashtags = _valueToSearchString(data['hashtags']);
      final userId = (data['userId'] ?? '').toString();

      final searchText = [username, caption, hashtags, userId].join(' ').toLowerCase();
      if (!_containsSearchText(searchText, query)) continue;

      videos.add({
        'id': doc.id,
        'username': username,
        'caption': caption,
        'hashtags': hashtags,
        'userId': userId,
        'videoUrl': (data['videoUrl'] ?? '').toString(),
        'thumbnailUrl': (data['thumbnailUrl'] ?? '').toString(),
      });
    }
    return videos;
  }

  List<dynamic> _searchLocalVideos(String query) {
    final textQuery = _normalize(query);
    if (textQuery.isEmpty) return [];
    final results = <dynamic>[];

    for (final video in widget.videos) {
      final text = [
        _readString(video, 'id'),
        _readString(video, 'username'),
        _readString(video, 'caption'),
        _readString(video, 'hashtags'),
        _readString(video, 'userId'),
      ].join(' ');

      if (_containsSearchText(text, textQuery)) {
        results.add(video);
      }
    }
    return results;
  }

  bool _containsSearchText(String source, String query) {
    return _normalize(source).contains(_normalize(query));
  }

  String _readString(dynamic object, String field) {
    try {
      if (object == null) return '';
      if (object is Map) return object[field]?.toString() ?? '';
      switch (field) {
        case 'id': return object.id?.toString() ?? '';
        case 'username': return object.username?.toString() ?? '';
        case 'caption': return object.caption?.toString() ?? '';
        case 'hashtags': return object.hashtags?.toString() ?? '';
        case 'thumbnailUrl': return object.thumbnailUrl?.toString() ?? '';
        default: return '';
      }
    } catch (_) {
      return '';
    }
  }

  String _valueToSearchString(dynamic value) {
    if (value == null) return '';
    if (value is Iterable) return value.map((e) => e.toString()).join(' ');
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final localVideos = query.isEmpty ? <dynamic>[] : _searchLocalVideos(query);
    final hasResults = _users.isNotEmpty || localVideos.isNotEmpty || _firestoreVideos.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        titleContainer: null,
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.black, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'অনুসন্ধান করুন',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _performSearch(_controller.text),
            child: const Text('অনুসন্ধান', style: TextStyle(color: _pink, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : query.isEmpty
              ? _buildEmptySearch()
              : !hasResults
                  ? _buildNoResults(query)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_users.isNotEmpty) ...[
                          const Text('ইউজারসমূহ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ..._users.map(_buildUserItem),
                          const SizedBox(height: 16),
                        ],
                        if (localVideos.isNotEmpty) ...[
                          const Text('ভিডিওসমূহ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ...localVideos.map((v) => _buildVideoItem(v, isLocal: true)),
                        ],
                        if (_firestoreVideos.isNotEmpty) ...[
                          const Text('আরও ভিডিও', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ..._firestoreVideos.map((v) => _buildVideoItem(v, isLocal: false)),
                        ],
                      ],
                    ),
    );
  }

  Widget _buildEmptySearch() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('আপনি পছন্দ করতে পারেন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildNoResults(String query) {
    return Center(
      child: Text('"$query" দিয়ে কোনো ফলাফল পাওয়া যায়নি', style: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    final username = (user['username'] ?? user['name'] ?? 'User').toString();
    return ListTile(
      leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
      title: Text('@$username', style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildVideoItem(dynamic video, {required bool isLocal}) {
    final username = _readString(video, 'username');
    final caption = _readString(video, 'caption');
    final thumb = _readString(video, 'thumbnailUrl');

    return ListTile(
      leading: Container(
        width: 50,
        height: 65,
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(6)),
        child: thumb.isNotEmpty ? Image.network(thumb, fit: BoxFit.cover) : const Icon(Icons.play_arrow),
      ),
      title: Text(username.isEmpty ? '@PALOK' : '@$username', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}
