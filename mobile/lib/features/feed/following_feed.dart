import 'package:flutter/material.dart';

/// PALOK - Following Feed
///
/// এই widget-এর দায়িত্ব:
/// - যেসব user-কে follow করা হয়েছে তাদের ভিডিও filter করা
/// - Following feed-এর vertical PageView চালানো
/// - ভিডিও পরিবর্তনের callback HomeScreen-এ পাঠানো
///
/// Video UI এখনো HomeScreen-এর existing _buildVideoPage()
/// থেকে আসবে। তাই বর্তমান UI/design পরিবর্তন হবে না.
class FollowingFeed extends StatelessWidget {
  const FollowingFeed({
    super.key,
    required this.videos,
    required this.followingIds,
    required this.pageController,
    required this.onPageChanged,
    required this.itemBuilder,
    required this.emptyBuilder,
  });

  /// HomeScreen-এর সম্পূর্ণ video list।
  final List<dynamic> videos;

  /// যেসব user-কে current user follow করেছে তাদের user ID।
  final Set<String> followingIds;

  /// HomeScreen-এর existing PageController।
  final PageController pageController;

  /// Page পরিবর্তন হলে HomeScreen-এ callback যাবে।
  final void Function(
    int index,
    List<dynamic> feed,
  ) onPageChanged;

  /// প্রতিটি video page-এর existing UI।
  final Widget Function(
    BuildContext context,
    int index,
    List<dynamic> feed,
  ) itemBuilder;

  /// Following list খালি হলে existing empty UI দেখাবে।
  final Widget Function() emptyBuilder;

  List<dynamic> _buildFollowingFeed() {
    return videos.where((video) {
      try {
        return followingIds.contains(
          video.userId as String,
        );
      } catch (_) {
        return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final feed = _buildFollowingFeed();

    if (feed.isEmpty) {
      return emptyBuilder();
    }

    return PageView.builder(
      controller: pageController,
      scrollDirection: Axis.vertical,
      physics: const PageScrollPhysics(),
      pageSnapping: true,
      allowImplicitScrolling: true,
      itemCount: feed.length,
      onPageChanged: (index) {
        onPageChanged(
          index,
          feed,
        );
      },
      itemBuilder: (context, index) {
        return itemBuilder(
          context,
          index,
          feed,
        );
      },
    );
  }
}
