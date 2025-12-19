import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Offline/Online status indicator badge
class OfflineIndicator extends StatelessWidget {
  final bool isOnline;
  final bool showLabel;

  const OfflineIndicator({
    super.key,
    required this.isOnline,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: isOnline ? AppTheme.successGreen : Colors.orange,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            color: AppTheme.white,
            size: 16,
          ),
          if (showLabel) ...[
            const SizedBox(width: AppTheme.spacingXS),
            Text(
              isOnline ? 'Online' : 'Offline',
              style: const TextStyle(
                color: AppTheme.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

