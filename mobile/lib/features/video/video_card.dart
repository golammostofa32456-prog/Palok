
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
    this.onLike,
    this.onComment,
    this.onSave,
    this.onShare,
    this.onFollow,
    this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildVideo(),

        _buildBottomGradient(),

        _buildVideoInfo(),

        _buildActionButtons(),
      ],
    );
  }

  Widget _buildVideo() {
    if (controller == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return VideoPlayerWidget(
      controller: controller!,
      fit: BoxFit.cover,
    );
  }

  Widget _buildBottomGradient() {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 280,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black54,
                Colors.black87,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Positioned(
      left: 16,
      right: 90,
      bottom: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
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
                    '@${video.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isFollowing)
                  GestureDetector(
                    onTap: onFollow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white,
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
            ),
          ),

          const SizedBox(height: 12),

          if (video.caption.isNotEmpty)
            Text(
              video.caption,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),

          if (video.hashtags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              video.hashtags
                  .map((tag) => tag.startsWith('#') ? tag : '#$tag')
                  .join(' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
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
                      fontSize: 13,
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

  Widget _buildActionButtons() {
    return Positioned(
      right: 12,
      bottom: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: isLiked
                ? Icons.favorite
                : Icons.favorite_border,
            label: _formatCount(video.likeCount),
            active: isLiked,
            onTap: onLike,
          ),

          const SizedBox(height: 18),

          _ActionButton(
            icon: Icons.comment_outlined,
            label: _formatCount(video.commentCount),
            onTap: onComment,
          ),

          const SizedBox(height: 18),

          _ActionButton(
            icon: isSaved
                ? Icons.bookmark
                : Icons.bookmark_border,
            label: _formatCount(video.saveCount),
            active: isSaved,
            onTap: onSave,
          ),

          const SizedBox(height: 18),

          _ActionButton(
            icon: Icons.share_outlined,
            label: _formatCount(video.shareCount),
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
              color: active ? Colors.redAccent : Colors.white,
              size: 32,
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
