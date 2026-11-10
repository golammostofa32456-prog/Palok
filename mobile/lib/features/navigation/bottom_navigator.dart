import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

class BottomNavigator extends StatelessWidget {
  const BottomNavigator({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.pink,
    required this.cyan,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Color pink;
  final Color cyan;

  @override
  Widget build(BuildContext context) {
    // Positioned অবশ্যই সবার উপরে থাকতে হবে (Stack এর সরাসরি সন্তান),
    // তাই ভাষা বদলের LanguageBuilder ভেতরে বসানো হয়েছে।
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          height: 78,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black87,
                Colors.black54,
                Colors.transparent,
              ],
            ),
          ),
          child: LanguageBuilder(
            builder: (context) => Row(
              children: [
                Expanded(
                  child: _item(
                    Icons.home_rounded,
                    tr('h_nav_home'),
                    0,
                  ),
                ),
                Expanded(
                  child: _item(
                    Icons.people_alt_outlined,
                    tr('h_nav_friends'),
                    1,
                  ),
                ),
                SizedBox(
                  width: 92,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => onSelect(2),
                      child: Container(
                        width: 72,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cyan, pink],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: pink.withOpacity(0.20),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _item(
                    Icons.chat_bubble_outline_rounded,
                    tr('h_nav_inbox'),
                    3,
                  ),
                ),
                Expanded(
                  child: _item(
                    Icons.person_outline_rounded,
                    tr('h_nav_profile'),
                    4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(
    IconData icon,
    String label,
    int index,
  ) {
    final selected = selectedIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: selected ? Colors.white : Colors.white54,
            size: 24,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
