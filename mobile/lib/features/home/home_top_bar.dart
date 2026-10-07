import 'package:flutter/material.dart';

class HomeTopBar extends StatelessWidget {
  final Animation<double> logoOpacity;
  final Animation<double> logoScale;

  final int topIndex;

  final VoidCallback onForYou;
  final VoidCallback onFollowing;
  final VoidCallback onSearch;

  final Color pink;
  final Color cyan;

  const HomeTopBar({
    super.key,
    required this.logoOpacity,
    required this.logoScale,
    required this.topIndex,
    required this.onForYou,
    required this.onFollowing,
    required this.onSearch,
    required this.pink,
    required this.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            12,
            10,
            10,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([
                  logoOpacity,
                  logoScale,
                ]),
                builder: (_, __) {
                  return Opacity(
                    opacity: logoOpacity.value,
                    child: Transform.scale(
                      scale: logoScale.value,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              pink,
                              cyan,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                              BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: pink.withOpacity(0.35),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'P',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const Spacer(),

              _TopTab(
                title: 'For You',
                selected: topIndex == 0,
                onTap: onForYou,
              ),

              const SizedBox(width: 18),

              _TopTab(
                title: 'Following',
                selected: topIndex == 1,
                onTap: onFollowing,
              ),

              const SizedBox(width: 8),

              IconButton(
                onPressed: onSearch,
                icon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _TopTab({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white60,
                fontSize: 15,
                fontWeight: selected
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(
                milliseconds: 180,
              ),
              width: selected ? 24 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
