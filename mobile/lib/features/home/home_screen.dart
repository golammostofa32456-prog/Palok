import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../search/search_screen.dart';

import '../../l10n/app_strings.dart';
import '../friends/friends_screen.dart';
import '../inbox/inbox_screen.dart';
import '../profile/profile_screen.dart';
import '../video/video_card.dart';
import '../video/video_post.dart';
import '../camera/camera_screen.dart';
import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _homeController;
  final PageController _pageController = PageController();

  int _selectedIndex = 0;
  int _topIndex = 0;

  static const Color _pink = Color(0xFFFF2D55);
  static const Color _cyan = Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();

    _homeController = HomeController();
    _homeController.load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _homeController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  bool _requireLogin() {
    if (FirebaseAuth.instance.currentUser != null) {
      return true;
    }

    _showMessage(tr('h_login_required'));
    return false;
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const TikTokCameraScreen(),
        ),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _toggleLike(VideoPost video) async {
    if (!_requireLogin()) return;

    final success = await _homeController.toggleLike(video);

    if (!success && mounted) {
      _showMessage(tr('h_like_failed'));
    }
  }

  Future<void> _toggleSave(VideoPost video) async {
    if (!_requireLogin()) return;

    final success = await _homeController.toggleSave(video);

    if (!success && mounted) {
      _showMessage(tr('h_save_failed'));
    } else if (success && mounted) {
      _showMessage(
        _homeController.isSaved(video.id)
            ? tr('h_saved_ok')
            : tr('h_unsaved_ok'),
      );
    }
  }

  Future<void> _toggleFollow(VideoPost video) async {
    if (!_requireLogin()) return;

    final success = await _homeController.toggleFollow(video);

    if (!success && mounted) {
      _showMessage(tr('h_follow_failed'));
    }
  }

  Future<void> _shareVideo(VideoPost video) async {
    final link = 'https://palok.app/video/${video.id}';

    try {
      await Share.share(
        '${tr('h_share_text')}\n\n$link',
      );

      await _homeController.addShare(video);
    } catch (e) {
      if (mounted) {
        _showMessage(tr('h_share_failed'));
      }
    }
  }

  void _openComments(VideoPost video) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        video: video,
        controller: _homeController,
        requireLogin: _requireLogin,
        showMessage: _showMessage,
      ),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          videos: _homeController.videos,
          onVideoSelected: (actualIndex) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(actualIndex);
              _homeController.onVideoChanged(actualIndex);
            }
          },
        ),
      ),
    );
  }

  Widget _buildFeed() {
    return AnimatedBuilder(
      animation: _homeController,
      builder: (context, _) {
        final videos = _homeController.videos;

        if (_homeController.loading && videos.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: _pink),
          );
        }

        if (_homeController.error != null && videos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    color: Colors.white70,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _homeController.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _homeController.refresh,
                    child: Text(tr('h_retry')),
                  ),
                ],
              ),
            ),
          );
        }

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.video_library_outlined,
                  color: Colors.white70,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  tr('h_no_videos'),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _homeController.refresh,
                  child: Text(tr('h_refresh')),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _homeController.refresh,
          color: _pink,
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            onPageChanged: (index) {
              _homeController.onVideoChanged(index);
            },
            itemBuilder: (context, index) {
              final video = videos[index];

              return VideoCard(
                video: video,
                controller: _homeController.controllerFor(index),
                isLiked: _homeController.isLiked(video.id),
                isSaved: _homeController.isSaved(video.id),
                isFollowing:
                    _homeController.isFollowing(video.ownerId),
                likeCount: _homeController.likeCount(video),
                commentCount: _homeController.commentCount(video),
                saveCount: _homeController.saveCount(video),
                shareCount: _homeController.shareCount(video),
                onLike: () => _toggleLike(video),
                onComment: () => _openComments(video),
                onSave: () => _toggleSave(video),
                onShare: () => _shareVideo(video),
                onFollow: () => _toggleFollow(video),
                // ভিডিওর মালিকের প্রোফাইল খোলে (আগে নিজের প্রোফাইল খুলত)
                onProfile: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: video.ownerId),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.play_circle_fill,
                color: _pink,
                size: 27,
              ),
              const SizedBox(width: 5),
              const Text(
                'PALOK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() => _topIndex = 0);
                },
                child: Text(
                  tr('p_following'),
                  style: TextStyle(
                    color: _topIndex == 0
                        ? Colors.white
                        : Colors.white60,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Text(
                '|',
                style: TextStyle(color: Colors.white38),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _topIndex = 1);
                },
                child: Text(
                  tr('h_for_you'),
                  style: TextStyle(
                    color: _topIndex == 1
                        ? Colors.white
                        : Colors.white60,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _openSearch,
                tooltip: tr('h_search'),
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

  @override
  Widget build(BuildContext context) {
    return LanguageBuilder(
      builder: (context) {
        final pages = <Widget>[
          Stack(
            fit: StackFit.expand,
            children: [
              _buildFeed(),
              _buildTopBar(),
            ],
          ),
          const FriendsScreen(),
          const SizedBox.shrink(),
          const InboxScreen(),
          const ProfileScreen(),
        ];

        return Scaffold(
          backgroundColor: Colors.black,
          body: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.black,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.grey,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_filled),
                label: tr('h_nav_home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.people_outline),
                label: tr('h_nav_friends'),
              ),
              BottomNavigationBarItem(
                icon: Container(
                  width: 45,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [_cyan, _pink],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.chat_bubble_outline),
                label: tr('h_nav_inbox'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                label: tr('h_nav_profile'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.video,
    required this.controller,
    required this.requireLogin,
    required this.showMessage,
  });

  final VideoPost video;
  final HomeController controller;
  final bool Function() requireLogin;
  final void Function(String) showMessage;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _textController =
      TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    if (!widget.requireLogin()) return;

    final text = _textController.text.trim();

    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    final success = await widget.controller.addComment(
      widget.video,
      text,
    );

    if (!mounted) return;

    setState(() => _sending = false);

    if (success) {
      _textController.clear();
      FocusScope.of(context).unfocus();
    } else {
      widget.showMessage(tr('h_comment_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.68,
        decoration: const BoxDecoration(
          color: Color(0xFF171717),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${tr('h_comments')} · ${widget.controller.commentCount(widget.video)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: widget.video.id.startsWith('demo_')
                  ? Center(
                      child: Text(
                        tr('h_demo_comments'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : StreamBuilder(
                      stream: widget.controller.commentsStream(
                        widget.video.id,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              tr('h_comments_failed'),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF2D55),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;

                        if (docs.isEmpty) {
                          return Center(
                            child: Text(
                              tr('h_first_comment'),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final username =
                                (data['username'] ?? 'PALOK User')
                                    .toString();
                            final text =
                                (data['text'] ?? '').toString();

                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.white12,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white70,
                                ),
                              ),
                              title: Text(
                                username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                text,
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendComment(),
                        decoration: InputDecoration(
                          hintText: tr('h_comment_hint'),
                          hintStyle: const TextStyle(
                            color: Colors.white54,
                          ),
                          filled: true,
                          fillColor: Colors.white10,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _sendComment,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00E5FF),
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Color(0xFF00E5FF),
                            ),
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
