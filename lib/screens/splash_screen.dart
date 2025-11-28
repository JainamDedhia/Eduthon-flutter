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
    print('🚀 [SplashScreen] Starting auth check...');
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // CRITICAL: Wait for AuthProvider to finish loading (Firebase session restore)
    print('⏳ [SplashScreen] Waiting for AuthProvider to load...');
    
    int attempts = 0;
    while (authProvider.loading && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    // Minimum splash screen time for better UX
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    print('👤 [SplashScreen] User: ${authProvider.user?.email}');
    print('🎭 [SplashScreen] Role: ${authProvider.userRole}');

    if (authProvider.user != null) {
      // User is logged in (session restored!)
      
      if (authProvider.userRole == null) {
        // Role not loaded yet - wait a bit more
        print('⏳ [SplashScreen] Role not loaded, waiting...');
        
        await Future.delayed(const Duration(seconds: 1));
        
        // Try to refresh user data
        await authProvider.refreshUserData();
        
        if (authProvider.userRole == null) {
          // Still no role - navigate to role select
          print('⚠️ [SplashScreen] No role found, going to role select');
          Navigator.pushReplacementNamed(context, '/role-select');
          return;
        }
      }
      
      // Navigate based on role
      print('✅ [SplashScreen] Session restored! Navigating to: ${authProvider.userRole}');
      
      if (authProvider.userRole == 'teacher') {
        Navigator.pushReplacementNamed(context, '/teacher/dashboard');
      } else if (authProvider.userRole == 'student') {
        Navigator.pushReplacementNamed(context, '/student/dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/role-select');
      }
    } else {
      // User not logged in
      print('ℹ️ [SplashScreen] No session found, going to home');
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
            // App Logo/Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.school,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'GyaanSetu',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A90E2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Offline-First Learning Platform',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Color(0xFF4A90E2)),
            const SizedBox(height: 16),
            Text(
              'Checking session...',
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