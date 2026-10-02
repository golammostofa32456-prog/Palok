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
  static const Color _pink = Color(0xFFFF2D55);
  static const Color _cyan = Color(0xFF00E5FF);

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
  void initState() {
    super.initState();

    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ============================================================
  // SEARCH TEXT NORMALIZE
  // ============================================================

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('@', '')
        .replaceAll('#', '');
  }

  // ============================================================
  // SEARCH TEXT CHANGED
  // ============================================================

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

    _searchTimer = Timer(
      const Duration(milliseconds: 350),
      () {
        _performSearch(query);
      },
    );
  }

  // ============================================================
  // MAIN SEARCH
  // ============================================================

  Future<void> _performSearch(String query) async {
    final text = _normalize(query);

    if (text.isEmpty) {
      return;
    }

    setState(() {
      _searching = true;
      _lastQuery = text;
    });

    // ----------------------------------------------------------
    // IMPORTANT:
    // Local search must work even if Firestore search fails.
    // ----------------------------------------------------------

    final localResults = _searchLocalVideos(text);

    List<Map<String, dynamic>> users = [];
    List<Map<String, dynamic>> firestoreVideos = [];

    // ----------------------------------------------------------
    // USER SEARCH
    // ----------------------------------------------------------

    try {
      users = await _searchUsers(text);
    } catch (_) {
      users = [];
    }

    // ----------------------------------------------------------
    // VIDEO SEARCH
    // ----------------------------------------------------------

    try {
      firestoreVideos = await _searchVideos(text);
    } catch (_) {
      firestoreVideos = [];
    }

    if (!mounted) {
      return;
    }

    if (_lastQuery != text) {
      return;
    }

    // ----------------------------------------------------------
    // Remove Firestore video duplicates that are already
    // present in the Home feed.
    // ----------------------------------------------------------

    final localIds = <String>{};

    for (final video in localResults) {
      final id = _readString(video, 'id');

      if (id.isNotEmpty) {
        localIds.add(id);
      }
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

  // ============================================================
  // FIRESTORE USER SEARCH
  // ============================================================

  Future<List<Map<String, dynamic>>> _searchUsers(
    String query,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .limit(200)
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

      final email =
          (data['email'] ?? '').toString();

      final searchText = [
        name,
        username,
        displayName,
        email,
      ].join(' ').toLowerCase();

      if (!_containsSearchText(
        searchText,
        query,
      )) {
        continue;
      }

      users.add({
        'id': doc.id,
        'name': name,
        'username': username,
        'displayName': displayName,
        'email': email,
        'photoURL':
            (
              data['photoURL'] ??
              data['profileImage'] ??
              data['photoUrl'] ??
              ''
            ).toString(),
      });
    }

    return users;
  }

  // ============================================================
  // FIRESTORE VIDEO SEARCH
  // ============================================================

  Future<List<Map<String, dynamic>>> _searchVideos(
    String query,
  ) async {
    final snapshot = await _firestore
        .collection('videos')
        .limit(200)
        .get();

    final videos = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final username =
          (data['username'] ?? '').toString();

      final caption =
          (data['caption'] ?? '').toString();

      final hashtags =
          _valueToSearchString(data['hashtags']);

      final userId =
          (data['userId'] ?? '').toString();

      final searchText = [
        username,
        caption,
        hashtags,
        userId,
      ].join(' ').toLowerCase();

      if (!_containsSearchText(
        searchText,
        query,
      )) {
        continue;
      }

      videos.add({
        'id': doc.id,
        'username': username,
        'caption': caption,
        'hashtags': hashtags,
        'userId': userId,
        'videoUrl':
            (data['videoUrl'] ?? '').toString(),
        'thumbnailUrl':
            (data['thumbnailUrl'] ?? '').toString(),
        'creatorImage':
            (
              data['creatorImage'] ??
              data['profileImage'] ??
              data['photoURL'] ??
              ''
            ).toString(),
      });
    }

    return videos;
  }

  // ============================================================
  // LOCAL HOME VIDEO SEARCH
  // ============================================================

  List<dynamic> _searchLocalVideos(String query) {
    final textQuery = _normalize(query);

    if (textQuery.isEmpty) {
      return [];
    }

    final results = <dynamic>[];

    for (final video in widget.videos) {
      final id =
          _readString(video, 'id').toLowerCase();

      final username =
          _readString(video, 'username').toLowerCase();

      final caption =
          _readString(video, 'caption').toLowerCase();

      final hashtags =
          _readString(video, 'hashtags').toLowerCase();

      final userId =
          _readString(video, 'userId').toLowerCase();

      final text = [
        id,
        username,
        caption,
        hashtags,
        userId,
      ].join(' ');

      if (_containsSearchText(
        text,
        textQuery,
      )) {
        results.add(video);
      }
    }

    return results;
  }

  // ============================================================
  // SEARCH MATCH HELPER
  // ============================================================

  bool _containsSearchText(
    String source,
    String query,
  ) {
    final normalizedSource =
        _normalize(source);

    final normalizedQuery =
        _normalize(query);

    if (normalizedQuery.isEmpty) {
      return true;
    }

    return normalizedSource.contains(
      normalizedQuery,
    );
  }

  // ============================================================
  // READ OBJECT FIELD SAFELY
  // ============================================================

  String _readString(
    dynamic object,
    String field,
  ) {
    try {
      if (object == null) {
        return '';
      }

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

        case 'hashtags':
          return object.hashtags?.toString() ?? '';

        case 'userId':
          return object.userId?.toString() ?? '';

        case 'creatorImage':
          return object.creatorImage?.toString() ?? '';

        case 'videoUrl':
          return object.videoUrl?.toString() ?? '';

        case 'thumbnailUrl':
          return object.thumbnailUrl?.toString() ?? '';

        default:
          return '';
      }
    } catch (_) {
      return '';
    }
  }

  // ============================================================
  // FIRESTORE VALUE -> STRING
  // ============================================================

  String _valueToSearchString(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    if (value is Iterable) {
      return value
          .map((item) => item.toString())
          .join(' ');
    }

    return value.toString();
  }

  // ============================================================
  // FIND LOCAL VIDEO INDEX
  // ============================================================

  int _findActualIndex(
    dynamic video,
  ) {
    final selectedId =
        _readString(video, 'id');

    if (selectedId.isEmpty) {
      return -1;
    }

    return widget.videos.indexWhere(
      (item) {
        final itemId =
            _readString(item, 'id');

        return itemId == selectedId;
      },
    );
  }

  // ============================================================
  // SELECT LOCAL VIDEO
  // ============================================================

  Future<void> _selectLocalVideo(
    BuildContext sheetContext,
    dynamic video,
  ) async {
    final actualIndex =
        _findActualIndex(video);

    if (actualIndex < 0) {
      return;
    }

    Navigator.of(sheetContext).pop();

    if (widget.onVideoSelected != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) async {
          await widget.onVideoSelected!(
            actualIndex,
          );
        },
      );
    }
  }

  // ============================================================
  // SELECT FIRESTORE VIDEO
  // ============================================================

  Future<void> _selectFirestoreVideo(
    BuildContext sheetContext,
    Map<String, dynamic> video,
  ) async {
    final selectedId =
        (video['id'] ?? '').toString();

    if (selectedId.isEmpty) {
      return;
    }

    final actualIndex =
        widget.videos.indexWhere(
      (item) {
        final id =
            _readString(item, 'id');

        return id == selectedId;
      },
    );

    if (actualIndex >= 0) {
      Navigator.of(sheetContext).pop();

      if (widget.onVideoSelected != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) async {
            await widget.onVideoSelected!(
              actualIndex,
            );
          },
        );
      }

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'ভিডিওটি বর্তমানে Home feed-এ নেই',
        ),
      ),
    );
  }

  // ============================================================
  // CLEAR SEARCH
  // ============================================================

  void _clearSearch() {
    _controller.clear();

    setState(() {
      _users = [];
      _firestoreVideos = [];
      _searching = false;
      _lastQuery = '';
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final query =
        _controller.text.trim();

    final localVideos =
        query.isEmpty
            ? <dynamic>[]
            : _searchLocalVideos(
                _normalize(query),
              );

    final hasResults =
        _users.isNotEmpty ||
        localVideos.isNotEmpty ||
        _firestoreVideos.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          initialChildSize: .78,
          minChildSize: .55,
          maxChildSize: .95,
          expand: false,
          builder: (
            context,
            scrollController,
          ) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF101010),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Column(
                children: [
                  // ------------------------------------------------
                  // DRAG HANDLE
                  // ------------------------------------------------

                  const SizedBox(height: 10),

                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ------------------------------------------------
                  // TITLE
                  // ------------------------------------------------

                  Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 18,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Search',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),

                        const Spacer(),

                        IconButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pop();
                          },
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ------------------------------------------------
                  // SEARCH FIELD
                  // ------------------------------------------------

                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      12,
                    ),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged:
                          _onSearchChanged,
                      textInputAction:
                          TextInputAction.search,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration:
                          InputDecoration(
                        hintText:
                            'Search videos, users...',
                        hintStyle:
                            const TextStyle(
                          color: Colors.white38,
                        ),

                        prefixIcon:
                            const Icon(
                          Icons.search,
                          color: Colors.white54,
                        ),

                        suffixIcon:
                            query.isNotEmpty
                                ? IconButton(
                                    onPressed:
                                        _clearSearch,
                                    icon:
                                        const Icon(
                                      Icons.clear,
                                      color:
                                          Colors.white54,
                                    ),
                                  )
                                : null,

                        filled: true,
                        fillColor:
                            Colors.white10,

                        contentPadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),

                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(18),
                          borderSide:
                              BorderSide.none,
                        ),

                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(18),
                          borderSide:
                              BorderSide.none,
                        ),

                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(18),
                          borderSide:
                              const BorderSide(
                            color: _pink,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ------------------------------------------------
                  // SEARCH BODY
                  // ------------------------------------------------

                  Expanded(
                    child: _searching
                        ? const Center(
                            child:
                                CircularProgressIndicator(
                              color: _pink,
                            ),
                          )
                        : query.isEmpty
                            ? _buildEmptySearch()
                            : !hasResults
                                ? _buildNoResults(
                                    query,
                                  )
                                : ListView(
                                    controller:
                                        scrollController,
                                    padding:
                                        const EdgeInsets
                                            .fromLTRB(
                                      16,
                                      4,
                                      16,
                                      30,
                                    ),
                                    children: [
                                      // --------------------------
                                      // USERS
                                      // --------------------------

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
                                          height: 18,
                                        ),
                                      ],

                                      // --------------------------
                                      // LOCAL VIDEOS
                                      // --------------------------

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

                                        ...localVideos
                                            .map(
                                          (
                                            video,
                                          ) =>
                                              _buildLocalVideoItem(
                                            context,
                                            video,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 18,
                                        ),
                                      ],

                                      // --------------------------
                                      // FIRESTORE VIDEOS
                                      // --------------------------

                                      if (_firestoreVideos
                                          .isNotEmpty) ...[
                                        const Padding(
                                          padding:
                                              EdgeInsets
                                                  .only(
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
                                          (
                                            video,
                                          ) =>
                                              _buildFirestoreVideoItem(
                                            context,
                                            video,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY SEARCH
  // ============================================================

  Widget _buildEmptySearch() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 30,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    const LinearGradient(
                  colors: [
                    _pink,
                    _cyan,
                  ],
                ),
              ),
              child: const Icon(
                Icons.search,
                color: Colors.white,
                size: 38,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Search PALOK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Username, caption অথবা hashtag দিয়ে ভিডিও খুঁজুন',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NO RESULTS
  // ============================================================

  Widget _buildNoResults(
    String query,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 30,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: Colors.white38,
              size: 58,
            ),

            const SizedBox(height: 14),

            const Text(
              'কোনো ফলাফল পাওয়া যায়নি',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              '"$query" দিয়ে কোনো User বা Video পাওয়া যায়নি',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // USER ITEM
  // ============================================================

  Widget _buildUserItem(
    Map<String, dynamic> user,
  ) {
    final username =
        (user['username'] ?? '')
            .toString();

    final name =
        (user['name'] ?? '')
            .toString();

    final displayName =
        (user['displayName'] ?? '')
            .toString();

    final photoURL =
        (user['photoURL'] ?? '')
            .toString();

    String title = username;

    if (title.isEmpty) {
      title = displayName;
    }

    if (title.isEmpty) {
      title = name;
    }

    if (title.isEmpty) {
      title = 'PALOK User';
    }

    String subtitle = '';

    if (displayName.isNotEmpty &&
        displayName != title) {
      subtitle = displayName;
    } else if (name.isNotEmpty &&
        name != title) {
      subtitle = name;
    }

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),

        leading: _buildAvatar(
          photoURL,
          title,
        ),

        title: Text(
          title.startsWith('@')
              ? title
              : '@$title',
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w700,
            fontSize: 15,
          ),
        ),

        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color:
                      Colors.white54,
                  fontSize: 13,
                ),
              )
            : null,

        trailing: const Icon(
          Icons.person_outline,
          color: Colors.white38,
        ),
      ),
    );
  }

  // ============================================================
  // LOCAL VIDEO ITEM
  // ============================================================

  Widget _buildLocalVideoItem(
    BuildContext sheetContext,
    dynamic video,
  ) {
    final username =
        _readString(
          video,
          'username',
        );

    final caption =
        _readString(
          video,
          'caption',
        );

    final hashtags =
        _readString(
          video,
          'hashtags',
        );

    final thumbnailUrl =
        _readString(
          video,
          'thumbnailUrl',
        );

    return InkWell(
      borderRadius:
          BorderRadius.circular(16),
      onTap: () async {
        await _selectLocalVideo(
          sheetContext,
          video,
        );
      },
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
            const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              Colors.white.withOpacity(.05),
          borderRadius:
              BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _buildVideoThumbnail(
              thumbnailUrl,
              username,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    username.isEmpty
                        ? '@PALOK'
                        : '@$username',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),

                  if (caption
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      caption,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],

                  if (hashtags
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      hashtags,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color: _cyan,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            const Icon(
              Icons.play_circle_outline,
              color: Colors.white70,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FIRESTORE VIDEO ITEM
  // ============================================================

  Widget _buildFirestoreVideoItem(
    BuildContext sheetContext,
    Map<String, dynamic> video,
  ) {
    final username =
        (video['username'] ?? '')
            .toString();

    final caption =
        (video['caption'] ?? '')
            .toString();

    final hashtags =
        (video['hashtags'] ?? '')
            .toString();

    final thumbnailUrl =
        (video['thumbnailUrl'] ?? '')
            .toString();

    return InkWell(
      borderRadius:
          BorderRadius.circular(16),
      onTap: () async {
        await _selectFirestoreVideo(
          sheetContext,
          video,
        );
      },
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
            const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              Colors.white.withOpacity(.05),
          borderRadius:
              BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _buildVideoThumbnail(
              thumbnailUrl,
              username,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    username.isEmpty
                        ? '@PALOK'
                        : '@$username',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),

                  if (caption
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      caption,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],

                  if (hashtags
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      hashtags,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color: _cyan,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            const Icon(
              Icons.play_circle_outline,
              color: Colors.white70,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // VIDEO THUMBNAIL
  // ============================================================

  Widget _buildVideoThumbnail(
    String imageUrl,
    String username,
  ) {
    final firstLetter =
        username.trim().isEmpty
            ? 'P'
            : username
                .trim()
                .substring(0, 1)
                .toUpperCase();

    if (imageUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius:
            BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          width: 58,
          height: 76,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) {
            return _videoPlaceholder(
              firstLetter,
            );
          },
        ),
      );
    }

    return _videoPlaceholder(
      firstLetter,
    );
  }

  // ============================================================
  // VIDEO PLACEHOLDER
  // ============================================================

  Widget _videoPlaceholder(
    String letter,
  ) {
    return Container(
      width: 58,
      height: 76,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(12),
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _pink,
            _cyan,
          ],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // USER AVATAR
  // ============================================================

  Widget _buildAvatar(
    String imageUrl,
    String name,
  ) {
    final firstLetter =
        name.trim().isEmpty
            ? 'P'
            : name
                .trim()
                .substring(0, 1)
                .toUpperCase();

    if (imageUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) {
            return _avatarPlaceholder(
              firstLetter,
            );
          },
        ),
      );
    }

    return _avatarPlaceholder(
      firstLetter,
    );
  }

  // ============================================================
  // AVATAR PLACEHOLDER
  // ============================================================

  Widget _avatarPlaceholder(
    String letter,
  ) {
    return Container(
      width: 48,
      height: 48,
      decoration:
          const BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            LinearGradient(
          colors: [
            _pink,
            _cyan,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style:
            const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }
}
