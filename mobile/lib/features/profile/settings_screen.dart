import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../inbox/inbox_screen.dart' show InboxActivityScreen;
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _pink = Color(0xFFFF2D55);
  static const Color _grey = Color(0xFF868686);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _busy = false;

  User? get _user => _auth.currentUser;

  bool get _isPasswordUser =>
      _user?.providerData.any((p) => p.providerId == 'password') ?? false;

  // ---------- helpers ----------

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  void _goToRoot() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(body, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('না'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText, style: const TextStyle(color: _pink)),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'পাসওয়ার্ড দিন',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'আপনার বর্তমান পাসওয়ার্ড',
            hintStyle: TextStyle(color: _grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('নিশ্চিত', style: TextStyle(color: _pink)),
          ),
        ],
      ),
    );
  }

  // ---------- actions ----------

  Future<void> _editProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute<Object?>(builder: (_) => const EditProfileScreen()),
    );
  }

  void _openActivity() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const InboxActivityScreen()),
    );
  }

  Future<void> _changePassword() async {
    final email = _user?.email;
    if (email == null || email.isEmpty) {
      _msg('এই অ্যাকাউন্টে ইমেইল নেই।');
      return;
    }

    final ok = await _confirm(
      title: 'পাসওয়ার্ড বদলান',
      body: '$email ঠিকানায় পাসওয়ার্ড রিসেটের লিংক পাঠানো হবে।',
      confirmText: 'পাঠান',
    );
    if (!ok) return;

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _msg('রিসেট লিংক পাঠানো হয়েছে। ইমেইল (স্প্যামসহ) দেখুন।');
    } on FirebaseAuthException catch (e) {
      _msg('পাঠানো যায়নি: ${e.message ?? e.code}');
    } catch (e) {
      _msg('পাঠানো যায়নি।');
    }
  }

  void _about() {
    showAboutDialog(
      context: context,
      applicationName: 'PALOK',
      applicationVersion: '1.0.0',
      children: const [
        SizedBox(height: 8),
        Text('PALOK একটি ছোট ভিডিও শেয়ারিং প্ল্যাটফর্ম।'),
      ],
    );
  }

  Future<void> _logout() async {
    final ok = await _confirm(
      title: 'Log out',
      body: 'আপনি কি Log out করতে চান?',
      confirmText: 'হ্যাঁ',
    );
    if (!ok) return;

    try {
      await _auth.signOut();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      _goToRoot();
    } catch (e) {
      _msg('Log out করা যায়নি।');
    }
  }

  // ---------- delete account ----------

  Future<bool> _reauthenticate(User user) async {
    final providers = user.providerData.map((p) => p.providerId).toList();

    if (providers.contains('password')) {
      final password = await _askPassword();
      if (password == null || password.isEmpty) return false;

      final credential = EmailAuthProvider.credential(
        email: user.email ?? '',
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    }

    if (providers.contains('google.com')) {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    }

    return true;
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    while (true) {
      final snap = await ref.limit(300).get();
      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snap.docs.length < 300) break;
    }
  }

  Future<void> _deleteUserData(String uid) async {
    final userRef = _db.collection('users').doc(uid);

    // আমাকে যাদের ফলো লিস্ট থেকে সরানো (অন্যদের followers থেকে আমার এন্ট্রি)
    try {
      final following = await userRef.collection('following').get();
      final peers = following.docs.map((d) => d.id).toList();
      for (var i = 0; i < peers.length; i += 400) {
        final batch = _db.batch();
        for (final peerId in peers.skip(i).take(400)) {
          batch.delete(
            _db.collection('users').doc(peerId).collection('followers').doc(uid),
          );
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Peer followers cleanup error: $e');
    }

    for (final sub in [
      'following',
      'notifications',
      'likedVideos',
      'savedVideos',
      'saved',
      'dismissed_suggestions',
      'sharedVideos',
    ]) {
      try {
        await _deleteCollection(userRef.collection(sub));
      } catch (e) {
        debugPrint('Delete $sub error: $e');
      }
    }

    // নিজের ভিডিও
    for (final field in ['ownerId', 'userId']) {
      try {
        final snap = await _db
            .collection('videos')
            .where(field, isEqualTo: uid)
            .get();
        for (var i = 0; i < snap.docs.length; i += 400) {
          final batch = _db.batch();
          for (final doc in snap.docs.skip(i).take(400)) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      } catch (e) {
        debugPrint('Delete videos ($field) error: $e');
      }
    }

    await userRef.delete();
  }

  Future<void> _deleteAccount() async {
    final user = _user;
    if (user == null) return;

    final ok = await _confirm(
      title: 'অ্যাকাউন্ট মুছবেন?',
      body: 'আপনার প্রোফাইল, ভিডিও, ফলো ও নোটিফিকেশন স্থায়ীভাবে মুছে যাবে। '
          'এটা আর ফেরানো যাবে না।',
      confirmText: 'মুছে ফেলুন',
    );
    if (!ok) return;

    setState(() => _busy = true);

    try {
      final verified = await _reauthenticate(user);
      if (!verified) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      await _deleteUserData(user.uid);
      await user.delete();

      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      _goToRoot();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _msg('পাসওয়ার্ড ভুল। আবার চেষ্টা করুন।');
      } else if (e.code == 'requires-recent-login') {
        _msg('নিরাপত্তার জন্য Log out করে আবার Log in করে চেষ্টা করুন।');
      } else {
        _msg('অ্যাকাউন্ট মোছা যায়নি: ${e.message ?? e.code}');
      }
    } catch (e) {
      debugPrint('Delete account error: $e');
      _msg('অ্যাকাউন্ট মোছা যায়নি। ইন্টারনেট ও Firebase Rules পরীক্ষা করুন।');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- UI ----------

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: _grey,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color color = Colors.white,
    bool chevron = true,
  }) {
    return ListTile(
      enabled: !_busy,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontSize: 16)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: const TextStyle(color: _grey, fontSize: 13)),
      trailing: onTap != null && chevron
          ? const Icon(Icons.chevron_right, color: _grey)
          : null,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _user?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'সেটিংস এবং গোপনীয়তা',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: _pink,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: ListView(
        children: [
          _section('অ্যাকাউন্ট'),
          _tile(
            icon: Icons.person_outline,
            title: 'Edit profile',
            onTap: _editProfile,
          ),
          _tile(
            icon: Icons.email_outlined,
            title: 'ইমেইল',
            subtitle: email.isEmpty ? 'ইমেইল নেই' : email,
          ),
          if (_isPasswordUser)
            _tile(
              icon: Icons.lock_outline,
              title: 'পাসওয়ার্ড বদলান',
              onTap: _changePassword,
            ),
          _section('কার্যকলাপ'),
          _tile(
            icon: Icons.history,
            title: 'কার্যকলাপ কেন্দ্র',
            onTap: _openActivity,
          ),
          _section('সহায়তা'),
          _tile(
            icon: Icons.info_outline,
            title: 'PALOK সম্পর্কে',
            onTap: _about,
          ),
          _section('লগইন'),
          _tile(
            icon: Icons.logout,
            title: 'Log out',
            color: _pink,
            onTap: _logout,
            chevron: false,
          ),
          _tile(
            icon: Icons.delete_forever_outlined,
            title: 'অ্যাকাউন্ট মুছুন',
            color: _pink,
            onTap: _deleteAccount,
            chevron: false,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
