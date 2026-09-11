import 'package:flutter/material.dart';

void main() {
  runApp(const PalokApp());
}

class PalokApp extends StatelessWidget {
  const PalokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Palok',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const PalokHomePage(),
    );
  }
}

class PalokHomePage extends StatelessWidget {
  const PalokHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF151515),
                  Colors.black,
                ],
              ),
            ),
          ),

          const Center(
            child: Text(
              'PALOK',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.black87,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Icon(Icons.home, size: 28),
                  Icon(Icons.search, size: 28),
                  Icon(Icons.add_circle, size: 42),
                  Icon(Icons.notifications_none, size: 28),
                  Icon(Icons.person_outline, size: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
