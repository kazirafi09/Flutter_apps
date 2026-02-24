import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Start a timer to hide the splash screen after 2.5 seconds
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800), // Speed of transition
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      // This builder adds a Fade transition effect
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _showSplash 
          ? const SplashScreen(key: ValueKey('splash')) 
          : StreamBuilder<User?>(
              key: const ValueKey('auth_stream'),
              stream: AuthService().userStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return const ChatScreen();
                } else {
                  return const LoginScreen();
                }
              },
            ),
    );
  }
}