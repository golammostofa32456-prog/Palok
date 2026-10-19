

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerPhotoUrl;

  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _messageController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _sending = false;

  String get _myId => _auth.currentUser!.uid;

  String get _chatId {
    final ids = [_myId, widget.peerId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  DocumentReference<Map<String, dynamic>> get _chatRef =>
      _db.collection('chats').doc(_chatId);

  @override
  void initState() {
    super.initState();
    _prepareChat();
  }

  Future<void> _prepareChat() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || widget.peerId.isEmpty) return;

    try {
      final myDoc =
          await _db.collection('users').doc(currentUser.uid).get();
      final peerDoc =
          await _db.collection('users').doc(widget.peerId).get();

      final myData = myDoc.data() ?? {};
      final peerData = peerDoc.data() ?? {};

      final myName = (myData['username'] ??
              myData['displayName'] ??
              currentUser.displayName ??
              'PALOK User')
          .toString();

      final peerName = (peerData['username'] ??
              peerData['displayName'] ??
              widget.peerName)
          .toString();

      final myPhoto = (myData['profileImage'] ??
              myData['photoURL'] ??
              currentUser.photoURL ??
              '')
          .toString();

      final peerPhoto = (peerData['profileImage'] ??
              peerData['photoURL'] ??
              widget.peerPhotoUrl ??
              '')
          .toString();

      final snapshot = await _chatRef.get();

      if (!snapshot.exists) {
        await _chatRef.set({
          'participants': [_myId, widget.peerId],
          'participantNames': {
            _myId: myName,
            widget.peerId: peerName,
          },
          'participantPhotos': {
            _myId: myPhoto,
            widget.peerId: peerPhoto,
          },
          'lastMessage': '',
          'lastSenderId': '',
          'updatedAt': FieldValue.serverTimestamp(),
          'unreadCounts': {
            _myId: 0,
            widget.peerId: 0,
          },
        });
      } else {
        await _chatRef.update({
          'unreadCounts.$_myId': 0,
        });
      }
    } catch (e) {
      debugPrint('Prepare chat error: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _sending || _auth.currentUser == null) {
      return;
    }

    if (widget.peerId == _myId) {
      _showMessage('নিজেকে মেসেজ পাঠানো যাবে না।');
      return;
    }

    setState(() => _sending = true);

    try {
      final chatSnapshot = await _chatRef.get();

      if (!chatSnapshot.exists) {
        await _prepareChat();
      }

      final latestChat = await _chatRef.get();
      if (!latestChat.exists) {
        throw Exception('Chat তৈরি করা যায়নি।');
      }

      final chatData = latestChat.data()!;
      final participants = List<String>.from(
        chatData['participants'] ?? [],
      );

      if (!participants.contains(_myId) ||
          !participants.contains(widget.peerId)) {
        throw Exception('Chat participant পাওয়া যায়নি।');
      }

      final batch = _db.batch();
      final messageRef = _chatRef.collection('messages').doc();

      batch.set(messageRef, {
        'senderId': _myId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(_chatRef, {
        'lastMessage': text,
        'lastSenderId': _myId,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts.${widget.peerId}': FieldValue.increment(1),
      });

      await batch.commit();

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      _showMessage('মেসেজ পাঠানো যায়নি। Firebase Rules পরীক্ষা করুন।');
      debugPrint('Send message error: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('চ্যাট করতে লগইন করুন।')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFE2C55),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.peerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _chatRef
                  .collection('messages')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('মেসেজ লোড করা যায়নি।'),
                  );
                }

                if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 54,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'কথা বলা শুরু করুন!',
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final isMine = data['senderId'] == _myId;
                    final text = (data['text'] ?? '').toString();

                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.78,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMine
                              ? const Color(0xFFFE2C55)
                              : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMine ? 16 : 4),
                            bottomRight: Radius.circular(isMine ? 4 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(12),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 15,
                            color: isMine ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              color: Colors.white,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 5000,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'মেসেজ লিখুন...',
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFF1F1F4),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFE2C55),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(13),
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    tooltip: 'মেসেজ পাঠান',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final photo = widget.peerPhotoUrl?.trim() ?? '';

    return CircleAvatar(
      radius: 19,
      backgroundColor: Colors.white24,
      backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
      child: photo.isEmpty
          ? const Icon(Icons.person, color: Colors.white)
          : null,
    );
  }
}
