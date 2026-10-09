
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.targetUserId,
  });

  /// যে ব্যবহারকারীকে Follow করা হবে তার Firebase UID
  final String targetUserId;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _isFollowing = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkFollowing();
  }

  @override
  void didUpdateWidget(covariant FollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.targetUserId != widget.targetUserId) {
      _isFollowing = false;
      _loading = true;
      _checkFollowing();
    }
  }

  Future<void> _checkFollowing() async {
    final user = _auth.currentUser;

    if (user == null || user.uid == widget.targetUserId) {
      if (mounted) {
        setState(() {
          _isFollowing = false;
          _loading = false;
        });
      }
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(widget.targetUserId)
          .get();

      if (!mounted) return;

      setState(() {
        _isFollowing = doc.exists;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final user = _auth.currentUser;

    if (user == null ||
        user.uid == widget.targetUserId ||
        _loading) {
      return;
    }

    setState(() {
      _loading = true;
    });

    final currentUserId = user.uid;
    final targetUserId = widget.targetUserId;

    final followingRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);

    final followerRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId);

    try {
      if (_isFollowing) {
        final batch = _firestore.batch();
        batch.delete(followingRef);
        batch.delete(followerRef);
        await batch.commit();

        if (!mounted) return;

        setState(() {
          _isFollowing = false;
          _loading = false;
        });
      } else {
        final batch = _firestore.batch();

        batch.set(followingRef, {
          'userId': targetUserId,
          'followedAt': FieldValue.serverTimestamp(),
        });

        batch.set(followerRef, {
          'userId': currentUserId,
          'followedAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();

        if (!mounted) return;

        setState(() {
          _isFollowing = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow পরিবর্তন করা যায়নি। আবার চেষ্টা করুন।'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    // নিজের প্রোফাইলে Follow বাটন দেখাবে না।
    if (user != null && user.uid == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    // Follow অবস্থা লোড হওয়ার সময়।
    if (_loading) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }

    // গোলাপি + অথবা Follow হলে চেক চিহ্ন।
    return GestureDetector(
      onTap: _toggleFollow,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _isFollowing
              ? Colors.black54
              : const Color(0xFFFF2055),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          _isFollowing ? Icons.check : Icons.add,
          color: Colors.white,
          size: 23,
        ),
      ),
    );
  }
}
