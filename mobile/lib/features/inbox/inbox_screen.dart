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
          icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.black, size: 26),
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
            icon: const Icon(Icons.search, color: Colors.black, size: 26),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          // ১. ওপরে বন্ধুদের স্টোরি/অ্যাক্টিভিটি সেকশন
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

          // ২. কার্যকলাপ ও সিস্টেম নোটিফিকেশন সেকশন
          _buildNotificationItem(
            icon: Icons.flash_on,
            iconBgColor: const Color(0xFFFF2C55),
            title: 'কার্যকলাপ ও নতুন অনুসারী',
            subtitle: 'সাম্প্রতিক নোটিফিকেশন ও মেসেজ...',
            onTap: () {},
          ),
          _buildNotificationItem(
            icon: Icons.inbox,
            iconBgColor: const Color(0xFF161823),
            title: 'সিস্টেমের নোটিফিকেশন',
            subtitle: 'TikTok: নতুন আপডেট ও নোটিশ...',
            time: '৭ঘন্টা',
            hasRedDot: true,
            onTap: () {},
          ),

          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black54,
            ),
            child: Text('সুপারিশকৃত অ্যাকাউন্ট'),
          ),

          // ৩. ডেমো ইউজার মেসেজ/পরামর্শ তালিকা
          _buildUserMessageItem(
            name: 'এমন একজনকে ভালোবাসো...',
            subtitle: 'আপনাকে অনুসরণ করছে',
            showFollowBtn: true,
          ),
          _buildUserMessageItem(
            name: 'মেসি লাভার',
            subtitle: 'মেসি লাভার কে হাই বলুন',
            showFollowBtn: true,
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
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
        radius: 24,
        backgroundColor: iconBgColor,
        child: Icon(icon, color: Colors.white, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (time != null) Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
        radius: 24,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: showFollowBtn
          ? TextButton(
              onPressed: () {},
              child: const Text('+ অনুসরণ করুন', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            )
          : const Icon(Icons.waving_hand, color: Colors.amber),
    );
  }
}
