// ============================================
// FILE: lib/screens/student/join_class_screen.dart
// ============================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:claudetest/providers/auth_provider.dart';
import 'package:claudetest/config/firebase_config.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({super.key});

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> {
  final _classCodeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _classCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoinClass() async {
    final classCode = _classCodeController.text.trim().toUpperCase();

    if (classCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a class code')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) throw Exception('No user logged in');

      // Check if class exists
      final classDoc = await FirebaseConfig.firestore
          .collection('classes')
          .doc(classCode)
          .get();

      if (!classDoc.exists) {
        throw Exception('Invalid class code. Please check and try again.');
      }

      final classData = classDoc.data()!;

      // Check if already enrolled
      final students = List<String>.from(classData['students'] ?? []);
      if (students.contains(userId)) {
        throw Exception('You are already enrolled in this class.');
      }

      // Add student to class
      await FirebaseConfig.firestore
          .collection('classes')
          .doc(classCode)
          .update({
        'students': FieldValue.arrayUnion([userId])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You\'ve joined ${classData['className']}')),
        );
        Navigator.pop(context);
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
      appBar: AppBar(
        title: const Text('Join a Class'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Join a Class', style: AppTextStyles.headline),
            const SizedBox(height: 8),
            const Text(
              'Enter the class code shared by your teacher',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _classCodeController,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: AppTextStyles.headline.copyWith(letterSpacing: 4),
              decoration: InputDecoration(
                hintText: 'ABC123',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _handleJoinClass,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Join Class'),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '💡 Ask your teacher for the class code. It\'s a 6-character code like "ABC123".',
                style: AppTextStyles.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

