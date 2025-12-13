import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/firebase_config.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/offline_db.dart';
import '../../services/download_manager.dart';
import 'package:claudetest/services/quiz_sync_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../services/onboarding_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/chatbot_bubble.dart';
import '../../widgets/chatbot_overlay.dart';
import '../../services/knowledge_indexer.dart';
import '../../services/rag_service.dart';
import '../../services/vector_store.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  List<ClassModel> _classes = [];
  bool _loading = true;
  bool _isOnline = true;
  bool _networkChecked = false;
  StorageStats _storageStats = StorageStats.empty();
  int _currentTab = 0; // Bottom nav index
  
  // Chatbot state
  bool _isIndexing = false;
  bool _showIndexingBadge = false;
  String? _indexingFile;
  double _indexingProgress = 0.0;

  // GlobalKeys for onboarding targets
  final GlobalKey _joinClassKey = GlobalKey();
  final GlobalKey _firstClassCardKey = GlobalKey(); // Only for first class card
  final GlobalKey _firstDownloadButtonKey = GlobalKey(); // Only for first download button
  final GlobalKey _aiToolsTabKey = GlobalKey();
  final GlobalKey _settingsTabKey = GlobalKey();
  
  TutorialCoachMark? _tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    _checkNetwork();
    _loadStorageStats();
    _listenToClasses();
    _syncQuizResults();
    _initializeKnowledgeIndexing();
    
    // Initialize onboarding after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowOnboarding();
    });
  }

  // Initialize knowledge base indexing
  Future<void> _initializeKnowledgeIndexing() async {
    try {
      // Always check for new files and index if needed
      await Future.delayed(const Duration(seconds: 2)); // Wait for UI to settle
      
      // Check if knowledge base is ready
      final isReady = await RAGService.isKnowledgeBaseReady();
      
      if (!isReady) {
        print('📚 [StudentDashboard] Knowledge base not ready, starting indexing...');
        // Start indexing in background
        _startBackgroundIndexing();
      } else {
        print('📚 [StudentDashboard] Knowledge base ready, checking for new files...');
        // Check for new files that need indexing
        _checkForNewFiles();
      }
    } catch (e) {
      print('⚠️ [StudentDashboard] Error initializing knowledge indexing: $e');
      // Try to start indexing anyway
      _startBackgroundIndexing();
    }
  }

  // Start background indexing
  Future<void> _startBackgroundIndexing() async {
    if (_isIndexing) return;

    setState(() {
      _isIndexing = true;
      _showIndexingBadge = true;
      _indexingProgress = 0.0;
    });

    try {
      final indexedCount = await KnowledgeIndexer.indexAllPDFs(
        onFileProgress: (fileName) {
          if (mounted) {
            setState(() {
              _indexingFile = fileName;
            });
          }
        },
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _indexingProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isIndexing = false;
          _indexingFile = null;
          _indexingProgress = 0.0;
        });

        // Hide badge after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showIndexingBadge = false;
            });
          }
        });
      }

      print('✅ [StudentDashboard] Indexed $indexedCount files');
    } catch (e) {
      print('❌ [StudentDashboard] Error during indexing: $e');
      if (mounted) {
        setState(() {
          _isIndexing = false;
          _indexingFile = null;
        });
      }
    }
  }

  // Check for new files that need indexing
  Future<void> _checkForNewFiles() async {
    try {
      final files = await OfflineDB.getAllOfflineFiles();
      final pdfFiles = files.where((f) => 
        f.name.toLowerCase().endsWith('.pdf') || 
        f.name.toLowerCase().endsWith('.pdf.gz')
      ).toList();

      if (pdfFiles.isEmpty) {
        print('📚 [StudentDashboard] No PDF files found');
        return;
      }

      final indexedFiles = await KnowledgeIndexer.getIndexedFiles();
      final newFiles = pdfFiles.where((f) {
        final fileKey = '${f.classCode}_${f.name}';
        return !indexedFiles.contains(fileKey);
      }).toList();

      print('📚 [StudentDashboard] Found ${pdfFiles.length} PDFs, ${indexedFiles.length} indexed, ${newFiles.length} new');

      if (newFiles.isNotEmpty) {
        print('📚 [StudentDashboard] Starting indexing for ${newFiles.length} new files');
        // Start indexing new files
        _startBackgroundIndexing();
      } else {
        // Verify existing chunks are accessible
        final totalChunks = await VectorStore.getTotalChunks();
        print('📚 [StudentDashboard] All files indexed. Total chunks: $totalChunks');
      }
    } catch (e) {
      print('⚠️ [StudentDashboard] Error checking for new files: $e');
      // Try to start indexing anyway
      _startBackgroundIndexing();
    }
  }

  // Open chatbot overlay
  void _openChatbot() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatbotOverlay(isOnline: _isOnline),
    ).then((_) {
      // Check for new files after closing chatbot
      _checkForNewFiles();
    });
  }

  Future<void> _checkAndShowOnboarding() async {
    final completed = await OnboardingService.isStudentDashboardCompleted();
    if (!completed && mounted) {
      // Wait a bit for UI to settle and data to load
      await Future.delayed(Duration(milliseconds: 1500));
      if (mounted && !_loading && _classes.isNotEmpty) {
        // Wait a bit more for the class cards to render properly
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          _showOnboarding();
        }
      }
    }
  }

  void _showOnboarding() {
    final targets = <TargetFocus>[];
    
    // Target 1: Classes Tab (current screen) - Only target first class card
    targets.add(
      TargetFocus(
        identify: "classes_tab",
        keyTarget: _firstClassCardKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildOnboardingContent(
                icon: Icons.class_,
                title: '📚 Your Classes',
                description: 'See all classes you joined here.\nTap any class to view materials.',
                onNext: () => controller.next(),
                onSkip: () => _skipOnboarding(controller),
              );
            },
          ),
        ],
      ),
    );
    
    // Target 2: Download Button - Only target first download button
    targets.add(
      TargetFocus(
        identify: "download_button",
        keyTarget: _firstDownloadButtonKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildOnboardingContent(
                icon: Icons.download,
                title: '⬇️ Download Files',
                description: 'Download PDFs to study offline.\nFiles work without internet!',
                onNext: () => controller.next(),
                onSkip: () => _skipOnboarding(controller),
              );
            },
          ),
        ],
      ),
    );
    
    // Target 3: AI Tools Tab
    targets.add(
      TargetFocus(
        identify: "ai_tools",
        keyTarget: _aiToolsTabKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildOnboardingContent(
                icon: Icons.auto_awesome,
                title: '🤖 AI Tools',
                description: 'Generate summaries & quizzes from PDFs.\nTap here to access AI features!',
                onNext: () => controller.next(),
                onSkip: () => _skipOnboarding(controller),
              );
            },
          ),
        ],
      ),
    );
    
    // Target 4: Settings Tab
    targets.add(
      TargetFocus(
        identify: "settings",
        keyTarget: _settingsTabKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildOnboardingContent(
                icon: Icons.settings,
                title: '⚙️ Settings',
                description: 'View your profile & logout here.\nCheck storage savings!',
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
        OnboardingService.markStudentDashboardCompleted();
      },
      onSkip: () {
        OnboardingService.markStudentDashboardCompleted();
        return true;
      },
    );
    
    _tutorialCoachMark?.show(context: context);
  }

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
          // Icon
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF4A90E2).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Color(0xFF4A90E2)),
          ),
          
          SizedBox(height: 16),
          
          // Title
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
          
          // Description
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
          
          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip button
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'Skip Tour',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              
              // Next/Finish button
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
    OnboardingService.markStudentDashboardCompleted();
  }

  void _finishOnboarding(TutorialCoachMarkController controller) {
    controller.next();
    OnboardingService.markStudentDashboardCompleted();
  }

  Future<void> _syncQuizResults() async {
    try {
      await QuizSyncService.syncPendingResults();
    } catch (e) {
      print('⚠️ Failed to sync quiz results: $e');
    }
  }

  Future<void> _checkNetwork() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
      _networkChecked = true;
    });

    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    });
  }

  Future<void> _loadStorageStats() async {
    final stats = await OfflineDB.getStorageStats();
    setState(() => _storageStats = stats);
  }

  void _listenToClasses() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    FirebaseConfig.firestore
        .collection('classes')
        .where('students', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _classes = snapshot.docs
            .map((doc) => ClassModel.fromFirestore(doc.data(), doc.id))
            .toList();
        _loading = false;
      });
    });
  }

  Future<bool> _isMaterialDownloaded(String classCode, String materialName) async {
    return await OfflineDB.checkFileExists(classCode, materialName);
  }

  Future<void> _handleMaterialClick(String classCode, ClassMaterial material) async {
    final isDownloaded = await _isMaterialDownloaded(classCode, material.name);
    
    if (isDownloaded) {
      await _openDownloadedMaterial(classCode, material.name);
    } else if (_isOnline) {
      await _openMaterialInBrowser(material.url);
    } else {
      _showOfflineError(material.name);
    }
  }

  Future<void> _openMaterialInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot open URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open material: $e')),
        );
      }
    }
  }

  Future<void> _openDownloadedMaterial(String classCode, String materialName) async {
    try {
      final files = await OfflineDB.getOfflineFiles(classCode);
      final file = files.firstWhere((f) => f.name == materialName);
      
      await DownloadManager.openFile(file.localPath, file.name);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Opening file...'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: $e')),
        );
      }
    }
  }

  void _showOfflineError(String materialName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Text('Offline'),
          ],
        ),
        content: Text(
          'You are offline and "$materialName" is not downloaded.\n\n'
          'Please connect to internet and download it first.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDownloadMaterial(String classCode, ClassMaterial material) async {
    if (!_isOnline) {
      _showOfflineError(material.name);
      return;
    }

    try {
      final exists = await OfflineDB.checkFileExists(classCode, material.name);
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ File already downloaded')),
          );
        }
        return;
      }

      if (mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Download for Offline'),
            content: Text(
              'Download "${material.name}" to access offline?\n\n'
              'File will be compressed to save space.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF66BB6A),
                ),
                child: Text('Download'),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      if (!mounted) return;
      
      bool isDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Downloading...', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );

      try {
        await DownloadManager.downloadAndStore(classCode, material);
        await _loadStorageStats();
        
        if (mounted && isDialogShowing) {
          Navigator.pop(context);
          isDialogShowing = false;
        }
        
        // Trigger re-indexing for the new file
        _checkForNewFiles();
        
        if (mounted) {
          setState(() {});
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('✅ Downloaded!')),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted && isDialogShowing) {
          Navigator.pop(context);
          isDialogShowing = false;
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleDeleteFile(FileRecord file) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete File'),
        content: Text('Delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await DownloadManager.deleteFile(file.localPath);
                await OfflineDB.deleteFileRecord(file.classCode, file.name);
                await _loadStorageStats();
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout'),
        content: Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
              }
            },
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.user == null || authProvider.userRole != 'student') {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildBody(),
          // Chatbot bubble - positioned bottom right (consistent across all tabs)
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 80, // Above bottom nav, accounts for safe area
            child: ChatbotBubble(
              onTap: _openChatbot,
              showBadge: _showIndexingBadge,
              isOnline: _isOnline,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      
      // Floating action button for Join Class
      floatingActionButton: _currentTab == 0 && _classes.isEmpty
          ? FloatingActionButton.extended(
              key: _joinClassKey,
              onPressed: () => Navigator.pushNamed(context, '/student/join-class'),
              icon: Icon(Icons.add, size: 28),
              label: Text(
                'Join Class',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Color(0xFF66BB6A),
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case 0:
        return _buildClassesTab();
      case 1:
        return _buildAIToolsTab();
      case 2:
        return _buildSettingsTab();
      default:
        return _buildClassesTab();
    }
  }

  // 🏠 TAB 1: MY CLASSES
  Widget _buildClassesTab() {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.school, color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'My Classes',
                        style: AppTextStyles.title.copyWith(color: Colors.white),
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isOnline ? AppColors.secondary : AppColors.warning,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isOnline ? Icons.wifi : Icons.wifi_off,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _isOnline ? 'Online' : 'Offline',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Classes List
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _classes.isEmpty
                    ? _buildEmptyClasses()
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _classes.length,
                        itemBuilder: (context, index) => _buildSimpleClassCard(_classes[index], index),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleClassCard(ClassModel classModel, int index) {
    return Card(
      key: index == 0 ? _firstClassCardKey : null, // ONLY apply to first card
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class Name
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.class_, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    classModel.className,
                    style: AppTextStyles.title,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Class Code
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tag, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Code: ${classModel.classCode}',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            
            if (classModel.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                classModel.description,
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            const Divider(height: 24),
            
            // Materials Count
            Row(
              children: [
                const Icon(Icons.insert_drive_file, size: 20, color: AppColors.secondary),
                const SizedBox(width: 8),
                Text(
                  '${classModel.materials.length} Files',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            
            if (classModel.materials.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...classModel.materials.asMap().entries.map((entry) =>
                _buildMaterialRow(classModel.classCode, entry.value, entry.key)
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialRow(String classCode, ClassMaterial material, int materialIndex) {
    return FutureBuilder<bool>(
      future: _isMaterialDownloaded(classCode, material.name),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDownloaded ? AppColors.surfaceMuted : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Icon(
                isDownloaded ? Icons.download_done : Icons.picture_as_pdf,
                color: isDownloaded ? AppColors.secondary : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  material.name,
                  style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDownloaded)
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 20, color: AppColors.primary),
                  onPressed: () => _handleMaterialClick(classCode, material),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                )
              else if (_isOnline)
                IconButton(
                  key: materialIndex == 0 ? _firstDownloadButtonKey : null, // Key on DOWNLOAD button
                  icon: const Icon(Icons.download, size: 20, color: AppColors.primary),
                  onPressed: () => _handleDownloadMaterial(classCode, material),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyClasses() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.class_, size: 80, color: AppColors.outline),
          const SizedBox(height: 16),
          const Text(
            'No classes yet',
            style: AppTextStyles.title,
          ),
          const SizedBox(height: 8),
          const Text('Join your first class!', style: AppTextStyles.body),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/student/join-class'),
            icon: const Icon(Icons.add, size: 22),
            label: const Text('Join class'),
          ),
        ],
      ),
    );
  }

  // 🤖 TAB 2: AI TOOLS
  Widget _buildAIToolsTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '🤖 AI Tools',
              style: AppTextStyles.headline,
            ),
            SizedBox(height: 24),
            
            _buildBigAIButton(
              icon: Icons.auto_awesome,
              title: 'Summary & Quiz',
              subtitle: 'Generate from PDFs',
              color: AppColors.primary,
              onTap: () => Navigator.pushNamed(context, '/student/summary-quiz'),
            ),
            
            SizedBox(height: 16),
            
            _buildBigAIButton(
              icon: Icons.smart_toy,
              title: 'Download AI Model',
              subtitle: 'Better summaries (678MB)',
              color: AppColors.secondary,
              onTap: () => Navigator.pushNamed(context, '/student/model-download'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBigAIButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 48, color: Colors.white),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ⚙️ TAB 3: SETTINGS
  Widget _buildSettingsTab() {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '⚙️ Settings',
              style: AppTextStyles.headline,
            ),
            SizedBox(height: 24),
            
            // Profile Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 38,
                      backgroundColor: AppColors.secondary,
                      child: Icon(Icons.person, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      authProvider.user?.email ?? '',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Student',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Storage Stats
            if (_storageStats.spaceSaved > 0)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: AppColors.surfaceMuted,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.savings, color: AppColors.secondary, size: 30),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Storage saved',
                              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${(_storageStats.spaceSaved / 1024 / 1024).toStringAsFixed(1)} MB',
                              style: AppTextStyles.headline.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            SizedBox(height: 16),
            
            // Logout Button
            ElevatedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, size: 22),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bottom Navigation
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 28),
            label: 'Classes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome, size: 28, key: _aiToolsTabKey),
            label: 'AI Tools',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings, size: 28, key: _settingsTabKey),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}