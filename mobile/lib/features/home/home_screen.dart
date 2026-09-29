import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../upload_video_screen.dart';
import '../video/video_post.dart';
import 'home_controller.dart';
import 'home_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;
  late final PageController _pageController;

  int _bottomIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _controller = HomeController();
    _pageController = PageController();

    _controller.addListener(
      _onControllerChanged,
    );

    _load();
  }

  @override
  void dispose() {
    _controller.removeListener(
      _onControllerChanged,
    );

    _controller.dispose();

    _pageController.dispose();

    super.dispose();
  }

  // ============================================================
  // CONTROLLER
  // ============================================================

  void _onControllerChanged() {
    if (!mounted) return;

    setState(() {});
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      await _controller.load();
    } catch (_) {
      // Controller handles its own error.
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      await _controller.refresh();
    } catch (_) {
      // Controller handles its own error.
    }
  }

  // ============================================================
  // LIKE
  // ============================================================

  Future<void> _onLike(
    VideoPost video,
  ) async {
    final success =
        await _controller.toggleLike(video);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Like করা যায়নি',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _onSave(
    VideoPost video,
  ) async {
    final success =
        await _controller.toggleSave(video);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Save করা যায়নি',
          ),
        ),
      );
    }
  }

  // ============================================================
  // FOLLOW
  // ============================================================

  Future<void> _onFollow(
    VideoPost video,
  ) async {
    final success =
        await _controller.toggleFollow(video);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Follow করা যায়নি',
          ),
        ),
      );
    }
  }

  // ============================================================
  // COMMENT
  // ============================================================

  Future<void> _onComment(
    VideoPost video,
  ) async {
    await _showComments(video);
  }

  Future<void> _showComments(
    VideoPost video,
  ) async {
    final commentController =
        TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Container(
          height:
              MediaQuery.of(sheetContext).size.height *
                  0.72,
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // ------------------------------------------------
              // HEADER
              // ------------------------------------------------

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  12,
                  8,
                  8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_controller.commentCount(video)} Comments',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        Navigator.pop(
                          sheetContext,
                        );
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(
                color: Colors.white12,
                height: 1,
              ),

              // ------------------------------------------------
              // COMMENTS
              // ------------------------------------------------

              Expanded(
                child: _buildCommentsList(
                  video,
                ),
              ),

              // ------------------------------------------------
              // INPUT
              // ------------------------------------------------

              Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom:
                      MediaQuery.of(sheetContext)
                              .viewInsets
                              .bottom +
                          12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller:
                            commentController,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        textInputAction:
                            TextInputAction.send,
                        onSubmitted: (_) {
                          _submitComment(
                            video,
                            commentController,
                          );
                        },
                        decoration:
                            InputDecoration(
                          hintText:
                              'Write a comment...',
                          hintStyle:
                              const TextStyle(
                            color: Colors.white38,
                          ),
                          filled: true,
                          fillColor:
                              const Color(
                            0xFF222222,
                          ),
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              24,
                            ),
                            borderSide:
                                BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Container(
                      width: 44,
                      height: 44,
                      decoration:
                          const BoxDecoration(
                        color:
                            Color(0xFFFF2D55),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          _submitComment(
                            video,
                            commentController,
                          );
                        },
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
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

    commentController.dispose();
  }

  Widget _buildCommentsList(
    VideoPost video,
  ) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _controller.commentsStream(
        video.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Comments load করা যায়নি',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ),
          );
        }

        final comments =
            snapshot.data?.docs ?? [];

        if (comments.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white54,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'এখনও কোনো comment নেই',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'প্রথম comment করুন',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12,
          ),
          itemCount: comments.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 16),
          itemBuilder: (
            context,
            index,
          ) {
            final data =
                comments[index].data();

            final username =
                (data['username'] ??
                        'PALOK User')
                    .toString();

            final text =
                (data['text'] ?? '')
                    .toString();

            final displayName =
                username.replaceFirst(
              '@',
              '',
            );

            return Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor:
                      const Color(
                    0xFFFF2D55,
                  ),
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName[0]
                            .toUpperCase()
                        : 'P',
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        '@$displayName',
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        text,
                        style:
                            const TextStyle(
                          color:
                              Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitComment(
    VideoPost video,
    TextEditingController controller,
  ) async {
    final text = controller.text.trim();

    if (text.isEmpty) return;

    final success =
        await _controller.addComment(
      video,
      text,
    );

    if (!mounted) return;

    if (success) {
      controller.clear();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Comment যোগ হয়েছে',
          ),
          duration:
              Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Comment যোগ করা যায়নি',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _onShare(
    VideoPost video,
  ) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              '${video.caption.isEmpty ? 'Watch this video on PALOK' : video.caption}\n\nPALOK',
        ),
      );

      await _controller.addShare(video);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Share করা যায়নি',
          ),
        ),
      );
    }
  }

  // ============================================================
  // PROFILE
  // ============================================================

  void _onProfile(
    VideoPost video,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          '@${video.username.replaceFirst('@', '')}',
        ),
      ),
    );
  }

  // ============================================================
  // VIDEO TAP
  // ============================================================

  void _onVideoTap(int index) {
    _controller.togglePlay();
  }

  // ============================================================
  // PAGE CHANGED
  // ============================================================

  Future<void> _onPageChanged(
    int index,
  ) async {
    await _controller.onVideoChanged(
      index,
    );
  }

  // ============================================================
  // UPLOAD
  // ============================================================

  Future<void> _openUpload() async {
    final result =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const UploadVideoScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _controller.refresh();

      if (!mounted) return;

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _openSearch() {
    showSearch<void>(
      context: context,
      delegate:
          _PalokVideoSearchDelegate(
        videos: _controller.videos,
      ),
    );
  }

  IconButton(
  icon: const Icon(Icons.search, color: Colors.white),
  onPressed: () {
    SearchScreen.open(context);
  },
)


  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void _onBottomNavigationChanged(
    int index,
  ) {
    setState(() {
      _bottomIndex = index;
    });

    if (index == 0) {
      return;
    }

    if (index == 1) {
      _showComingSoon('Friends');
      return;
    }

    if (index == 2) {
      _showComingSoon('Inbox');
      return;
    }

    if (index == 3) {
      _showComingSoon('Profile');
      return;
    }
  }

  void _showComingSoon(
    String name,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          '$name section পরের ধাপে যুক্ত করা হবে',
        ),
        duration:
            const Duration(seconds: 1),
      ),
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,

      body: Stack(
        children: [
          _buildFeed(),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: HomeWidgets.topBar(
              onSearch: _openSearch,
            ),
          ),

          Positioned(
            right: 16,
            bottom: 82,
            child: _buildUploadButton(),
          ),
        ],
      ),

      bottomNavigationBar:
          _buildBottomNavigation(),
    );
  }

  // ============================================================
  // FEED
  // ============================================================

  Widget _buildFeed() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_controller.error != null) {
      return HomeWidgets.error(
        message: _controller.error!,
        onRetry: _load,
      );
    }

    if (_controller.videos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 260),
            SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  'কোনো ভিডিও পাওয়া যায়নি',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount:
          _controller.videos.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (
        context,
        index,
      ) {
        final video =
            _controller.videos[index];

        return GestureDetector(
          behavior:
              HitTestBehavior.opaque,
          onTap: () =>
              _onVideoTap(index),
          child: HomeWidgets.videoCard(
            video: video,
            controller: _controller,
            index: index,
            onLike: () =>
                _onLike(video),
            onComment: () =>
                _onComment(video),
            onSave: () =>
                _onSave(video),
            onShare: () =>
                _onShare(video),
            onFollow: () =>
                _onFollow(video),
            onProfile: () =>
                _onProfile(video),
          ),
        );
      },
    );
  }

  // ============================================================
  // UPLOAD BUTTON
  // ============================================================

  Widget _buildUploadButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openUpload,
        borderRadius:
            BorderRadius.circular(18),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),
            color:
                const Color(0xFFFF2D55),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration:
            const BoxDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(
              color: Colors.white12,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceAround,
          children: [
            _bottomItem(
              index: 0,
              icon: Icons.home_filled,
              label: 'Home',
            ),
            _bottomItem(
              index: 1,
              icon: Icons.people_outline,
              label: 'Friends',
            ),
            _bottomItem(
              index: 2,
              icon: Icons.mail_outline,
              label: 'Inbox',
            ),
            _bottomItem(
              index: 3,
              icon: Icons.person_outline,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected =
        _bottomIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () =>
            _onBottomNavigationChanged(
          index,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected
                  ? const Color(
                      0xFFFF2D55,
                    )
                  : Colors.white70,
              size: 24,
            ),

            const SizedBox(height: 3),

            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(
                        0xFFFF2D55,
                      )
                    : Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// SEARCH DELEGATE
// ==================================================================

class _PalokVideoSearchDelegate
    extends SearchDelegate<void> {
  final List<VideoPost> videos;

  _PalokVideoSearchDelegate({
    required this.videos,
  });

  @override
  ThemeData appBarTheme(
    BuildContext context,
  ) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor:
          Colors.black,
      appBarTheme:
          const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme:
          const InputDecorationTheme(
        hintStyle: TextStyle(
          color: Colors.white54,
        ),
      ),
      textTheme:
          const TextTheme(
        titleLarge: TextStyle(
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(
    BuildContext context,
  ) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () {
            query = '';
          },
          icon: const Icon(
            Icons.clear,
            color: Colors.white,
          ),
        ),
    ];
  }

  @override
  Widget? buildLeading(
    BuildContext context,
  ) {
    return IconButton(
      onPressed: () {
        close(
          context,
          null,
        );
      },
      icon: const Icon(
        Icons.arrow_back,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget buildResults(
    BuildContext context,
  ) {
    return _buildResults();
  }

  @override
  Widget buildSuggestions(
    BuildContext context,
  ) {
    return _buildResults();
  }

  Widget _buildResults() {
    final searchText =
        query.trim().toLowerCase();

    if (searchText.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'ভিডিও বা username খুঁজুন',
            style: TextStyle(
              color: Colors.white54,
            ),
          ),
        ),
      );
    }

    final results =
        videos.where((video) {
      final username =
          video.username
              .toLowerCase();

      final caption =
          video.caption
              .toLowerCase();

      final hashtags =
          video.hashtags
              .join(' ')
              .toLowerCase();

      return username
              .contains(searchText) ||
          caption.contains(
            searchText,
          ) ||
          hashtags.contains(
            searchText,
          );
    }).toList();

    if (results.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'কোনো ফলাফল পাওয়া যায়নি',
            style: TextStyle(
              color: Colors.white54,
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: ListView.separated(
        padding:
            const EdgeInsets.all(16),
        itemCount: results.length,
        separatorBuilder:
            (_, __) =>
                const Divider(
          color: Colors.white12,
        ),
        itemBuilder: (
          context,
          index,
        ) {
          final video =
              results[index];

          return ListTile(
            contentPadding:
                const EdgeInsets
                    .symmetric(
              vertical: 4,
            ),
            leading: Container(
              width: 48,
              height: 64,
              decoration:
                  BoxDecoration(
                color: Colors.white10,
                borderRadius:
                    BorderRadius.circular(
                  8,
                ),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
              ),
            ),
            title: Text(
              '@${video.username.replaceFirst('@', '')}',
              style:
                  const TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            subtitle: Text(
              video.caption.isEmpty
                  ? 'PALOK Video'
                  : video.caption,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color: Colors.white60,
              ),
            ),
          );
        },
      ),
    );
  }
}
