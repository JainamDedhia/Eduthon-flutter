import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/common/rounded_card.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  String? _selectedRole;
  bool _loading = false;

  Future<void> _handleRoleSelection() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a role'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.setUserRole(_selectedRole!);

      if (mounted) {
        if (_selectedRole == 'teacher') {
          Navigator.pushReplacementNamed(context, '/teacher/dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/student/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Text(
                'Select Your Role',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontFamily: 'Roboto',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingS),
              const Text(
                'Choose how you\'ll use GYAANSETU',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontFamily: 'Roboto',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingXXL),
              
              // Teacher Card
              _buildRoleCard(
                role: 'teacher',
                emoji: '👨‍🏫',
                title: 'Teacher',
                description: 'Create classes and share content with students',
                icon: Icons.school_outlined,
                color: AppTheme.primaryBlue,
              ),
              
              const SizedBox(height: AppTheme.spacingM),
              
              // Student Card
              _buildRoleCard(
                role: 'student',
                emoji: '👨‍🎓',
                title: 'Student',
                description: 'Join classes and access learning materials',
                icon: Icons.person_outline,
                color: AppTheme.successGreen,
              ),
              
              const SizedBox(height: AppTheme.spacingXXL),
              
              // Continue Button
              PrimaryButton(
                label: 'Continue',
                onPressed: _handleRoleSelection,
                isLoading: _loading,
                backgroundColor: _selectedRole == null
                    ? AppTheme.secondaryTextGrey
                    : AppTheme.primaryBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String emoji,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedRole == role;
    return RoundedCard(
      onTap: () => setState(() => _selectedRole = role),
      padding: const EdgeInsets.all(AppTheme.spacingL),
      color: isSelected
          ? color.withOpacity(0.1)
          : AppTheme.white,
      elevation: isSelected ? AppTheme.elevationMedium : AppTheme.elevationLow,
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : AppTheme.dividerGrey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            // Emoji/Icon
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Column(
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Icon(icon, color: color, size: 24),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : AppTheme.textPrimary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
            
            // Selection Indicator
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? color : AppTheme.secondaryTextGrey,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}