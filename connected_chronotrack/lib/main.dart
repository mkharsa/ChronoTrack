import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ChronoTrackApp());
}

class ChronoTrackApp extends StatelessWidget {
  const ChronoTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connected ChronoTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0077B6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
