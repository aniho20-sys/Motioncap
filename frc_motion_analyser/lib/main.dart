import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/tokens.dart';

void main() {
  runApp(const MotionAnalyserApp());
}

class MotionAnalyserApp extends StatelessWidget {
  const MotionAnalyserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FRC Motion Analyser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.ink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.orange,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
