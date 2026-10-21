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

  // FULL-SCREEN VIDEO PLAYING

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

  // BOTTOM SHADOW/GRADIENT LAYER

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

  // VIDEO INFORMATION AREA (গোল আইকন এবং @ চিহ্ন সম্পূর্ণ বাদ দেওয়া হয়েছে)

  Widget _buildVideoInfo(double bottom) {
    // নামের শুরু বা মাঝখানে যদি @ চিহ্ন থাকে, তা স্বয়ংক্রিয়ভাবে মুছে ফেলার লজিক
    final cleanUsername = video.username.replaceAll('@', '').trim();

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
            child: Text(
              cleanUsername, // গোল আইকন ছাড়া শুধু ইউজার নেমটি থাকবে
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16, // টেক্সট সাইজ টিকটক স্টাইলে একটু স্পষ্ট করা হলো
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    blurRadius: 2.0,
                    color: Colors.black54,
                    offset: Offset(1.0, 1.0),
                  ),
                ],
              ),
            ),
          ),
          if (video.caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              video.caption, // ভিডিওর মূল ক্যাপশন
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
                  .map((tag) => tag.startsWith('#') ? tag : '#$tag')
                  .join(' '), // হ্যাশট্যাগগুলো পাশাপাশি সুন্দর ফাঁকা জায়গা নিয়ে বসবে
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF20D7E8), // হ্যাশট্যাগগুলোকে আকর্ষণীয় করতে পালক সায়ান টোন দেওয়া হলো
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
                  size: 15,
                ),
                const SizedBox(width: 4),
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

  // RIGHT SIDE SOCIAL ACTIONS PANEL

  Widget _buildActionButtons(double bottom) {
    return Positioned(
      right: 10,
      bottom: bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            label: _formatCount(likeCount ?? video.likeCount),
            active: isLiked,
            onTap: onLike,
          ),
          const SizedBox(height: 18),
          _ActionButton(
            icon: Icons.comment_outlined,
            label: _formatCount(commentCount ?? video.commentCount),
            onTap: onComment,
          ),
          const SizedBox(height: 18),
          _ActionButton(
            icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
            label: _formatCount(saveCount ?? video.saveCount),
            active: isSaved,
            onTap: onSave,
          ),
          const SizedBox(height: 18),
          _ActionButton(
            icon: Icons.share_outlined,
            label: _formatCount(shareCount ?? video.shareCount),
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
              color: active ? const Color(0xFFFF2D55) : Colors.white,
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
