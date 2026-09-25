import 'package:flutter/material.dart';

import '../video/video_card.dart';
import '../video/video_post.dart';
import 'home_controller.dart';

class HomeWidgets {
  HomeWidgets._();

  // ------------------------------------------------------------
  // VIDEO CARD
  // ------------------------------------------------------------

  static Widget videoCard({
    required VideoPost video,
    required HomeController controller,
    required int index,
    VoidCallback? onLike,
    VoidCallback? onComment,
    VoidCallback? onSave,
    VoidCallback? onShare,
    VoidCallback? onFollow,
    VoidCallback? onProfile,
  }) {
    return VideoCard(
      video: video,
      controller: controller.controllerFor(index),
      isLiked: controller.isLiked(video.id),
      isSaved: controller.isSaved(video.id),
      isFollowing: controller.isFollowing(video.ownerId),
      onLike: onLike,
      onComment: onComment,
      onSave: onSave,
      onShare: onShare,
      onFollow: onFollow,
      onProfile: onProfile,
    );
  }

  // ------------------------------------------------------------
  // LOADING
  // ------------------------------------------------------------

  static Widget loading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  // ------------------------------------------------------------
  // ERROR
  // ------------------------------------------------------------

  static Widget error({
    required String message,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('আবার চেষ্টা করুন'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY FEED
  // ------------------------------------------------------------

  static Widget emptyFeed() {
    return const Center(
      child: Text(
        'কোনো ভিডিও পাওয়া যায়নি',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TOP BAR
  // ------------------------------------------------------------

  static Widget topBar({
    required VoidCallback onSearch,
    VoidCallback? onFollowing,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        child: Row(
          children: [
            const Text(
              'PALOK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Spacer(),

            if (onFollowing != null)
              TextButton(
                onPressed: onFollowing,
                child: const Text(
                  'Following',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),

            IconButton(
              onPressed: onSearch,
              icon: const Icon(
                Icons.search,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SIMPLE ACTION BUTTON
  // ------------------------------------------------------------

  static Widget actionButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? label,
    bool active = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: active ? const Color(0xFFFF2D55) : Colors.white,
            size: 30,
          ),
        ),
        if (label != null)
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}
