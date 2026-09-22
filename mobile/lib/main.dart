import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseApp? firebaseApp;
  Object? firebaseError;

  try {
    // Firebase আগে থেকেই initialized থাকলে আবার initialize করবে না।
    if (Firebase.apps.isEmpty) {
      firebaseApp = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      firebaseApp = Firebase.apps.first;
    }
  } catch (e) {
    firebaseError = e;

    // duplicate-app হলেও যদি Firebase app তৈরি হয়ে থাকে,
    // existing app ব্যবহার করার চেষ্টা করবে।
    try {
      if (Firebase.apps.isNotEmpty) {
        firebaseApp = Firebase.apps.first;
        firebaseError = null;
      }
    } catch (_) {
      // Ignore and keep the original Firebase error.
    }
  }

  runApp(
    PalokApp(
      firebaseApp: firebaseApp,
      firebaseError: firebaseError,
    ),
  );
}

class PalokApp extends StatelessWidget {
  final FirebaseApp? firebaseApp;
  final Object? firebaseError;

  const PalokApp({
    super.key,
    this.firebaseApp,
    this.firebaseError,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PALOK',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFFF2D55),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF2D55),
          secondary: Color(0xFF00E5FF),
          surface: Colors.black,
        ),
        useMaterial3: true,
      ),
      home: firebaseError != null
          ? FirebaseErrorScreen(
              error: firebaseError!,
            )
          : const SplashScreen(),
    );
  }
}

// ------------------------------------------------------------
// AUTH GATE
// ------------------------------------------------------------

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Firebase Auth এখনো loading হলে
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AuthLoadingScreen();
        }

        // Firebase Auth error
        if (snapshot.hasError) {
          return FirebaseErrorScreen(
            error: snapshot.error!,
          );
        }

        // User logged in
        if (snapshot.data != null) {
          return const HomeScreen();
        }

        // User logged out
        return const LoginScreen();
      },
    );
  }
}

// ------------------------------------------------------------
// AUTH LOADING SCREEN
// ------------------------------------------------------------

class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF2D55),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'PALOK',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// FIREBASE ERROR SCREEN
// ------------------------------------------------------------

class FirebaseErrorScreen extends StatefulWidget {
  final Object error;

  const FirebaseErrorScreen({
    super.key,
    required this.error,
  });

  @override
  State<FirebaseErrorScreen> createState() => _FirebaseErrorScreenState();
}

class _FirebaseErrorScreenState extends State<FirebaseErrorScreen> {
  bool _retrying = false;

  Future<void> _retryFirebase() async {
    if (_retrying) return;

    setState(() {
      _retrying = true;
    });

    Object? error;

    try {
      // Existing Firebase app থাকলে সেটাই ব্যবহার করবে।
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // Firebase Auth-এর সাথে connection পরীক্ষা
      FirebaseAuth.instance;

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const SplashScreen(),
        ),
        (route) => false,
      );

      return;
    } catch (e) {
      error = e;
    }

    if (!mounted) return;

    setState(() {
      _retrying = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error?.toString() ?? 'Firebase connection failed.',
        ),
      ),
    );
  }

  String _cleanError(Object error) {
    final text = error.toString();

    if (text.contains('duplicate-app')) {
      return 'Firebase ইতিমধ্যে চালু আছে। '
          'অ্যাপটি পুনরায় চালু করুন।';
    }

    if (text.contains('network')) {
      return 'ইন্টারনেট connection পরীক্ষা করুন।';
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 40,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error icon
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF2D55).withOpacity(0.12),
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    size: 58,
                    color: Color(0xFFFF2D55),
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  'PALOK',
                  style: TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Firebase connection failed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Please check your Firebase configuration '
                  'and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white60,
                  ),
                ),

                const SizedBox(height: 24),

                // Error details
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white10,
                    ),
                  ),
                  child: Text(
                    _cleanError(widget.error),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.white60,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Retry button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _retrying ? null : _retryFirebase,
                    icon: _retrying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                          ),
                    label: Text(
                      _retrying ? 'Connecting...' : 'Try Again',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D55),
                      disabledBackgroundColor:
                          const Color(0xFFFF2D55).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
