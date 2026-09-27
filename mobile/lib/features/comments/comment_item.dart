import 'package:flutter/material.dart';

import 'comment_model.dart';

class CommentItem extends StatelessWidget {
  final CommentModel comment;
  final bool isCurrentUser;
  final VoidCallback? onDelete;

  const CommentItem({
    super.key,
    required this.comment,
    this.isCurrentUser = false,
    this.onDelete,
  });

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment.createdAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentUser && onDelete != null)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: Colors.white.withOpacity(0.65),
                size: 20,
              ),
              color: const Color(0xFF252525),
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete!();
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ];
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (comment.userPhoto.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.white12,
        backgroundImage: NetworkImage(
          comment.userPhoto,
        ),
      );
    }

    final firstLetter = comment.username.trim().isNotEmpty
        ? comment.username.trim()[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFFF2D55),
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
