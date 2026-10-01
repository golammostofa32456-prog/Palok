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
  final TextEditingController _controller =
      TextEditingController();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Timer? _searchTimer;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _firestoreVideos = [];

  bool _searching = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _searchTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});

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

    _searchTimer = Timer(
      const Duration(milliseconds: 350),
      () {
        _performSearch(query);
      },
    );
  }

  Future<void> _performSearch(String query) async {
    final text = query.trim().toLowerCase();

    if (text.isEmpty) return;

    setState(() {
      _searching = true;
      _lastQuery = text;
    });

    try {
      final results = await Future.wait([
        _searchUsers(text),
        _searchVideos(text),
      ]);

      if (!mounted) return;

      if (_lastQuery != text) return;

      setState(() {
        _users = results[0] as List<Map<String, dynamic>>;
        _firestoreVideos =
            results[1] as List<Map<String, dynamic>>;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _users = [];
        _firestoreVideos = [];
        _searching = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _searchUsers(
    String query,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .limit(100)
        .get();

    final users = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final name =
          (data['name'] ?? '').toString();

      final username =
          (data['username'] ?? '').toString();

      final displayName =
          (data['displayName'] ?? '').toString();

      final searchText =
          '$name $username $displayName'.toLowerCase();

      if (!searchText.contains(query)) {
        continue;
      }

      users.add({
        'id': doc.id,
        'name': name,
        'username': username,
        'displayName': displayName,
        'photoURL':
            (data['photoURL'] ??
                    data['profileImage'] ??
                    '')
                .toString(),
      });
    }

    return users;
  }

  Future<List<Map<String, dynamic>>> _searchVideos(
    String query,
  ) async {
    final snapshot = await _firestore
        .collection('videos')
        .limit(100)
        .get();

    final videos = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final username =
          (data['username'] ?? '').toString();

      final caption =
          (data['caption'] ?? '').toString();

      final hashtags =
          (data['hashtags'] ?? '').toString();

      final searchText =
          '$username $caption $hashtags'.toLowerCase();

      if (!searchText.contains(query)) {
        continue;
      }

      videos.add({
        'id': doc.id,
        'username': username,
        'caption': caption,
        'hashtags': hashtags,
        'videoUrl':
            (data['videoUrl'] ?? '').toString(),
        'thumbnailUrl':
            (data['thumbnailUrl'] ?? '').toString(),
      });
    }

    return videos;
  }

  List<dynamic> _searchLocalVideos(String query) {
    return widget.videos.where((video) {
      final username =
          _readString(video, 'username').toLowerCase();

      final caption =
          _readString(video, 'caption').toLowerCase();

      final hashtags =
          _readString(video, 'hashtags').toLowerCase();

      final text =
          '$username $caption $hashtags';

      return text.contains(query);
    }).toList();
  }

  String _readString(
    dynamic object,
    String field,
  ) {
    try {
      switch (field) {
        case 'id':
          return object.id?.toString() ?? '';

        case 'username':
          return object.username?.toString() ?? '';

        case 'caption':
          return object.caption?.toString() ?? '';

        case 'hashtags':
          return object.hashtags?.toString() ?? '';

        default:
          return '';
      }
    } catch (_) {
      return '';
    }
  }

  int _findActualIndex(dynamic video) {
    final selectedId =
        _readString(video, 'id');

    return widget.videos.indexWhere(
      (item) =>
          _readString(item, 'id') == selectedId,
    );
  }

  Future<void> _selectLocalVideo(
    BuildContext sheetContext,
    dynamic video,
  ) async {
    final actualIndex =
        _findActualIndex(video);

    Navigator.of(sheetContext).pop();

    if (actualIndex < 0) {
      return;
    }

    if (widget.onVideoSelected != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) async {
        await widget.onVideoSelected!(
          actualIndex,
        );
      });
    }
  }

  Widget _buildUserItem(
    Map<String, dynamic> user,
  ) {
    final username =
        user['username'].toString();

    final name =
        user['name'].toString();

    final displayName =
        user['displayName'].toString();

    final photo =
        user['photoURL'].toString();

    final title = username.isNotEmpty
        ? '@$username'
        : displayName.isNotEmpty
            ? displayName
            : name.isNotEmpty
                ? name
                : 'PALOK User';

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white10,
              image: photo.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(photo),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: photo.isEmpty
                ? const Icon(
                    Icons.person,
                    color: Colors.white70,
                    size: 28,
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
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                if (name.isNotEmpty &&
                    name != title) ...[
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Icon(
            Icons.person_outline,
            color: Colors.white54,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoItem(
    Map<String, dynamic> video,
  ) {
    final username =
        video['username'].toString();

    final caption =
        video['caption'].toString();

    final hashtags =
        video['hashtags'].toString();

    final thumbnail =
        video['thumbnailUrl'].toString();

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius:
                  BorderRadius.circular(12),
              image: thumbnail.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(
                        thumbnail,
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: thumbnail.isEmpty
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
                      ? '@PALOK User'
                      : username,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  caption.isEmpty
                      ? hashtags
                      : caption,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.chevron_right,
            color: Colors.white54,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query =
        _controller.text.trim().toLowerCase();

    final localVideos =
        query.isEmpty
            ? <dynamic>[]
            : _searchLocalVideos(query);

    final hasResults =
        _users.isNotEmpty ||
        _firestoreVideos.isNotEmpty ||
        localVideos.isNotEmpty;

    return SafeArea(
      child: Container(
        height:
            MediaQuery.of(context).size.height *
                0.78,
        decoration:
            const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius:
              BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),

            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius:
                    BorderRadius.circular(20),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                10,
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                decoration:
                    InputDecoration(
                  hintText:
                      'Search videos, users...',
                  hintStyle:
                      const TextStyle(
                    color: Colors.white54,
                  ),
                  prefixIcon:
                      const Icon(
                    Icons.search,
                    color: Colors.white,
                  ),
                  suffixIcon:
                      IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                    ),
                    onPressed: () {
                      _controller.clear();

                      setState(() {
                        _users = [];
                        _firestoreVideos =
                            [];
                        _searching = false;
                        _lastQuery = '';
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white
                      .withOpacity(0.08),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),
            ),

            Expanded(
              child: query.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search,
                            size: 52,
                            color:
                                Colors.white30,
                          ),
                          SizedBox(
                            height: 12,
                          ),
                          Text(
                            'Search PALOK',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          Text(
                            'Users, captions and hashtags খুঁজুন',
                            style:
                                TextStyle(
                              color:
                                  Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _searching
                      ? const Center(
                          child:
                              CircularProgressIndicator(
                            color:
                                Color(
                              0xFFFF2D55,
                            ),
                          ),
                        )
                      : !hasResults
                          ? const Center(
                              child: Text(
                                'কোনো ফলাফল পাওয়া যায়নি',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView(
                              padding:
                                  const EdgeInsets
                                      .fromLTRB(
                                18,
                                8,
                                18,
                                24,
                              ),
                              children: [
                                if (_users
                                    .isNotEmpty) ...[
                                  const Padding(
                                    padding:
                                        EdgeInsets
                                            .only(
                                      bottom: 10,
                                    ),
                                    child: Text(
                                      'Users',
                                      style:
                                          TextStyle(
                                        color:
                                            Colors.white,
                                        fontSize:
                                            16,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                      ),
                                    ),
                                  ),

                                  ..._users.map(
                                    _buildUserItem,
                                  ),

                                  const SizedBox(
                                    height: 12,
                                  ),
                                ],

                                if (localVideos
                                    .isNotEmpty) ...[
                                  const Padding(
                                    padding:
                                        EdgeInsets
                                            .only(
                                      bottom: 10,
                                    ),
                                    child: Text(
                                      'Videos',
                                      style:
                                          TextStyle(
                                        color:
                                            Colors.white,
                                        fontSize:
                                            16,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                      ),
                                    ),
                                  ),

                                  ...localVideos.map(
                                    (video) {
                                      return InkWell(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          16,
                                        ),
                                        onTap: () async {
                                          await _selectLocalVideo(
                                            context,
                                            video,
                                          );
                                        },
                                        child:
                                            Container(
                                          margin:
                                              const EdgeInsets
                                                  .only(
                                            bottom: 10,
                                          ),
                                          padding:
                                              const EdgeInsets
                                                  .all(
                                            12,
                                          ),
                                          decoration:
                                              BoxDecoration(
                                            color: Colors
                                                .white
                                                .withOpacity(
                                              0.06,
                                            ),
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                              16,
                                            ),
                                          ),
                                          child:
                                              Row(
                                            children: [
                                              Container(
                                                width:
                                                    58,
                                                height:
                                                    76,
                                                decoration:
                                                    BoxDecoration(
                                                  color:
                                                      Colors.white10,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    12,
                                                  ),
                                                ),
                                                child:
                                                    const Icon(
                                                  Icons
                                                      .play_arrow_rounded,
                                                  color:
                                                      Colors.white70,
                                                  size:
                                                      30,
                                                ),
                                              ),

                                              const SizedBox(
                                                width:
                                                    12,
                                              ),

                                              Expanded(
                                                child:
                                                    Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _readString(
                                                        video,
                                                        'username',
                                                      ),
                                                      style:
                                                          const TextStyle(
                                                        color:
                                                            Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),

                                                    const SizedBox(
                                                      height:
                                                          4,
                                                    ),

                                                    Text(
                                                      _readString(
                                                        video,
                                                        'caption',
                                                      ).isEmpty
                                                          ? _readString(
                                                              video,
                                                              'hashtags',
                                                            )
                                                          : _readString(
                                                              video,
                                                              'caption',
                                                            ),
                                                      maxLines:
                                                          2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          const TextStyle(
                                                        color:
                                                            Colors.white60,
                                                        fontSize:
                                                            13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              const Icon(
                                                Icons
                                                    .chevron_right,
                                                color:
                                                    Colors.white54,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],

                                if (_firestoreVideos
                                    .isNotEmpty) ...[
                                  const Padding(
                                    padding:
                                        EdgeInsets
                                            .only(
                                      top: 6,
                                      bottom: 10,
                                    ),
                                    child: Text(
                                      'More Videos',
                                      style:
                                          TextStyle(
                                        color:
                                            Colors.white,
                                        fontSize:
                                            16,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                      ),
                                    ),
                                  ),

                                  ..._firestoreVideos
                                      .map(
                                    _buildVideoItem,
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
}
