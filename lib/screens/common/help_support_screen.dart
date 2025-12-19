import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/rounded_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/primary_button.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isExpanded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    if (_formKey.currentState!.validate()) {
      // TODO: Submit feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your feedback!'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _nameController.clear();
      _emailController.clear();
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FAQ Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildFAQItem(
              question: 'How do I join a class?',
              answer: 'Go to Dashboard and tap "Join Class". Enter the class code provided by your teacher.',
            ),
            _buildFAQItem(
              question: 'How does offline mode work?',
              answer: 'Download materials when online. Once downloaded, you can access them without internet. Enable offline mode in Settings.',
            ),
            _buildFAQItem(
              question: 'How do I generate a quiz?',
              answer: 'Go to Dashboard > AI Tools > Summary & Quiz. Upload a PDF and generate a quiz from it.',
            ),
            _buildFAQItem(
              question: 'Where are my downloaded files?',
              answer: 'Go to Profile > Settings > Manage Offline Content to view and manage all downloaded materials.',
            ),
            _buildFAQItem(
              question: 'How do I sync quiz results?',
              answer: 'Quiz results sync automatically when you\'re online. Check your internet connection if sync fails.',
            ),

            const SizedBox(height: AppTheme.spacingXL),

            // Contact Support Section
            RoundedCard(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  const Text(
                    'Email: support@gyaansetu.com',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  const Text(
                    'Phone: +91-XXX-XXX-XXXX',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingXL),

            // Feedback Form
            RoundedCard(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Send Feedback',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                          ),
                          onPressed: () => setState(() => _isExpanded = !_isExpanded),
                        ),
                      ],
                    ),
                    if (_isExpanded) ...[
                      const SizedBox(height: AppTheme.spacingM),
                      AppTextField(
                        controller: _nameController,
                        label: 'Your Name',
                        hint: 'Enter your name',
                        prefixIcon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      AppTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'Enter your email',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      AppTextField(
                        controller: _messageController,
                        label: 'Message',
                        hint: 'Enter your feedback or question',
                        prefixIcon: Icons.message_outlined,
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a message';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      PrimaryButton(
                        label: 'Send Feedback',
                        onPressed: _submitFeedback,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: RoundedCard(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              answer,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontFamily: 'Roboto',
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

