import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'comment_item.dart';
import 'comment_model.dart';
import 'comment_service.dart';

class CommentsSheet extends StatefulWidget {
  final String videoId;
  final String videoOwnerId;
  final String videoOwnerUsername;
  final String currentUsername;
  final String currentUserId;
  final FirebaseFirestore firestore;

  const CommentsSheet({
    super.key,
    required this.videoId,
    required this.videoOwnerId,
    required this.videoOwnerUsername,
    required this.currentUsername,
    required this.currentUserId,
    required this.firestore,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  late final CommentService _commentService;

  final TextEditingController _commentController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  List<CommentModel> _comments = [];

  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();

    _commentService = CommentService(
      firestore: widget.firestore,
    );

    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _commentService.getComments(
        widget.videoId,
      );

      if (!mounted) return;

      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Comments লোড করা যায়নি',
      );
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();

    if (text.isEmpty) {
      return;
    }

    if (widget.currentUserId.trim().isEmpty) {
      _showMessage(
        'Comment করতে Login করতে হবে',
      );
      return;
    }

    if (_sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final commentId =
          await _commentService.addComment(
        videoId: widget.videoId,
        userId: widget.currentUserId,
        username: widget.currentUsername.isNotEmpty
            ? widget.currentUsername
            : 'PALOK User',
        userPhoto: '',
        text: text,
      );

      final newComment = CommentModel(
        id: commentId,
        userId: widget.currentUserId,
        username: widget.currentUsername.isNotEmpty
            ? widget.currentUsername
            : 'PALOK User',
        userPhoto: '',
        text: text,
        createdAt: DateTime.now(),
      );

      if (!mounted) return;

      setState(() {
        _comments.insert(0, newComment);
      });

      _commentController.clear();

      await _updateCommentCount(1);

      if (widget.videoOwnerId.isNotEmpty &&
          widget.videoOwnerId != widget.currentUserId) {
        await _sendCommentNotification();
      }

      if (!mounted) return;

      setState(() {
        _sending = false;
      });

      _scrollToTop();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _sending = false;
      });

      _showMessage(
        'Comment করা যায়নি',
      );
    }
  }

  Future<void> _deleteComment(
    CommentModel comment,
  ) async {
    if (comment.userId != widget.currentUserId) {
      return;
    }

    try {
      await _commentService.deleteComment(
        videoId: widget.videoId,
        commentId: comment.id,
      );

      if (!mounted) return;

      setState(() {
        _comments.removeWhere(
          (item) => item.id == comment.id,
        );
      });

      await _updateCommentCount(-1);
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Comment মুছে ফেলা যায়নি',
      );
    }
  }

  Future<void> _updateCommentCount(int amount) async {
    if (widget.videoId.startsWith('demo_')) {
      return;
    }

    try {
      await widget.firestore
          .collection('videos')
          .doc(widget.videoId)
          .set(
        {
          'commentCount': FieldValue.increment(amount),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Comment itself already succeeded.
    }
  }

  Future<void> _sendCommentNotification() async {
    try {
      await widget.firestore
          .collection('users')
          .doc(widget.videoOwnerId)
          .collection('notifications')
          .add({
        'type': 'comment',
        'fromUserId': widget.currentUserId,
        'fromUsername': widget.currentUsername,
        'text': 'তোমার ভিডিওতে Comment করেছে',
        'videoId': widget.videoId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Notification failure should not break commenting.
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      0,
      duration: const Duration(
        milliseconds: 250,
      ),
      curve: Curves.easeOut,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            const Divider(
              height: 1,
              color: Colors.white12,
            ),
            Expanded(
              child: _buildCommentsList(),
            ),
            _buildInput(bottomInset),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'Comments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Positioned(
            left: 8,
            child: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            right: 16,
            child: Text(
              '${_comments.length}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (_comments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white38,
                size: 52,
              ),
              SizedBox(height: 14),
              Text(
                'No comments yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'প্রথম Comment করুন।',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];

        return CommentItem(
          key: ValueKey(comment.id),
          comment: comment,
          isCurrentUser:
              comment.userId == widget.currentUserId,
          onDelete: comment.userId ==
                  widget.currentUserId
              ? () => _confirmDelete(comment)
              : null,
        );
      },
    );
  }

  Widget _buildInput(double bottomInset) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + bottomInset,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 44,
                maxHeight: 120,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white12,
                ),
              ),
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Write a comment...',
                  hintStyle: TextStyle(
                    color: Colors.white38,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFFFF2D55),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _sending
                  ? null
                  : _addComment,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: _sending
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    CommentModel comment,
  ) async {
    final shouldDelete =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF242424),
          title: const Text(
            'Delete comment?',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: const Text(
            'এই Comment মুছে ফেলতে চান?',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Color(0xFFFF2D55),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteComment(comment);
    }
  }
}
