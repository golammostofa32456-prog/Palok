import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

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
      home: const HomeScreen(),
    );
  }
}
