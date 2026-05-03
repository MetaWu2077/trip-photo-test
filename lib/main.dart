import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TripPhotoApp());
}

class TripPhotoApp extends StatelessWidget {
  const TripPhotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '旅途相册',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      home: const HomeScreen(),
    );
  }
}
