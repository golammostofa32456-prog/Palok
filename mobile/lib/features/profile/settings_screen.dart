import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../l10n/app_strings.dart';
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
            child: Text(tr('no')),
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
        title: Text(
          tr('enter_password'),
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: tr('current_password_hint'),
            hintStyle: const TextStyle(color: _grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(tr('confirm'), style: const TextStyle(color: _pink)),
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

  void _pickLanguage() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final current = LanguageController.instance.code;

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      tr('choose_language'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                for (final lang in AppLanguage.all)
                  ListTile(
                    title: Text(
                      lang.nativeName,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    trailing: lang.code == current
                        ? const Icon(Icons.check, color: _pink)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await LanguageController.instance.setLanguage(lang.code);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changePassword() async {
    final email = _user?.email;
    if (email == null || email.isEmpty) {
      _msg(tr('no_email_on_account'));
      return;
    }

    final ok = await _confirm(
      title: tr('change_password'),
      body: tr('reset_body', {'email': email}),
      confirmText: tr('send'),
    );
    if (!ok) return;

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _msg(tr('reset_sent'));
    } on FirebaseAuthException catch (e) {
      _msg(tr('reset_failed', {'error': e.message ?? e.code}));
    } catch (e) {
      _msg(tr('reset_failed_generic'));
    }
  }

  void _about() {
    showAboutDialog(
      context: context,
      applicationName: 'PALOK',
      applicationVersion: '1.0.0',
      children: [
        const SizedBox(height: 8),
        Text(tr('about_body')),
      ],
    );
  }

  Future<void> _logout() async {
    final ok = await _confirm(
      title: tr('logout'),
      body: tr('logout_confirm'),
      confirmText: tr('yes'),
    );
    if (!ok) return;

    try {
      await _auth.signOut();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      _goToRoot();
    } catch (e) {
      _msg(tr('logout_failed'));
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

    // অন্যদের followers লিস্ট থেকে আমার এন্ট্রি সরানো
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
      title: tr('delete_title'),
      body: tr('delete_body'),
      confirmText: tr('delete_confirm_btn'),
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
        _msg(tr('wrong_password'));
      } else if (e.code == 'requires-recent-login') {
        _msg(tr('relogin_required'));
      } else {
        _msg(tr('delete_failed', {'error': e.message ?? e.code}));
      }
    } catch (e) {
      debugPrint('Delete account error: $e');
      _msg(tr('delete_failed_generic'));
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
    return LanguageBuilder(
      builder: (context) {
        final email = _user?.email ?? '';

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(
              tr('settings_title'),
              style: const TextStyle(fontWeight: FontWeight.w800),
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
              _section(tr('section_account')),
              _tile(
                icon: Icons.person_outline,
                title: tr('edit_profile'),
                onTap: _editProfile,
              ),
              _tile(
                icon: Icons.email_outlined,
                title: tr('email'),
                subtitle: email.isEmpty ? tr('no_email') : email,
              ),
              if (_isPasswordUser)
                _tile(
                  icon: Icons.lock_outline,
                  title: tr('change_password'),
                  onTap: _changePassword,
                ),
              _section(tr('section_language')),
              _tile(
                icon: Icons.language,
                title: LanguageController.instance.current.nativeName,
                subtitle: tr('choose_language'),
                onTap: _pickLanguage,
              ),
              _section(tr('section_activity')),
              _tile(
                icon: Icons.history,
                title: tr('activity_center'),
                onTap: _openActivity,
              ),
              _section(tr('section_help')),
              _tile(
                icon: Icons.info_outline,
                title: tr('about_palok'),
                onTap: _about,
              ),
              _section(tr('section_login')),
              _tile(
                icon: Icons.logout,
                title: tr('logout'),
                color: _pink,
                onTap: _logout,
                chevron: false,
              ),
              _tile(
                icon: Icons.delete_forever_outlined,
                title: tr('delete_account'),
                color: _pink,
                onTap: _deleteAccount,
                chevron: false,
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}
