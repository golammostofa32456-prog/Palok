import 'dart:math' as math;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../inbox/chat_screen.dart';
import '../inbox/inbox_screen.dart' show InboxActivityScreen, InboxNotifier;
import '../video/video_url.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
const Color _kPink = Color(0xFFFF2D55);
const Color _kCyan = Color(0xFF20D7E8);
const Color _kGrey = Color(0xFF868686);

/// ফলো / আনফলো (দুই ব্যবহারকারীর সাব-কালেকশন ও কাউন্টার আপডেট করে)
Future<void> _followUser(String peerId, bool follow) async {
  final me = FirebaseAuth.instance.currentUser;
  if (me == null || peerId.isEmpty || peerId == me.uid) return;

  final db = FirebaseFirestore.instance;
  final myDoc = db.collection('users').doc(me.uid);
  final peerDoc = db.collection('users').doc(peerId);
  final myFollowing = myDoc.collection('following').doc(peerId);
  final theirFollowers = peerDoc.collection('followers').doc(me.uid);

  final peerSnap = await peerDoc.get();
  final mySnap = await myDoc.get();
  final peerCount = peerSnap.data()?['followersCount'];
  final myCount = mySnap.data()?['followingCount'];

  final batch = db.batch();
  if (follow) {
    batch.set(myFollowing, {
      'userId': peerId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(theirFollowers, {
      'userId': me.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (peerCount is int) {
      batch.update(peerDoc, {'followersCount': FieldValue.increment(1)});
    }
    batch.set(
      myDoc,
      {'followingCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  } else {
    batch.delete(myFollowing);
    batch.delete(theirFollowers);
    if (peerCount is int && peerCount > 0) {
      batch.update(peerDoc, {'followersCount': FieldValue.increment(-1)});
    }
    if (myCount is int && myCount > 0) {
      batch.update(myDoc, {'followingCount': FieldValue.increment(-1)});
    }
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

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({
    super.key,
    this.userId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _bg = Colors.black;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;
  String? _streamFor;

  int _tab = 0;
  bool _loading = true;
  bool _following = false;
  bool _followBusy = false;
  int _followersCount = 0;
  int _followingCount = 0;

  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _liked = [];
  List<Map<String, dynamic>> _saved = [];
  bool _likedLoaded = false;
  bool _savedLoaded = false;
  bool _tabLoading = false;

  User? get _me => _auth.currentUser;
  String get _targetId => widget.userId ?? _me?.uid ?? '';
  bool get _isMine => _me != null && _targetId == _me!.uid;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _tab = 0;
      _likedLoaded = false;
      _savedLoaded = false;
      _loadAll();
    }
  }

  // ---------- helpers ----------

  String _text(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString();

  int _number(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  int _millis(dynamic v) {
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    return 0;
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  String _username(Map<String, dynamic> data) {
    final name = _text(data['username']).trim();
    if (name.isNotEmpty) return name;
    final email = _text(data['email'], _isMine ? _me?.email ?? '' : '');
    if (email.contains('@')) return email.split('@').first;
    return 'palok_user';
  }

  String _displayName(Map<String, dynamic> data) {
    final name = _text(data['displayName']).trim();
    if (name.isNotEmpty) return name;
    if (_isMine) {
      final authName = _text(_me?.displayName).trim();
      if (authName.isNotEmpty) return authName;
    }
    return _username(data);
  }

  String _photo(Map<String, dynamic> data) {
    for (final key in [
      'profileImageUrl',
      'photoURL',
      'photoUrl',
      'profileImage',
    ]) {
      final v = _text(data[key]).trim();
      if (v.startsWith('http')) return v;
    }
    if (_isMine) {
      final v = _text(_me?.photoURL).trim();
      if (v.startsWith('http')) return v;
    }
    return '';
  }

  /// গ্রিডের থাম্বনেইল: ছোট একটা ছবি, পুরো ভিডিও না।
  String _thumbOf(Map<String, dynamic> v) {
    final t = _text(v['thumbnailUrl'] ?? v['thumbnail']).trim();
    if (t.startsWith('http')) return t;

    final url = _text(v['videoUrl']).trim();
    const marker = '/video/upload/';
    if (url.contains('res.cloudinary.com') && url.contains(marker)) {
      var out = url.replaceFirst(marker, '${marker}so_1,w_300,c_limit,f_jpg/');
      final dot = out.lastIndexOf('.');
      if (dot > out.lastIndexOf('/')) {
        out = '${out.substring(0, dot)}.jpg';
      }
      return out;
    }
    return '';
  }

  // ---------- data loading ----------

  Future<int> _countOf(Query<Map<String, dynamic>> query) async {
    try {
      final snap = await query.count().get();
      return snap.count ?? 0;
    } catch (_) {
      final snap = await query.get();
      return snap.size;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchVideos(String id) async {
    final col = _db.collection('videos');
    final snaps = await Future.wait([
      col.where('ownerId', isEqualTo: id).limit(60).get(),
      col.where('userId', isEqualTo: id).limit(60).get(),
    ]);

    final map = <String, Map<String, dynamic>>{};
    for (final snap in snaps) {
      for (final doc in snap.docs) {
        map[doc.id] = {...doc.data(), 'id': doc.id};
      }
    }

    final list = map.values.toList()
      ..sort(
        (a, b) => _millis(b['createdAt']).compareTo(_millis(a['createdAt'])),
      );
    return list;
  }

  Future<List<Map<String, dynamic>>> _fetchFromSub(
    String id,
    String sub,
  ) async {
    final snap = await _db
        .collection('users')
        .doc(id)
        .collection(sub)
        .limit(40)
        .get();

    final docs = await Future.wait(
      snap.docs.map((d) => _db.collection('videos').doc(d.id).get()),
    );

    final list = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final data = doc.data();
      if (doc.exists && data != null) {
        list.add({...data, 'id': doc.id});
      }
    }
    return list;
  }

  Future<bool> _checkFollowing(String id) async {
    final me = _me;
    if (me == null || me.uid == id) return false;
    final doc = await _db
        .collection('users')
        .doc(me.uid)
        .collection('following')
        .doc(id)
        .get();
    return doc.exists;
  }

  Future<void> _loadAll() async {
    final id = _targetId;
    if (id.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (mounted) setState(() => _loading = true);

    try {
      final userRef = _db.collection('users').doc(id);
      final results = await Future.wait<Object?>([
        _fetchVideos(id),
        _countOf(userRef.collection('followers')),
        _countOf(userRef.collection('following')),
        _checkFollowing(id),
      ]);

      if (!mounted) return;
      setState(() {
        _videos = results[0] as List<Map<String, dynamic>>;
        _followersCount = results[1] as int;
        _followingCount = results[2] as int;
        _following = results[3] as bool;
      });
    } catch (e) {
      debugPrint('Profile load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ensureTabLoaded(int tab) async {
    final id = _targetId;
    if (!_isMine || id.isEmpty) return;

    final needLiked = tab == 1 && !_likedLoaded;
    final needSaved = tab == 2 && !_savedLoaded;
    if (!needLiked && !needSaved) return;

    setState(() => _tabLoading = true);
    try {
      if (needLiked) {
        _liked = await _fetchFromSub(id, 'likedVideos');
        _likedLoaded = true;
      } else {
        _saved = await _fetchFromSub(id, 'savedVideos');
        _savedLoaded = true;
      }
    } catch (e) {
      debugPrint('Profile tab load error: $e');
    } finally {
      if (mounted) setState(() => _tabLoading = false);
    }
  }

  Future<void> _refresh() async {
    _likedLoaded = false;
    _savedLoaded = false;
    await _loadAll();
    await _ensureTabLoaded(_tab);
  }

  // ---------- actions ----------

  Future<void> _toggleFollow() async {
    final me = _me;
    if (me == null) {
      _msg('Follow করতে আগে Sign In করুন।');
      return;
    }
    if (_isMine || _followBusy) return;

    final id = _targetId;
    final was = _following;

    setState(() {
      _followBusy = true;
      _following = !was;
      _followersCount = math.max(0, _followersCount + (was ? -1 : 1));
    });

    try {
      await _followUser(id, !was);
    } catch (e) {
      debugPrint('Follow error: $e');
      if (mounted) {
        setState(() {
          _following = was;
          _followersCount = math.max(0, _followersCount + (was ? 1 : -1));
        });
      }
      _msg('Follow করা যায়নি। আবার চেষ্টা করুন।');
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _editProfile() async {
    if (_me == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<Object?>(builder: (_) => const EditProfileScreen()),
    );
  }

  Future<void> _openChat(Map<String, dynamic> data) async {
    if (_me == null) {
      _msg('মেসেজ করতে আগে Sign In করুন।');
      return;
    }
    if (_isMine) return;

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          peerId: _targetId,
          peerName: _displayName(data),
          peerPhotoUrl: _photo(data),
        ),
      ),
    );
  }

  Future<void> _openList(String sub, String title) async {
    final id = _targetId;
    if (id.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _UserListScreen(userId: id, title: title, sub: sub),
      ),
    );
    if (mounted) _loadAll();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Log out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'আপনি কি Log out করতে চান?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('না'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('হ্যাঁ', style: TextStyle(color: _kPink)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _msg('Log out করা যায়নি।');
    }
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white),
              title: const Text(
                'Edit profile',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _editProfile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white),
              title: const Text(
                'কার্যকলাপ কেন্দ্র',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const InboxActivityScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border, color: Colors.white),
              title: const Text(
                'Save করা ভিডিও',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _tab = 2);
                _ensureTabLoaded(2);
              },
            ),
                        ListTile(
              leading:
                  const Icon(Icons.settings_outlined, color: Colors.white),
              title: const Text(
                'সেটিংস এবং গোপনীয়তা',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ListTile(
              leading: const Icon(Icons.logout, color: _kPink),
              title: const Text('Log out', style: TextStyle(color: _kPink)),
              onTap: () {
                Navigator.pop(ctx);
                _logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openViewer(List<Map<String, dynamic>> list, int index) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _VideoViewer(videos: list, initialIndex: index),
      ),
    );
  }

  // ---------- UI ----------

  Widget _topBar(String title) {
    final canPop = Navigator.of(context).canPop();

    return SizedBox(
      height: 52,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: canPop
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: _isMine
                ? IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: _openMenu,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _avatar(String url, {double size = 96}) {
    final ring = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_kPink, _kCyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFF1E1E1E),
        backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
        child: url.isEmpty
            ? const Icon(Icons.person, color: _kGrey, size: 48)
            : null,
      ),
    );

    if (!_isMine) return ring;

    return GestureDetector(
      onTap: _editProfile,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ring,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _kCyan,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(
                _fmt(value),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(color: _kGrey, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions(Map<String, dynamic> data) {
    if (_isMine) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: _editProfile,
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF161616),
              side: const BorderSide(color: Color(0xFF252525)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text(
              'Edit Profile',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    final Widget followButton = _following
        ? OutlinedButton(
            onPressed: _followBusy ? null : _toggleFollow,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF3A3A3A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text(
              'Following',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        : ElevatedButton(
            onPressed: _followBusy ? null : _toggleFollow,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text(
              'Follow',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(child: followButton),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 44,
              child: OutlinedButton(
                onPressed: () => _openChat(data),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: const BorderSide(color: Color(0xFF3A3A3A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(IconData icon, int index) {
    final selected = _tab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _tab = index);
          _ensureTabLoaded(index);
        },
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : Colors.grey.shade600,
                size: 24,
              ),
              const SizedBox(height: 7),
              Container(
                height: 2,
                color: selected ? Colors.white : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> data) {
    final username = _username(data);
    final bio = _text(data['bio']).trim();
    final likes = math.max(
      _videos.fold<int>(0, (sum, v) => sum + _number(v['likeCount'])),
      _number(data['likesCount'] ?? data['totalLikes']),
    );
    final followers = math.max(
      _followersCount,
      _number(data['followersCount']),
    );
    final following = math.max(
      _followingCount,
      _number(data['followingCount']),
    );

    return Column(
      children: [
        _topBar(_displayName(data)),
        const SizedBox(height: 8),
        _avatar(_photo(data)),
        const SizedBox(height: 10),
        Text(
          '@$username',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _stat(
              'Following',
              following,
              () => _openList('following', 'Following'),
            ),
            Container(width: 1, height: 12, color: Colors.grey.shade800),
            _stat(
              'Followers',
              followers,
              () => _openList('followers', 'Followers'),
            ),
            Container(width: 1, height: 12, color: Colors.grey.shade800),
            _stat('Likes', likes, null),
          ],
        ),
        const SizedBox(height: 16),
        _actions(data),
        if (bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFF1F1F1F)),
        Row(
          children: [
            _tabButton(Icons.grid_on_outlined, 0),
            _tabButton(
              _isMine ? Icons.favorite_border : Icons.lock_outline,
              1,
            ),
            if (_isMine) _tabButton(Icons.bookmark_border, 2),
          ],
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _currentList {
    switch (_tab) {
      case 1:
        return _isMine ? _liked : const [];
      case 2:
        return _isMine ? _saved : const [];
      default:
        return _videos;
    }
  }

  Widget _emptyState() {
    IconData icon = Icons.video_library_outlined;
    String text = 'এখনো কোনো ভিডিও নেই';

    if (_tab == 1) {
      icon = _isMine ? Icons.favorite_border : Icons.lock_outline;
      text = _isMine
          ? 'Like করা ভিডিও এখানে দেখা যাবে'
          : 'এই ব্যবহারকারীর Like করা ভিডিও গোপন';
    } else if (_tab == 2) {
      icon = Icons.bookmark_border;
      text = 'Save করা ভিডিও এখানে দেখা যাবে';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade700),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: _kGrey)),
        ],
      ),
    );
  }

  Widget _tile(List<Map<String, dynamic>> list, int index) {
    final video = list[index];
    final thumb = _thumbOf(video);

    return GestureDetector(
      onTap: () => _openViewer(list, index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: const Color(0xFF1A1A1A),
            child: thumb.isNotEmpty
                ? Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.play_arrow,
                      color: Colors.white24,
                      size: 36,
                    ),
                  )
                : const Icon(
                    Icons.play_arrow,
                    color: Colors.white24,
                    size: 36,
                  ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Row(
              children: [
                const Icon(
                  Icons.favorite_border,
                  color: Colors.white,
                  size: 14,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
                const SizedBox(width: 3),
                Text(
                  _fmt(_number(video['likeCount'])),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _gridSlivers() {
    final list = _currentList;
    final busy = (_tab == 0 && _loading && list.isEmpty) ||
        (_tab != 0 && _tabLoading);

    if (busy) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: _kPink)),
          ),
        ),
      ];
    }

    if (list.isEmpty) {
      return [SliverToBoxAdapter(child: Center(child: _emptyState()))];
    }

    return [
      SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _tile(list, index),
          childCount: list.length,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final id = _targetId;

    if (id.isEmpty) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Text(
            'প্রোফাইল দেখতে আগে Sign In করুন।',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    if (_streamFor != id) {
      _streamFor = id;
      _userStream = _db.collection('users').doc(id).snapshots();
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userStream,
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? <String, dynamic>{};

            return RefreshIndicator(
              color: _kPink,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _header(data)),
                  ..._gridSlivers(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ======================================================================
// Followers / Following list
// ======================================================================

class _UserListScreen extends StatefulWidget {
  final String userId;
  final String title;
  final String sub; // 'followers' | 'following'

  const _UserListScreen({
    required this.userId,
    required this.title,
    required this.sub,
  });

  @override
  State<_UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<_UserListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _myId = FirebaseAuth.instance.currentUser?.uid ?? '';

  final Set<String> _myFollowing = <String>{};
  final Set<String> _busy = <String>{};
  final Map<String, Map<String, dynamic>> _cache = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _db
        .collection('users')
        .doc(widget.userId)
        .collection(widget.sub)
        .limit(200)
        .snapshots();

    if (_myId.isNotEmpty) {
      _sub = _db
          .collection('users')
          .doc(_myId)
          .collection('following')
          .snapshots()
          .listen((s) {
        if (!mounted) return;
        setState(() {
          _myFollowing
            ..clear()
            ..addAll(s.docs.map((d) => d.id));
        });
      }, onError: (Object e) => debugPrint('My following error: $e'));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadUser(String id) async {
    _cache[id] = {};
    try {
      final snap = await _db.collection('users').doc(id).get();
      if (!mounted) return;
      setState(() => _cache[id] = snap.data() ?? {});
    } catch (e) {
      debugPrint('Load user error: $e');
    }
  }

  String _name(Map<String, dynamic> d) {
    for (final k in ['displayName', 'name', 'username']) {
      final v = (d[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return 'PALOK User';
  }

  String _photoOf(Map<String, dynamic> d) {
    for (final k in ['profileImageUrl', 'photoURL', 'photoUrl', 'profileImage']) {
      final v = (d[k] ?? '').toString().trim();
      if (v.startsWith('http')) return v;
    }
    return '';
  }

  Future<void> _toggle(String id) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await _followUser(id, !_myFollowing.contains(id));
    } catch (e) {
      debugPrint('List follow error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow করা যায়নি।')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('User list error: ${snapshot.error}');
            return const Center(
              child: Text(
                'লিস্ট লোড করা যায়নি।',
                style: TextStyle(color: _kGrey),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _kPink),
            );
          }

          final ids = snapshot.data!.docs.map((d) => d.id).toList();
          if (ids.isEmpty) {
            return Center(
              child: Text(
                widget.sub == 'followers'
                    ? 'এখনো কোনো Follower নেই'
                    : 'এখনো কাউকে Follow করা হয়নি',
                style: const TextStyle(color: _kGrey),
              ),
            );
          }

          return ListView.builder(
            itemCount: ids.length,
            itemBuilder: (context, index) {
              final id = ids[index];
              if (!_cache.containsKey(id)) _loadUser(id);

              final d = _cache[id] ?? {};
              final name = d.isEmpty ? '...' : _name(d);
              final username = (d['username'] ?? '').toString();
              final photo = _photoOf(d);
              final isMe = id == _myId;
              final isFollowing = _myFollowing.contains(id);
              final busy = _busy.contains(id);

              return ListTile(
                onTap: () {
                  if (isMe) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ProfileScreen(userId: id),
                    ),
                  );
                },
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF25B7E8),
                  backgroundImage:
                      photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo.isEmpty
                      ? Text(
                          name.isNotEmpty && name != '...'
                              ? name.characters.first.toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: username.isEmpty
                    ? null
                    : Text(
                        '@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _kGrey, fontSize: 12),
                      ),
                trailing: isMe
                    ? null
                    : SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: busy ? null : () => _toggle(id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isFollowing ? const Color(0xFF2A2A2A) : _kPink,
                            disabledBackgroundColor: const Color(0xFF2A2A2A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
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

// ======================================================================
// Full-screen video viewer (প্রোফাইল গ্রিড থেকে ভিডিও খুললে)
// একসাথে শুধু একটা ভিডিও নামে, তাই bandwidth কম খরচ হয়।
// ======================================================================

class _VideoViewer extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final int initialIndex;

  const _VideoViewer({
    required this.videos,
    required this.initialIndex,
  });

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) => _ViewerPage(
              video: widget.videos[index],
              active: index == _current,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerPage extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool active;

  const _ViewerPage({
    required this.video,
    required this.active,
  });

  @override
  State<_ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<_ViewerPage> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _init();
  }

  @override
  void didUpdateWidget(covariant _ViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && _controller == null && !_failed) {
      _init();
    } else if (!widget.active && _controller != null) {
      final c = _controller;
      _controller = null;
      c?.dispose();
    }
  }

  Future<void> _init() async {
    final url = (widget.video['videoUrl'] ?? '').toString().trim();
    if (url.isEmpty) {
      _failed = true;
      return;
    }

    final controller = url.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(optimizeVideoUrl(url)))
        : VideoPlayerController.asset(url);
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.play();
      setState(() {});
    } catch (e) {
      debugPrint('Viewer video error: $e');
      if (_controller == controller) _controller = null;
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    c.value.isPlaying ? c.pause() : c.play();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    final username = (widget.video['username'] ?? '').toString();
    final caption = (widget.video['caption'] ?? '').toString();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              ),
            )
          else
            Center(
              child: _failed
                  ? const Text(
                      'ভিডিও চালু করা যায়নি।',
                      style: TextStyle(color: Colors.white70),
                    )
                  : const CircularProgressIndicator(color: _kPink),
            ),
          if (ready && !c.value.isPlaying)
            const Center(
              child: Icon(Icons.play_arrow, color: Colors.white70, size: 80),
            ),
          IgnorePointer(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 220,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (username.isNotEmpty)
                  Text(
                    username.replaceAll('@', ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
