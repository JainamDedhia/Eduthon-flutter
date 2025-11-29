// FILE: lib/screens/student/summary_quiz_screen.dart
import 'package:flutter/material.dart';
import '../../services/summary_generator.dart';
import '../../services/mind_map_generator.dart';
import '../../models/models.dart';
import 'package:provider/provider.dart';
import '../../services/quiz_sync_service.dart';
import '../../providers/auth_provider.dart';
import 'package:claudetest/services/llm_summary_service.dart';
import 'package:claudetest/services/offline_db.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart'; // 🆕 ADD
import '../../services/onboarding_service.dart'; // 🆕 ADD
// 🆕 ADD: TTS & STT services
import '../../services/tts_service.dart';
import '../../services/stt_service.dart';

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
  
  // 🆕 ADD: Onboarding keys
  final GlobalKey _fileListKey = GlobalKey();
  final GlobalKey _firstGenerateButtonKey = GlobalKey();
  final GlobalKey _firstViewButtonKey = GlobalKey();
  TutorialCoachMark? _tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    _loadOfflineFiles();
    
    // 🆕 ADD: Initialize onboarding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowOnboarding();
    });
  }

  // 🆕 ADD: Check and show onboarding
  Future<void> _checkAndShowOnboarding() async {
    final completed = await OnboardingService.isSummaryQuizCompleted();
    if (!completed && mounted && _offlineFiles.isNotEmpty) {
      await Future.delayed(Duration(milliseconds: 800));
      if (mounted) {
        _showOnboarding();
      }
    }
  }

  // 🆕 ADD: Create onboarding tutorial
  void _showOnboarding() {
    final targets = <TargetFocus>[];
    
    // Target 1: File List
    targets.add(
      TargetFocus(
        identify: "file_list",
        keyTarget: _fileListKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildOnboardingContent(
                icon: Icons.picture_as_pdf,
                title: '📄 Your PDFs',
                description: 'These are your downloaded PDF files.\nSelect any to generate summary & quiz!',
                onNext: () => controller.next(),
                onSkip: () => _skipOnboarding(controller),
              );
            },
          ),
        ],
      ),
    );
    
    // Target 2: Generate Button
    targets.add(
      TargetFocus(
        identify: "generate_button",
        keyTarget: _firstGenerateButtonKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildOnboardingContent(
                icon: Icons.auto_awesome,
                title: '✨ Generate AI Content',
                description: 'Tap this button to create:\n• Summary\n• Quiz questions\n• Mind map',
                onNext: () => controller.next(),
                onSkip: () => _skipOnboarding(controller),
              );
            },
          ),
        ],
      ),
    );
    
    // Target 3: View Button
    targets.add(
      TargetFocus(
        identify: "view_button",
        keyTarget: _firstViewButtonKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildOnboardingContent(
                icon: Icons.visibility,
                title: '👁️ View Results',
                description: 'After generating, tap here to:\n• Read summary\n• Take quiz\n• See mind map',
                onNext: () => _finishOnboarding(controller),
                onSkip: () => _skipOnboarding(controller),
                isLast: true,
              );
            },
          ),
        ],
      ),
    );
    
    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        OnboardingService.markSummaryQuizCompleted();
      },
      onSkip: () {
        OnboardingService.markSummaryQuizCompleted();
        return true;
      },
    );
    
    _tutorialCoachMark?.show(context: context);
  }

  // 🆕 ADD: Onboarding content widget
  Widget _buildOnboardingContent({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onNext,
    required VoidCallback onSkip,
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF4A90E2).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Color(0xFF4A90E2)),
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'Skip',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4A90E2),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isLast ? '✓ Got it!' : 'Next →',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _skipOnboarding(TutorialCoachMarkController controller) {
    controller.skip();
    OnboardingService.markSummaryQuizCompleted();
  }

  void _finishOnboarding(TutorialCoachMarkController controller) {
    controller.next();
    OnboardingService.markSummaryQuizCompleted();
  }

  Future<void> _loadOfflineFiles() async {
    setState(() => _loading = true);
    try {
      final files = await OfflineDB.getAllOfflineFiles();
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

  // UPDATED: Now also generates mind map
  Future<void> _generateSummaryQuizAndMindMap(FileRecord file) async {
    final modelAvailable = await LLMSummaryService.isModelAvailable();
    
    String? selectedLanguage;
    
    if (modelAvailable && mounted) {
      selectedLanguage = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.language, color: Color(0xFF4A90E2)),
              SizedBox(width: 8),
              Text('Select Language'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🤖 AI Model detected!\nChoose summary language:',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildLanguageOption(context, 'English', 'en', '🇬🇧'),
              const SizedBox(height: 12),
              _buildLanguageOption(context, 'हिंदी (Hindi)', 'hi', '🇮🇳'),
              const SizedBox(height: 12),
              _buildLanguageOption(context, 'मराठी (Marathi)', 'mr', '🇮🇳'),
            ],
          ),
        ),
      );
      
      if (selectedLanguage == null) return;
    }

    setState(() {
      _processingFile = file.name;
      _progress = 0.0;
    });

    try {
      print('🔄 Starting generation for: ${file.name}');

      // Step 1: Extract text (15%)
      setState(() => _progress = 0.15);
      final text = await SummaryGenerator.extractTextFromPDF(file.localPath);
      
      if (text.isEmpty) {
        throw Exception('Could not extract text from PDF');
      }

      String summary;
      List<Map<String, dynamic>> quiz;

      if (modelAvailable && selectedLanguage != null) {
        // LLM path
        setState(() => _progress = 0.4);
        summary = await LLMSummaryService.generateSummaryWithLLM(
          text: text,
          language: selectedLanguage,
        );

        setState(() => _progress = 0.65);
        quiz = await LLMSummaryService.generateQuizWithLLM(
          summary: summary,
          language: selectedLanguage,
          numQuestions: 5,
        );
      } else {
        // Script path
        setState(() => _progress = 0.4);
        summary = await SummaryGenerator.generateSummary(text);

        setState(() => _progress = 0.65);
        quiz = await SummaryGenerator.generateQuiz(summary);
      }

      // Step 4: Generate Mind Map (85%)
      setState(() => _progress = 0.85);
      print('🧠 Generating mind map...');
      
      final mindMap = await MindMapGenerator.generateMindMap(
        summary: summary,
        quiz: quiz,
        fileName: file.name,
      );

      // Step 5: Save everything (100%)
      setState(() => _progress = 1.0);
      
      await OfflineDB.saveSummaryAndQuiz(
        file.classCode,
        file.name,
        summary,
        quiz,
      );

      await OfflineDB.saveMindMap(
        file.classCode,
        file.name,
        mindMap.toJson(),
      );

      print('✅ Summary, Quiz, and Mind Map saved');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              modelAvailable 
                ? '✅ Generated with AI! Summary, Quiz & Mind Map ready!'
                : '✅ Summary, Quiz & Mind Map generated!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error: $e');
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
  
  Widget _buildLanguageOption(BuildContext context, String name, String code, String flag) {
    return InkWell(
      onTap: () => Navigator.pop(context, code),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4A90E2)),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewResults(FileRecord file) async {
    try {
      final result = await OfflineDB.getSummaryAndQuiz(file.classCode, file.name);
      final mindMapData = await OfflineDB.getMindMap(file.classCode, file.name);
      
      if (result == null) {
        throw Exception('No summary found. Generate it first!');
      }

      final summary = result['summary'] as String;
      final quizRaw = result['quiz'] as List<dynamic>;
      
      final quiz = quizRaw.map((item) {
        if (item is Map<String, dynamic>) {
          return item;
        } else if (item is Map) {
          return Map<String, dynamic>.from(item);
        } else {
          throw Exception('Invalid quiz data format');
        }
      }).toList();

      // Parse mind map if available
      MindMapNode? mindMap;
      if (mindMapData != null) {
        try {
          final mindMapJson = mindMapData['mindmap'] as Map<String, dynamic>;
          mindMap = MindMapNode.fromJson(mindMapJson);
        } catch (e) {
          print('⚠️ Failed to parse mind map: $e');
        }
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SummaryQuizResultScreen(
            fileName: file.name,
            summary: summary,
            quiz: quiz,
            classCode: file.classCode,
            mindMap: mindMap,
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
        title: const Text('📚 Summary, Quiz & Mind Map'),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: const Color(0xFFE3F2FD),
                      child: const Text(
                        '💡 Generate AI-powered summary, quiz & mind map from PDFs',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1976D2),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

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

                    Expanded(
                      child: ListView.builder(
                        key: _fileListKey, // 🆕 ADD KEY
                        padding: const EdgeInsets.all(16),
                        itemCount: _offlineFiles.length,
                        itemBuilder: (context, index) =>
                            _buildFileCard(_offlineFiles[index], index),
                      ),
                    ),
                  ],
                ),
    );
  }

  // 🆕 UPDATED: Added index parameter to only apply keys to first file card
  Widget _buildFileCard(FileRecord file, int index) {
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
                  IconButton(
                    key: index == 0 ? _firstViewButtonKey : null, // 🆕 ONLY apply to first view button
                    icon: const Icon(Icons.visibility, color: Colors.green),
                    tooltip: 'View Results',
                    onPressed: () => _viewResults(file),
                  ),
                  IconButton(
                    key: index == 0 ? _firstGenerateButtonKey : null, // 🆕 ONLY apply to first generate button
                    icon: const Icon(Icons.auto_awesome, color: Color(0xFF4A90E2)),
                    tooltip: 'Generate All',
                    onPressed: () => _generateSummaryQuizAndMindMap(file),
                  ),
                ],
              ),
      ),
    );
  }
}

// UPDATED Result Screen with TTS & STT
class SummaryQuizResultScreen extends StatefulWidget {
  final String fileName;
  final String summary;
  final List<Map<String, dynamic>> quiz;
  final String classCode;
  final MindMapNode? mindMap;

  const SummaryQuizResultScreen({
    super.key,
    required this.fileName,
    required this.summary,
    required this.quiz,
    required this.classCode,
    this.mindMap,
  });

  @override
  State<SummaryQuizResultScreen> createState() => _SummaryQuizResultScreenState();
}

class _SummaryQuizResultScreenState extends State<SummaryQuizResultScreen> {
  Map<int, String> userAnswers = {};
  bool showResults = false;
  
  // 🆕 ADD: TTS & STT instances
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  bool _isTTSSpeaking = false;
  bool _isSTTListening = false;
  int? _currentQuestionIndex; // Track which question is being read for voice input

  @override
  void initState() {
    super.initState();
    _initializeTTS();
  }

  // 🆕 ADD: Initialize TTS
  Future<void> _initializeTTS() async {
    try {
      await _ttsService.initialize();
      await _sttService.initialize();
      print('✅ [SummaryQuiz] TTS & STT initialized');
    } catch (e) {
      print('❌ [SummaryQuiz] TTS/STT initialization failed: $e');
    }
  }

  @override
  void dispose() {
    // Stop TTS when leaving screen
     _ttsService.clearCompletionHandler();
    _ttsService.stop();
    _sttService.dispose();
    super.dispose();
  }

  Future<void> _saveQuizResult(int correctAnswers, int totalQuestions) async {
    try {
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
      print('✅ Quiz result saved: $correctAnswers/$totalQuestions');
      
    } catch (e) {
      print('❌ Failed to save quiz result: $e');
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

    int correct = 0;
    for (int i = 0; i < widget.quiz.length; i++) {
      final question = widget.quiz[i];
      final correctAnswer = question['answer_label'] as String;
      if (userAnswers[i] == correctAnswer) {
        correct++;
      }
    }

    final score = (correct / widget.quiz.length * 100).toStringAsFixed(0);
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

  // 🆕 ADD: Toggle TTS for summary
  Future<void> _toggleSummaryTTS() async {
    if (_isTTSSpeaking) {
      await _ttsService.stop();
      setState(() => _isTTSSpeaking = false);
    } else {
      setState(() => _isTTSSpeaking = true);
      await _ttsService.speak(widget.summary);
      // Update state after completion
      await Future.delayed(Duration(milliseconds: 500));
      if (mounted && !_ttsService.isSpeaking) {
        setState(() => _isTTSSpeaking = false);
      }
    }
  }

  // FIXED _handleVoiceQuiz method for summary_quiz_screen.dart
  Future<void> _handleVoiceQuiz(int questionIndex) async {
  if (_isSTTListening) {
    // Stop current listening
    await _sttService.stopListening();
    setState(() {
      _isSTTListening = false;
      _currentQuestionIndex = null;
    });
    return;
  }

  final question = widget.quiz[questionIndex];
  final questionText = question['question'] as String? ?? '';
  final options = question['options'] as List<dynamic>? ?? [];

  // Build TTS text
  String ttsText = 'Question ${questionIndex + 1}. $questionText. ';
  
  for (final opt in options) {
    final label = opt['label'] as String? ?? '';
    final text = opt['text'] as String? ?? '';
    ttsText += 'Option $label: $text. ';
  }

  ttsText += 'Please say your answer: A, B, C, or D.';

  try {
    setState(() {
      _isTTSSpeaking = true;
      _currentQuestionIndex = questionIndex;
    });

    // ✅ PROPER FIX: Use completion callback instead of timing
    _ttsService.setOnCompletionHandler(() {
      print('✅ [VoiceQuiz] TTS ACTUALLY finished, now starting STT');
      
      // Check if still on the same question
      if (!mounted || _currentQuestionIndex != questionIndex) return;
      
      // Start STT after TTS truly finishes
      _startSTTForQuestion(questionIndex);
    });

    // Start speaking - DON'T await this!
    await _ttsService.speak(ttsText);
    
    // 🚫 DON'T put any STT code here! It will wait for completion callback
    
  } catch (e) {
    print('❌ [VoiceQuiz] Error: $e');
    _resetVoiceState();
  }
}

// 🆕 ADD: Separate method for starting STT
Future<void> _startSTTForQuestion(int questionIndex) async {
  if (!mounted || _currentQuestionIndex != questionIndex) return;
  
  // Check if STT is available
  final sttAvailable = await _sttService.isAvailable();
  if (!sttAvailable) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Speech recognition not available'),
          backgroundColor: Colors.red,
        ),
      );
    }
    _resetVoiceState();
    return;
  }

  // Start listening for answer
  setState(() {
    _isSTTListening = true;
    _isTTSSpeaking = false;
  });

  print('🎤 [VoiceQuiz] Starting STT after TTS finished...');
  
  await _sttService.startListening(
    onResult: (recognizedWords) {
      _handleVoiceAnswer(questionIndex, recognizedWords);
    },
  );

  // Auto-stop after 10 seconds
  Future.delayed(Duration(seconds: 10), () {
    if (mounted && _isSTTListening && _currentQuestionIndex == questionIndex) {
      _sttService.stopListening();
      setState(() {
        _isSTTListening = false;
        _currentQuestionIndex = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏱️ Voice input timed out'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  });
}

// 🆕 ADD: Reset voice state
void _resetVoiceState() {
  setState(() {
    _isTTSSpeaking = false;
    _isSTTListening = false;
    _currentQuestionIndex = null;
  });
}

  // 🆕 ADD: Handle voice answer
  void _handleVoiceAnswer(int questionIndex, String recognizedWords) {
    // Stop listening
    _sttService.stopListening();
    setState(() => _isSTTListening = false);

    // Parse answer (A, B, C, D)
    final words = recognizedWords.toUpperCase();
    String? selectedOption;

    // Try to match A, B, C, or D
    if (words.contains('A')) {
      selectedOption = 'A';
    } else if (words.contains('B')) {
      selectedOption = 'B';
    } else if (words.contains('C')) {
      selectedOption = 'C';
    } else if (words.contains('D')) {
      selectedOption = 'D';
    }

    if (selectedOption != null) {
      // Valid answer detected
      setState(() {
        userAnswers[questionIndex] = selectedOption!;
        _currentQuestionIndex = null;
      });

      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Selected: Option $selectedOption'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Speak confirmation
      _ttsService.speak('You selected option $selectedOption');
    } else {
      // Invalid answer
      setState(() => _currentQuestionIndex = null);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Could not recognize A, B, C, or D. Please try again.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Stop TTS when back button pressed
        await _ttsService.stop();
        await _sttService.dispose();
        return true;
      },
      child: DefaultTabController(
        length: widget.mindMap != null ? 3 : 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.fileName),
            backgroundColor: const Color(0xFF4A90E2),
            bottom: TabBar(
              tabs: [
                const Tab(icon: Icon(Icons.notes), text: 'Summary'),
                const Tab(icon: Icon(Icons.quiz), text: 'Quiz'),
                if (widget.mindMap != null)
                  const Tab(icon: Icon(Icons.account_tree), text: 'Mind Map'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildSummaryTab(),
              _buildQuizTab(),
              if (widget.mindMap != null) _buildMindMapTab(),
            ],
          ),
        ),
      ),
    );
  }

  // 🆕 UPDATED: Summary tab with TTS button
  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with TTS button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '📝 Summary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // 🆕 ADD: TTS Button
                  IconButton(
                    onPressed: _toggleSummaryTTS,
                    icon: AnimatedSwitcher(
                      duration: Duration(milliseconds: 300),
                      child: Icon(
                        _isTTSSpeaking ? Icons.stop_circle : Icons.volume_up,
                        key: ValueKey(_isTTSSpeaking),
                        color: _isTTSSpeaking ? Colors.red : Color(0xFF4A90E2),
                        size: 32,
                      ),
                    ),
                    tooltip: _isTTSSpeaking ? 'Stop Reading' : 'Read Aloud',
                  ),
                ],
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
    );
  }

  // 🆕 UPDATED: Quiz tab with voice controls
  Widget _buildQuizTab() {
    return widget.quiz.isEmpty
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
              ],
            ),
          )
        : Column(
            children: [
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
              
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.quiz.length,
                  itemBuilder: (context, index) => _buildQuizCard(widget.quiz[index], index),
                ),
              ),
            ],
          );
  }

  Widget _buildMindMapTab() {
    if (widget.mindMap == null) {
      return const Center(child: Text('No mind map available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_tree, color: Color(0xFF4A90E2), size: 28),
                  SizedBox(width: 12),
                  Text(
                    '🧠 Mind Map',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildMindMapTree(widget.mindMap!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMindMapTree(MindMapNode node) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMindMapNode(node),
        if (node.children.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: node.level == 0 ? 20.0 : 30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: node.children
                  .map((child) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildMindMapTree(child),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMindMapNode(MindMapNode node) {
    final colors = [
      const Color(0xFF4A90E2), // Blue - Root
      const Color(0xFF66BB6A), // Green - Level 1
      const Color(0xFFFF7043), // Orange - Level 2
    ];

    final color = colors[node.level.clamp(0, colors.length - 1)];
    
    final fontSizes = [20.0, 16.0, 14.0];
    final fontSize = fontSizes[node.level.clamp(0, fontSizes.length - 1)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            node.level == 0
                ? Icons.center_focus_strong
                : node.level == 1
                    ? Icons.folder
                    : Icons.label,
            color: color,
            size: fontSize + 4,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              node.title,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: node.level == 0 
                    ? FontWeight.bold 
                    : node.level == 1
                        ? FontWeight.w600
                        : FontWeight.normal,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 UPDATED: Quiz card with voice button
  Widget _buildQuizCard(Map<String, dynamic> q, int index) {
    try {
      final question = q['question'] as String? ?? 'Question unavailable';
      final answerLabel = q['answer_label'] as String? ?? 'A';
      final answerText = q['answer_text'] as String? ?? '';
      
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
      final isCurrentVoiceQuestion = _currentQuestionIndex == index;

      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question header with voice button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Q${index + 1}. $question',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 🆕 ADD: Voice Quiz Button
                  if (!showResults)
                    Container(
                      decoration: BoxDecoration(
                        color: isCurrentVoiceQuestion 
                            ? Colors.red.withOpacity(0.1) 
                            : Color(0xFF4A90E2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: () => _handleVoiceQuiz(index),
                        icon: AnimatedSwitcher(
                          duration: Duration(milliseconds: 300),
                          child: Icon(
                            isCurrentVoiceQuestion
                                ? (_isSTTListening ? Icons.mic : Icons.volume_up)
                                : Icons.mic_none,
                            key: ValueKey('$isCurrentVoiceQuestion-$_isSTTListening'),
                            color: isCurrentVoiceQuestion
                                ? (_isSTTListening ? Colors.red : Colors.orange)
                                : Color(0xFF4A90E2),
                            size: 24,
                          ),
                        ),
                        tooltip: isCurrentVoiceQuestion
                            ? (_isSTTListening ? 'Listening...' : 'Reading...')
                            : 'Voice Answer',
                      ),
                    ),
                ],
              ),
              
              // 🆕 ADD: Voice status indicator
              if (isCurrentVoiceQuestion) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSTTListening 
                        ? Colors.red.withOpacity(0.1) 
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isSTTListening ? Colors.red : Colors.orange,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            _isSTTListening ? Colors.red : Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isSTTListening
                              ? '🎤 Listening... Say A, B, C, or D'
                              : '🔊 Reading question aloud...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isSTTListening ? Colors.red : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Options
              ...options.map((opt) {
                final label = opt['label'] as String? ?? '?';
                final text = opt['text'] as String? ?? 'Option unavailable';
                final isSelected = userAnswer == label;
                final isCorrect = label == answerLabel;
                
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
              
              // Correct answer explanation
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