import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/firebase_config.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/offline_db.dart';
import '../../services/download_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/rounded_card.dart';
import '../../widgets/common/offline_indicator.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/primary_button.dart';
import 'package:claudetest/services/quiz_sync_service.dart';
import '../common/notifications_screen.dart';
import '../common/profile_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  List<ClassModel> _classes = [];
  bool _loading = true;
  bool _isOnline = true;
  StorageStats _storageStats = StorageStats.empty();
  int _currentTab = 0; // 0: Dashboard, 1: Notifications, 2: Profile

  @override
  void initState() {
    super.initState();
    _checkNetwork();
    _loadStorageStats();
    _listenToClasses();
    _syncQuizResults();
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
    });

    Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _isOnline = result != ConnectivityResult.none;
        });
      }
    });
  }

  Future<void> _loadStorageStats() async {
    final stats = await OfflineDB.getStorageStats();
    if (mounted) {
      setState(() => _storageStats = stats);
    }
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
      if (mounted) {
        setState(() {
          _classes = snapshot.docs
              .map((doc) => ClassModel.fromFirestore(doc.data(), doc.id))
              .toList();
          _loading = false;
        });
      }
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
          SnackBar(
            content: Text('Failed to open material: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
          ),
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
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.white),
                SizedBox(width: AppTheme.spacingS),
                Text('Opening file...'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
          ),
        );
      }
    }
  }

  void _showOfflineError(String materialName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange, size: 32),
            SizedBox(width: AppTheme.spacingM),
            Text('Offline'),
          ],
        ),
        content: Text(
          'You are offline and "$materialName" is not downloaded.\n\n'
          'Please connect to internet and download it first.',
          style: const TextStyle(fontSize: 16, fontFamily: 'Roboto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontSize: 16)),
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
            const SnackBar(
              content: Text('✅ File already downloaded'),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
            ),
            title: const Text('Download for Offline'),
            content: Text(
              'Download "${material.name}" to access offline?\n\n'
              'File will be compressed to save space.',
              style: const TextStyle(fontFamily: 'Roboto'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                ),
                child: const Text('Download'),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: AppTheme.spacingM),
                Text('Downloading...', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );

      try {
        await DownloadManager.downloadAndStore(classCode, material);
        await _loadStorageStats();
        
        if (mounted) {
          Navigator.pop(context);
          setState(() {});
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.white),
                  SizedBox(width: AppTheme.spacingS),
                  Expanded(child: Text('✅ Downloaded!')),
                ],
              ),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.user == null || authProvider.userRole != 'student') {
      return const Scaffold(
        body: LoadingIndicator(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _currentTab == 0 && _classes.isEmpty
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/student/join-class'),
              icon: const Icon(Icons.add, size: 28),
              label: const Text(
                'Join Class',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.successGreen,
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return const NotificationsScreen();
      case 2:
        return const ProfileScreen();
      default:
        return _buildDashboardTab();
    }
  }

  // 🏠 TAB 1: DASHBOARD (Classes + AI Tools)
  Widget _buildDashboardTab() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dashboard_rounded, color: AppTheme.white, size: 32),
                      const SizedBox(width: AppTheme.spacingM),
                      const Expanded(
                        child: Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                      OfflineIndicator(isOnline: _isOnline),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Quick Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Row(
                children: [
                  Expanded(
                    child: RoundedCard(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        children: [
                          const Icon(Icons.class_, color: AppTheme.primaryBlue, size: 32),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            '${_classes.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          const Text(
                            'Classes',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: RoundedCard(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        children: [
                          const Icon(Icons.insert_drive_file, color: AppTheme.successGreen, size: 32),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            '${_classes.fold(0, (sum, c) => sum + c.materials.length)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          const Text(
                            'Materials',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // AI Tools Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Tools',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  _buildAIToolCard(
                    icon: Icons.auto_awesome,
                    title: 'Summary & Quiz',
                    subtitle: 'Generate from PDFs',
                    color: AppTheme.primaryBlue,
                    onTap: () => Navigator.pushNamed(context, '/student/summary-quiz'),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  _buildAIToolCard(
                    icon: Icons.smart_toy,
                    title: 'Download AI Model',
                    subtitle: 'Better summaries (678MB)',
                    color: Colors.orange,
                    onTap: () => Navigator.pushNamed(context, '/student/model-download'),
                  ),
                ],
              ),
            ),
          ),

          // Library Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Library',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  _buildAIToolCard(
                    icon: Icons.library_books,
                    title: 'Offline Content',
                    subtitle: 'View downloaded materials',
                    color: AppTheme.secondaryBlue,
                    onTap: () => Navigator.pushNamed(context, '/student/offline-content'),
                  ),
                ],
              ),
            ),
          ),

          // Classes Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Classes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  if (_classes.isNotEmpty)
                    Text(
                      '${_classes.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        fontFamily: 'Roboto',
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Classes List
          _loading
              ? const SliverFillRemaining(
                  child: LoadingIndicator(),
                )
              : _classes.isEmpty
                  ? SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.class_,
                        title: 'No Classes Yet',
                        message: 'Join your first class to get started!',
                        actionLabel: 'Join Class',
                        onAction: () => Navigator.pushNamed(context, '/student/join-class'),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingM,
                            vertical: AppTheme.spacingS,
                          ),
                          child: _buildClassCard(_classes[index]),
                        ),
                        childCount: _classes.length,
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildAIToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return RoundedCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 20, color: AppTheme.textSecondary),
        ],
      ),
    );
  }

  Widget _buildClassCard(ClassModel classModel) {
    return RoundedCard(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: const Icon(Icons.class_, color: AppTheme.primaryBlue, size: 24),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classModel.className,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingS,
                        vertical: AppTheme.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                      child: Text(
                        'Code: ${classModel.classCode}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (classModel.description.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingM),
            Text(
              classModel.description,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontFamily: 'Roboto',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          if (classModel.materials.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingM),
            const Divider(),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                const Icon(Icons.insert_drive_file, size: 20, color: AppTheme.successGreen),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  '${classModel.materials.length} Materials',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successGreen,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...classModel.materials.take(3).map((material) => _buildMaterialRow(
              classCode: classModel.classCode,
              material: material,
            )),
            if (classModel.materials.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingS),
                child: Text(
                  '+ ${classModel.materials.length - 3} more',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaterialRow({
    required String classCode,
    required ClassMaterial material,
  }) {
    return FutureBuilder<bool>(
      future: _isMaterialDownloaded(classCode, material.name),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        
        return Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: isDownloaded
                ? AppTheme.successGreen.withOpacity(0.1)
                : AppTheme.lightGrey,
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Row(
            children: [
              Icon(
                isDownloaded ? Icons.download_done : Icons.picture_as_pdf,
                color: isDownloaded ? AppTheme.successGreen : AppTheme.errorRed,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  material.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Roboto',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDownloaded)
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 20, color: AppTheme.primaryBlue),
                  onPressed: () => _handleMaterialClick(classCode, material),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else if (_isOnline)
                IconButton(
                  icon: const Icon(Icons.download, size: 20, color: AppTheme.primaryBlue),
                  onPressed: () => _handleDownloadMaterial(classCode, material),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        );
      },
    );
  }

  // Bottom Navigation
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: AppTheme.softShadow,
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: AppTheme.secondaryTextGrey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded, size: 28),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined, size: 28),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, size: 28),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
