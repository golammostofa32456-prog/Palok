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
        vertical: 9,
      ),
      child: Row(
        children: [
          // Profile avatar
          Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
                      size: 29,
                    )
                  : null,
            ),
          ),

          const SizedBox(width: 13),

          // User information
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  '${_formatCount(friend.followersCount)} followers',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Follow button
          SizedBox(
            height: 36,
            child: OutlinedButton(
              onPressed: onFollowTap,
              style: OutlinedButton.styleFrom(
                backgroundColor: friend.isFollowing
                    ? const Color(0xFF242424)
                    : Colors.redAccent,
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: friend.isFollowing
                      ? Colors.white24
                      : Colors.redAccent,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                ),
              ),
              child: Text(
                friend.isFollowing
                    ? 'অনুসরণ করা হচ্ছে'
                    : 'অনুসরণ করুন',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
