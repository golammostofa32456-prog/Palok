import 'package:flutter/material.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Friends',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // টিকটক স্টাইল 'Add/Search Friends' বাটন
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white, size: 24),
            onPressed: () {
              // বন্ধুদের সার্চ করার স্ক্রিনে যাওয়ার লজিক
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            // ১. সার্চ কনটাক্টস এবং সামাজিক যোগাযোগ বাটন (Find Friends)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.contacts_rounded, color: Colors.redAccent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAlignment.start,
                        children: const [
                          Text(
                            'Find contacts',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'আপনার পরিচিত বন্ধুদের খুঁজুন',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Find', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ২. Following সেকশন
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Following',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            // ফলোয়িং ইউজার লিস্ট (টিকটক স্টাইল লিস্ট ভিউ)
            _buildUserListItem(
              username: '@palok_creator',
              subtext: '11.7K likes',
              isFollowing: true,
            ),
            _buildUserListItem(
              username: '@nature_palok',
              subtext: '8.5K likes',
              isFollowing: true,
            ),
            _buildUserListItem(
              username: '@palok_video',
              subtext: '4.2K likes',
              isFollowing: true,
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),

            // ৩. Suggested Creators / Friends
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Suggested creators',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            // ৪. নো সাজেস্টেড ক্রিয়েটর এম্পটি স্টেট
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Column(
                  children: const [
                    Icon(Icons.group_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'নতুন কোনো creator পাওয়া যায়নি',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ইউজার লিস্ট আইটেম হেল্পার (টিকটক রেডিয়েন্ট পিকচার সহ)
  Widget _buildUserListItem({
    required String username,
    required String subtext,
    required bool isFollowing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // গ্র্যাডিয়ান্ট অবতার বর্ডার
          Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.cyan, Colors.pinkAccent],
              ),
            ),
            child: const CircleAvatar(
              backgroundColor: Color(0xFF222222),
              child: Icon(Icons.person, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade800),
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

