Widget _buildBottomNavigation() {
  return Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(
              color: Colors.white12,
              width: 0.6,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _bottomItem(
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
              ),
            ),
            Expanded(
              child: _bottomItem(
                icon: Icons.people_outline_rounded,
                label: 'Friends',
                index: 1,
              ),
            ),

            // TikTok Style Center + Button
            SizedBox(
              width: 78,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    unawaited(_selectBottom(2));
                  },
                  child: Container(
                    width: 48,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF00F2EA),
                          Color(0xFFFF0050),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7.5),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: _bottomItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Inbox',
                index: 3,
              ),
            ),
            Expanded(
              child: _bottomItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                index: 4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _bottomItem({
  required IconData icon,
  required String label,
  required int index,
}) {
  final selected = _bottomIndex == index;

  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      unawaited(_selectBottom(index));
    },
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: selected ? Colors.white : Colors.white54,
          size: 26,
        ),
        const SizedBox(height: 2),
        Text(
          label,
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
