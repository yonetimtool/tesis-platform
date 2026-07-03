import 'package:flutter/material.dart';

/// Acilista saklanan oturum kontrol edilirken gosterilen gecici ekran.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
