import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
// import 'login_screen.dart'; // We will build this next!

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // 1. Tell it which stream to listen to
      stream: AuthService().userStream, 
      builder: (context, snapshot) {
        // 2. Check if the user is logged in
        if (snapshot.hasData) {
          return const ChatScreen();
        } else {
          // 3. If not, show the login screen (for now, use a Placeholder)
          return LoginScreen(); // We will implement this screen next!
        }
      },
    );
  }
}