import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _usernameController =
      TextEditingController();

  final TextEditingController _bioController =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String _email = '';
  String _profileImage = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      _email = user.email ?? '';

      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection('users').doc(user.uid).get();

      final data = doc.data();

      String username = '';

      if (data != null) {
        username = (data['username'] ?? '').toString();
        _profileImage = (data['profileImage'] ?? '').toString();
      }

      if (username.isEmpty) {
        username = user.displayName ?? '';
      }

      if (username.isEmpty) {
        username = user.email?.split('@').first ?? 'PALOK User';
      }

      _usernameController.text = username;

      if (data != null) {
        _bioController.text = (data['bio'] ?? '').toString();
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile load failed: $e'),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final String username = _usernameController.text.trim();
    final String bio = _bioController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username cannot be empty'),
        ),
      );
      return;
    }

    if (username.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username must be at least 3 characters'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _firestore.collection('users').doc(user.uid).set(
        {
          'username': username,
          'bio': bio,
          'email': user.email ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await user.updateDisplayName(username);

      await user.reload();

      if (!mounted) return;

      Navigator.pop(
        context,
        {
          'username': username,
          'bio': bio,
          'email': user.email ?? _email,
          'profileImage': _profileImage,
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile save failed: $e'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Edit profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: Text(
              'Save',
              style: TextStyle(
                color: _saving
                    ? Colors.white38
                    : const Color(0xFFFF2D55),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF2D55),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00E5FF),
                                    Color(0xFFFF2D55),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black,
                                ),
                                child: ClipOval(
                                  child: _profileImage.isNotEmpty
                                      ? Image.network(
                                          _profileImage,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                            return const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 58,
                                            );
                                          },
                                        )
                                      : const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 58,
                                        ),
                                ),
                              ),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF2D55),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Change photo',
                          style: TextStyle(
                            color: Color(0xFFFF2D55),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),

                  _buildLabel('Username'),

                  const SizedBox(height: 8),

                  _buildTextField(
                    controller: _usernameController,
                    hintText: 'Username',
                    prefixIcon: Icons.person_outline,
                    maxLength: 30,
                  ),

                  const SizedBox(height: 24),

                  _buildLabel('Bio'),

                  const SizedBox(height: 8),

                  _buildTextField(
                    controller: _bioController,
                    hintText: 'Tell people about yourself',
                    prefixIcon: Icons.edit_note,
                    maxLines: 4,
                    maxLength: 150,
                  ),

                  const SizedBox(height: 24),

                  _buildLabel('Email'),

                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 17,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          color: Colors.white54,
                          size: 21,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _email,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.lock_outline,
                          color: Colors.white30,
                          size: 18,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D55),
                        disabledBackgroundColor:
                            const Color(0xFF3A3A3A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save changes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),
      cursorColor: const Color(0xFFFF2D55),
      decoration: InputDecoration(
        counterStyle: const TextStyle(
          color: Colors.white38,
        ),
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Colors.white38,
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: Colors.white54,
        ),
        filled: true,
        fillColor: const Color(0xFF171717),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.white12,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.white12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFFF2D55),
            width: 1.3,
          ),
        ),
      ),
    );
  }
}
