import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mosque_outlined, size: 80, color: Color(0xFFD4AF37)),
              SizedBox(height: 16),
              Text("Welcome", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Text("Talk to Quran", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)), // Updated
                  labelText: "Email Address",
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05), // Updated
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)), // Updated
                  labelText: "Password",
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05), // Updated
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide.none,
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 54), // Tall and wide
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: _isLoading ? null : () async {
                  setState(() {
                    _isLoading = true;
                  });
                  try {
                    await AuthService().signInwithEmailAndPassword(
                      _emailController.text, 
                      _passwordController.text
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Login failed: $e"))
                    );
                  } finally {
                    if (context.mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                }, 
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Login")
              ),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const RegisterScreen())
                    );
                  }, 
                  child: const Text("Don't have an account? Register")
              )
            ],
          ),
        ),
      ),
    );
  }
}