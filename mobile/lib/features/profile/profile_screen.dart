import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // লাইট মোড ব্যাকগ্রাউন্ড
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.black),
          onPressed: () {},
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Golam Mostofa',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.black),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // Top Section: Name/Stats on Left, Profile Picture on Right
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Side: Stats & Bio Button Area
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '@golam.mostofa8403',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 15),
                              // Stats: অনুসরণ করছেন, অনুসরণকারী, লাইক
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatItem('0', 'অনুসরণ করছেন'),
                                  _buildStatItem('0', 'অনুসরণকারী'),
                                  _buildStatItem('2', 'লাইক'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Right Side: Profile Picture with Floating Bubble & Add Icon
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Speech bubble on top right (যেমন ছবিতে আছে)
                            Positioned(
                              top: -35,
                              right: -10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.3),
                                      blurRadius: 5,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'ফিসফিস,\nফিসফিস',
                                  style: TextStyle(fontSize: 10, color: Colors.black54),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            // Profile Avatar
                            const CircleAvatar(
                              radius: 40,
                              backgroundColor: Color(0xFF00897B),
                              child: Text(
                                'G',
                                style: TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Plus Icon Button
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.cyan,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // জীবন বৃত্তান্ত যোগ করুন Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        minimumSize: const Size(double.infinity, 40),
                        backgroundColor: Colors.grey.shade100,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.black, size: 18),
                          SizedBox(width: 5),
                          Text(
                            'জীবন বৃত্তান্ত যোগ করুন',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
            // Tab Bar with Icons (Grid, Lock, Repost, Bookmark, Heart)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.black,
                  indicatorWeight: 2,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(icon: Icon(Icons.menu_rounded, size: 22)),
                    Tab(icon: Icon(Icons.lock_outline, size: 22)),
                    Tab(icon: Icon(Icons.repeat, size: 22)),
                    Tab(icon: Icon(Icons.bookmark_border, size: 22)),
                    Tab(icon: Icon(Icons.favorite_border, size: 22)),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildVideoGrid(),
            const Center(child: Text('লকড ভিডিও')),
            const Center(child: Text('রিপোস্টসমূহ')),
            const Center(child: Text('সেভ করা ভিডিও')),
            const Center(child: Text('লাইক করা ভিডিও')),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      itemCount: 2, // ভিডিওর সংখ্যা
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 1.5,
        mainAxisSpacing: 1.5,
      ),
      itemBuilder: (context, index) {
        return Container(
          color: Colors.grey.shade200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black87),
              Positioned(
                bottom: 6,
                left: 6,
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                    const SizedBox(width: 2),
                    Text(
                      index == 0 ? '38' : '21',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
