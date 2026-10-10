
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileNotificationsScreen extends StatelessWidget {
  const ProfileNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'নোটিফিকেশন দেখতে লগইন করুন',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final notifications = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notifications.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'নোটিফিকেশন লোড করা যায়নি',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.pink),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    color: Colors.grey,
                    size: 64,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'এখনো কোনো নোটিফিকেশন নেই',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Colors.white12, height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final isRead = data['isRead'] == true;
              final message =
                  (data['message'] ?? 'নতুন নোটিফিকেশন').toString();

              return ListTile(
                leading: Icon(
                  data['type'] == 'follow'
                      ? Icons.person_add_alt_1
                      : Icons.notifications,
                  color: isRead ? Colors.grey : Colors.pink,
                ),
                title: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight:
                        isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  _formatDate(data['createdAt']),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () async {
                  if (!isRead) {
                    await doc.reference.update({'isRead': true});
                  }
                },
                trailing: isRead
                    ? null
                    : const Icon(
                        Icons.circle,
                        size: 9,
                        color: Colors.pink,
                      ),
              );
            },
          );
        },
      ),
    );
  }

  static String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return '';
  }
}
