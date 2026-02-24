import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ensure the background color matches the start of your transition
      backgroundColor: const Color(0xFF0F2027), 
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF132A20), 
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mosque Icon with a slight shadow for depth
            Icon(
              Icons.mosque,
              size: 120,
              color: const Color(0xFFD4AF37),
              shadows: [
                Shadow(
                  blurRadius: 20,
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(0, 10),
                )
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              "Talk To Quran",
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              color: Color(0xFFD4AF37),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}