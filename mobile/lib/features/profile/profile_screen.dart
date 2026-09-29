
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Golam Mostofa',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ১. প্রোফাইল পিকচার (টিকটক স্টাইল গ্র্যাডিয়ান্ট বর্ডার সহ)
            Center(
              child: Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.cyan, Colors.pink, Colors.purple],
                  ),
                ),
                child: const CircleAvatar(
                  backgroundColor: Color(0xFF1E1E1E),
                  child: Icon(Icons.person, size: 55, color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ২. ইউজারনেম (সেন্টার অ্যালাইনড)
            const Text(
              '@golammostofa32456',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 18),

            // ৩. স্ট্যাটাস কাউন্টার (Following, Followers, Likes)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatItem('9', 'Following'),
                _buildDivider(),
                _buildStatItem('0', 'Followers'),
                _buildDivider(),
                _buildStatItem('0', 'Likes'),
              ],
            ),

            const SizedBox(height: 18),

            // ৪. এডিট প্রোফাইল বাটন (টিকটক স্টাইল)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    // Navigate to Edit Profile Screen
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade800),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                    backgroundColor: const Color(0xFF1A1A1A),
                  ),
                  child: const Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade800),
                    borderRadius: BorderRadius.circular(4),
                    color: const Color(0xFF1A1A1A),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.bookmark_border, color: Colors.white, size: 20),
                    onPressed: () {},
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ৫. বায়ো (Bio)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Sirajgonj sadar sirajgonj',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(color: Colors.white12, height: 1),

            // ৬. গ্রিড ট্যাব আইকনসমূহ (Videos, Liked Videos)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white, width: 2)),
                    ),
                    child: const Icon(Icons.grid_on, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: const Icon(Icons.favorite_border, color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: const Icon(Icons.lock_outline, color: Colors.grey),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 60),

            // ৭. নো ভিডিও স্টেট (Empty State)
            Column(
              children: const [
                Icon(Icons.video_collection_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'আপনার এখনো কোনো ভিডিও নেই',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // কাউন্টার আইটেম তৈরি করার হেল্পার
  static Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  // ডিভাইডার তৈরি করার হেল্পার
  static Widget _buildDivider() {
    return Container(
      height: 14,
      width: 1,
      color: Colors.grey.shade800,
      margin: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
