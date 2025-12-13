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
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../services/onboarding_service.dart';
import '../../services/tts_service.dart';
import '../../services/stt_service.dart';
import '../../services/translation_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/server_api_service.dart';
import '../../widgets/model_selection_dialog.dart';
import 'summary_quiz_online_service.dart';
import 'summary_quiz_offline_service.dart';
import 'onboarding_content_widgets.dart';
import 'chatbot_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';

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
  
  final GlobalKey _fileListKey = GlobalKey();
  final GlobalKey _firstGenerateButtonKey = GlobalKey();
  final GlobalKey _firstViewButtonKey = GlobalKey();
  TutorialCoachMark? _tutorialCoachMark;

  final TranslationService _translationService = TranslationService();

  @override
  void initState() {
    super.initState();
    _loadOfflineFiles();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowOnboarding();
    });
  }

  @override
  void dispose() {
    _translationService.dispose();
    super.dispose();
  }

  Future<void> _checkAndShowOnboarding() async {
    final completed = await OnboardingService.isSummaryQuizCompleted();
    if (!completed && mounted && _offlineFiles.isNotEmpty) {
      await Future.delayed(Duration(milliseconds: 800));
      if (mounted) {
        _showOnboarding();
      }
    }
  }

  void _showOnboarding() {
    final targets = <TargetFocus>[];
  
    targets.add(
      TargetFocus(
        identify: "generate_button",
        keyTarget: _firstGenerateButtonKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        paddingFocus: 3,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return OnboardingContentWidgets.buildOnboardingContent(
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
              return OnboardingContentWidgets.buildOnboardingContent(
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

  Future<void> _generateSummaryQuizAndMindMap(FileRecord file) async {
  // Check connectivity first
  final isOnline = await SummaryQuizOnlineService.checkConnectivity();

  if (!isOnline) {
    // No internet - use offline mode directly
    print('📴 [SummaryQuiz] No internet - using offline mode');
    await _generateOfflineMode(file);
    return;
  }

  // Has internet - check if server is healthy
  print('🌐 [SummaryQuiz] Checking server health...');
  final serverHealthy = await ServerAPIService.isServerHealthy();

  if (serverHealthy) {
    // Server is up - show model selection
    print('✅ [SummaryQuiz] Server healthy - showing model selection');
    await _generateWithServerAPI(file);
  } else {
    // Server is down - fallback to offline
    print('⚠️ [SummaryQuiz] Server unreachable - using offline mode');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📴 Server unavailable - using offline mode'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    
    await _generateOfflineMode(file);
  }
}
  Future<void> _generateWithServerAPI(FileRecord file) async {
    await SummaryQuizOnlineService.generateWithServerAPI(
      context: context,
      file: file,
      setProcessingFile: (value) => setState(() => _processingFile = value),
      setProgress: (value) => setState(() => _progress = value),
      onSuccess: () => print('✅ Online generation completed'),
      onError: (e) => print('❌ Online generation failed: $e'),
      onFallbackToOffline: () => _generateOfflineMode(file),
    );
  }

  Future<void> _generateOfflineMode(FileRecord file) async {
    await SummaryQuizOfflineService.generateOfflineMode(
      context: context,
      file: file,
      setProcessingFile: (value) => setState(() => _processingFile = value),
      setProgress: (value) => setState(() => _progress = value),
      onSuccess: () => print('✅ Offline generation completed'),
      onError: (e) => print('❌ Offline generation failed: $e'),
    );
  }

  Future<void> _viewResults(FileRecord file) async {
    try {
      final result = await OfflineDB.getSummaryAndQuiz(file.classCode, file.name);
      final mindMapData = await OfflineDB.getMindMap(file.classCode, file.name);
      
      if (result == null) {
        throw Exception('No summary found. Generate it first!');
      }

      final language = await _showLanguageSelectionDialog();
      if (language == null) return;

      String summary = result['summary'] as String;
      final quizRaw = result['quiz'] as List<dynamic>;
      
      List<Map<String, dynamic>> quiz = quizRaw.map((item) {
        if (item is Map<String, dynamic>) {
          return item;
        } else if (item is Map) {
          return Map<String, dynamic>.from(item);
        } else {
          throw Exception('Invalid quiz data format');
        }
      }).toList();

      if (language != 'en') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Translating to ${TranslationService.getLanguageName(language)}...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );

        try {
          summary = await _translationService.translate(summary, language);
          
          for (int i = 0; i < quiz.length; i++) {
            final question = quiz[i]['question'] as String? ?? '';
            quiz[i]['question'] = await _translationService.translate(question, language);
            
            final options = quiz[i]['options'] as List<dynamic>? ?? [];
            for (int j = 0; j < options.length; j++) {
              final optMap = options[j] as Map<String, dynamic>;
              final optText = optMap['text'] as String? ?? '';
              optMap['text'] = await _translationService.translate(optText, language);
            }
            
            final answerText = quiz[i]['answer_text'] as String? ?? '';
            quiz[i]['answer_text'] = await _translationService.translate(answerText, language);
          }
          
          print('✅ [ViewResults] All content translated to $language');
        } catch (e) {
          print('❌ [ViewResults] Translation error: $e');
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Translation failed. Showing in English.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        
        if (mounted) {
          Navigator.pop(context);
        }
      }

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
            selectedLanguage: language,
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

  Future<String?> _showLanguageSelectionDialog() async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              '🌐 Choose language for content display and voice features',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('🤖 AI Summary & Quiz', style: AppTextStyles.title),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _offlineFiles.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildInfoBanner(),
                    
                    if (_processingFile != null) _buildProcessingCard(),
                    
                    Expanded(
                      child: ListView.builder(
                        key: _fileListKey,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'No PDFs Downloaded Yet',
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Download study materials from your classes first!',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 20),
              label: const Text('Go Back to Classes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lightbulb, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works:',
                  style: AppTextStyles.title.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  '1️⃣ Click ✨ to generate  2️⃣ Click 👁️ to view',
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🤖 AI Processing...',
                      style: AppTextStyles.title,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _processingFile ?? '',
                      style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 10,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(_progress * 100).toInt()}% Complete',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                _getProgressText(),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getProgressText() {
    if (_progress < 0.2) return 'Reading PDF...';
    if (_progress < 0.5) return 'Creating summary...';
    if (_progress < 0.8) return 'Making quiz...';
    if (_progress < 0.95) return 'Drawing mind map...';
    return 'Almost done!';
  }

  Widget _buildFileCard(FileRecord file, int index) {
    final isProcessing = _processingFile == file.name;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.surface,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: AppColors.error, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: AppTextStyles.title.copyWith(fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Class: ${file.classCode}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              Divider(height: 1, color: AppColors.outline),
              const SizedBox(height: 16),
              
              if (isProcessing)
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Processing... Please wait',
                        style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        key: index == 0 ? _firstGenerateButtonKey : null,
                        onPressed: () => _generateSummaryQuizAndMindMap(file),
                        icon: const Icon(Icons.auto_awesome, size: 20),
                        label: const Text('Generate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: ElevatedButton.icon(
                        key: index == 0 ? _firstViewButtonKey : null,
                        onPressed: () => _viewResults(file),
                        icon: const Icon(Icons.visibility, size: 20),
                        label: const Text('View'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SummaryQuizResultScreen extends StatefulWidget {
  final String fileName;
  final String summary;
  final List<Map<String, dynamic>> quiz;
  final String classCode;
  final MindMapNode? mindMap;
  final String selectedLanguage;

  const SummaryQuizResultScreen({
    super.key,
    required this.fileName,
    required this.summary,
    required this.quiz,
    required this.classCode,
    this.mindMap,
    required this.selectedLanguage,
  });

  @override
  State<SummaryQuizResultScreen> createState() => _SummaryQuizResultScreenState();
}

class _SummaryQuizResultScreenState extends State<SummaryQuizResultScreen> {
  Map<int, String> userAnswers = {};
  bool showResults = false;
  
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  final TranslationService _translationService = TranslationService();
  bool _isTTSSpeaking = false;
  bool _isSTTListening = false;
  int? _currentQuestionIndex;
  
  final GlobalKey _summaryTabKey = GlobalKey();
  final GlobalKey _quizTabKey = GlobalKey();
  final GlobalKey _mindMapTabKey = GlobalKey();
  final GlobalKey _ttsButtonKey = GlobalKey();
  final GlobalKey _voiceQuizButtonKey = GlobalKey();
  TutorialCoachMark? _resultTutorialCoachMark;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowResultOnboarding();
    });
  }

  Future<void> _checkAndShowResultOnboarding() async {
    final completed = await OnboardingService.isResultScreenCompleted();
    if (!completed && mounted) {
      await Future.delayed(Duration(milliseconds: 1000));
      if (mounted) {
        _showResultOnboarding();
      }
    }
  }

  void _showResultOnboarding() {
    final targets = <TargetFocus>[];
    
    targets.add(
      TargetFocus(
        identify: "summary_tab",
        keyTarget: _summaryTabKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return OnboardingContentWidgets.buildResultOnboardingContent(
                icon: Icons.notes,
                title: '📝 Summary Tab',
                description: 'Read the AI-generated summary of your PDF content here.',
                onNext: () => controller.next(),
                onSkip: () => _skipResultOnboarding(controller),
              );
            },
          ),
        ],
      ),
    );
    
    targets.add(
      TargetFocus(
        identify: "tts_button",
        keyTarget: _ttsButtonKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.left,
            builder: (context, controller) {
              return OnboardingContentWidgets.buildResultOnboardingContent(
                icon: Icons.volume_up,
                title: '🔊 Read Aloud',
                description: 'Tap this button to hear the summary read aloud in your selected language.',
                onNext: () => controller.next(),
                onSkip: () => _skipResultOnboarding(controller),
              );
            },
          ),
        ],
      ),
    );
    
    targets.add(
      TargetFocus(
        identify: "quiz_tab",
        keyTarget: _quizTabKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return OnboardingContentWidgets.buildResultOnboardingContent(
                icon: Icons.quiz,
                title: '📝 Quiz Tab',
                description: 'Test your knowledge with AI-generated quiz questions.',
                onNext: () => controller.next(),
                onSkip: () => _skipResultOnboarding(controller),
              );
            },
          ),
        ],
      ),
    );
    
    if (widget.quiz.isNotEmpty) {
      targets.add(
        TargetFocus(
          identify: "voice_quiz_button",
          keyTarget: _voiceQuizButtonKey,
          alignSkip: Alignment.topRight,
          enableOverlayTab: true,
          contents: [
            TargetContent(
              align: ContentAlign.left,
              builder: (context, controller) {
                return OnboardingContentWidgets.buildResultOnboardingContent(
                  icon: Icons.mic,
                  title: '🎤 Voice Quiz',
                  description: 'Answer quiz questions using your voice! The app will read the question and listen for your answer (A, B, C, or D).',
                  onNext: () => _finishResultOnboarding(controller),
                  onSkip: () => _skipResultOnboarding(controller),
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }
    
    if (widget.mindMap != null) {
      targets.add(
        TargetFocus(
          identify: "mindmap_tab",
          keyTarget: _mindMapTabKey,
          alignSkip: Alignment.topRight,
          enableOverlayTab: true,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return OnboardingContentWidgets.buildResultOnboardingContent(
                  icon: Icons.account_tree,
                  title: '🧠 Mind Map',
                  description: 'Visualize the key concepts and their relationships in an interactive mind map.',
                  onNext: () => controller.next(),
                  onSkip: () => _skipResultOnboarding(controller),
                );
              },
            ),
          ],
        ),
      );
    }
    
    _resultTutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        OnboardingService.markResultScreenCompleted();
      },
      onSkip: () {
        OnboardingService.markResultScreenCompleted();
        return true;
      },
    );
    
    _resultTutorialCoachMark?.show(context: context);
  }

  void _skipResultOnboarding(TutorialCoachMarkController controller) {
    controller.skip();
    OnboardingService.markResultScreenCompleted();
  }

  void _finishResultOnboarding(TutorialCoachMarkController controller) {
    controller.next();
    OnboardingService.markResultScreenCompleted();
  }

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
    _ttsService.clearCompletionHandler();
    _ttsService.stop();
    _sttService.dispose();
    _translationService.dispose();
    _resultTutorialCoachMark?.finish();
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

  Future<void> _toggleSummaryTTS() async {
    if (_isTTSSpeaking) {
      await _ttsService.stop();
      setState(() => _isTTSSpeaking = false);
    } else {
      setState(() => _isTTSSpeaking = true);
      
      try {
        await _ttsService.setLanguageForReading(widget.selectedLanguage);
        await _ttsService.speak(widget.summary);
        
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted && !_ttsService.isSpeaking) {
          setState(() => _isTTSSpeaking = false);
        }
      } catch (e) {
        print('❌ [SummaryTTS] Error: $e');
        if (mounted) {
          setState(() => _isTTSSpeaking = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to read summary: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleVoiceQuiz(int questionIndex) async {
    if (_isSTTListening) {
      await _sttService.stopListening();
      setState(() {
        _isSTTListening = false;
        _currentQuestionIndex = null;
      });
      return;
    }

    await _ttsService.setLanguageForReading(widget.selectedLanguage);

    final question = widget.quiz[questionIndex];
    final questionText = question['question'] as String? ?? '';
    final options = question['options'] as List<dynamic>? ?? [];

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

      _ttsService.setOnCompletionHandler(() {
        print('✅ [VoiceQuiz] TTS ACTUALLY finished, now starting STT');
        
        if (!mounted || _currentQuestionIndex != questionIndex) return;
        
        _startSTTForQuestion(questionIndex);
      });

      await _ttsService.speak(ttsText);
      
    } catch (e) {
      print('❌ [VoiceQuiz] Error: $e');
      _resetVoiceState();
    }
  }

  Future<void> _startSTTForQuestion(int questionIndex) async {
    if (!mounted || _currentQuestionIndex != questionIndex) return;
    
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

  void _resetVoiceState() {
    setState(() {
      _isTTSSpeaking = false;
      _isSTTListening = false;
      _currentQuestionIndex = null;
    });
  }

  void _handleVoiceAnswer(int questionIndex, String recognizedWords) {
    _sttService.stopListening();
    setState(() => _isSTTListening = false);

    final words = recognizedWords.toUpperCase();
    String? selectedOption;

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
      setState(() {
        userAnswers[questionIndex] = selectedOption!;
        _currentQuestionIndex = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Selected: Option $selectedOption'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      _ttsService.speak('You selected option $selectedOption');
    } else {
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
        await _ttsService.stop();
        await _sttService.dispose();
        return true;
      },
      child: DefaultTabController(
        length: widget.mindMap != null ? 3 : 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.fileName),
            backgroundColor: AppColors.surface,
            // 🆕 ADD THIS ACTIONS ARRAY
            actions: [
              // Chatbot button - NEW!
              IconButton(
                icon: Icon(Icons.chat_bubble_outline, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatbotScreen(
                        pdfContext: widget.summary,
                        fileName: widget.fileName,
                      ),
                    ),
                  );
                },
                tooltip: '💬 Ask AI about this content',
              ),
            ],
            bottom: TabBar(
              tabs: [
                Tab(
                  key: _summaryTabKey,
                  icon: Icon(Icons.notes), 
                  text: 'Summary'
                ),
                Tab(
                  key: _quizTabKey,
                  icon: Icon(Icons.quiz), 
                  text: 'Quiz'
                ),
                if (widget.mindMap != null)
                  Tab(
                    key: _mindMapTabKey,
                    icon: Icon(Icons.account_tree), 
                    text: 'Mind Map'
                  ),
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

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📝 Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.selectedLanguage != 'en')
                        Text(
                          '🌐 ${TranslationService.getLanguageName(widget.selectedLanguage)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    key: _ttsButtonKey,
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

    return _InteractiveMindMap(mindMap: widget.mindMap!, fileName: widget.fileName);
  }

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
                  if (!showResults)
                    Container(
                      key: index == 0 ? _voiceQuizButtonKey : null,
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
              }).toList(),
              
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

class _InteractiveMindMap extends StatefulWidget {
  final MindMapNode mindMap;
  final String fileName;

  const _InteractiveMindMap({required this.mindMap, required this.fileName});

  @override
  State<_InteractiveMindMap> createState() => _InteractiveMindMapState();
}

class _InteractiveMindMapState extends State<_InteractiveMindMap> {
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _previousOffset = Offset.zero;
  final double _minScale = 0.3;
  final double _maxScale = 3.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          // Background grid with scrollable content
          Positioned.fill(
            child: GestureDetector(
              onScaleStart: (details) {
                _previousScale = _scale;
                _previousOffset = details.focalPoint;
              },
              onScaleUpdate: (details) {
                setState(() {
                  _scale = (_previousScale * details.scale).clamp(_minScale, _maxScale);
                  
                  final currentFocal = details.focalPoint;
                  final delta = currentFocal - _previousOffset;
                  _offset += delta;
                  _previousOffset = currentFocal;
                });
              },
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 2, // Extra width for large mind maps
                    height: MediaQuery.of(context).size.height * 2, // Extra height for large mind maps
                    child: Stack(
                      children: [
                        // Background grid
                        _buildGrid(),
                        
                        // Mind map content
                        Transform.translate(
                          offset: _offset,
                          child: Transform.scale(
                            scale: _scale,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(40),
                                child: _buildMindMapTree(widget.mindMap),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Controls
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildControlButton(
                    icon: Icons.zoom_in,
                    onPressed: () => setState(() {
                      _scale = (_scale + 0.2).clamp(_minScale, _maxScale);
                    }),
                  ),
                  _buildControlButton(
                    icon: Icons.zoom_out,
                    onPressed: () => setState(() {
                      _scale = (_scale - 0.2).clamp(_minScale, _maxScale);
                    }),
                  ),
                  _buildControlButton(
                    icon: Icons.center_focus_weak,
                    onPressed: () => setState(() {
                      _scale = 1.0;
                      _offset = Offset.zero;
                    }),
                  ),
                ],
              ),
            ),
          ),

          // File name indicator
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_tree, size: 16, color: Color(0xFF4A90E2)),
                  SizedBox(width: 8),
                  Text(
                    widget.fileName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return CustomPaint(
      size: Size(MediaQuery.of(context).size.width * 2, MediaQuery.of(context).size.height * 2),
      painter: _GridPainter(offset: _offset, scale: _scale),
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Icon(icon, size: 20, color: Color(0xFF4A90E2)),
        ),
      ),
    );
  }

  Widget _buildMindMapTree(MindMapNode node) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMindMapNode(node),
        if (node.children.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildChildrenConnector(node.level),
          Wrap(
            spacing: 40,
            runSpacing: 40,
            alignment: WrapAlignment.center,
            children: node.children.map((child) => _buildMindMapTree(child)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildChildrenConnector(int level) {
    return Container(
      height: 2,
      width: _nodeChildrenWidth(level),
      color: _getNodeColor(level).withOpacity(0.3),
    );
  }

  double _nodeChildrenWidth(int level) {
    switch (level) {
      case 0: return 300;
      case 1: return 200;
      default: return 150;
    }
  }

  Widget _buildMindMapNode(MindMapNode node) {
    final color = _getNodeColor(node.level);
    final isRoot = node.level == 0;
    
    return GestureDetector(
      onTap: () => _showNodeDetails(node),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: isRoot ? 3 : 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNodeIcon(node),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                node.title,
                style: TextStyle(
                  fontSize: _getNodeFontSize(node.level),
                  fontWeight: isRoot ? FontWeight.bold : FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (node.children.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${node.children.length}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNodeIcon(MindMapNode node) {
    final color = _getNodeColor(node.level);
    final icon = _getNodeIcon(node.level);
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  IconData _getNodeIcon(int level) {
    switch (level) {
      case 0: return Icons.center_focus_strong;
      case 1: return Icons.category;
      case 2: return Icons.label_important;
      default: return Icons.label;
    }
  }

  double _getNodeFontSize(int level) {
    switch (level) {
      case 0: return 18.0;
      case 1: return 16.0;
      case 2: return 14.0;
      default: return 12.0;
    }
  }

  Color _getNodeColor(int level) {
    final colors = [
      Color(0xFF4A90E2), // Blue - Root
      Color(0xFF66BB6A), // Green - Level 1
      Color(0xFFFF7043), // Orange - Level 2
      Color(0xFFAB47BC), // Purple - Level 3
      Color(0xFF26C6DA), // Cyan - Level 4
    ];
    return colors[level.clamp(0, colors.length - 1)];
  }

  void _showNodeDetails(MindMapNode node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getNodeIcon(node.level), color: _getNodeColor(node.level)),
            SizedBox(width: 8),
            Text('Node Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              node.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getNodeColor(node.level),
              ),
            ),
            SizedBox(height: 12),
            if (node.children.isNotEmpty)
              Text(
                'Child nodes: ${node.children.length}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            SizedBox(height: 8),
            Text(
              'Level: ${node.level}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Offset offset;
  final double scale;

  _GridPainter({required this.offset, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    final cellSize = 20.0 * scale;

    final startX = -offset.dx % cellSize;
    final startY = -offset.dy % cellSize;

    for (double x = startX; x < size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = startY; y < size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}