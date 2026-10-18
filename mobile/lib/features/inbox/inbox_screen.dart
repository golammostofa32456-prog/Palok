import 'package:flutter/material.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.person_add_outlined, color: Colors.black),
          onPressed: () {},
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ইনবক্স',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),

          // 1. Stories / Active Users Horizontal List
          SizedBox(
            height: 95,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildStoryAvatar('তৈরি করুন', isAdd: true, subText: 'কী অবস্থা?'),
                _buildStoryAvatar('এই দিনে', isLock: true),
                _buildStoryAvatar('MD FORID', name: 'MD FORID'),
                _buildStoryAvatar("It's_E.O", name: "It's_E.O"),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.black12),

          // 2. Banner Notification
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.blue,
                  radius: 20,
                  child: Icon(Icons.group, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('নতুন অনুসরণকারীরা স্থানান্তরিত হয়েছে।', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('কার্যকলাপে এটি খুঁজে পান', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: () {}),
              ],
            ),
          ),

          // 3. Activity Categories
          _buildActivityTile(
            icon: Icons.bolt,
            iconBg: Colors.pinkAccent,
            title: 'কার্যকলাপ ও নতুন অনুসরণকারী',
            subtitle: 'মন্তব্য করেছেন...',
          ),
          _buildActivityTile(
            icon: Icons.notifications,
            iconBg: const Color(0xFF1D263B),
            title: 'সিস্টেমের নোটিফিকেশন',
            subtitle: 'TikTok: ভিজ্যুয়াল অনুসন্ধান...',
            time: '৫ঘণ্টা',
          ),

          // 4. Friend / User List Section
          _buildUserTile('এমন একজনকে ভা...', 'এমন একজনকে ভালোবাসো বাজার চে...', hasWave: true),
          _buildUserTile('মেসি লাভার', 'মেসি লাভার কে হাই বলুন', hasWave: true),
          _buildUserTile('litonsanaul', 'litonsanaul কে হাই বলুন', hasWave: true),

          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('সুপারিশকৃত অ্যাকাউন্ট', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryAvatar(String label, {bool isAdd = false, bool isLock = false, String? name, String? subText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: isAdd ? Colors.teal : Colors.cyan, width: 2),
                ),
                child: CircleAvatar(
                  backgroundColor: isAdd ? Colors.teal : Colors.grey.shade300,
                  child: isLock
                      ? const Icon(Icons.lock, color: Colors.white)
                      : Text(label[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              if (isAdd)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 65,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile({required IconData icon, required Color iconBg, required String title, required String subtitle, String? time}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconBg,
        radius: 22,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (time != null) Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Container(margin: const EdgeInsets.only(left: 6), width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
        ],
      ),
    );
  }

  Widget _buildUserTile(String name, String subText, {bool hasWave = false}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade300,
        radius: 24,
        child: Text(name[0], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      title: Row(
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 4),
          const Text('+ অনুসরণ করুন', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
      subtitle: Text(subText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: hasWave ? const Icon(Icons.back_hand, color: Colors.amber, size: 22) : null,
    );
  }
}
