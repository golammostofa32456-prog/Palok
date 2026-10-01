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
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<dynamic> _searchVideos(String query) {
    final text = query.trim().toLowerCase();

    if (text.isEmpty) {
      return [];
    }

    return widget.videos.where((video) {
      final username =
          _readString(video, 'username').toLowerCase();

      final caption =
          _readString(video, 'caption').toLowerCase();

      final hashtags =
          _readString(video, 'hashtags').toLowerCase();

      final searchableText =
          '$username $caption $hashtags';

      return searchableText.contains(text);
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

        case 'thumbnailUrl':
          return object.thumbnailUrl?.toString() ?? '';

        default:
          return '';
      }
    } catch (_) {
      return '';
    }
  }

  int _findActualIndex(dynamic video) {
    final selectedId = _readString(video, 'id');

    return widget.videos.indexWhere(
      (item) => _readString(item, 'id') == selectedId,
    );
  }

  Future<void> _selectVideo(
    BuildContext sheetContext,
    dynamic video,
  ) async {
    final actualIndex = _findActualIndex(video);

    Navigator.of(sheetContext).pop();

    if (actualIndex < 0) {
      return;
    }

    if (widget.onVideoSelected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await widget.onVideoSelected!(actualIndex);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();

    final results = _searchVideos(query);

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
                onChanged: (_) {
                  setState(() {});
                },
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Search videos, users...',
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

                      setState(() {});
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            Expanded(
              child: query.isEmpty
                  ? const Center(
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
                    )
                  : results.isEmpty
                      ? const Center(
                          child: Text(
                            'কোনো ফলাফল পাওয়া যায়নি',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(18),
                          itemCount: results.length,
                          separatorBuilder: (_, __) {
                            return const SizedBox(height: 10);
                          },
                          itemBuilder: (_, index) {
                            final video = results[index];

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

                            return InkWell(
                              borderRadius:
                                  BorderRadius.circular(16),
                              onTap: () async {
                                await _selectVideo(
                                  context,
                                  video,
                                );
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withOpacity(0.06),
                                  borderRadius:
                                      BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    _smallVideoThumbnail(
                                      video,
                                    ),

                                    const SizedBox(width: 12),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            username,
                                            style:
                                                const TextStyle(
                                              color:
                                                  Colors.white,
                                              fontWeight:
                                                  FontWeight
                                                      .w700,
                                            ),
                                          ),

                                          const SizedBox(
                                            height: 4,
                                          ),

                                          Text(
                                            caption.isEmpty
                                                ? hashtags
                                                : caption,
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                            style:
                                                const TextStyle(
                                              color:
                                                  Colors.white60,
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
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallVideoThumbnail(
    dynamic video,
  ) {
    return Container(
      width: 58,
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white70,
        size: 30,
      ),
    );
  }
}
