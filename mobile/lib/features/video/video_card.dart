
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_post.dart';
import 'video_player_widget.dart';

class VideoCard extends StatelessWidget {
  final VideoPost video;
  final VideoPlayerController? controller;

  final bool isLiked;
  final bool isSaved;
  final bool isFollowing;

  final int? likeCount;
  final int? commentCount;
  final int? saveCount;
  final int? shareCount;

  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onFollow;
  final VoidCallback? onProfile;

  const VideoCard({
    super.key,
    required this.video,
    this.controller,
    this.isLiked = false,
    this.isSaved = false,
    this.isFollowing = false,
    this.likeCount,
    this.commentCount,
    this.saveCount,
    this.shareCount,
    this.onLike,
    this.onComment,
    this.onSave,
    this.onShare,
    this.onFollow,
    this.onProfile,
  });

  static const Color _pink = Color(0xFFFF2D55);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;

        // নিচের নেভিগেশন বারের জন্য নিরাপদ জায়গা।
        final bottomSafeSpace =
            MediaQuery.of(context).padding.bottom + 76.0;

        final actionBottom =
            bottomSafeSpace + 12.0;

        final infoBottom =
            bottomSafeSpace + 12.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            _buildVideo(),
            _buildBottomGradient(),
            _buildVideoInfo(infoBottom),
            _buildActionButtons(actionBottom),
          ],
        );
      },
    );
  }

  // FULL-SCREEN VIDEO

  Widget _buildVideo() {
    final videoController = controller;

    if (videoController == null ||
        !videoController.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: _pink,
          ),
        ),
      );
    }

    return VideoPlayerWidget(
      controller: videoController,
      fit: BoxFit.cover,
    );
  }

  // BOTTOM GRADIENT

  Widget _buildBottomGradient() {
    return const IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: 330,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black38,
                  Colors.black87,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // VIDEO INFORMATION

  Widget _buildVideoInfo(double bottom) {
    return Positioned(
      left: 16,
      right: 88,
      bottom: bottom,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onProfile,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  child: Text(
                    video.username.isNotEmpty
                        ? video.username[0].toUpperCase()
                        : 'P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '@${video.username.replaceFirst('@', '')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isFollowing) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onFollow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _pink,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Follow',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (video.caption.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              video.caption,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ],
          if (video.hashtags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              video.hashtags
                  .map(
                    (tag) => tag.startsWith('#') ? tag : '#$tag',
                  )
                  .join(' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (video.soundName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.music_note,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    video.soundName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ACTION BUTTONS

  Widget _buildActionButtons(double bottom) {
    return Positioned(
      right: 10,
      bottom: bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: isLiked
                ? Icons.favorite
                : Icons.favorite_border,
            label: _formatCount(
              likeCount ?? video.likeCount,
            ),
            active: isLiked,
            onTap: onLike,
          ),
          const SizedBox(height: 18),
          _ActionButton(
            icon: Icons.comment_outlined,
            label: _formatCount(
              commentCount ?? video.commentCount,
            ),
            onTap: onComment,
          ),
          const SizedBox(height: 18),
          _ActionButton(
            icon: isSaved
                ? Icons.bookmark
                : Icons.bookmark_border,
            label: _formatCount(
              saveCount ?? video.saveCount,
            ),
            active: isSaved,
            onTap: onSave,
          ),
          const SizedBox(height: 18),
          _ActionButton(
            icon: Icons.share_outlined,
            label: _formatCount(
              shareCount ?? video.shareCount,
            ),
            onTap: onShare,
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }

    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }

    return count.toString();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active
                  ? const Color(0xFFFF2D55)
                  : Colors.white,
              size: 31,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
