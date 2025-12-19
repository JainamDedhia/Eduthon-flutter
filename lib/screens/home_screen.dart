import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common/primary_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.secondaryBlue,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: AppTheme.spacingL,
              right: AppTheme.spacingL,
              top: AppTheme.spacingM,
              bottom: 0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo with enhanced styling
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                        spreadRadius: 5,
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
                
                // App Name with better typography
                const Text(
                  'GYAANSETU',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.white,
                    letterSpacing: 2,
                    fontFamily: 'Roboto',
                    height: 1.1,
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingL),
                
                // Tagline with enhanced styling
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingXL,
                    vertical: AppTheme.spacingM,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXL + 4),
                    border: Border.all(
                      color: AppTheme.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Text(
                    'Learning without limits',
                    style: TextStyle(
                      fontSize: 17,
                      color: AppTheme.white,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                // Login Button
                _buildBigButton(
                  context: context,
                  icon: Icons.login_rounded,
                  label: 'Login',
                  subtitle: 'Already have account',
                  color: AppTheme.white,
                  textColor: AppTheme.primaryBlue,
                  onTap: () => Navigator.pushNamed(context, '/login'),
                ),
                
                const SizedBox(height: AppTheme.spacingM),
                
                // Register Button
                _buildBigButton(
                  context: context,
                  icon: Icons.person_add_rounded,
                  label: 'Register',
                  subtitle: 'Create new account',
                  color: AppTheme.successGreen,
                  textColor: AppTheme.white,
                  onTap: () => Navigator.pushNamed(context, '/register'),
                ),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                // Features Row
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingL),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFeatureBadge(Icons.wifi_off, 'Works\nOffline'),
                      _buildFeatureBadge(Icons.download_rounded, 'Download\nContent'),
                      _buildFeatureBadge(Icons.quiz, 'AI Quiz\n& Summary'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBigButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            boxShadow: [
              BoxShadow(
                color: (color == AppTheme.white 
                    ? Colors.black 
                    : color).withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: (color == AppTheme.white 
                    ? Colors.black 
                    : color).withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS + 2),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: textColor),
              ),
              const SizedBox(width: AppTheme.spacingL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontFamily: 'Roboto',
                        letterSpacing: 0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS / 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withOpacity(0.75),
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: textColor.withOpacity(0.7),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: AppTheme.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: AppTheme.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: AppTheme.white, size: 24),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.white,
            height: 1.3,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}