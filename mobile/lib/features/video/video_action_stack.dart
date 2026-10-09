import 'package:flutter/material.dart';

class VideoActionStack extends StatelessWidget {
  final bool isFollowing;
  final bool isLiked;
  final bool isSaved;

  final int likeCount;
  final int commentCount;
  final int saveCount;
  final int shareCount;
  final int? viewCount;

  final bool showFollow;

  final VoidCallback onFollow;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;

  final String? profileImageUrl;
  final VoidCallback? onProfileTap;

  const VideoActionStack({
    super.key,
    required this.isFollowing,
    required this.isLiked,
    required this.isSaved,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.shareCount,
    required this.showFollow,
    required this.onFollow,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
    this.viewCount,
    this.profileImageUrl,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 10,
      bottom: 116,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showFollow) ...[
            _profileButton(),
            const SizedBox(height: 7),
          ],

          _actionButton(
            icon: isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: _formatCount(likeCount),
            active: isLiked,
            onTap: onLike,
          ),

          const SizedBox(height: 13),

          _actionButton(
            icon: Icons.mode_comment_outlined,
            label: _formatCount(commentCount),
            onTap: onComment,
          ),

          const SizedBox(height: 13),

          _actionButton(
            icon: isSaved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            label: _formatCount(saveCount),
            active: isSaved,
            onTap: onSave,
          ),


          const SizedBox(height: 13),

          _actionButton(
            icon: Icons.share_rounded,
            label: _formatCount(shareCount),
            onTap: onShare,
          ),
        ],
      ),
    );
  }

  Widget _profileButton() {
    final url = profileImageUrl?.trim() ?? '';

    return SizedBox(
      width: 54,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: url.isEmpty
                    ? _defaultAvatar()
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _defaultAvatar();
                        },
                      ),
              ),
            ),
          ),

          Transform.translate(
            offset: const Offset(0, -10),
            child: GestureDetector(
              onTap: onFollow,
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: isFollowing
                      ? Colors.grey.shade700
                      : const Color(0xFFFF2D55),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1.3,
                  ),
                ),
                child: Icon(
                  isFollowing
                      ? Icons.check_rounded
                      : Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: Colors.grey.shade400,
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
              child: Icon(
                icon,
                color: active
                    ? const Color(0xFFFF2D55)
                    : Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      final result = value / 1000000;
      return '${result.toStringAsFixed(
        result.truncateToDouble() == result ? 0 : 1,
      )}M';
    }

    if (value >= 1000) {
      final result = value / 1000;
      return '${result.toStringAsFixed(
        result.truncateToDouble() == result ? 0 : 1,
      )}K';
    }

    return value.toString();
  }
}
