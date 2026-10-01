import 'dart:async';

import 'package:flutter/material.dart';

import 'search_service.dart';

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
  final SearchService _searchService = SearchService();

  late final TextEditingController _controller;

  Timer? _debounce;

  bool _loading = false;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _videos = [];

  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();

    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final text = query.trim();

    _debounce?.cancel();

    if (text.isEmpty) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _users = [];
        _videos = [];
      });

      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 350),
      () async {
        final requestId = ++_searchRequestId;

        if (!mounted) return;

        setState(() {
          _loading = true;
        });

        try {
          final results = await Future.wait([
            _searchService.searchUsers(text),
            _searchService.searchVideos(text),
          ]);

          if (!mounted || requestId != _searchRequestId) {
            return;
          }

          setState(() {
            _users = List<Map<String, dynamic>>.from(
              results[0],
            );

            _videos = List<Map<String, dynamic>>.from(
              results[1],
            );

            _loading = false;
          });
        } catch (_) {
          if (!mounted || requestId != _searchRequestId) {
            return;
          }

          setState(() {
            _users = [];
            _videos = [];
            _loading = false;
          });
        }
      },
    );
  }

  int _findHomeVideoIndex(String videoId) {
    if (videoId.isEmpty) {
      return -1;
    }

    return widget.videos.indexWhere(
      (video) {
        try {
          return video.id?.toString() == videoId;
        } catch (_) {
          return false;
        }
      },
    );
  }

  Future<void> _openVideo(
    BuildContext sheetContext,
    Map<String, dynamic> video,
  ) async {
    final videoId = video['id']?.toString() ?? '';

    final actualIndex = _findHomeVideoIndex(videoId);

    Navigator.of(sheetContext).pop();

    if (actualIndex < 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'এই ভিডিওটি বর্তমানে Home feed-এ নেই',
          ),
        ),
      );

      return;
    }

    if (widget.onVideoSelected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        await widget.onVideoSelected!(
          actualIndex,
        );
      });
    }
  }

  String _userName(
    Map<String, dynamic> user,
  ) {
    final username =
        user['username']?.toString().trim() ?? '';

    final name =
        user['name']?.toString().trim() ?? '';

    if (username.isNotEmpty) {
      return '@$username';
    }

    if (name.isNotEmpty) {
      return name;
    }

    return 'PALOK User';
  }

  String _userPhoto(
    Map<String, dynamic> user,
  ) {
    return user['photoURL']?.toString() ?? '';
  }

  Widget _userAvatar(
    Map<String, dynamic> user,
  ) {
    final photoUrl = _userPhoto(user);

    if (photoUrl.isEmpty) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person,
          color: Colors.white70,
          size: 28,
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        photoUrl,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white70,
              size: 28,
            ),
          );
        },
      ),
    );
  }

  Widget _videoThumbnail(
    Map<String, dynamic> video,
  ) {
    final thumbnailUrl =
        video['thumbnailUrl']?.toString() ?? '';

    if (thumbnailUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          thumbnailUrl,
          width: 58,
          height: 76,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _videoPlaceholder();
          },
        ),
      );
    }

    return _videoPlaceholder();
  }

  Widget _videoPlaceholder() {
    return Container(
      width: 58,
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white70,
        size: 30,
      ),
    );
  }

  Widget _sectionTitle(
    String title,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        10,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _emptySearch() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 52,
            color: Colors.white30,
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
          SizedBox(height: 5),
          Text(
            'Users, captions and hashtags খুঁজুন',
            style: TextStyle(
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noResults() {
    return const Center(
      child: Text(
        'কোনো ফলাফল পাওয়া যায়নি',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    final hasResults =
        _users.isNotEmpty || _videos.isNotEmpty;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius: BorderRadius.vertical(
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
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                10,
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _performSearch,
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Search videos, users...',
                  hintStyle: const TextStyle(
                    color: Colors.white54,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                    ),
                    onPressed: () {
                      _controller.clear();

                      _debounce?.cancel();

                      setState(() {
                        _users = [];
                        _videos = [];
                        _loading = false;
                      });
                    },
                  ),
                  filled: true,
                  fillColor:
                      Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            Expanded(
              child: query.isEmpty
                  ? _emptySearch()
                  : _loading
                      ? const Center(
                          child:
                              CircularProgressIndicator(
                            color: Color(0xFFFF2D55),
                          ),
                        )
                      : !hasResults
                          ? _noResults()
                          : ListView(
                              padding:
                                  const EdgeInsets.only(
                                bottom: 24,
                              ),
                              children: [
                                if (_users.isNotEmpty) ...[
                                  _sectionTitle(
                                    'Users',
                                  ),

                                  ..._users.map(
                                    (user) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal: 18,
                                          vertical: 5,
                                        ),
                                        child: Container(
                                          padding:
                                              const EdgeInsets
                                                  .all(12),
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
                                          child: Row(
                                            children: [
                                              _userAvatar(
                                                user,
                                              ),
                                              const SizedBox(
                                                width: 12,
                                              ),
                                              Expanded(
                                                child:
                                                    Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Text(
                                                      _userName(
                                                        user,
                                                      ),
                                                      style:
                                                          const TextStyle(
                                                        color:
                                                            Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize:
                                                            15,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height:
                                                          4,
                                                    ),
                                                    Text(
                                                      user['name']
                                                              ?.toString() ??
                                                          '',
                                                      maxLines:
                                                          1,
                                                      overflow:
                                                          TextOverflow
                                                              .ellipsis,
                                                      style:
                                                          const TextStyle(
                                                        color:
                                                            Colors.white54,
                                                        fontSize:
                                                            13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Icon(
                                                Icons
                                                    .person_outline,
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

                                if (_videos.isNotEmpty) ...[
                                  const SizedBox(
                                    height: 12,
                                  ),

                                  _sectionTitle(
                                    'Videos',
                                  ),

                                  ..._videos.map(
                                    (video) {
                                      final username =
                                          video['username']
                                                  ?.toString() ??
                                              '';

                                      final caption =
                                          video['caption']
                                                  ?.toString() ??
                                              '';

                                      return Padding(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal: 18,
                                          vertical: 5,
                                        ),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                            16,
                                          ),
                                          onTap: () async {
                                            await _openVideo(
                                              context,
                                              video,
                                            );
                                          },
                                          child:
                                              Container(
                                            padding:
                                                const EdgeInsets
                                                    .all(12),
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
                                            child: Row(
                                              children: [
                                                _videoThumbnail(
                                                  video,
                                                ),

                                                const SizedBox(
                                                  width: 12,
                                                ),

                                                Expanded(
                                                  child:
                                                      Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        username
                                                                .isEmpty
                                                            ? 'PALOK Video'
                                                            : username,
                                                        maxLines:
                                                            1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
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
                                                        caption
                                                                .isEmpty
                                                            ? 'PALOK Video'
                                                            : caption,
                                                        maxLines:
                                                            2,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
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
                                        ),
                                      );
                                    },
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
