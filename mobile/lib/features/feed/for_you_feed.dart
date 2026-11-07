import 'package:flutter/material.dart';

/// PALOK - For You Feed
///
/// এই widget-এর দায়িত্ব:
/// - For You feed-এর vertical PageView চালানো
/// - ভিডিও swipe/navigation handle করার সুযোগ দেওয়া
/// - বর্তমান HomeScreen-এর video UI পরিবর্তন না করা
///
/// Video UI এখনো HomeScreen-এর itemBuilder থেকে আসবে।
class ForYouFeed extends StatelessWidget {
  const ForYouFeed({
    super.key,
    required this.videos,
    required this.pageController,
    required this.onPageChanged,
    required this.itemBuilder,
  });

  /// HomeScreen-এর মূল video list।
  ///
  /// এখানে dynamic রাখা হয়েছে যাতে বর্তমানে HomeScreen-এর
  /// VideoPost model আলাদা করে সরাতে না হয়।
  final List<dynamic> videos;

  /// HomeScreen-এর existing PageController।
  final PageController pageController;

  /// User vertical swipe করলে এই callback call হবে।
  final ValueChanged<int> onPageChanged;

  /// প্রতিটি video page-এর existing UI HomeScreen থেকে আসবে।
  final Widget Function(
    BuildContext context,
    int index,
  ) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return const SizedBox.shrink();
    }

    return PageView.builder(
      controller: pageController,
      scrollDirection: Axis.vertical,
      physics: const PageScrollPhysics(),
      pageSnapping: true,
      // ভিডিও প্রিলোড HomeScreen নিজে সামলায়, তাই এখানে বন্ধ রাখা হলো।
      allowImplicitScrolling: false,
      itemCount: videos.length,
      onPageChanged: onPageChanged,
      itemBuilder: itemBuilder,
    );
  }
}
