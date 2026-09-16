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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String _email = '';
  String _profileImage = '';

  static const Color palokPink = Color(0xFFFF2D55);
  static const Color cardColor = Color(0xFF18181B);
  static const Color appBarColor = Color(0xFF101014);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

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

      final Map<String, dynamic>? data = doc.data();

      String name = '';
      String username = '';
      String bio = '';
      String profileImage = '';

      if (data != null) {
        name = (data['name'] ?? '').toString();

        if (name.isEmpty) {
          name = (data['displayName'] ?? '').toString();
        }

        username = (data['username'] ?? '').toString();
        bio = (data['bio'] ?? '').toString();

        profileImage = (data['profileImage'] ??
                data['photoUrl'] ??
                data['profilePhoto'] ??
                '')
            .toString();

        final String savedEmail = (data['email'] ?? '').toString();

        if (savedEmail.isNotEmpty) {
          _email = savedEmail;
        }
      }

      if (name.isEmpty) {
        name = user.displayName ?? '';
      }

      if (name.isEmpty) {
        name = user.email?.split('@').first ?? 'PALOK User';
      }

      if (username.isEmpty) {
        username = name;
      }

      _nameController.text = name;
      _usernameController.text = username;
      _bioController.text = bio;
      _profileImage = profileImage;

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile load failed: ${e.message ?? e.code}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile load failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> _saveProfile() async {
    if (_saving) return;

    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please login again.',
        isError: true,
      );
      return;
    }

    final String name = _nameController.text.trim();
    final String username = _usernameController.text.trim();
    final String bio = _bioController.text.trim();

    // ----------------------------------------------------------
    // NAME VALIDATION
    // ----------------------------------------------------------

    if (name.isEmpty) {
      _showMessage(
        'Name cannot be empty.',
        isError: true,
      );
      return;
    }

    if (name.length < 3) {
      _showMessage(
        'Name must be at least 3 characters.',
        isError: true,
      );
      return;
    }

    if (name.length > 50) {
      _showMessage(
        'Name cannot be longer than 50 characters.',
        isError: true,
      );
      return;
    }

    // ----------------------------------------------------------
    // USERNAME VALIDATION
    // ----------------------------------------------------------

    if (username.isEmpty) {
      _showMessage(
        'Username cannot be empty.',
        isError: true,
      );
      return;
    }

    if (username.length < 3) {
      _showMessage(
        'Username must be at least 3 characters.',
        isError: true,
      );
      return;
    }

    if (username.length > 30) {
      _showMessage(
        'Username cannot be longer than 30 characters.',
        isError: true,
      );
      return;
    }

    final RegExp usernameRegex = RegExp(
      r'^[a-zA-Z0-9._]+$',
    );

    if (!usernameRegex.hasMatch(username)) {
      _showMessage(
        'Username can only contain letters, numbers, dots and underscores.',
        isError: true,
      );
      return;
    }

    // ----------------------------------------------------------
    // BIO VALIDATION
    // ----------------------------------------------------------

    if (bio.length > 150) {
      _showMessage(
        'Bio cannot be longer than 150 characters.',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
    });

    try {
      // ========================================================
      // SAVE TO FIRESTORE
      // ========================================================

      final DocumentReference<Map<String, dynamic>> userRef =
          _firestore.collection('users').doc(user.uid);

      await userRef.set(
        {
          'name': name,
          'displayName': name,
          'username': username,
          'bio': bio,
          'email': user.email ?? _email,
          'profileImage': _profileImage,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // ========================================================
      // UPDATE FIREBASE AUTH PROFILE
      // ========================================================

      try {
        if (user.displayName != name) {
          await user.updateDisplayName(name);
        }
      } catch (_) {
        // Firestore save already succeeded.
      }

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      // ========================================================
      // SUCCESS
      // ========================================================

      _showMessage(
        'Profile saved successfully.',
        isError: false,
      );

      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        {
          'name': name,
          'displayName': name,
          'username': username,
          'bio': bio,
          'email': user.email ?? _email,
          'profileImage': _profileImage,
        },
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      String message;

      switch (e.code) {
        case 'permission-denied':
          message =
              'Firestore permission denied. Check Firestore Rules.';
          break;

        case 'unauthenticated':
          message =
              'Your login session expired. Please login again.';
          break;

        case 'network-request-failed':
          message =
              'Internet connection failed. Please try again.';
          break;

        case 'unavailable':
          message =
              'Firebase is temporarily unavailable. Please try again.';
          break;

        case 'failed-precondition':
          message =
              'Firestore is not ready. Please check Firebase setup.';
          break;

        default:
          message =
              'Save failed: ${e.message ?? e.code}';
      }

      _showMessage(
        message,
        isError: true,
        seconds: 5,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage(
        'Save failed: $e',
        isError: true,
        seconds: 5,
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    required bool isError,
    int seconds = 2,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor:
              isError ? Colors.red.shade700 : palokPink,
          duration: Duration(seconds: seconds),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: appBarColor,
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
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: Text(
              _saving ? 'Saving...' : 'Save',
              style: TextStyle(
                color: _saving
                    ? Colors.white38
                    : palokPink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: palokPink,
              ),
            )
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  45,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // PROFILE PHOTO
                    // ==================================================

                    Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 118,
                                height: 118,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient:
                                      const LinearGradient(
                                    colors: [
                                      Color(0xFF00E5FF),
                                      Color(0xFF8E7CC3),
                                      Color(0xFFFF2D55),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                padding:
                                    const EdgeInsets.all(3),
                                child: Container(
                                  decoration:
                                      const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black,
                                  ),
                                  child: ClipOval(
                                    child: _profileImage
                                            .isNotEmpty
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
                                                color:
                                                    Colors.white,
                                                size: 62,
                                              );
                                            },
                                          )
                                        : const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 62,
                                          ),
                                  ),
                                ),
                              ),

                              Container(
                                width: 38,
                                height: 38,
                                decoration:
                                    BoxDecoration(
                                  color: palokPink,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'Change photo',
                            style: TextStyle(
                              color: palokPink,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 38),

                    // ==================================================
                    // PROFILE INFORMATION
                    // ==================================================

                    const Text(
                      'Profile information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // NAME
                    _buildTextField(
                      controller: _nameController,
                      label: 'Name',
                      hintText: 'Your name',
                      prefixIcon:
                          Icons.person_outline_rounded,
                      maxLines: 1,
                      maxLength: 50,
                      textCapitalization:
                          TextCapitalization.words,
                    ),

                    const SizedBox(height: 22),

                    // USERNAME
                    _buildTextField(
                      controller: _usernameController,
                      label: 'Username',
                      hintText: 'username',
                      prefixIcon:
                          Icons.alternate_email_rounded,
                      maxLines: 1,
                      maxLength: 30,
                      textCapitalization:
                          TextCapitalization.none,
                    ),

                    const SizedBox(height: 22),

                    // BIO
                    _buildTextField(
                      controller: _bioController,
                      label: 'Bio',
                      hintText:
                          'Tell people about yourself',
                      prefixIcon:
                          Icons.edit_note_rounded,
                      maxLines: 5,
                      maxLength: 150,
                      textCapitalization:
                          TextCapitalization.sentences,
                    ),

                    const SizedBox(height: 30),

                    // ==================================================
                    // ACCOUNT INFORMATION
                    // ==================================================

                    const Text(
                      'Account information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius:
                            BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            color: Colors.white54,
                            size: 24,
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
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w500,
                                  ),
                                ),

                                const SizedBox(height: 5),

                                Text(
                                  _email.isEmpty
                                      ? 'No email'
                                      : _email,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          const Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.white38,
                            size: 22,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ==================================================
                    // SAVE CHANGES BUTTON
                    // ==================================================

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed:
                            _saving ? null : _saveProfile,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor: palokPink,
                          disabledBackgroundColor:
                              const Color(0xFF3A3A3A),
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save changes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight.w800,
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

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    required int maxLines,
    required int maxLength,
    required TextCapitalization textCapitalization,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,

      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w500,
      ),

      cursorColor: palokPink,

      decoration: InputDecoration(
        labelText: label,

        labelStyle: const TextStyle(
          color: Colors.white54,
          fontSize: 17,
        ),

        floatingLabelStyle: const TextStyle(
          color: palokPink,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),

        hintText: hintText,

        hintStyle: const TextStyle(
          color: Colors.white30,
          fontSize: 16,
        ),

        counterStyle: const TextStyle(
          color: Colors.white38,
          fontSize: 13,
        ),

        prefixIcon: Icon(
          prefixIcon,
          color: Colors.white54,
          size: 27,
        ),

        filled: true,
        fillColor: cardColor,

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Colors.white12),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Colors.white12),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: palokPink,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
