
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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

  @override
  void initState() {
    super.initState();

    _controller = HomeController();
    _pageController = PageController();

    _load();
  }

  Future<void> _load() async {
    await _controller.load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller.dispose();

    super.dispose();
  }

  // ============================================================
  // VIDEO ACTIONS
  // ============================================================

  Future<void> _onLike(VideoPost video) async {
    final success = await _controller.toggleLike(video);

    if (!success && mounted) {
      _showMessage('Like করতে Login করতে হবে');
    }
  }

  Future<void> _onSave(VideoPost video) async {
    final success = await _controller.toggleSave(video);

    if (!success && mounted) {
      _showMessage('Save করতে Login করতে হবে');
      return;
    }

    if (mounted) {
      _showMessage(
        _controller.isSaved(video.id)
            ? 'ভিডিও Saved হয়েছে'
            : 'ভিডিও Unsave হয়েছে',
      );
    }
  }

  Future<void> _onFollow(VideoPost video) async {
    final success = await _controller.toggleFollow(video);

    if (!success && mounted) {
      _showMessage(
        video.ownerId.isEmpty
            ? 'Creator information পাওয়া যায়নি'
            : 'Follow করতে Login করতে হবে',
      );
    }
  }

  Future<void> _onShare(VideoPost video) async {
    try {
      final String shareUrl =
          'https://palok.app/video/${video.id}';

      await SharePlus.instance.share(
        ShareParams(
          text:
              '${video.caption.isNotEmpty ? video.caption : 'PALOK ভিডিও'}\n\n'
              '$shareUrl',
        ),
      );

      await _controller.addShare(video);

      if (mounted) {
        _showMessage('ভিডিও Share হয়েছে');
      }
    } catch (e) {
      debugPrint('Share error: $e');

      if (mounted) {
        _showMessage('Share করা যায়নি');
      }
    }
  }

  void _onComment(VideoPost video) {
    _showCommentSheet(video);
  }

  void _onProfile(VideoPost video) {
    _showMessage('@${video.username} Profile');
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  void _showCommentSheet(VideoPost video) {
    final TextEditingController commentController =
        TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom:
                  MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    const Icon(
                      Icons.comment_outlined,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_controller.commentCount(video)} Comments',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Container(
                  constraints: const BoxConstraints(
                    minHeight: 100,
                    maxHeight: 260,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Comments এখানে দেখা যাবে।',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 15,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'একটি Comment লিখুন...',
                          hintStyle: const TextStyle(
                            color: Colors.white38,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF252525),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    IconButton(
                      onPressed: () {
                        final text =
                            commentController.text.trim();

                        if (text.isEmpty) {
                          return;
                        }

                        _controller.addCommentCount(
                          video.id,
                          1,
                        );

                        commentController.clear();

                        Navigator.pop(sheetContext);

                        _showMessage(
                          'Comment যোগ হয়েছে',
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFFF2D55),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(
                        Icons.send,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(
      commentController.dispose,
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _openSearch() {
    showSearch(
      context: context,
      delegate: _PalokSearchDelegate(
        videos: _controller.videos,
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void _onBottomNavigation(int index) {
    if (index == 2) {
      _openUpload();
      return;
    }

    setState(() {
      _bottomIndex = index;
    });

    if (index == 0) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } else if (index == 1) {
      _showMessage('Friends section');
    } else if (index == 3) {
      _showMessage('Inbox section');
    } else if (index == 4) {
      _showMessage('Profile section');
    }
  }

  // ============================================================
  // UPLOAD
  // ============================================================

  Future<void> _openUpload() async {
    _showMessage('Upload screen খুলতে প্রস্তুত করুন');
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: Row(
            children: [
              const Text(
                'PALOK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),

              const Spacer(),

              IconButton(
                onPressed: _openSearch,
                icon: const Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // VIDEO FEED
  // ============================================================

  Widget _buildFeed() {
    if (_controller.loading &&
        _controller.videos.isEmpty) {
      return HomeWidgets.loading();
    }

    if (_controller.error != null &&
        _controller.videos.isEmpty) {
      return HomeWidgets.error(
        message: _controller.error!,
        onRetry: _load,
      );
    }

    if (_controller.videos.isEmpty) {
      return HomeWidgets.emptyFeed();
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      physics: const PageScrollPhysics(),
      allowImplicitScrolling: true,
      itemCount: _controller.videos.length,
      onPageChanged: (index) {
        _controller.onVideoChanged(index);
      },
      itemBuilder: (context, index) {
        final video = _controller.videos[index];

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _controller.togglePlay();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              HomeWidgets.videoCard(
                video: video,
                controller: _controller,
                index: index,
                onLike: () => _onLike(video),
                onComment: () => _onComment(video),
                onSave: () => _onSave(video),
                onShare: () => _onShare(video),
                onFollow: () => _onFollow(video),
                onProfile: () => _onProfile(video),
              ),

              // Play / Pause indicator
              if (!_controller.isPlaying(index))
                const Center(
                  child: IgnorePointer(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white70,
                      size: 72,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION UI
  // ============================================================

  Widget _buildBottomNavigation() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          height: 72,
          decoration: const BoxDecoration(
            color: Colors.black,
            border: Border(
              top: BorderSide(
                color: Colors.white12,
                width: 1,
              ),
            ),
          ),
          child: Row(
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

              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => _onBottomNavigation(2),
                    child: Container(
                      width: 58,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF00E5FF),
                            Color(0xFFFF2D55),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),

              _bottomItem(
                index: 3,
                icon: Icons.chat_bubble_outline,
                label: 'Inbox',
              ),

              _bottomItem(
                index: 4,
                icon: Icons.person_outline,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool selected = _bottomIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onBottomNavigation(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected
                  ? Colors.white
                  : Colors.white54,
              size: 25,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white54,
                fontSize: 11,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(
            seconds: 2,
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _buildFeed(),

              _buildTopBar(),

              _buildBottomNavigation(),
            ],
          ),
        );
      },
    );
  }
}

// ================================================================
// SEARCH DELEGATE
// ================================================================

class _PalokSearchDelegate
    extends SearchDelegate<VideoPost?> {
  final List<VideoPost> videos;

  _PalokSearchDelegate({
    required this.videos,
  });

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
          icon: const Icon(Icons.clear),
        ),
    ];
  }

  @override
  Widget? buildLeading(
    BuildContext context,
  ) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back),
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
    final String searchText =
        query.trim().toLowerCase();

    final results = searchText.isEmpty
        ? videos
        : videos.where((video) {
            return video.username
                    .toLowerCase()
                    .contains(searchText) ||
                video.caption
                    .toLowerCase()
                    .contains(searchText) ||
                video.hashtags.any(
                  (tag) => tag
                      .toLowerCase()
                      .contains(searchText),
                );
          }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text(
          'কোনো ভিডিও পাওয়া যায়নি',
          style: TextStyle(
            color: Colors.white54,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final video = results[index];

        return ListTile(
          leading: const CircleAvatar(
            child: Icon(
              Icons.person,
            ),
          ),
          title: Text(
            '@${video.username}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            video.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
            ),
          ),
          onTap: () {
            close(context, video);
          },
        );
      },
    );
  }
}
