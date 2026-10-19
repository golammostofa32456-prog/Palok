import 'package:flutter/material.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.black, size: 24),
          onPressed: () {},
        ),
        title: const Text(
          'ইনবক্স',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black, size: 24),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          // ১. ওপরে স্টোরি এবং অ্যাক্টিভিটি সেকশন (Horizontal List)
          SizedBox(
            height: 105,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                _buildStoryItem(
                  icon: Icons.add,
                  label: 'তৈরি করুন',
                  isAdd: true,
                ),
                _buildStoryItem(
                  icon: Icons.lock_outline,
                  label: 'এই দিনে',
                  isLock: true,
                ),
                _buildUserStoryItem('It\'s_E.O', 'https://via.placeholder.com/150'),
                _buildUserStoryItem('MOHON', 'https://via.placeholder.com/150'),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // ২. নতুন অনুসারী নোটিশ ব্যানার
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.group, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'নতুন অনুসারীরা স্থানান্তরিত হয়েছে।',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'কার্যকলাপে এটি খুঁজে পান',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // ৩. অ্যাক্টিভিটি ও সিস্টেম নোটিফিকেশন তালিকা
          _buildNotificationItem(
            icon: Icons.flash_on,
            iconBgColor: const Color(0xFFFF2C55),
            title: 'কার্যকলাপ ও নতুন অনুসারী',
            subtitle: 'সাম্প্রতিক লাইক, কমেন্ট ও ফলোয়ার...',
            onTap: () {},
          ),
          _buildNotificationItem(
            icon: Icons.inbox,
            iconBgColor: const Color(0xFF161823),
            title: 'সিস্টেমের নোটিফিকেশন',
            subtitle: 'TikTok: ভিজ্যুয়াল অনুসন্ধান আপডেট...',
            time: '১৬ঘন্টা',
            hasRedDot: true,
            onTap: () {},
          ),

          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'সুপারিশকৃত অ্যাকাউন্ট',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),

          // ৪. ইউজার রিকমেন্ডেশন বা ফলো লিস্ট
          _buildUserMessageItem(
            name: 'এমন একজনকে ভালোবাসো...',
            subtitle: 'আপনাকে অনুসরণ করছে',
            showFollowBtn: true,
          ),
          _buildUserMessageItem(
            name: 'gaminggrils8',
            subtitle: 'gaminggrils8 কে হাই বলুন',
            showFollowBtn: false,
          ),
        ],
      ),
    );
  }

  // স্টোরি আইটেম উইজেট
  Widget _buildStoryItem({required IconData icon, required String label, bool isAdd = false, bool isLock = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: isLock ? Colors.grey.shade300 : const Color(0xFF009688),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              if (isAdd)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ইউজার স্টোরি উইজেট
  Widget _buildUserStoryItem(String name, String imgUrl) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundImage: NetworkImage(imgUrl),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // নোটিফিকেশন রো উইজেট
  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    String? time,
    bool hasRedDot = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: iconBgColor,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (time != null) Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          if (hasRedDot) ...[
            const SizedBox(width: 6),
            const CircleAvatar(radius: 4, backgroundColor: Colors.red),
          ],
        ],
      ),
    );
  }

  // ইউজার মেসেজ/ফলো আইটেম উইজেট
  Widget _buildUserMessageItem({required String name, required String subtitle, bool showFollowBtn = false}) {
    return ListTile(
      leading: const CircleAvatar(
        radius: 22,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white, size: 20),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: showFollowBtn
          ? TextButton(
              onPressed: () {},
              child: const Text('+ অনুসরণ করুন', style: TextStyle(color: Color(0xFFFF2C55), fontWeight: FontWeight.bold, fontSize: 12)),
            )
          : const Icon(Icons.waving_hand, color: Colors.amber, size: 22),
    );
  }
}
