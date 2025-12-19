import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PrivacyNotesScreen extends StatelessWidget {
  const PrivacyNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: const Text('Privacy & Notes'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Privacy Policy',
              content: '''
At GYAANSETU, we are committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application.

**Information We Collect:**
- Account information (email address)
- Learning data (classes, materials, quiz results)
- Device information for offline functionality
- Usage analytics to improve our services

**How We Use Your Information:**
- To provide and improve our educational services
- To personalize your learning experience
- To enable offline functionality
- To communicate important updates

**Data Security:**
- All data is encrypted in transit
- Offline data is stored securely on your device
- We do not share your personal information with third parties

**Your Rights:**
- Access your personal data
- Request data deletion
- Opt-out of data collection
- Export your learning data

For questions about this policy, please contact us at privacy@gyaansetu.com
              ''',
            ),
            const SizedBox(height: AppTheme.spacingXL),
            _buildSection(
              title: 'Terms of Service',
              content: '''
By using GYAANSETU, you agree to the following terms:

**User Responsibilities:**
- Use the app for educational purposes only
- Respect intellectual property rights
- Do not share account credentials
- Report any security issues

**Content Usage:**
- Educational materials are for personal use
- Do not redistribute content without permission
- Respect copyright and licensing terms

**Service Availability:**
- We strive for 99.9% uptime
- Offline mode ensures continuous access
- We may update or modify features

**Limitation of Liability:**
- We are not liable for indirect damages
- Service provided "as is"
- Users responsible for data backup

Last updated: January 2024
              ''',
            ),
            const SizedBox(height: AppTheme.spacingXL),
            _buildSection(
              title: 'Data Usage',
              content: '''
**Offline Storage:**
- Downloaded materials are stored locally
- Compressed to save storage space
- You can manage storage in Settings

**Data Sync:**
- Quiz results sync when online
- Class updates sync automatically
- You control what to download

**Analytics:**
- We collect anonymous usage data
- Helps us improve the app
- No personal information shared

**Third-Party Services:**
- Firebase for authentication
- Cloud storage for materials
- All services comply with privacy standards
              ''',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontFamily: 'Roboto',
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

