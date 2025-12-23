// FILE: lib/screens/student/personal_pdf_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/offline_db.dart';
import '../../models/models.dart';
import 'package:path_provider/path_provider.dart';

class PersonalPdfScreen extends StatefulWidget {
  const PersonalPdfScreen({super.key});

  @override
  State<PersonalPdfScreen> createState() => _PersonalPdfScreenState();
}

class _PersonalPdfScreenState extends State<PersonalPdfScreen> {
  List<FileRecord> _personalPdfs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPersonalPdfs();
  }

  Future<void> _loadPersonalPdfs() async {
    setState(() => _loading = true);
    try {
      // Get all files with classCode "personal"
      final files = await OfflineDB.getOfflineFiles('personal');
      final pdfFiles = files.where((f) => f.name.toLowerCase().endsWith('.pdf')).toList();
      setState(() {
        _personalPdfs = pdfFiles;
        _loading = false;
      });
      print('✅ Loaded ${pdfFiles.length} personal PDFs');
    } catch (e) {
      print('❌ Error loading personal PDFs: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAndSavePdf() async {
    try {
      // Pick PDF file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) {
        print('⚠️ No file selected');
        return;
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      // Check if file already exists
      final exists = await OfflineDB.checkFileExists('personal', fileName);
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ File "$fileName" already uploaded'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check file size (max 10 MB)
      final fileSize = await file.length();
      const maxSize = 10 * 1024 * 1024; // 10 MB
      
      if (fileSize > maxSize) {
        if (mounted) {
          _showFileTooLargeDialog(fileSize);
        }
        return;
      }

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Saving PDF...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Copy file to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final personalDir = Directory('${appDir.path}/personalFiles');
      
      if (!await personalDir.exists()) {
        await personalDir.create(recursive: true);
      }

      final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final localPath = '${personalDir.path}/$sanitizedName';
      
      await file.copy(localPath);

      // Save to database
      await OfflineDB.saveFileRecord(
        'personal',
        fileName,
        localPath,
        originalSize: fileSize,
      );

      await _loadPersonalPdfs();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('✅ PDF saved successfully!')),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error picking/saving PDF: $e');
      
      if (mounted) {
        // Close loading dialog if open
        Navigator.of(context, rootNavigator: true).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFileTooLargeDialog(int fileSize) {
    final sizeMB = (fileSize / 1024 / 1024).toStringAsFixed(1);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('File Too Large'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This PDF is too large for processing.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text('File size: $sizeMB MB'),
            Text('Maximum allowed: 10 MB'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, size: 18, color: Colors.orange[800]),
                      SizedBox(width: 6),
                      Text(
                        'Why this limit?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Large PDFs take too long to process\n'
                    '• Text extraction may fail\n'
                    '• AI summary quality decreases\n'
                    '• May cause app to crash',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange[900],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              '💡 Tips:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '• Try splitting the PDF into smaller sections\n'
              '• Compress the PDF using online tools\n'
              '• Remove unnecessary images/pages',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePdf(FileRecord file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete PDF'),
        content: Text('Delete "${file.name}"?\n\nThis will also delete any generated summaries and quizzes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Delete file
      final fileObj = File(file.localPath);
      if (await fileObj.exists()) {
        await fileObj.delete();
      }

      // Delete from database
      await OfflineDB.deleteFileRecord('personal', file.name);
      
      // Delete summary/quiz if exists
      await OfflineDB.deleteSummaryAndQuiz('personal', file.name);
      
      // Delete mind map if exists
      await OfflineDB.deleteMindMap('personal', file.name);

      await _loadPersonalPdfs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Deleted "${file.name}"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error deleting PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          '📄 My Personal PDFs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF4A90E2),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Info Banner
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.info, color: Color(0xFF4A90E2), size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Your Own PDFs',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Max 10 MB per file • Generate summaries & quizzes',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // PDF List
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _personalPdfs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _personalPdfs.length,
                        itemBuilder: (context, index) =>
                            _buildPdfCard(_personalPdfs[index]),
                      ),
          ),
        ],
      ),
      
      // Upload FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndSavePdf,
        icon: Icon(Icons.upload_file, size: 28),
        label: Text(
          'Upload PDF',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF66BB6A),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.upload_file,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Personal PDFs Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Upload your own PDFs to generate\nsummaries and quiz questions!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickAndSavePdf,
              icon: Icon(Icons.upload_file, size: 24),
              label: Text(
                'Upload Your First PDF',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF66BB6A),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfCard(FileRecord file) {
    final sizeMB = file.originalSize != null 
        ? (file.originalSize! / 1024 / 1024).toStringAsFixed(2)
        : 'Unknown';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File info
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFEF5350), Color(0xFFE53935)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Size: $sizeMB MB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deletePdf(file),
                  icon: Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete PDF',
                ),
              ],
            ),
            
            SizedBox(height: 16),
            Divider(height: 1),
            SizedBox(height: 16),
            
            // Action: Go to Summary/Quiz screen
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to summary/quiz screen with this file
                  Navigator.pushNamed(
                    context,
                    '/student/summary-quiz',
                    arguments: 'personal', // Pass "personal" as classCode
                  );
                },
                icon: Icon(Icons.auto_awesome, size: 20),
                label: Text(
                  'Generate Summary & Quiz',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}