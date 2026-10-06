import 'package:flutter/material.dart';

import 'follow_service.dart';

class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.targetUserId,
    this.initialFollowing = false,
    this.onChanged,
  });

  final String targetUserId;
  final bool initialFollowing;
  final ValueChanged<bool>? onChanged;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  late bool _isFollowing;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialFollowing;
  }

  Future<void> _toggleFollow() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      if (_isFollowing) {
        await FollowService.unfollowUser(
          widget.targetUserId,
        );
      } else {
        await FollowService.followUser(
          widget.targetUserId,
        );
      }

      if (!mounted) return;

      setState(() {
        _isFollowing = !_isFollowing;
      });

      widget.onChanged?.call(_isFollowing);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Follow পরিবর্তন করা যায়নি। আবার চেষ্টা করুন।',
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: _loading ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isFollowing ? Colors.white : const Color(0xFFFF2055),
          foregroundColor:
              _isFollowing ? Colors.black : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: _isFollowing
                ? const BorderSide(
                    color: Colors.grey,
                  )
                : BorderSide.none,
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Text(
                _isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
