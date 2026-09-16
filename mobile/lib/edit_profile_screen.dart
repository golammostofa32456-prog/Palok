
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  File? _selectedImage;

  String _email = '';
  String _oldPhotoUrl = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('users').doc(user.uid).get();

      final data = snapshot.data();

      _email = user.email ?? '';

      if (data != null) {
        _nameController.text =
            (data['name'] ?? data['displayName'] ?? '').toString();

        _usernameController.text =
            (data['username'] ?? '').toString();

        _bioController.text =
            (data['bio'] ?? '').toString();

        _oldPhotoUrl =
            (data['photoUrl'] ?? data['profilePhoto'] ?? '').toString();
      }

      // যদি Firestore-এ username না থাকে,
      // Firebase Auth থেকে একটি default username তৈরি হবে।
      if (_usernameController.text.trim().isEmpty) {
        final emailName = (_email.split('@').first).trim();

        if (emailName.isNotEmpty) {
          _usernameController.text = emailName;
        }
      }

      // যদি Name না থাকে, Firebase-এর displayName ব্যবহার করবে।
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = user.displayName ?? '';
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Profile তথ্য লোড করা যায়নি।',
          isError: true,
        );
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 900,
        maxHeight: 900,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
      });
    } catch (e) {
      if (mounted) {
        _showMessage(
          'ছবি নির্বাচন করা যায়নি।',
          isError: true,
        );
      }
    }
  }

  Future<void> _takeProfilePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 900,
        maxHeight: 900,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
      });
    } catch (e) {
      if (mounted) {
        _showMessage(
          'ক্যামেরা থেকে ছবি নেওয়া যায়নি।',
          isError: true,
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Change profile photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 18),

                _photoOption(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickProfilePhoto();
                  },
                ),

                _photoOption(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take a photo',
                  onTap: () {
                    Navigator.pop(context);
                    _takeProfilePhoto();
                  },
                ),

                if (_selectedImage != null || _oldPhotoUrl.isNotEmpty)
                  _photoOption(
                    icon: Icons.delete_outline,
                    title: 'Remove photo',
                    onTap: () {
                      Navigator.pop(context);

                      setState(() {
                        _selectedImage = null;
                        _oldPhotoUrl = '';
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _photoOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 3,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white38,
      ),
    );
  }

  Future<void> _saveProfile() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'আপনি লগইন করা নেই।',
        isError: true,
      );
      return;
    }

    final String name = _nameController.text.trim();
    final String username =
        _usernameController.text.trim().replaceAll(' ', '');
    final String bio = _bioController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Name লিখুন।',
        isError: true,
      );
      return;
    }

    if (username.isEmpty) {
      _showMessage(
        'Username লিখুন।',
        isError: true,
      );
      return;
    }

    if (username.length < 3) {
      _showMessage(
        'Username কমপক্ষে ৩ অক্ষরের হতে হবে।',
        isError: true,
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // Username আগে অন্য কেউ ব্যবহার করছে কি না পরীক্ষা।
      final QuerySnapshot<Map<String, dynamic>> usernameQuery =
          await _firestore
              .collection('users')
              .where('username', isEqualTo: username)
              .limit(2)
              .get();

      final bool usernameTaken = usernameQuery.docs.any(
        (doc) => doc.id != user.uid,
      );

      if (usernameTaken) {
        if (mounted) {
          setState(() {
            _saving = false;
          });

          _showMessage(
            'এই username ইতিমধ্যে ব্যবহার করা হয়েছে।',
            isError: true,
          );
        }
        return;
      }

      final Map<String, dynamic> profileData = {
        'name': name,
        'displayName': name,
        'username': username,
        'bio': bio,
        'email': user.email ?? _email,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Profile photo remove করা হলে null save হবে।
      if (_oldPhotoUrl.isEmpty && _selectedImage == null) {
        profileData['photoUrl'] = '';
      } else if (_oldPhotoUrl.isNotEmpty && _selectedImage == null) {
        profileData['photoUrl'] = _oldPhotoUrl;
      }

      // নতুন local image আপাতত preview হিসেবে কাজ করবে।
      // Firebase Storage না থাকলে local image-এর path Firestore-এ
      // save করা হচ্ছে না।
      //
      // পরে Firebase Storage/Cloudinary যুক্ত করলে এখানে permanent
      // photo upload করা যাবে।

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
            profileData,
            SetOptions(merge: true),
          );

      // Firebase Auth-এর displayName-ও update হবে।
      await user.updateDisplayName(name);

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage(
        'Profile updated successfully',
      );

      // Profile screen-এ ফিরে যাবে।
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage(
        'Profile save করা যায়নি। আবার চেষ্টা করুন।',
        isError: true,
      );
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? const Color(0xFFB00020) : const Color(0xFF252525),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        ),
      );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Widget _buildProfilePhoto(User? user) {
    if (_selectedImage != null) {
      return ClipOval(
        child: Image.file(
          _selectedImage!,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        ),
      );
    }

    if (_oldPhotoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          _oldPhotoUrl,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _defaultProfileIcon();
          },
        ),
      );
    }

    return _defaultProfileIcon();
  }

  Widget _defaultProfileIcon() {
    return Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color(0xFF00D9FF),
            Color(0xFFFF2D55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 52,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
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
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(
            color: Colors.white70,
          ),
          hintStyle: const TextStyle(
            color: Colors.white30,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white60,
          ),
          filled: true,
          fillColor: const Color(0xFF171719),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Colors.white12,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFFF2D55),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

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
            size: 21,
          ),
          onPressed: _saving
              ? null
              : () {
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: (_saving || _loading)
                  ? null
                  : _saveProfile,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF2D55),
                        ),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Color(0xFFFF2D55),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF2D55),
                ),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PROFILE PHOTO
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _showPhotoOptions,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF00D9FF),
                                        Color(0xFFFF2D55),
                                      ],
                                    ),
                                  ),
                                  child: _buildProfilePhoto(user),
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
                          ),

                          const SizedBox(height: 12),

                          GestureDetector(
                            onTap: _showPhotoOptions,
                            child: const Text(
                              'Change photo',
                              style: TextStyle(
                                color: Color(0xFFFF2D55),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 34),

                    const Text(
                      'Profile information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _nameController,
                      label: 'Name',
                      hint: 'Your name',
                      icon: Icons.person_outline,
                      maxLength: 50,
                    ),

                    _buildTextField(
                      controller: _usernameController,
                      label: 'Username',
                      hint: 'username',
                      icon: Icons.alternate_email,
                      maxLength: 30,
                    ),

                    _buildTextField(
                      controller: _bioController,
                      label: 'Bio',
                      hint: 'Tell people about yourself',
                      icon: Icons.edit_note,
                      maxLines: 4,
                      maxLength: 150,
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Account information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171719),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            color: Colors.white60,
                            size: 23,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Email',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _email.isEmpty
                                      ? 'No email'
                                      : _email,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.lock_outline,
                            color: Colors.white30,
                            size: 19,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // BOTTOM SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFFF2D55),
                          disabledBackgroundColor:
                              const Color(0xFF5A1726),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation<
                                          Color>(
                                    Colors.white,
                                  ),
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
            ),
    );
  }
}
