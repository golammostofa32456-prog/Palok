import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';

// ───────────────────────── Shared style & helpers ─────────────────────────

const Color _pink = Color(0xFFFE2C55);
const Color _blue = Color(0xFF25B7E8);
const Color _text = Colors.white;
const Color _muted = Color(0xFFB0B0B8);
const Color _background = Colors.black;
const Color _surface = Color(0xFF171717);

String _userName(Map<String, dynamic> d) {
  return (d['username'] ?? d['displayName'] ?? d['name'] ?? 'PALOK User')
      .toString();
}

String _userPhoto(Map<String, dynamic> d) {
  return (d['profileImage'] ?? d['photoURL'] ?? d['photoUrl'] ?? '')
      .toString();
}

String _bn(String s) {
  const en = '0123456789';
  const bn = '০১২৩৪৫৬৭৮৯';
  var out = s;
  for (var i = 0; i < en.length; i++) {
    out = out.replaceAll(en[i], bn[i]);
  }
  return out;
}

String _timeAgo(Timestamp? ts) {
  if (ts == null) return 'এখন';
  final date = ts.toDate();
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'এখন';
  if (diff.inMinutes < 60) return '${_bn('${diff.inMinutes}')} মিনিট আগে';
  if (diff.inHours < 24) return '${_bn('${diff.inHours}')} ঘণ্টা আগে';
  if (diff.inDays < 7) return '${_bn('${diff.inDays}')} দিন আগে';
  return _bn('${date.day}/${date.month}/${date.year}');
}

Widget _avatar(
  String name,
  String photo, {
  double radius = 29,
  Color background = _blue,
}) {
  final hasPhoto = photo.trim().isNotEmpty;
  return CircleAvatar(
    radius: radius,
    backgroundColor: background,
    backgroundImage: hasPhoto ? NetworkImage(photo) : null,
    child: hasPhoto
        ? null
        : Text(
            name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
            style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.8,
              fontWeight: FontWeight.bold,
            ),
          ),
  );
}

void _snack(BuildContext context, String message) {
  if (!context.mounted) return;
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

/// Follow / unfollow (updates both users' sub-collections).
Future<void> _setFollow(String peerId, bool follow) async {
  final me = FirebaseAuth.instance.currentUser;
  if (me == null || peerId.isEmpty || peerId == me.uid) return;

  final db = FirebaseFirestore.instance;
  final myFollowing = db
      .collection('users')
      .doc(me.uid)
      .collection('following')
      .doc(peerId);
  final theirFollowers = db
      .collection('users')
      .doc(peerId)
      .collection('followers')
      .doc(me.uid);

  final batch = db.batch();
  if (follow) {
    batch.set(myFollowing, {'createdAt': FieldValue.serverTimestamp()});
    batch.set(theirFollowers, {'createdAt': FieldValue.serverTimestamp()});
  } else {
    batch.delete(myFollowing);
    batch.delete(theirFollowers);
  }
  await batch.commit();

  if (follow) {
    try {
      await InboxNotifier.send(
        toUserId: peerId,
        type: 'follow',
        text: 'আপনাকে অনুসরণ করা শুরু করেছে',
      );
    } catch (e) {
      debugPrint('Follow notification error: $e');
    }
  }
}

/// অন্য জায়গা (লাইক/কমেন্ট কোড) থেকে ডাকুন:
/// InboxNotifier.send(toUserId: ownerId, type: 'like', text: 'আপনার ভিডিও লাইক করেছে');
/// type: 'like' | 'comment' | 'follow'
class InboxNotifier {
  static Future<void> send({
    required String toUserId,
    required String type,
    String text = '',
    String? videoId,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || toUserId.isEmpty || me.uid == toUserId) return;

    final db = FirebaseFirestore.instance;
    final meDoc = await db.collection('users').doc(me.uid).get();
    final d = meDoc.data() ?? {};

    final col =
        db.collection('users').doc(toUserId).collection('notifications');

    final data = <String, dynamic>{
      'type': type,
      'fromUserId': me.uid,
      'fromName': d.isEmpty ? (me.displayName ?? 'PALOK User') : _userName(d),
      'fromPhoto': d.isEmpty ? (me.photoURL ?? '') : _userPhoto(d),
      'text': text,
      'videoId': videoId ?? '',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (type == 'follow') {
      // একই ব্যক্তির বারবার ফলোতে ডুপ্লিকেট হবে না
      await col.doc('follow_${me.uid}').set(data);
    } else {
      await col.add(data);
    }
  }
}

// ───────────────────────────── Inbox screen ──────────────────────────────

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Set<String> _following = <String>{};
  final Set<String> _dismissed = <String>{};
  final Set<String> _sessionFollowed = <String>{};
  final Set<String> _busy = <String>{};

  bool _bannerHidden = false;
  bool _online = true;
  Timestamp? _systemSeenAt;

  final List<StreamSubscription<dynamic>> _subs = [];

  Stream<QuerySnapshot<Map<String, dynamic>>>? _chatsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _usersStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _notifStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _systemStream;

  String get _myId => _auth.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> get _myDoc =>
      _db.collection('users').doc(_myId);

  @override
  void initState() {
    super.initState();
    if (_myId.isEmpty) return;

    _chatsStream = _db
        .collection('chats')
        .where('participants', arrayContains: _myId)
        .snapshots();
    _usersStream = _db.collection('users').limit(100).snapshots();
    _notifStream = _myDoc
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
    _systemStream = _db
        .collection('system_notifications')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();

    _subs.add(_myDoc.snapshots().listen((s) {
      final d = s.data() ?? {};
      if (!mounted) return;
      setState(() {
        _bannerHidden = d['inboxBannerHidden'] == true;
        _online = d['showOnlineStatus'] != false;
        _systemSeenAt = d['systemSeenAt'] as Timestamp?;
      });
    }, onError: (Object e) => debugPrint('My doc error: $e')));

    _subs.add(_myDoc.collection('following').snapshots().listen((s) {
      if (!mounted) return;
      setState(() {
        _following
          ..clear()
          ..addAll(s.docs.map((d) => d.id));
      });
    }, onError: (Object e) => debugPrint('Following error: $e')));

    _subs.add(_myDoc.collection('dismissed_suggestions').snapshots().listen(
      (s) {
        if (!mounted) return;
        setState(() {
          _dismissed
            ..clear()
            ..addAll(s.docs.map((d) => d.id));
        });
      },
      onError: (Object e) => debugPrint('Dismissed error: $e'),
    ));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // ─────────────── actions ───────────────

  Future<void> _hideBanner() async {
    setState(() => _bannerHidden = true);
    try {
      await _myDoc.set({'inboxBannerHidden': true}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Hide banner error: $e');
    }
  }

  Future<void> _toggleOnline() async {
    final value = !_online;
    setState(() => _online = value);
    _snack(context, value ? 'অনলাইন স্ট্যাটাস চালু' : 'অনলাইন স্ট্যাটাস বন্ধ');
    try {
      await _myDoc.set(
        {'showOnlineStatus': value, 'isOnline': value},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Online status error: $e');
    }
  }

  Future<void> _toggleFollow(String id, String name) async {
    if (_myId.isEmpty) {
      _snack(context, 'অনুসরণ করতে আগে Sign In করুন।');
      return;
    }
    if (_busy.contains(id)) return;

    final wasFollowing = _following.contains(id);
    setState(() => _busy.add(id));

    try {
      await _setFollow(id, !wasFollowing);
      if (!wasFollowing) _sessionFollowed.add(id);
      if (mounted) {
        _snack(
          context,
          wasFollowing
              ? '$name-কে আনফলো করা হয়েছে'
              : '$name-কে অনুসরণ করা হয়েছে',
        );
      }
    } catch (e) {
      debugPrint('Follow error: $e');
      if (mounted) {
        _snack(context, 'অনুসরণ করা যায়নি। Firebase Rules পরীক্ষা করুন।');
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _dismissSuggestion(String id) async {
    setState(() => _dismissed.add(id));
    try {
      await _myDoc.collection('dismissed_suggestions').doc(id).set({
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Dismiss error: $e');
    }
  }

  Future<void> _openChatWithUser(
    String peerId,
    String peerName,
    String? peerPhotoUrl,
  ) async {
    if (_myId.isEmpty) {
      _snack(context, 'চ্যাট করতে আগে Sign In করুন।');
      return;
    }
    if (peerId.isEmpty || peerId == _myId) {
      _snack(context, 'নিজের সঙ্গে চ্যাট শুরু করা যাবে না।');
      return;
    }

    try {
      final userDoc = await _db.collection('users').doc(peerId).get();
      if (!mounted) return;

      if (!userDoc.exists) {
        _snack(context, 'ব্যবহারকারীর অ্যাকাউন্ট পাওয়া যায়নি।');
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
      debugPrint('Open chat error: $e');
      if (mounted) {
        _snack(
          context,
          'চ্যাট খোলা যায়নি। ইন্টারনেট ও Firebase Rules পরীক্ষা করুন।',
        );
      }
    }
  }

  void _openActivity() {
    if (_myId.isEmpty) {
      _snack(context, 'আগে Sign In করুন।');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const InboxActivityScreen()),
    );
  }

  void _openSystem() {
    if (_myId.isEmpty) {
      _snack(context, 'আগে Sign In করুন।');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const InboxSystemScreen(),
      ),
    );
  }

  void _showSearchDialog() {
    final controller = TextEditingController();
    final stream = _db.collection('users').limit(100).snapshots();

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
                        prefixIcon: const Icon(Icons.search, color: _muted),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Color(0xFF444444)),
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
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: stream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text(
                                'ব্যবহারকারী লোড করা যায়নি।',
                                style: TextStyle(color: _text),
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(color: _pink),
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
                                'কোনো ব্যবহারকারী পাওয়া যায়নি।',
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
                                  _openChatWithUser(doc.id, name, photo);
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
    );
  }

  // ─────────────── build ───────────────

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
        centerTitle: true,
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
              onTap: _myId.isEmpty ? null : _toggleOnline,
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
                        color: _online ? const Color(0xFF25C76A) : _muted,
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
        actions: [
          IconButton(
            tooltip: 'ব্যবহারকারী খুঁজুন',
            icon: const Icon(Icons.search, color: Colors.white, size: 29),
            onPressed: _showSearchDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (!_bannerHidden) _buildBanner(),
          _buildActivityItem(),
          _buildSystemItem(),
          _sectionTitle('মেসেজ ও ব্যবহারকারী', withInfo: true),
          _buildRecentChats(),
          _sectionTitle('সুপারিশকৃত অ্যাকাউন্ট'),
          _buildSuggestedUsers(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {bool withInfo = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (withInfo) ...[
            const SizedBox(width: 5),
            const Icon(Icons.info_outline, size: 15, color: Colors.white54),
          ],
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return GestureDetector(
      onTap: _openActivity,
      child: Container(
        margin: const EdgeInsets.only(top: 5, bottom: 8),
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        color: _surface,
        child: Row(
          children: [
            const CircleAvatar(
              radius: 29,
              backgroundColor: _blue,
              child: Icon(Icons.people_alt, color: Colors.white, size: 30),
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
                    style: TextStyle(fontSize: 13, color: _muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'বন্ধ করুন',
              onPressed: _hideBanner,
              icon: const Icon(Icons.close, size: 21, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem() {
    if (_notifStream == null) {
      return _notificationItem(
        icon: Icons.bolt,
        color: _pink,
        title: 'কার্যকলাপ ও নতুন অনুসরণকারী',
        subtitle: 'লাইক, মন্তব্য ও নতুন অনুসরণকারীর আপডেট',
        onTap: _openActivity,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _notifStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final unread = docs.where((d) => d.data()['read'] != true).length;
        final latest = docs.isEmpty
            ? null
            : docs.first.data()['createdAt'] as Timestamp?;

        return _notificationItem(
          icon: Icons.bolt,
          color: _pink,
          title: 'কার্যকলাপ ও নতুন অনুসরণকারী',
          subtitle: unread > 0
              ? '${_bn('$unread')}টি নতুন আপডেট'
              : 'লাইক, মন্তব্য ও নতুন অনুসরণকারীর আপডেট',
          time: docs.isEmpty ? null : _timeAgo(latest),
          unreadCount: unread,
          onTap: _openActivity,
        );
      },
    );
  }

  Widget _buildSystemItem() {
    if (_systemStream == null) {
      return _notificationItem(
        icon: Icons.inbox_rounded,
        color: const Color(0xFF34365C),
        title: 'সিস্টেমের নোটিফিকেশন',
        subtitle: 'PALOK-এর গুরুত্বপূর্ণ আপডেট',
        onTap: _openSystem,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _systemStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        String subtitle = 'PALOK-এর গুরুত্বপূর্ণ আপডেট';
        String? time;
        var unread = false;

        if (docs.isNotEmpty) {
          final d = docs.first.data();
          final created = d['createdAt'] as Timestamp?;
          final title = (d['title'] ?? '').toString();
          if (title.isNotEmpty) subtitle = title;
          time = _timeAgo(created);
          unread = created != null &&
              (_systemSeenAt == null || created.compareTo(_systemSeenAt!) > 0);
        }

        return _notificationItem(
          icon: Icons.inbox_rounded,
          color: const Color(0xFF34365C),
          title: 'সিস্টেমের নোটিফিকেশন',
          subtitle: subtitle,
          time: time,
          showDot: unread,
          onTap: _openSystem,
        );
      },
    );
  }

  Widget _notificationItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? time,
    int unreadCount = 0,
    bool showDot = false,
  }) {
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
              Text(time, style: const TextStyle(fontSize: 11, color: _muted)),
            ],
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 11,
                backgroundColor: _pink,
                child: Text(
                  unreadCount > 99 ? '99+' : _bn('$unreadCount'),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ] else if (showDot) ...[
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

  Widget _buildRecentChats() {
    if (_chatsStream == null) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'মেসেজ দেখতে আগে Sign In করুন।',
          style: TextStyle(color: _muted),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _chatsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Chats stream error: ${snapshot.error}');
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'চ্যাট লোড করা যায়নি। Firebase Rules পরীক্ষা করুন।',
              style: TextStyle(color: _muted),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator(color: _pink)),
          );
        }

        final chats = snapshot.data!.docs
            .where((d) => (d.data()['lastMessage'] ?? '').toString().isNotEmpty)
            .toList();

        chats.sort((a, b) {
          final aTime = a.data()['updatedAt'] as Timestamp?;
          final bTime = b.data()['updatedAt'] as Timestamp?;
          return (bTime?.millisecondsSinceEpoch ?? 1 << 50)
              .compareTo(aTime?.millisecondsSinceEpoch ?? 1 << 50);
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
            final participants = List<String>.from(data['participants'] ?? []);
            final others = participants.where((id) => id != _myId).toList();
            if (others.isEmpty) return const SizedBox.shrink();

            final peerId = others.first;
            final names =
                Map<String, dynamic>.from(data['participantNames'] ?? {});
            final photos =
                Map<String, dynamic>.from(data['participantPhotos'] ?? {});
            final unreadMap =
                Map<String, dynamic>.from(data['unreadCounts'] ?? {});

            final name = (names[peerId] ?? 'PALOK User').toString();
            final photo = (photos[peerId] ?? '').toString();
            final lastMessage = (data['lastMessage'] ?? '').toString();
            final lastSender = (data['lastSenderId'] ?? '').toString();
            final updatedAt = data['updatedAt'] as Timestamp?;
            final unreadCount = unreadMap[_myId] is num
                ? (unreadMap[_myId] as num).toInt()
                : 0;

            return ListTile(
              leading: _avatar(name, photo),
              title: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight:
                      unreadCount > 0 ? FontWeight.w800 : FontWeight.w700,
                  color: _text,
                ),
              ),
              subtitle: Text(
                lastSender == _myId ? 'আপনি: $lastMessage' : lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unreadCount > 0 ? _text : _muted,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _timeAgo(updatedAt),
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(height: 4),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: _pink,
                      child: Text(
                        unreadCount > 99 ? '99+' : _bn('$unreadCount'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () => _openChatWithUser(peerId, name, photo),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSuggestedUsers() {
    if (_usersStream == null) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'ব্যবহারকারী দেখতে আগে Sign In করুন।',
          style: TextStyle(color: _muted),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Users stream error: ${snapshot.error}');
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'ব্যবহারকারী লোড করা যায়নি। Firebase Rules পরীক্ষা করুন।',
              style: TextStyle(color: _muted),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator(color: _pink)),
          );
        }

        final users = snapshot.data!.docs.where((doc) {
          if (doc.id == _myId) return false;
          if (_dismissed.contains(doc.id)) return false;
          // যাদের আগে থেকেই ফলো করেন তাদের লুকানো হবে (এই সেশনে ফলো করা বাদে)
          if (_following.contains(doc.id) &&
              !_sessionFollowed.contains(doc.id)) {
            return false;
          }
          return true;
        }).toList();

        if (users.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'এখনো সুপারিশ করার মতো অন্য কোনো ব্যবহারকারী নেই।',
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
            final busy = _busy.contains(doc.id);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'মেসেজ পাঠান',
                    onPressed: () => _openChatWithUser(doc.id, name, photo),
                    icon: const Icon(Icons.chat_bubble_outline, color: _pink),
                  ),
                  SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      onPressed: busy ? null : () => _toggleFollow(doc.id, name),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? _surface : _pink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _surface,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isFollowing ? 'অনুসরণ করছেন' : 'অনুসরণ',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'সরিয়ে দিন',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _dismissSuggestion(doc.id),
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
}

// ─────────────────────── Activity (likes/comments/follows) ───────────────────────

class InboxActivityScreen extends StatefulWidget {
  const InboxActivityScreen({super.key});

  @override
  State<InboxActivityScreen> createState() => _InboxActivityScreenState();
}

class _InboxActivityScreenState extends State<InboxActivityScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _myId = FirebaseAuth.instance.currentUser?.uid ?? '';

  final Set<String> _following = <String>{};
  final Set<String> _busy = <String>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _followSub;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  CollectionReference<Map<String, dynamic>> get _notifCol =>
      _db.collection('users').doc(_myId).collection('notifications');

  @override
  void initState() {
    super.initState();
    _stream = _notifCol
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();

    _followSub = _db
        .collection('users')
        .doc(_myId)
        .collection('following')
        .snapshots()
        .listen((s) {
      if (!mounted) return;
      setState(() {
        _following
          ..clear()
          ..addAll(s.docs.map((d) => d.id));
      });
    }, onError: (Object e) => debugPrint('Following error: $e'));
  }

  @override
  void dispose() {
    _followSub?.cancel();
    super.dispose();
  }

  Future<void> _markAllRead() async {
    try {
      final snap = await _notifCol.where('read', isEqualTo: false).get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.update(d.reference, {'read': true});
      }
      await batch.commit();
      if (mounted) _snack(context, 'সব নোটিফিকেশন পড়া হয়েছে');
    } catch (e) {
      debugPrint('Mark all read error: $e');
      if (mounted) _snack(context, 'আপডেট করা যায়নি।');
    }
  }

  Future<void> _markRead(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await ref.update({'read': true});
    } catch (e) {
      debugPrint('Mark read error: $e');
    }
  }

  Future<void> _followBack(String id) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await _setFollow(id, !_following.contains(id));
    } catch (e) {
      debugPrint('Follow back error: $e');
      if (mounted) _snack(context, 'অনুসরণ করা যায়নি।');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.mode_comment;
      default:
        return Icons.person_add;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'like':
        return _pink;
      case 'comment':
        return const Color(0xFF3B82F6);
      default:
        return _blue;
    }
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
        title: const Text(
          'কার্যকলাপ',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'সব পড়া হয়েছে',
            icon: const Icon(Icons.done_all),
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Activity stream error: ${snapshot.error}');
            return const Center(
              child: Text(
                'কার্যকলাপ লোড করা যায়নি। Firebase Rules পরীক্ষা করুন।',
                style: TextStyle(color: _muted),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _pink),
            );
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'এখনো কোনো কার্যকলাপ নেই।',
                style: TextStyle(color: _muted, fontSize: 15),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final d = doc.data();
              final type = (d['type'] ?? 'follow').toString();
              final fromId = (d['fromUserId'] ?? '').toString();
              final name = (d['fromName'] ?? 'PALOK User').toString();
              final photo = (d['fromPhoto'] ?? '').toString();
              final text = (d['text'] ?? '').toString();
              final unread = d['read'] != true;
              final createdAt = d['createdAt'] as Timestamp?;
              final isFollowing = _following.contains(fromId);
              final busy = _busy.contains(fromId);

              return Dismissible(
                key: ValueKey(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: _pink,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => doc.reference.delete(),
                child: InkWell(
                  onTap: () => _markRead(doc.reference),
                  child: Container(
                    color: unread
                        ? _pink.withAlpha(25)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _avatar(name, photo, radius: 25),
                            Positioned(
                              right: -3,
                              bottom: -3,
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: _background,
                                child: CircleAvatar(
                                  radius: 8,
                                  backgroundColor: _typeColor(type),
                                  child: Icon(
                                    _typeIcon(type),
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _timeAgo(createdAt),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (type == 'follow' && fromId.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 34,
                            child: ElevatedButton(
                              onPressed:
                                  busy ? null : () => _followBack(fromId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isFollowing ? _surface : _pink,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _surface,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(
                                isFollowing ? 'অনুসরণ করছেন' : 'ফলো ব্যাক',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ───────────────────────────── System notifications ─────────────────────────────

class InboxSystemScreen extends StatefulWidget {
  const InboxSystemScreen({super.key});

  @override
  State<InboxSystemScreen> createState() => _InboxSystemScreenState();
}

class _InboxSystemScreenState extends State<InboxSystemScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('system_notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
    _markSeen();
  }

  Future<void> _markSeen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'systemSeenAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Mark system seen error: $e');
    }
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
        title: const Text(
          'সিস্টেমের নোটিফিকেশন',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('System stream error: ${snapshot.error}');
            return const Center(
              child: Text(
                'নোটিফিকেশন লোড করা যায়নি। Firebase Rules পরীক্ষা করুন।',
                style: TextStyle(color: _muted),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _pink),
            );
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'এখনো কোনো সিস্টেম নোটিফিকেশন নেই।',
                style: TextStyle(color: _muted, fontSize: 15),
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFF222222)),
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final title = (d['title'] ?? 'PALOK').toString();
              final body = (d['body'] ?? '').toString();
              final createdAt = d['createdAt'] as Timestamp?;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0xFF34365C),
                      child: Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: _text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              body,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            _timeAgo(createdAt),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
