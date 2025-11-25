// FILE: lib/screens/student/summary_quiz_screen.dart
import 'package:flutter/material.dart';
import '../../services/offline_db.dart';
import '../../services/summary_generator.dart';
import '../../models/models.dart';

class SummaryQuizScreen extends StatefulWidget {
  const SummaryQuizScreen({super.key});

  @override
  State<SummaryQuizScreen> createState() => _SummaryQuizScreenState();
}

class _SummaryQuizScreenState extends State<SummaryQuizScreen> {
  List<FileRecord> _offlineFiles = [];
  bool _loading = true;
  String? _processingFile;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadOfflineFiles();
  }

  Future<void> _loadOfflineFiles() async {
    setState(() => _loading = true);
    try {
      final files = await OfflineDB.getAllOfflineFiles();
      // Filter only PDFs
      final pdfFiles = files.where((f) => f.name.toLowerCase().endsWith('.pdf')).toList();
      setState(() {
        _offlineFiles = pdfFiles;
        _loading = false;
      });
      print('✅ Loaded ${pdfFiles.length} offline PDFs');
    } catch (e) {
      print('❌ Error loading offline files: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _generateSummaryAndQuiz(FileRecord file) async {
    setState(() {
      _processingFile = file.name;
      _progress = 0.0;
    });

    try {
      print('🔄 Starting summary & quiz generation for: ${file.name}');

      // Step 1: Extract text from PDF (20%)
      setState(() => _progress = 0.2);
      final text = await SummaryGenerator.extractTextFromPDF(file.localPath);
      
      if (text.isEmpty) {
        throw Exception('Could not extract text from PDF');
      }
      print('✅ Text extracted: ${text.length} characters');

      // Step 2: Generate summary (50%)
      setState(() => _progress = 0.5);
      final summary = await SummaryGenerator.generateSummary(text);
      print('✅ Summary generated: ${summary.length} characters');

      // Step 3: Generate quiz (80%)
      setState(() => _progress = 0.8);
      final quiz = await SummaryGenerator.generateQuiz(summary);
      print('✅ Quiz generated: ${quiz.length} questions');

      // Step 4: Save locally (100%)
      setState(() => _progress = 1.0);
      await OfflineDB.saveSummaryAndQuiz(
        file.classCode,
        file.name,
        summary,
        quiz,
      );
      print('✅ Summary & quiz saved locally');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Generated summary & ${quiz.length} questions!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error generating summary & quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _processingFile = null;
        _progress = 0.0;
      });
    }
  }

  Future<void> _viewResults(FileRecord file) async {
    try {
      final result = await OfflineDB.getSummaryAndQuiz(file.classCode, file.name);
      
      if (result == null) {
        throw Exception('No summary found. Generate it first!');
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SummaryQuizResultScreen(
            fileName: file.name,
            summary: result['summary'] as String,
            quiz: result['quiz'] as List<Map<String, dynamic>>,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 Summary & Quiz Generator'),
        backgroundColor: const Color(0xFF4A90E2),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _offlineFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No offline PDFs found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Download some materials first!',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Info banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: const Color(0xFFE3F2FD),
                      child: const Text(
                        '💡 Select a PDF to generate AI-powered summary and quiz questions',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1976D2),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Processing indicator
                    if (_processingFile != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.amber[50],
                        child: Column(
                          children: [
                            Text(
                              'Processing: $_processingFile',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF4A90E2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(_progress * 100).toInt()}%',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                    // PDF list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _offlineFiles.length,
                        itemBuilder: (context, index) =>
                            _buildFileCard(_offlineFiles[index]),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFileCard(FileRecord file) {
    final isProcessing = _processingFile == file.name;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          Icons.picture_as_pdf,
          color: isProcessing ? Colors.orange : const Color(0xFF4A90E2),
          size: 32,
        ),
        title: Text(
          file.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Class: ${file.classCode}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // View results button
                  IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.green),
                    tooltip: 'View Summary & Quiz',
                    onPressed: () => _viewResults(file),
                  ),
                  // Generate button
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, color: Color(0xFF4A90E2)),
                    tooltip: 'Generate Summary & Quiz',
                    onPressed: () => _generateSummaryAndQuiz(file),
                  ),
                ],
              ),
      ),
    );
  }
}

// Result viewing screen
class SummaryQuizResultScreen extends StatelessWidget {
  final String fileName;
  final String summary;
  final List<Map<String, dynamic>> quiz;

  const SummaryQuizResultScreen({
    super.key,
    required this.fileName,
    required this.summary,
    required this.quiz,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(fileName),
          backgroundColor: const Color(0xFF4A90E2),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.notes), text: 'Summary'),
              Tab(icon: Icon(Icons.quiz), text: 'Quiz'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Summary tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📝 Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Quiz tab
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: quiz.length,
              itemBuilder: (context, index) {
                final q = quiz[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Q${index + 1}. ${q['question']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...((q['options'] as List).map((opt) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: opt['label'] == q['answer_label']
                                          ? Colors.green
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      opt['label'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: opt['label'] == q['answer_label']
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      opt['text'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: opt['label'] == q['answer_label']
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ))),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '✅ Correct Answer: ${q['answer_label']} - ${q['answer_text']}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}