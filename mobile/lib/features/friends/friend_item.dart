import 'package:flutter/material.dart';

import 'friend_model.dart';

class FriendItem extends StatelessWidget {
  const FriendItem({
    super.key,
    required this.friend,
    required this.onFollowTap,
  });

  final FriendModel friend;
  final VoidCallback onFollowTap;

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }

    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }

    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final name = friend.displayName.isNotEmpty
        ? friend.displayName
        : friend.username.isNotEmpty
            ? friend.username
            : 'PALOK User';

    final username = friend.username.isNotEmpty
        ? '@${friend.username.replaceFirst('@', '')}'
        : '@user';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 7,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.cyan,
                  Colors.pinkAccent,
                ],
              ),
            ),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF222222),
              backgroundImage: friend.photoUrl.isNotEmpty
                  ? NetworkImage(friend.photoUrl)
                  : null,
              child: friend.photoUrl.isEmpty
                  ? const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 28,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$username • ${_formatCount(friend.followersCount)} followers',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onFollowTap,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: friend.isFollowing
                    ? Colors.grey.shade800
                    : Colors.redAccent,
              ),
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
            ),
            child: Text(
              friend.isFollowing ? 'Following' : 'Follow',
              style: TextStyle(
                color: friend.isFollowing
                    ? Colors.white
                    : Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
