import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ------------------------------------------------------------
  // Firebase
  // ------------------------------------------------------------

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ------------------------------------------------------------
  // Controllers
  // ------------------------------------------------------------

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final TextEditingController _nameController =
      TextEditingController();

  // ------------------------------------------------------------
  // Focus nodes
  // ------------------------------------------------------------

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();

  // ------------------------------------------------------------
  // State
  // ------------------------------------------------------------

  bool _isLogin = true;
  bool _loading = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ------------------------------------------------------------
  // Animation
  // ------------------------------------------------------------

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // ------------------------------------------------------------
  // PALOK colors
  // ------------------------------------------------------------

  static const Color _pink = Color(0xFFFF2D55);
  static const Color _cyan = Color(0xFF00E5FF);

  // ------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 700,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();

    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();

    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _nameFocus.dispose();

    super.dispose();
  }

  // ============================================================
  // USER PROFILE
  // ============================================================

  Future<void> _ensureUserProfile(
    User user, {
    String? name,
  }) async {
    final DocumentReference<Map<String, dynamic>> userRef =
        _firestore.collection('users').doc(user.uid);

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await userRef.get();

    final String email = user.email?.trim() ?? '';

    final String displayNameFromAuth =
        user.displayName?.trim() ?? '';

    final String suppliedName =
        name?.trim() ?? '';

    final String displayName =
        suppliedName.isNotEmpty
            ? suppliedName
            : displayNameFromAuth;

    if (snapshot.exists) {
      // Existing profile.
      // Only fill missing important fields.
      final Map<String, dynamic> existing =
          snapshot.data() ?? {};

      final Map<String, dynamic> updates =
          <String, dynamic>{
        'uid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if ((existing['email'] as String? ?? '').isEmpty &&
          email.isNotEmpty) {
        updates['email'] = email;
      }

      if ((existing['name'] as String? ?? '').isEmpty &&
          displayName.isNotEmpty) {
        updates['name'] = displayName;
      }

      if ((existing['displayName'] as String? ?? '')
              .isEmpty &&
          displayName.isNotEmpty) {
        updates['displayName'] = displayName;
      }

      if (!existing.containsKey('followersCount')) {
        updates['followersCount'] = 0;
      }

      if (!existing.containsKey('followingCount')) {
        updates['followingCount'] = 0;
      }

      await userRef.set(
        updates,
        SetOptions(merge: true),
      );

      return;
    }

    // ----------------------------------------------------------
    // New profile
    // ----------------------------------------------------------

    final String username =
        _createUsername(
      displayName.isNotEmpty
          ? displayName
          : email.isNotEmpty
              ? email.split('@').first
              : 'palok_user',
      user.uid,
    );

    await userRef.set(
      <String, dynamic>{
        'uid': user.uid,
        'name': displayName,
        'displayName': displayName,
        'username': username,
        'bio': '',
        'email': email,
        'profileImage': user.photoURL ?? '',
        'followersCount': 0,
        'followingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  String _createUsername(
    String value,
    String uid,
  ) {
    String username = value
        .toLowerCase()
        .trim()
        .replaceAll(
          RegExp(r'[^a-z0-9._]'),
          '',
        );

    if (username.isEmpty) {
      username = 'palok_user';
    }

    if (username.length > 18) {
      username = username.substring(0, 18);
    }

    // Add a short UID suffix so new users are less likely
    // to collide with another username.
    final String suffix =
        uid.length >= 5 ? uid.substring(0, 5) : uid;

    username = '${username}_$suffix';

    if (username.length > 24) {
      username = username.substring(0, 24);
    }

    return username;
  }

  // ============================================================
  // EMAIL LOGIN / SIGNUP
  // ============================================================

  Future<void> _submitEmailAuth() async {
    if (_loading) {
      return;
    }

    FocusScope.of(context).unfocus();

    final String email =
        _emailController.text.trim();

    final String password =
        _passwordController.text;

    final String confirmPassword =
        _confirmPasswordController.text;

    final String name =
        _nameController.text.trim();

    // ----------------------------------------------------------
    // Validation
    // ----------------------------------------------------------

    if (email.isEmpty) {
      _showMessage(
        'Email address দিন।',
      );
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage(
        'সঠিক email address দিন।',
      );
      return;
    }

    if (password.isEmpty) {
      _showMessage(
        'Password দিন।',
      );
      return;
    }

    if (password.length < 6) {
      _showMessage(
        'Password কমপক্ষে 6 characters হতে হবে।',
      );
      return;
    }

    if (!_isLogin) {
      if (name.isEmpty) {
        _showMessage(
          'আপনার নাম দিন।',
        );
        return;
      }

      if (name.length < 2) {
        _showMessage(
          'নাম কমপক্ষে 2 characters হতে হবে।',
        );
        return;
      }

      if (confirmPassword.isEmpty) {
        _showMessage(
          'Confirm password দিন।',
        );
        return;
      }

      if (password != confirmPassword) {
        _showMessage(
          'দুইটি password একই নয়।',
        );
        return;
      }
    }

    setState(() {
      _loading = true;
    });

    try {
      if (_isLogin) {
        // ------------------------------------------------------
        // LOGIN
        // ------------------------------------------------------

        final UserCredential credential =
            await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final User? user = credential.user;

        if (user != null) {
          await _ensureUserProfile(user);
        }
      } else {
        // ------------------------------------------------------
        // SIGN UP
        // ------------------------------------------------------

        final UserCredential credential =
            await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final User? user = credential.user;

        if (user != null) {
          // Update Firebase Auth display name.
          await user.updateDisplayName(name);

          // Refresh user object.
          await user.reload();

          final User? refreshedUser =
              _auth.currentUser;

          if (refreshedUser != null) {
            await _ensureUserProfile(
              refreshedUser,
              name: name,
            );
          }
        }
      }

      // AuthGate in main.dart will automatically
      // navigate to HomeScreen.
    } on FirebaseAuthException catch (e) {
      _showFirebaseAuthError(e);
    } catch (e) {
      _showMessage(
        'কিছু সমস্যা হয়েছে। আবার চেষ্টা করুন।',
      );

      debugPrint(
        'Email authentication error: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // GOOGLE LOGIN
  // ============================================================

  Future<void> _signInWithGoogle() async {
    if (_loading) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    try {
      final GoogleSignIn googleSignIn =
          GoogleSignIn(
        scopes: <String>[
          'email',
        ],
      );

      // If an old Google session exists,
      // sign out first so the account picker can appear.
      try {
        await googleSignIn.signOut();
      } catch (_) {
        // Ignore sign-out errors.
      }

      final GoogleSignInAccount? googleUser =
          await googleSignIn.signIn();

      // User cancelled Google account selection.
      if (googleUser == null) {
        return;
      }

      final GoogleSignInAuthentication
          googleAuth =
          await googleUser.authentication;

      final String? accessToken =
          googleAuth.accessToken;

      final String? idToken =
          googleAuth.idToken;

      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'google-sign-in-failed',
          message:
              'Google ID token পাওয়া যায়নি।',
        );
      }

      final OAuthCredential credential =
          GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(
        credential,
      );

      final User? user =
          userCredential.user;

      if (user != null) {
        await _ensureUserProfile(user);
      }

      // AuthGate handles navigation.
    } on FirebaseAuthException catch (e) {
      _showFirebaseAuthError(e);
    } catch (e) {
      debugPrint(
        'Google sign-in error: $e',
      );

      _showMessage(
        'Google দিয়ে Login করা যায়নি। '
        'আবার চেষ্টা করুন।',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> _forgotPassword() async {
    if (_loading) {
      return;
    }

    final String email =
        _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage(
        'আগে আপনার email address দিন।',
      );

      _emailFocus.requestFocus();
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage(
        'সঠিক email address দিন।',
      );

      _emailFocus.requestFocus();
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _auth.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Password reset email পাঠানো হয়েছে।',
      );
    } on FirebaseAuthException catch (e) {
      _showFirebaseAuthError(e);
    } catch (e) {
      debugPrint(
        'Password reset error: $e',
      );

      _showMessage(
        'Password reset করা যায়নি।',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // TOGGLE LOGIN / SIGNUP
  // ============================================================

  void _toggleAuthMode() {
    if (_loading) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLogin = !_isLogin;

      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  // ============================================================
  // FIREBASE AUTH ERROR
  // ============================================================

  void _showFirebaseAuthError(
    FirebaseAuthException e,
  ) {
    String message;

    switch (e.code) {
      case 'invalid-email':
        message =
            'Email address সঠিক নয়।';
        break;

      case 'user-not-found':
        message =
            'এই email দিয়ে কোনো account পাওয়া যায়নি।';
        break;

      case 'wrong-password':
      case 'invalid-credential':
        message =
            'Email অথবা password সঠিক নয়।';
        break;

      case 'email-already-in-use':
        message =
            'এই email দিয়ে ইতিমধ্যে account আছে।';
        break;

      case 'weak-password':
        message =
            'Password আরও শক্তিশালী দিন।';
        break;

      case 'user-disabled':
        message =
            'এই accountটি disabled করা হয়েছে।';
        break;

      case 'too-many-requests':
        message =
            'অনেকবার চেষ্টা করা হয়েছে। '
            'কিছুক্ষণ পরে আবার চেষ্টা করুন।';
        break;

      case 'network-request-failed':
        message =
            'Internet connection সমস্যা হয়েছে।';
        break;

      case 'operation-not-allowed':
        message =
            'এই login method Firebase Console-এ '
            'enable করা নেই।';
        break;

      case 'account-exists-with-different-credential':
        message =
            'এই email অন্য একটি login method-এর সঙ্গে '
            'যুক্ত আছে।';
        break;

      default:
        message =
            e.message?.trim().isNotEmpty == true
                ? e.message!.trim()
                : 'Authentication failed। আবার চেষ্টা করুন।';
    }

    _showMessage(message);
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final Size size =
        MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        child: Stack(
          children: [
            // ----------------------------------------------------
            // Background glow
            // ----------------------------------------------------

            Positioned(
              top: -150,
              left: -100,
              child: _GlowCircle(
                color: _pink,
                size: 280,
              ),
            ),

            Positioned(
              top: 100,
              right: -160,
              child: _GlowCircle(
                color: _cyan,
                size: 300,
              ),
            ),

            // ----------------------------------------------------
            // Main content
            // ----------------------------------------------------

            Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,

                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),

                child: FadeTransition(
                  opacity: _fadeAnimation,

                  child: SlideTransition(
                    position: _slideAnimation,

                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(
                        maxWidth: 460,
                      ),

                      child: Column(
                        children: [
                          // ------------------------------------------------
                          // Logo
                          // ------------------------------------------------

                          _buildLogo(),

                          const SizedBox(height: 14),

                          Text(
                            _isLogin
                                ? 'Welcome back'
                                : 'Create your account',

                            style: TextStyle(
                              color: Colors.white
                                  .withValues(
                                alpha: 0.85,
                              ),
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 34),

                          // ------------------------------------------------
                          // Form card
                          // ------------------------------------------------

                          Container(
                            width: double.infinity,

                            padding:
                                const EdgeInsets.all(
                              20,
                            ),

                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFF101010,
                              ),

                              borderRadius:
                                  BorderRadius.circular(
                                24,
                              ),

                              border: Border.all(
                                color: Colors.white
                                    .withValues(
                                  alpha: 0.07,
                                ),
                              ),

                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 30,
                                  offset:
                                      const Offset(
                                    0,
                                    15,
                                  ),
                                ),
                              ],
                            ),

                            child: Column(
                              children: [
                                // ------------------------------------------
                                // Name - Signup only
                                // ------------------------------------------

                                if (!_isLogin) ...[
                                  _buildTextField(
                                    controller:
                                        _nameController,
                                    focusNode:
                                        _nameFocus,
                                    label: 'Name',
                                    hint:
                                        'আপনার নাম',
                                    icon: Icons
                                        .person_outline_rounded,
                                    textInputAction:
                                        TextInputAction
                                            .next,
                                    onSubmitted: (_) {
                                      _emailFocus
                                          .requestFocus();
                                    },
                                  ),

                                  const SizedBox(
                                    height: 14,
                                  ),
                                ],

                                // ------------------------------------------
                                // Email
                                // ------------------------------------------

                                _buildTextField(
                                  controller:
                                      _emailController,
                                  focusNode:
                                      _emailFocus,
                                  label: 'Email',
                                  hint:
                                      'you@example.com',
                                  icon: Icons
                                      .email_outlined,
                                  keyboardType:
                                      TextInputType
                                          .emailAddress,
                                  textInputAction:
                                      TextInputAction
                                          .next,
                                  onSubmitted: (_) {
                                    _passwordFocus
                                        .requestFocus();
                                  },
                                ),

                                const SizedBox(
                                  height: 14,
                                ),

                                // ------------------------------------------
                                // Password
                                // ------------------------------------------

                                _buildTextField(
                                  controller:
                                      _passwordController,
                                  focusNode:
                                      _passwordFocus,
                                  label: 'Password',
                                  hint:
                                      '••••••••',
                                  icon: Icons
                                      .lock_outline_rounded,
                                  obscureText:
                                      _obscurePassword,
                                  textInputAction:
                                      _isLogin
                                          ? TextInputAction
                                              .done
                                          : TextInputAction
                                              .next,
                                  suffixIcon:
                                      IconButton(
                                    onPressed:
                                        () {
                                      setState(() {
                                        _obscurePassword =
                                            !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons
                                              .visibility_off_outlined
                                          : Icons
                                              .visibility_outlined,
                                      color: Colors
                                          .white54,
                                    ),
                                  ),
                                  onSubmitted: (_) {
                                    if (_isLogin) {
                                      _submitEmailAuth();
                                    } else {
                                      _confirmPasswordFocus
                                          .requestFocus();
                                    }
                                  },
                                ),

                                // ------------------------------------------
                                // Confirm password
                                // ------------------------------------------

                                if (!_isLogin) ...[
                                  const SizedBox(
                                    height: 14,
                                  ),

                                  _buildTextField(
                                    controller:
                                        _confirmPasswordController,
                                    focusNode:
                                        _confirmPasswordFocus,
                                    label:
                                        'Confirm Password',
                                    hint:
                                        '••••••••',
                                    icon: Icons
                                        .lock_reset_outlined,
                                    obscureText:
                                        _obscureConfirmPassword,
                                    textInputAction:
                                        TextInputAction
                                            .done,
                                    suffixIcon:
                                        IconButton(
                                      onPressed:
                                          () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons
                                                .visibility_off_outlined
                                            : Icons
                                                .visibility_outlined,
                                        color: Colors
                                            .white54,
                                      ),
                                    ),
                                    onSubmitted:
                                        (_) {
                                      _submitEmailAuth();
                                    },
                                  ),
                                ],

                                // ------------------------------------------
                                // Forgot password
                                // ------------------------------------------

                                if (_isLogin) ...[
                                  const SizedBox(
                                    height: 8,
                                  ),

                                  Align(
                                    alignment:
                                        Alignment
                                            .centerRight,

                                    child:
                                        TextButton(
                                      onPressed:
                                          _loading
                                              ? null
                                              : _forgotPassword,
                                      child:
                                          const Text(
                                        'Forgot password?',
                                        style:
                                            TextStyle(
                                          color:
                                              _cyan,
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(
                                  height: 8,
                                ),

                                // ------------------------------------------
                                // Main button
                                // ------------------------------------------

                                SizedBox(
                                  width:
                                      double.infinity,
                                  height: 54,

                                  child:
                                      ElevatedButton(
                                    onPressed:
                                        _loading
                                            ? null
                                            : _submitEmailAuth,

                                    style:
                                        ElevatedButton
                                            .styleFrom(
                                      backgroundColor:
                                          _pink,
                                      disabledBackgroundColor:
                                          _pink.withValues(
                                        alpha: 0.45,
                                      ),
                                      foregroundColor:
                                          Colors.white,
                                      elevation: 0,
                                      shape:
                                          RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          15,
                                        ),
                                      ),
                                    ),

                                    child: _loading
                                        ? const SizedBox(
                                            width: 23,
                                            height: 23,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth:
                                                  2.4,
                                              color: Colors
                                                  .white,
                                            ),
                                          )
                                        : Text(
                                            _isLogin
                                                ? 'Login'
                                                : 'Create Account',
                                            style:
                                                const TextStyle(
                                              fontSize:
                                                  16,
                                              fontWeight:
                                                  FontWeight
                                                      .w700,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(
                                  height: 22,
                                ),

                                // ------------------------------------------
                                // Divider
                                // ------------------------------------------

                                Row(
                                  children: [
                                    Expanded(
                                      child:
                                          Divider(
                                        color: Colors
                                            .white
                                            .withValues(
                                          alpha: 0.10,
                                        ),
                                      ),
                                    ),

                                    Padding(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 14,
                                      ),
                                      child: Text(
                                        'OR',
                                        style:
                                            TextStyle(
                                          color: Colors
                                              .white
                                              .withValues(
                                            alpha: 0.45,
                                          ),
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                        ),
                                      ),
                                    ),

                                    Expanded(
                                      child:
                                          Divider(
                                        color: Colors
                                            .white
                                            .withValues(
                                          alpha: 0.10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(
                                  height: 22,
                                ),

                                // ------------------------------------------
                                // Google
                                // ------------------------------------------

                                SizedBox(
                                  width:
                                      double.infinity,
                                  height: 52,

                                  child:
                                      OutlinedButton.icon(
                                    onPressed:
                                        _loading
                                            ? null
                                            : _signInWithGoogle,

                                    style:
                                        OutlinedButton
                                            .styleFrom(
                                      foregroundColor:
                                          Colors.white,
                                      side:
                                          BorderSide(
                                        color: Colors
                                            .white
                                            .withValues(
                                          alpha: 0.14,
                                        ),
                                      ),
                                      shape:
                                          RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          15,
                                        ),
                                      ),
                                    ),

                                    icon: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth:
                                                  2,
                                              color: Colors
                                                  .white,
                                            ),
                                          )
                                        : const _GoogleIcon(),

                                    label: const Text(
                                      'Continue with Google',
                                      style:
                                          TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight
                                                .w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(
                            height: 24,
                          ),

                          // ------------------------------------------------
                          // Login / Signup switch
                          // ------------------------------------------------

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              Text(
                                _isLogin
                                    ? "Don't have an account?"
                                    : 'Already have an account?',

                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(
                                    alpha: 0.55,
                                  ),
                                  fontSize: 14,
                                ),
                              ),

                              TextButton(
                                onPressed:
                                    _loading
                                        ? null
                                        : _toggleAuthMode,
                                child: Text(
                                  _isLogin
                                      ? 'Sign up'
                                      : 'Login',
                                  style:
                                      const TextStyle(
                                    color: _cyan,
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          Text(
                            'PALOK • Create. Share. Connect.',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              color: Colors.white
                                  .withValues(
                                alpha: 0.28,
                              ),
                              fontSize: 11,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ----------------------------------------------------
            // Small top logo
            // ----------------------------------------------------

            Positioned(
              top: 16,
              left: 20,
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context)
                      .unfocus();
                },
                child: const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.white24,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOGO
  // ============================================================

  Widget _buildLogo() {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          colors: [
            _pink,
            Color(0xFFFF4D8D),
            _cyan,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(bounds);
      },

      child: const Text(
        'PALOK',
        style: TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.w900,
          letterSpacing: 5,
          height: 1,
        ),
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white
                .withValues(alpha: 0.75),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 7),

        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          enabled: !_loading,
          onSubmitted: onSubmitted,

          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
          ),

          cursorColor: _pink,

          decoration: InputDecoration(
            hintText: hint,

            hintStyle: TextStyle(
              color: Colors.white
                  .withValues(alpha: 0.28),
            ),

            prefixIcon: Icon(
              icon,
              color: Colors.white54,
              size: 21,
            ),

            suffixIcon: suffixIcon,

            filled: true,
            fillColor: const Color(0xFF181818),

            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 16,
            ),

            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),

            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white
                    .withValues(alpha: 0.05),
              ),
            ),

            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide:
                  const BorderSide(
                color: _pink,
                width: 1.2,
              ),
            ),

            disabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white
                    .withValues(alpha: 0.03),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// GLOW CIRCLE
// ================================================================

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowCircle({
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,

        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.13),
              color.withValues(alpha: 0.04),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// GOOGLE ICON
// ================================================================

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,

      alignment: Alignment.center,

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(5),
      ),

      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
