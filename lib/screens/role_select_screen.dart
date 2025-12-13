import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/buttons.dart';
import '../widgets/gyaansetu_logo.dart';
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
        const SnackBar(content: Text('Please select a role')),
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
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Center(child: GyaanSetuLogo(size: 74, showWordmark: false)),
              const SizedBox(height: 16),
              const Text('Select your role', style: AppTextStyles.headline, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              const Text(
                'Pick how you want to use GyaanSetu today.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              _buildRoleCard(
                role: 'teacher',
                emoji: '👩‍🏫',
                title: 'Teacher',
                description: 'Create classes, upload materials, track students.',
              ),
              const SizedBox(height: 14),
              _buildRoleCard(
                role: 'student',
                emoji: '👨‍🎓',
                title: 'Student',
                description: 'Join classes, learn offline, generate summaries.',
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: _selectedRole == null ? 'Select a role' : 'Continue as ${_selectedRole!}',
                busy: _loading,
                onPressed: _loading ? null : _handleRoleSelection,
              ),
              const SizedBox(height: 10),
              const Text(
                'You can switch later from settings.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
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
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
            width: isSelected ? 2.2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: isSelected ? 16 : 10,
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 42)),
            const SizedBox(height: 10),
            Text(title, style: AppTextStyles.title),
            const SizedBox(height: 6),
            Text(
              description,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}