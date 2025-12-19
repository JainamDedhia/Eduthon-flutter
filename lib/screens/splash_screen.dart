import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../services/streak_service.dart';
import '../widgets/common/milestone_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkAuth();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

    // Check and update streak
    final streakIncremented = await StreakService.checkAndUpdateStreak();
    
    // Check for milestone achievement
    if (streakIncremented) {
      final milestone = await StreakService.checkForNewMilestone();
      if (milestone != null && mounted) {
        // Show milestone dialog after navigation
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            await MilestoneDialog.show(context, milestone);
          }
        });
      }
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
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo with shadow
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'Logo.jpg',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXL),
                    const Text(
                      'GYAANSETU',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.white,
                        letterSpacing: 2,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingL,
                        vertical: AppTheme.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                      ),
                      child: const Text(
                        'Learning without limits',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.white,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXXL),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    const Text(
                      'Checking session...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.white,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}