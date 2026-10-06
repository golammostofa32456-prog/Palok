import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.targetUserId,
  });

  /// যাকে Follow করা হবে তার Firebase UID
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

  Future<void> _checkFollowing() async {
    final user = _auth.currentUser;

    if (user == null ||
        user.uid == widget.targetUserId) {
      if (mounted) {
        setState(() {
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

      if (mounted) {
        setState(() {
          _isFollowing = doc.exists;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
        await followingRef.delete();
        await followerRef.delete();

        if (mounted) {
          setState(() {
            _isFollowing = false;
            _loading = false;
          });
        }
      } else {
        await followingRef.set({
          'userId': targetUserId,
          'followedAt': FieldValue.serverTimestamp(),
        });

        await followerRef.set({
          'userId': currentUserId,
          'followedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            _isFollowing = true;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    // নিজের profile হলে Follow button দেখাবে না।
    if (user != null &&
        user.uid == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    if (_loading) {
      return const SizedBox(
        width: 80,
        height: 34,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleFollow,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: _isFollowing
              ? Colors.transparent
              : const Color(0xFFFF2055),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isFollowing
                ? Colors.white
                : const Color(0xFFFF2055),
            width: 1,
          ),
        ),
        child: Text(
          _isFollowing ? 'Following' : 'Follow',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
