import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/primary_button.dart';

/// Milestone Celebration Dialog
/// Shows when user reaches streak milestones (7, 30, 100 days)
class MilestoneDialog extends StatelessWidget {
  final int milestone;

  const MilestoneDialog({
    super.key,
    required this.milestone,
  });

  static Future<void> show(BuildContext context, int milestone) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MilestoneDialog(milestone: milestone),
    );
  }

  String get _milestoneMessage {
    switch (milestone) {
      case 7:
        return 'Week Warrior!';
      case 30:
        return 'Monthly Master!';
      case 100:
        return 'Century Champion!';
      default:
        return 'Amazing Achievement!';
    }
  }

  String get _milestoneDescription {
    switch (milestone) {
      case 7:
        return 'You\'ve maintained a ${milestone}-day streak! Keep up the great work!';
      case 30:
        return 'Incredible! ${milestone} days of consistent learning. You\'re unstoppable!';
      case 100:
        return 'Outstanding! ${milestone} days of dedication. You\'re a true learning champion!';
      default:
        return 'Congratulations on your ${milestone}-day streak!';
    }
  }

  Color get _milestoneColor {
    switch (milestone) {
      case 7:
        return Colors.orange;
      case 30:
        return Colors.deepOrange;
      case 100:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _milestoneColor.withOpacity(0.1),
              _milestoneColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Fire Icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_milestoneColor, _milestoneColor.withOpacity(0.7)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _milestoneColor.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      color: AppTheme.white,
                      size: 64,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: AppTheme.spacingXL),

            // Milestone Number
            Text(
              '$milestone',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [_milestoneColor, _milestoneColor.withOpacity(0.7)],
                  ).createShader(
                    const Rect.fromLTWH(0, 0, 200, 100),
                  ),
                fontFamily: 'Roboto',
              ),
            ),

            const SizedBox(height: AppTheme.spacingS),

            // Days Text
            Text(
              'Days Streak!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _milestoneColor,
                fontFamily: 'Roboto',
              ),
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Title
            Text(
              _milestoneMessage,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontFamily: 'Roboto',
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppTheme.spacingM),

            // Description
            Text(
              _milestoneDescription,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                fontFamily: 'Roboto',
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppTheme.spacingXL),

            // Continue Button
            PrimaryButton(
              label: 'Continue',
              onPressed: () => Navigator.of(context).pop(),
              backgroundColor: _milestoneColor,
              icon: Icons.check_circle,
              width: 200,
            ),
          ],
        ),
      ),
    );
  }
}

