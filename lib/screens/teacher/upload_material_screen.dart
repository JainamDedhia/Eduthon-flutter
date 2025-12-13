import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/firebase_config.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';

class UploadMaterialScreen extends StatefulWidget {
  const UploadMaterialScreen({super.key});

  @override
  State<UploadMaterialScreen> createState() => _UploadMaterialScreenState();
}

class _UploadMaterialScreenState extends State<UploadMaterialScreen> {
  bool _loading = false;
  String? _fileName;
  double? _uploadProgress;

  Future<void> _handlePickAndUpload() async {
    // Get classCode from route arguments
    final classCode = ModalRoute.of(context)?.settings.arguments as String?;
    if (classCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No class code provided')),
      );
      return;
    }

    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      setState(() {
        _loading = true;
        _fileName = fileName;
        _uploadProgress = 0;
      });

      // Upload to backend
      final dio = Dio();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
        'folder': classCode,
      });

      final response = await dio.post(
        'https://eduthon-backend.onrender.com/upload',
        data: formData,
        onSendProgress: (sent, total) {
          setState(() {
            _uploadProgress = sent / total;
          });
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Upload failed: ${response.statusMessage}');
      }

      final fileUrl = response.data['url'];

      // Add to Firestore
      await FirebaseConfig.firestore.collection('classes').doc(classCode).update({
        'materials': FieldValue.arrayUnion([
          {
            'name': fileName,
            'url': fileUrl,
            'uploadedAt': DateTime.now().toIso8601String(),
          }
        ])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ File uploaded successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _uploadProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Material'),
        backgroundColor: AppColors.surface,
        elevation: 0.5,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Upload Material', style: AppTextStyles.headline),
              const SizedBox(height: 40),
              if (_loading && _fileName != null) ...[
                Text(
                  'Uploading: $_fileName',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_uploadProgress != null)
                  LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 16),
                Text(
                  '${(_uploadProgress! * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.title,
                ),
              ] else ...[
                PrimaryButton(
                  label: 'Select & Upload File',
                  leading: const Icon(Icons.upload_file, color: Colors.white),
                  onPressed: _loading ? null : _handlePickAndUpload,
                ),
                const SizedBox(height: 20),
                SecondaryButton(
                  label: 'Back',
                  onPressed: () => Navigator.pop(context),
                  leading: const Icon(Icons.arrow_back, color: AppColors.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}