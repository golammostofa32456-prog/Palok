
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  static const Color _text = Colors.white;
  static const Color _muted = Color(0xFFB0B0B8);
  static const Color _background = Colors.black;
  static const Color _surface = Color(0xFF171717);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _myId => _auth.currentUser?.uid ?? '';

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _surface,
        ),
      );
  }

  String _userName(Map<String, dynamic> data) {
    return (data['username'] ??
            data['displayName'] ??
            data['name'] ??
            'PALOK User')
        .toString();
  }

  String _userPhoto(Map<String, dynamic> data) {
    return (data['profileImage'] ??
            data['photoURL'] ??
            data['photoUrl'] ??
            '')
        .toString();
  }

  Future<void> _openChatWithUser(
    String peerId,
    String peerName,
    String? peerPhotoUrl,
  ) async {
    if (_myId.isEmpty) {
      _showMessage('চ্যাট করতে আগে Sign In করুন।');
      return;
    }

    if (peerId.isEmpty || peerId == _myId) {
      _showMessage('নিজের সঙ্গে চ্যাট শুরু করা যাবে না।');
      return;
    }

    try {
      final userDoc = await _db.collection('users').doc(peerId).get();

      if (!mounted) return;

      if (!userDoc.exists) {
        _showMessage('ব্যবহারকারীর অ্যাকাউন্ট পাওয়া যায়নি।');
        return;
      }

      final data = userDoc.data() ?? {};
      final name = _userName(data);
      final photo = _userPhoto(data).isNotEmpty
          ? _userPhoto(data)
          : (peerPhotoUrl ?? '');

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            peerId: peerId,
            peerName: name.isEmpty ? peerName : name,
            peerPhotoUrl: photo,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          'চ্যাট খোলা যায়নি। ইন্টারনেট ও Firebase Rules পরীক্ষা করুন।',
        );
      }
      debugPrint('Open chat error: $e');
    }
  }

  void _showSearchDialog() {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = controller.text.trim().toLowerCase();

            return AlertDialog(
              backgroundColor: _surface,
              title: const Text(
                'ব্যবহারকারী খুঁজুন',
                style: TextStyle(color: _text),
              ),
              content: SizedBox(
                width: 360,
                height: 390,
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(color: _text),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: 'নাম লিখুন...',
                        hintStyle: const TextStyle(color: _muted),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: _muted,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFF444444),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: _pink),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>>(
                        stream: _db.collection('users').limit(100).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text(
                                'ব্যবহারকারী লোড করা যায়নি।',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _text),
                              ),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: _pink,
                              ),
                            );
                          }

                          final users = snapshot.data!.docs.where((doc) {
                            if (doc.id == _myId) return false;

                            final data = doc.data();
                            final name = _userName(data).toLowerCase();
                            final username = (data['username'] ?? '')
                                .toString()
                                .toLowerCase();

                            return query.isEmpty ||
                                name.contains(query) ||
                                username.contains(query);
                          }).toList();

                          if (users.isEmpty) {
                            return const Center(
                              child: Text(
                                'কোনো ব্যবহারকারী পাওয়া যায়নি।',
                                style: TextStyle(color: _muted),
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final doc = users[index];
                              final data = doc.data();
                              final name = _userName(data);
                              final photo = _userPhoto(data);

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: _avatar(name, photo, radius: 21),
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: _text),
                                ),
                                trailing: const Icon(
                                  Icons.chat_bubble_outline,
                                  color: _pink,
                                ),
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  _openChatWithUser(
                                    doc.id,
                                    name,
                                    photo,
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'বন্ধ করুন',
                    style: TextStyle(color: _pink),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  Widget _avatar(
    String name,
    String photo, {
    double radius = 29,
    Color background = _blue,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      backgroundImage: photo.trim().isNotEmpty
          ? NetworkImage(photo)
          : null,
      child: photo.trim().isEmpty
          ? Text(
              name.isNotEmpty ? name.characters.first : '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        surfaceTintColor: _background,
        elevation: 0,
        toolbarHeight: 58,
        leading: IconButton(
          tooltip: 'বন্ধু যোগ করুন',
          icon: const Icon(
            Icons.group_add_outlined,
            color: Colors.white,
            size: 27,
          ),
          onPressed: _showSearchDialog,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ইনবক্স',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() => _online = !_online);
                _showMessage(
                  _online
                      ? 'অনলাইন স্ট্যাটাস চালু'
                      : 'অনলাইন স্ট্যাটাস বন্ধ',
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _online
                            ? const Color(0xFF25C76A)
                            : _muted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: Colors.white70,
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
            tooltip: 'ব্যবহারকারী খুঁজুন',
            icon: const Icon(
              Icons.search,
              color: Colors.white,
              size: 29,
            ),
            onPressed: _showSearchDialog,
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
              color: _surface,
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
                          style: TextStyle(
                            fontSize: 13,
                            color: _muted,
                          ),
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
                      color: Colors.white70,
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
            onTap: () => _showMessage(
              'কার্যকলাপের নোটিফিকেশন এখনো সংযুক্ত করা হয়নি।',
            ),
          ),

          _notificationItem(
            id: 'system',
            icon: Icons.inbox_rounded,
            color: const Color(0xFF34365C),
            title: 'সিস্টেমের নোটিফিকেশন',
            subtitle: 'PALOK-এর গুরুত্বপূর্ণ আপডেট',
            time: 'এখন',
            unread: true,
            onTap: () => _showMessage(
              'সিস্টেম নোটিফিকেশন এখনো সংযুক্ত করা হয়নি।',
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(18, 22, 16, 8),
            child: Row(
              children: [
                Text(
                  'মেসেজ ও ব্যবহারকারী',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 5),
                Icon(
                  Icons.info_outline,
                  size: 15,
                  color: Colors.white54,
                ),
              ],
            ),
          ),

          _buildRecentChats(),

          const Padding(
            padding: EdgeInsets.fromLTRB(18, 22, 16, 8),
            child: Text(
              'সুপারিশকৃত অ্যাকাউন্ট',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),

          _buildSuggestedUsers(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRecentChats() {
    if (_myId.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'মেসেজ দেখতে আগে Sign In করুন।',
          style: TextStyle(color: _muted),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('chats')
          .where('participants', arrayContains: _myId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'চ্যাট লোড করা যায়নি। Firebase Rules পরীক্ষা করুন।',
              style: TextStyle(color: _muted),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Center(
              child: CircularProgressIndicator(color: _pink),
            ),
          );
        }

        final chats = snapshot.data!.docs.toList();

        chats.sort((a, b) {
          final aTime = a.data()['updatedAt'] as Timestamp?;
          final bTime = b.data()['updatedAt'] as Timestamp?;

          return (bTime?.millisecondsSinceEpoch ?? 0)
              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
        });

        if (chats.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              'এখনো কোনো চ্যাট নেই। সার্চ থেকে একজন ব্যবহারকারী বেছে মেসেজ দিন।',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          );
        }

        return Column(
          children: chats.map((chatDoc) {
            final data = chatDoc.data();
            final participants =
                List<String>.from(data['participants'] ?? []);

            final others = participants.where((id) => id != _myId).toList();

            if (others.isEmpty) return const SizedBox.shrink();

            final peerId = others.first;

            final names = Map<String, dynamic>.from(
              data['participantNames'] ?? {},
            );
            final photos = Map<String, dynamic>.from(
              data['participantPhotos'] ?? {},
            );
            final unread = Map<String, dynamic>.from(
              data['unreadCounts'] ?? {},
            );

            final name = (names[peerId] ?? 'PALOK User').toString();
            final photo = (photos[peerId] ?? '').toString();
            final lastMessage = (data['lastMessage'] ?? '').toString();
            final unreadCount = unread[_myId] is num
                ? (unread[_myId] as num).toInt()
                : 0;

            return ListTile(
              leading: _avatar(name, photo),
              title: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              subtitle: Text(
                lastMessage.isEmpty ? 'চ্যাট শুরু করুন' : lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted),
              ),
              trailing: unreadCount > 0
                  ? CircleAvatar(
                      radius: 12,
                      backgroundColor: _pink,
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.chat_bubble_outline,
                      color: _pink,
                    ),
              onTap: () => _openChatWithUser(peerId, name, photo),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSuggestedUsers() {
    if (_myId.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'ব্যবহারকারী দেখতে আগে Sign In করুন।',
          style: TextStyle(color: _muted),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('users').limit(100).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'ব্যবহারকারী লোড করা যায়নি। Firebase Rules পরীক্ষা করুন।',
              style: TextStyle(color: _muted),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Center(
              child: CircularProgressIndicator(color: _pink),
            ),
          );
        }

        final users = snapshot.data!.docs
            .where((doc) =>
                doc.id != _myId && !_dismissed.contains(doc.id))
            .toList();

        if (users.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'এখনো অন্য কোনো ব্যবহারকারী পাওয়া যায়নি।',
              style: TextStyle(color: _muted),
            ),
          );
        }

        return Column(
          children: users.map((doc) {
            final data = doc.data();
            final name = _userName(data);
            final photo = _userPhoto(data);
            final isFollowing = _following.contains(doc.id);

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  _avatar(name, photo),
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
                          (data['username'] ?? 'PALOK ব্যবহারকারী').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'মেসেজ পাঠান',
                    onPressed: () => _openChatWithUser(
                      doc.id,
                      name,
                      photo,
                    ),
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: _pink,
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (isFollowing) {
                            _following.remove(doc.id);
                          } else {
                            _following.add(doc.id);
                          }
                        });

                        _showMessage(
                          isFollowing
                              ? '$name-কে আনফলো করা হয়েছে'
                              : '$name-কে অনুসরণ করা হয়েছে',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isFollowing ? _surface : _pink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        isFollowing ? 'অনুসরণ করছেন' : 'অনুসরণ',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'সরিয়ে দিন',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() => _dismissed.add(doc.id));
                    },
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
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
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 11,
        ),
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: _muted,
                    ),
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
}
