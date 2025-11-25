// This file contains all auth-related screens
// Save each class in separate files as indicated in comments

// ============================================
// FILE: lib/screens/splash_screen.dart
// ============================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.user != null) {
      if (authProvider.userRole == 'teacher') {
        Navigator.pushReplacementNamed(context, '/teacher/dashboard');
      } else if (authProvider.userRole == 'student') {
        Navigator.pushReplacementNamed(context, '/student/dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/role-select');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF4A90E2)),
            const SizedBox(height: 16),
            const Text(
              'Welcome to GyaanSetu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading your learning platform...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
