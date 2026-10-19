
import 'package:flutter/material.dart';
import 'chat_screen.dart';
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _showBanner = true;
  bool _online = true;
  final Set<String> _following = <String>{};
  final Set<String> _dismissed = <String>{};

  static const Color _pink = Color(0xFFFE2C55);
  static const Color _blue = Color(0xFF25B7E8);
  static const Color _text = Color(0xFF161823);
  static const Color _muted = Color(0xFF8A8B91);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _text,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 58,
        leading: IconButton(
          tooltip: 'বন্ধু যোগ করুন',
          icon: const Icon(
            Icons.group_add_outlined,
            color: Colors.black,
            size: 27,
          ),
          onPressed: () => _showMessage('বন্ধু খোঁজার সুবিধা শিগগিরই আসছে'),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ইনবক্স',
              style: TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() => _online = !_online);
                _showMessage(
                  _online ? 'অনলাইন স্ট্যাটাস চালু' : 'অনলাইন স্ট্যাটাস বন্ধ',
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _online ? const Color(0xFF25C76A) : _muted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'খুঁজুন',
            icon: const Icon(Icons.search, color: Colors.black, size: 29),
            onPressed: () => _showSearchDialog(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (_showBanner)
            Container(
              margin: const EdgeInsets.only(top: 5, bottom: 8),
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              color: const Color(0xFFF3F3F3),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 29,
                    backgroundColor: _blue,
                    child: Icon(
                      Icons.people_alt,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'নতুন অনুসরণকারীরা স্থানান্তরিত হয়েছে',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _text,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'কার্যকলাপে এটি খুঁজে পান',
                          style: TextStyle(fontSize: 13, color: _text),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'বন্ধ করুন',
                    onPressed: () => setState(() => _showBanner = false),
                    icon: const Icon(
                      Icons.close,
                      size: 21,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          _notificationItem(
            id: 'activity',
            icon: Icons.bolt,
            color: _pink,
            title: 'কার্যকলাপ ও নতুন অনুসরণকারী',
            subtitle: 'লাইক, মন্তব্য ও নতুন অনুসরণকারীর আপডেট',
            onTap: () => _showMessage('কার্যকলাপের তালিকা শিগগিরই যুক্ত হবে'),
          ),
          _notificationItem(
            id: 'system',
            icon: Icons.inbox_rounded,
            color: const Color(0xFF15183D),
            title: 'সিস্টেমের নোটিফিকেশন',
            subtitle: 'PALOK-এর গুরুত্বপূর্ণ আপডেট এখানে দেখা যাবে',
            time: 'এখন',
            unread: true,
            onTap: () => _showMessage('সিস্টেম নোটিফিকেশন খুলছে'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 22, 16, 8),
            child: Row(
              children: [
                Text(
                  'সুপারিশকৃত অ্যাকাউন্ট',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                SizedBox(width: 5),
                Icon(Icons.info_outline, size: 15, color: Colors.black45),
              ],
            ),
          ),
          _suggestedUser(
            id: 'user_1',
            name: 'gaminggrils8',
            subtitle: 'আপনি চিনতে পারেন এমন লোকজন',
            avatarColor: const Color(0xFF8D786A),
            initial: 'G',
          ),
          _suggestedUser(
            id: 'user_2',
            name: 'আফিকা',
            subtitle: 'আপনি চিনতে পারেন এমন লোকজন',
            avatarColor: const Color(0xFFE7A6B5),
            initial: 'আ',
          ),
          _suggestedUser(
            id: 'user_3',
            name: 'Tanisha Islam',
            subtitle: 'আপনার জন্য সুপারিশ করা হয়েছে',
            avatarColor: const Color(0xFF75A6A0),
            initial: 'T',
          ),
          _suggestedUser(
            id: 'user_4',
            name: 'PALOK User',
            subtitle: 'নতুন বন্ধু খুঁজে নিন',
            avatarColor: const Color(0xFF8E9BDB),
            initial: 'P',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _notificationItem({
    required String id,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? time,
    bool unread = false,
  }) {
    if (_dismissed.contains(id)) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            CircleAvatar(
              radius: 29,
              backgroundColor: color,
              child: Icon(icon, color: Colors.white, size: 29),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _muted),
                  ),
                ],
              ),
            ),
            if (time != null) ...[
              const SizedBox(width: 5),
              Text(
                time,
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ],
            if (unread) ...[
              const SizedBox(width: 8),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: _pink,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _suggestedUser({
    required String id,
    required String name,
    required String subtitle,
    required Color avatarColor,
    required String initial,
  }) {
    if (_dismissed.contains(id)) return const SizedBox.shrink();

    final isFollowing = _following.contains(id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: avatarColor,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  if (isFollowing) {
                    _following.remove(id);
                  } else {
                    _following.add(id);
                  }
                });
                _showMessage(
                  isFollowing ? '$name-কে আনফলো করা হয়েছে' : '$name-কে অনুসরণ করা হয়েছে',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isFollowing ? const Color(0xFFF1F1F2) : _pink,
                foregroundColor: isFollowing ? _text : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                isFollowing ? 'অনুসরণ করছেন' : 'অনুসরণ করুন',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'সরিয়ে দিন',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _dismissed.add(id)),
            icon: const Icon(Icons.close, color: Colors.black38, size: 20),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'ইনবক্সে খুঁজুন',
          style: TextStyle(color: Colors.black),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(
            hintText: 'নাম লিখুন',
            hintStyle: TextStyle(color: Colors.black45),
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('বন্ধ করুন'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final query = controller.text.trim();
              if (query.isNotEmpty) {
                _showMessage('"$query" অনুসন্ধান করতে মেসেজ সার্চ যুক্ত করতে হবে');
              }
            },
            child: const Text('খুঁজুন'),
          ),
        ],
      ),
    );
  }
}
