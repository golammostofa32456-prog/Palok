
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../profile/profile_screen.dart';

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
  static const Color _pink = Color(0xFFFF2D55);

  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _searchTimer;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _onlineVideos = [];

  bool _searching = false;
  bool _searchFailed = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refreshInput);
  }

  void _refreshInput() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _controller.removeListener(_refreshInput);
    _controller.dispose();
    super.dispose();
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('@', '')
        .replaceAll('#', '');
  }

  String _readString(dynamic object, String field) {
    try {
      if (object == null) return '';

      if (object is Map) {
        return object[field]?.toString() ?? '';
      }

      switch (field) {
        case 'id':
          return object.id?.toString() ?? '';
        case 'username':
          return object.username?.toString() ?? '';
        case 'caption':
          return object.caption?.toString() ?? '';
        case 'ownerId':
        case 'userId':
          return object.ownerId?.toString() ?? '';
        case 'hashtags':
          return object.hashtags?.toString() ?? '';
        case 'thumbnailUrl':
          return object.thumbnailUrl?.toString() ?? '';
        default:
          return '';
      }
    } catch (_) {
      return '';
    }
  }

  String _stringify(dynamic value) {
    if (value == null) return '';
    if (value is Iterable) {
      return value.map((item) => item.toString()).join(' ');
    }
    return value.toString();
  }

  bool _matches(String source, String query) {
    return _normalize(source).contains(_normalize(query));
  }

  List<dynamic> _localVideoResults(String query) {
    if (query.isEmpty) return [];

    return widget.videos.where((video) {
      final text = [
        _readString(video, 'username'),
        _readString(video, 'caption'),
        _readString(video, 'hashtags'),
        _readString(video, 'ownerId'),
      ].join(' ');

      return _matches(text, query);
    }).toList();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();

    final query = _normalize(value);

    if (query.isEmpty) {
      setState(() {
        _users = [];
        _onlineVideos = [];
        _searching = false;
        _searchFailed = false;
        _lastQuery = '';
      });
      return;
    }

    _searchTimer = Timer(
      const Duration(milliseconds: 350),
      () => _performSearch(query),
    );
  }

  Future<void> _performSearch(String query) async {
    final text = _normalize(query);

    if (text.isEmpty) {
      setState(() {
        _users = [];
        _onlineVideos = [];
        _searching = false;
        _searchFailed = false;
        _lastQuery = '';
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchFailed = false;
      _lastQuery = text;
    });

    List<Map<String, dynamic>> users = [];
    List<Map<String, dynamic>> videos = [];
    bool failed = false;

    try {
      users = await _searchUsers(text);
    } catch (e) {
      failed = true;
      debugPrint('Search users error: $e');
    }

    try {
      videos = await _searchVideos(text);
    } catch (e) {
      failed = true;
      debugPrint('Search videos error: $e');
    }

    if (!mounted || _lastQuery != text) return;

    final localIds = widget.videos
        .map((video) => _readString(video, 'id'))
        .where((id) => id.isNotEmpty)
        .toSet();

    videos = videos.where((video) {
      final id = (video['id'] ?? '').toString();
      return id.isEmpty || !localIds.contains(id);
    }).toList();

    setState(() {
      _users = users;
      _onlineVideos = videos;
      _searching = false;
      _searchFailed = failed;
    });
  }

  Future<List<Map<String, dynamic>>> _searchUsers(
    String query,
  ) async {
    final snapshot =
        await _firestore.collection('users').limit(200).get();

    final results = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final name = (data['name'] ?? '').toString();
      final username = (data['username'] ?? '').toString();
      final displayName = (data['displayName'] ?? '').toString();
      final email = (data['email'] ?? '').toString();

      if (!_matches(
        '$name $username $displayName $email',
        query,
      )) {
        continue;
      }

      results.add({
        'id': doc.id,
        'name': name,
        'username': username,
        'displayName': displayName,
        'photoURL': (data['photoURL'] ??
                data['profileImage'] ??
                data['photoUrl'] ??
                '')
            .toString(),
      });
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> _searchVideos(
    String query,
  ) async {
    final snapshot =
        await _firestore.collection('videos').limit(200).get();

    final results = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final username = (data['username'] ?? '').toString();
      final caption = (data['caption'] ?? '').toString();
      final hashtags = _stringify(data['hashtags']);
      final ownerId =
          (data['ownerId'] ?? data['userId'] ?? '').toString();

      if (!_matches(
        '$username $caption $hashtags $ownerId',
        query,
      )) {
        continue;
      }

      results.add({
        'id': doc.id,
        'username': username,
        'caption': caption,
        'ownerId': ownerId,
        'thumbnailUrl': (data['thumbnailUrl'] ?? '').toString(),
      });
    }

    return results;
  }

  Future<void> _openLocalVideo(dynamic video) async {
    final callback = widget.onVideoSelected;

    if (callback == null) {
      _showMessage('ভিডিও চালু করার ব্যবস্থা পাওয়া যায়নি।');
      return;
    }

    final id = _readString(video, 'id');

    final index = widget.videos.indexWhere((item) {
      if (identical(item, video)) return true;

      final itemId = _readString(item, 'id');
      return id.isNotEmpty && itemId == id;
    });

    if (index < 0) {
      _showMessage('ভিডিওটি ফিডে পাওয়া যায়নি।');
      return;
    }

    try {
      await callback(index);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Open feed video error: $e');
      _showMessage('ভিডিও চালু করা যায়নি।');
    }
  }

  void _openProfile(String userId) {
    final id = userId.trim();

    if (id.isEmpty) {
      _showMessage('এই ব্যবহারকারীর ID পাওয়া যায়নি।');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(userId: id),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _normalize(_controller.text);
    final localVideos = _localVideoResults(query);

    final hasResults = _users.isNotEmpty ||
        localVideos.isNotEmpty ||
        _onlineVideos.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onSearchChanged,
            onSubmitted: _performSearch,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'ব্যবহারকারী বা ভিডিও খুঁজুন',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.grey,
              ),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        _controller.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _performSearch(query),
            child: const Text(
              'খুঁজুন',
              style: TextStyle(
                color: _pink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _searching
            ? const Center(
                child: CircularProgressIndicator(color: _pink),
              )
            : query.isEmpty
                ? _buildEmptySearch()
                : !hasResults
                    ? _buildNoResults(query)
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_users.isNotEmpty) ...[
                            _sectionTitle('ব্যবহারকারী'),
                            const SizedBox(height: 8),
                            ..._users.map(_buildUserItem),
                            const SizedBox(height: 20),
                          ],
                          if (localVideos.isNotEmpty) ...[
                            _sectionTitle('ভিডিওসমূহ'),
                            const SizedBox(height: 8),
                            ...localVideos.map(
                              (video) => _buildVideoItem(
                                video,
                                isLocal: true,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (_onlineVideos.isNotEmpty) ...[
                            _sectionTitle('আরও ভিডিও'),
                            const SizedBox(height: 8),
                            ..._onlineVideos.map(
                              (video) => _buildVideoItem(
                                video,
                                isLocal: false,
                              ),
                            ),
                          ],
                          if (_searchFailed) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'কিছু অনলাইন ফলাফল লোড করা যায়নি।',
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: () => _performSearch(query),
                              child: const Text(
                                'আবার চেষ্টা করুন',
                                style: TextStyle(color: _pink),
                              ),
                            ),
                          ],
                        ],
                      ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 56,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          const Text(
            'ব্যবহারকারী বা ভিডিও খুঁজুন',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'নাম, ইউজারনেম বা হ্যাশট্যাগ লিখুন',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              '"$query" নিয়ে কোনো ফলাফল পাওয়া যায়নি',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
            if (_searchFailed) ...[
              const SizedBox(height: 10),
              const Text(
                'অনলাইন সার্চে সমস্যা হয়েছে।',
                style: TextStyle(color: Colors.grey),
              ),
              TextButton(
                onPressed: () => _performSearch(query),
                child: const Text(
                  'আবার চেষ্টা করুন',
                  style: TextStyle(color: _pink),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    final username = (user['username'] ?? '').toString();
    final name =
        (user['displayName'] ?? user['name'] ?? '').toString();
    final photo = (user['photoURL'] ?? '').toString();
    final id = (user['id'] ?? '').toString();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade200,
        backgroundImage:
            photo.isNotEmpty ? NetworkImage(photo) : null,
        child: photo.isEmpty
            ? const Icon(Icons.person, color: Colors.grey)
            : null,
      ),
      title: Text(
        username.isNotEmpty ? '@$username' : name,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: name.isNotEmpty && name != username
          ? Text(
              name,
              style: TextStyle(color: Colors.grey.shade600),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
      onTap: () => _openProfile(id),
    );
  }

  Widget _buildVideoItem(
    dynamic video, {
    required bool isLocal,
  }) {
    final username = _readString(video, 'username');
    final caption = _readString(video, 'caption');
    final thumbnail = _readString(video, 'thumbnailUrl');

    final ownerId = video is Map
        ? (video['ownerId'] ?? video['userId'] ?? '').toString()
        : _readString(video, 'ownerId');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 54,
          height: 66,
          color: Colors.grey.shade200,
          child: thumbnail.isNotEmpty
              ? Image.network(
                  thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.play_arrow,
                    color: Colors.grey,
                  ),
                )
              : const Icon(
                  Icons.play_arrow,
                  color: Colors.grey,
                ),
        ),
      ),
      title: Text(
        username.isEmpty ? 'PALOK ব্যবহারকারী' : '@$username',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: caption.isNotEmpty
          ? Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade700),
            )
          : const Text(
              'ভিডিও',
              style: TextStyle(color: Colors.grey),
            ),
      trailing: const Icon(
        Icons.play_circle_outline,
        color: _pink,
        size: 28,
      ),
      onTap: () {
        if (ownerId.isNotEmpty) {
          // ব্যবহারকারীর প্রোফাইল খুলতে নামের বদলে
          // Firestore user ID ব্যবহার করা হচ্ছে।
          // ভিডিও চালাতে ভিডিওর নিজস্ব ফলাফলে চাপ দাও।
        }

        if (isLocal) {
          _openLocalVideo(video);
        } else {
          _showMessage(
            'এই ভিডিওটি মূল ফিডে নেই। '
            'অনলাইন ভিডিও চালাতে আলাদা ভিডিও-প্লেয়ার '
            'পেজ যুক্ত করতে হবে।',
          );
        }
      },
    );
  }
}
