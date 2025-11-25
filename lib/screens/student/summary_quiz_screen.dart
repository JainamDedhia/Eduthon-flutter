// FILE: lib/screens/student/summary_quiz_screen.dart
import 'package:flutter/material.dart';
import '../../services/offline_db.dart';
import '../../services/summary_generator.dart';
import '../../models/models.dart';
import 'package:provider/provider.dart';
import '../../services/quiz_sync_service.dart';
import '../../providers/auth_provider.dart';

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

      // CRITICAL FIX: Properly cast the quiz data
      final summary = result['summary'] as String;
      final quizRaw = result['quiz'] as List<dynamic>;
      
      // Convert List<dynamic> to List<Map<String, dynamic>>
      final quiz = quizRaw.map((item) {
        if (item is Map<String, dynamic>) {
          return item;
        } else if (item is Map) {
          // Convert Map<dynamic, dynamic> to Map<String, dynamic>
          return Map<String, dynamic>.from(item);
        } else {
          throw Exception('Invalid quiz data format');
        }
      }).toList();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SummaryQuizResultScreen(
            fileName: file.name,
            summary: summary,
            quiz: quiz,
            classCode: file.classCode, // ← PASS THE CLASS CODE HERE
          ),
        ),
      );
    } catch (e) {
      print('❌ Error viewing results: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
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
class SummaryQuizResultScreen extends StatefulWidget {
  final String fileName;
  final String summary;
  final List<Map<String, dynamic>> quiz;
  final String classCode;

  const SummaryQuizResultScreen({
    super.key,
    required this.fileName,
    required this.summary,
    required this.quiz,
    required this.classCode,
  });

  @override
  State<SummaryQuizResultScreen> createState() => _SummaryQuizResultScreenState();
}

class _SummaryQuizResultScreenState extends State<SummaryQuizResultScreen> {
  // Track user's answers
  Map<int, String> userAnswers = {};
  bool showResults = false;

  // NEW: Save quiz result method
  Future<void> _saveQuizResult(int correctAnswers, int totalQuestions) async {
    try {
      // Get studentId from AuthProvider
      final studentId = await Future.microtask(() {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      return auth.user?.uid ?? 'unknown';
       });
      
      final result = QuizResult(
        studentId: studentId,
        classCode: widget.classCode,
        fileName: widget.fileName,
        score: ((correctAnswers / totalQuestions) * 100).toInt(),
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        userAnswers: userAnswers,
        quiz: widget.quiz,
        completedAt: DateTime.now().toIso8601String(),
        synced: false,
      );
      
      await QuizSyncService.saveQuizResultLocally(result);
      print('✅ Quiz result saved and queued for sync: $correctAnswers/$totalQuestions');
      
    } catch (e) {
      print('❌ Failed to save quiz result: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Result saved locally but sync failed: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _submitQuiz() {
    if (userAnswers.length < widget.quiz.length) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Incomplete Quiz'),
          content: Text(
            'You have answered ${userAnswers.length} out of ${widget.quiz.length} questions.\n\n'
            'Please answer all questions before submitting.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      showResults = true;
    });

    // Calculate score
    int correct = 0;
    for (int i = 0; i < widget.quiz.length; i++) {
      final question = widget.quiz[i];
      final correctAnswer = question['answer_label'] as String;
      if (userAnswers[i] == correctAnswer) {
        correct++;
      }
    }

    final score = (correct / widget.quiz.length * 100).toStringAsFixed(0);

    // ✅ CRITICAL FIX: Save the quiz result
    _saveQuizResult(correct, widget.quiz.length);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Quiz Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score%',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A90E2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You got $correct out of ${widget.quiz.length} correct!',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '✅ Result saved successfully!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                showResults = false;
                userAnswers.clear();
              });
            },
            child: const Text('Retry'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName),
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
                        widget.summary,
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
            widget.quiz.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No quiz questions generated',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The summary might be too short',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Quiz header
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: const Color(0xFFE3F2FD),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${userAnswers.length}/${widget.quiz.length} answered',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!showResults)
                              ElevatedButton(
                                onPressed: _submitQuiz,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF66BB6A),
                                ),
                                child: const Text('Submit Quiz'),
                              ),
                          ],
                        ),
                      ),
                      
                      // Questions list
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: widget.quiz.length,
                          itemBuilder: (context, index) => _buildQuizCard(widget.quiz[index], index),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard(Map<String, dynamic> q, int index) {
    try {
      final question = q['question'] as String? ?? 'Question unavailable';
      final answerLabel = q['answer_label'] as String? ?? 'A';
      final answerText = q['answer_text'] as String? ?? '';
      
      // Handle options properly
      final optionsRaw = q['options'];
      List<Map<String, dynamic>> options = [];
      
      if (optionsRaw is List) {
        options = optionsRaw.map((opt) {
          if (opt is Map<String, dynamic>) {
            return opt;
          } else if (opt is Map) {
            return Map<String, dynamic>.from(opt);
          } else {
            return {'label': 'X', 'text': 'Invalid option'};
          }
        }).toList();
      }

      final userAnswer = userAnswers[index];

      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Q${index + 1}. $question',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Options
              ...options.map((opt) {
                final label = opt['label'] as String? ?? '?';
                final text = opt['text'] as String? ?? 'Option unavailable';
                final isSelected = userAnswer == label;
                final isCorrect = label == answerLabel;
                
                // Determine color
                Color? backgroundColor;
                Color? textColor;
                
                if (showResults) {
                  if (isCorrect) {
                    backgroundColor = Colors.green[100];
                    textColor = Colors.green[900];
                  } else if (isSelected && !isCorrect) {
                    backgroundColor = Colors.red[100];
                    textColor = Colors.red[900];
                  }
                } else if (isSelected) {
                  backgroundColor = const Color(0xFFE3F2FD);
                  textColor = const Color(0xFF1976D2);
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: showResults ? null : () {
                      setState(() {
                        userAnswers[index] = label;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: backgroundColor ?? Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected 
                            ? const Color(0xFF4A90E2) 
                            : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: showResults && isCorrect 
                                ? Colors.green 
                                : isSelected 
                                  ? const Color(0xFF4A90E2) 
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: (showResults && isCorrect) || isSelected 
                                  ? Colors.white 
                                  : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: textColor,
                              ),
                            ),
                          ),
                          if (showResults && isCorrect)
                            const Icon(Icons.check_circle, color: Colors.green),
                          if (showResults && isSelected && !isCorrect)
                            const Icon(Icons.cancel, color: Colors.red),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              
              // Show correct answer after submission
              if (showResults)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Correct Answer: $answerLabel - $answerText',
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
            ],
          ),
        ),
      );
    } catch (e) {
      print('❌ Error rendering quiz card: $e');
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error displaying question ${index + 1}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
  }
}