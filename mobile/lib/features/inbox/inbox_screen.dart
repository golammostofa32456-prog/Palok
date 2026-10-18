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
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
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
          const SizedBox(height: 10),

          // 1. Top Story / Active Users Horizontal Bar
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildStoryItem('তৈরি করুন', true, false),
                _buildStoryItem('এই দিনে', false, true),
                _buildStoryItem("It's_E.O", false, false),
                _buildStoryItem('MD FORID', false, false),
              ],
            ),
          ),

          const Divider(height: 1),

          // 2. Main Notification Categories
          _buildNotificationCategory(
            icon: Icons.flash_on,
            iconColor: Colors.pinkAccent,
            title: 'কার্যকলাপ ও নতুন অনুসরণকারী',
            subtitle: 'লাইক, কমেন্ট ও নতুন ফলোয়ারদের অ্যাক্টিভিটি',
            onTap: () {},
          ),
          _buildNotificationCategory(
            icon: Icons.notifications_active,
            iconColor: Colors.blueAccent,
            title: 'সিস্টেমের নোটিফিকেশন',
            subtitle: 'PALOK: প্ল্যাটফর্ম সংক্রান্ত নোটিফিকেশন',
            onTap: () {},
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'মেসেজ ও সাজেস্টেড',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),

          // 3. User Messages / Suggested List
          _buildUserMessageTile(
            name: 'এমন একজনকে ভা...',
            message: 'এমন একজনকে ভালোবাসো বাজার চে...',
            time: 'নতুন',
            isFollowBtn: true,
          ),
          _buildUserMessageTile(
            name: 'মেসি লাভার',
            message: 'মেসি লাভার কে হাই বলুন',
            time: 'গতকাল',
            isFollowBtn: true,
          ),
          _buildUserMessageTile(
            name: 'litonsanaul',
            message: 'litonsanaul কে হাই বলুন',
            time: '২ দিন আগে',
            isFollowBtn: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStoryItem(String label, String isCreate, bool isLock) {
    return Container(
      margin: const EdgeInsets.only(right: 15),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.cyan, width: 2),
                  color: Colors.teal,
                ),
                child: Center(
                  child: isLock
                      ? const Icon(Icons.lock, color: Colors.white)
                      : Text(
                          label[0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                ),
              ),
              if (isCreate)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.cyan,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 65,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCategory({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: iconColor,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
    );
  }

  Widget _buildUserMessageTile({
    required String name,
    required String message,
    required String time,
    bool isFollowBtn = false,
  }) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade300,
        child: Text(
          name[0],
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: isFollowBtn
          ? ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFE2C55),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '+ অনুসরণ করুন',
                style: TextStyle(fontSize: 11, color: Colors.white),
              ),
            )
          : Text(
              time,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
    );
  }
}
