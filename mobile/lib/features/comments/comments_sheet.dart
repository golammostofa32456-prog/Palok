import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';

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
  final TextEditingController _controller = TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _sending) return;

    if (widget.currentUserId.isEmpty) {
      _showError('Comment করতে Login করতে হবে');
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.firestore
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .add({
        'userId': widget.currentUserId,
        'username': widget.currentUsername,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!widget.videoId.startsWith('demo_')) {
        await widget.firestore
            .collection('videos')
            .doc(widget.videoId)
            .set(
          {
            'commentCount': FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );
      }

      if (widget.videoOwnerId.isNotEmpty &&
          widget.videoOwnerId != widget.currentUserId) {
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
        } catch (_) {}
      }

      _controller.clear();

      if (!mounted) return;

      setState(() {
        _sending = false;
      });

      Navigator.pop(context, 1);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _sending = false;
      });

      _showError('Comment করা যায়নি');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    final keyboardInset = mediaQuery.viewInsets.bottom;
    final systemBottomInset = mediaQuery.viewPadding.bottom;

    final bottomInset = keyboardInset > systemBottomInset
        ? keyboardInset
        : systemBottomInset;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: bottomInset,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.62,
        decoration: const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),

            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const SizedBox(width: 18),

                const Text(
                  'Comments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const Spacer(),

                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),

            const Divider(
              color: Colors.white10,
              height: 1,
            ),

            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.firestore
                    .collection('videos')
                    .doc(widget.videoId)
                    .collection('comments')
                    .limit(100)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet',
                        style: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    );
                  }

                  final comments = [...docs];

                  comments.sort((a, b) {
                    final aTime = a.data()['createdAt'];
                    final bTime = b.data()['createdAt'];

                    if (aTime is Timestamp &&
                        bTime is Timestamp) {
                      return aTime.compareTo(bTime);
                    }

                    return 0;
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      12,
                      18,
                      12,
                    ),
                    itemCount: comments.length,
                    itemBuilder: (_, index) {
                      final data = comments[index].data();

                      final username =
                          (data['username'] ?? 'PALOK User')
                              .toString();

                      final text =
                          (data['text'] ?? '').toString();

                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 17,
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration:
                                  const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFF2D55),
                                    Color(0xFF00E5FF),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight:
                                          FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),

                                  const SizedBox(height: 3),

                                  Text(
                                    text,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      height: 1.25,
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
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                10,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF151515),
                border: Border(
                  top: BorderSide(
                    color: Colors.white10,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        unawaited(_sendComment());
                      },
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor:
                            Colors.white.withOpacity(0.07),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  GestureDetector(
                    onTap: () {
                      unawaited(_sendComment());
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF2D55),
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
