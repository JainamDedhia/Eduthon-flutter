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

  // NEW: Check if material is downloaded
  Future<bool> _isMaterialDownloaded(String classCode, String materialName) async {
    return await OfflineDB.checkFileExists(classCode, materialName);
  }

  // NEW: Handle material click - SMART LOGIC
  Future<void> _handleMaterialClick(String classCode, ClassMaterial material) async {
    print('🔍 Material clicked: ${material.name}');
    
    // Check if downloaded
    final isDownloaded = await _isMaterialDownloaded(classCode, material.name);
    
    if (isDownloaded) {
      // Material is downloaded - Open locally (works online & offline)
      print('✅ Material is downloaded, opening locally...');
      await _openDownloadedMaterial(classCode, material.name);
    } else if (_isOnline) {
      // Online but not downloaded - Open in browser
      print('🌐 Material not downloaded, opening in browser...');
      await _openMaterialInBrowser(material.url);
    } else {
      // Offline and not downloaded - Show error
      print('❌ Offline and material not downloaded');
      _showOfflineError(material.name);
    }
  }

  // Open material in browser
  Future<void> _openMaterialInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ Opened in browser: $url');
      } else {
        throw Exception('Cannot open URL');
      }
    } catch (e) {
      print('❌ Failed to open in browser: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open material: $e')),
        );
      }
    }
  }

  // Open downloaded material locally
  Future<void> _openDownloadedMaterial(String classCode, String materialName) async {
    try {
      final files = await OfflineDB.getOfflineFiles(classCode);
      final file = files.firstWhere((f) => f.name == materialName);
      
      print('📂 Opening downloaded file: ${file.localPath}');
      await DownloadManager.openFile(file.localPath, file.name);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Opening downloaded file...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ Failed to open downloaded file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: $e')),
        );
      }
    }
  }

  // Show offline error
  void _showOfflineError(String materialName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Offline'),
          ],
        ),
        content: Text(
          'You are offline and "$materialName" is not downloaded.\n\n'
          'Please connect to internet and download it first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Download material for offline access
  // Replace the _handleDownloadMaterial method in student_dashboard.dart

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
          const SnackBar(content: Text('File already downloaded')),
        );
      }
      return;
    }

    if (mounted) {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Download for Offline'),
          content: Text(
            'Download "${material.name}" with compression to access offline?\n\n'
            'This will save storage space on your device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Download'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // FIXED: Use a GlobalKey to properly track the dialog
    if (!mounted) return;
    
    // Show loading dialog with proper context management
    bool isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Downloading and compressing...'),
            ],
          ),
        ),
      ),
    );

    try {
      // Download and store
      await DownloadManager.downloadAndStore(classCode, material);
      
      // Refresh storage stats
      await _loadStorageStats();
      
      // CRITICAL FIX: Close dialog before showing snackbar
      if (mounted && isDialogShowing) {
        Navigator.pop(context); // Close loading dialog
        isDialogShowing = false;
      }
      
      // Force UI refresh
      if (mounted) {
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${material.name}" downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close dialog on error too
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

  // Delete downloaded file
  Future<void> _handleDeleteFile(FileRecord file) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Offline File'),
        content: Text(
            'Delete "${file.name}" from offline storage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
                    SnackBar(
                        content: Text(
                            '✅ "${file.name}" deleted from offline storage')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deletion failed: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Downloading and compressing...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (route) => false);
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.user == null || authProvider.userRole != 'student') {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome back! 👋',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              authProvider.user?.email ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        onPressed: _handleLogout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Add this code to student_dashboard.dart
// Replace the existing Row with _buildStatItem with this:

Row(
  children: [
    _buildStatItem(_classes.length.toString(), 'Classes'),
    const SizedBox(width: 16),
    _buildStatItem(
      _classes.fold<int>(0, (sum, c) => sum + c.materials.length).toString(),
      'Materials',
    ),
    const SizedBox(width: 16),
    _buildStatItem(
      _isOnline ? '🌐' : '📴',
      _isOnline ? 'Online' : 'Offline',
    ),
    const SizedBox(width: 16),
    _buildStatItem(
      '💾',
      '${(_storageStats.spaceSaved / 1024 / 1024).toStringAsFixed(0)}MB',
    ),
    const SizedBox(width: 16),

    // ---------------------------
    // NEW: Summary Button (unchanged)
    // ---------------------------
    GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/student/summary-quiz'),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFF4A90E2),
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Summary',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    ),

    const SizedBox(width: 16),

    // ---------------------------
    // NEW: AI MODEL Button you requested
    // ---------------------------
    GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/student/model-download'),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Color(0xFF4A90E2),
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'AI Model',
            style: TextStyle(fontSize: 10),
          ),
        ],
      ),
    ),
  ],
),

                ],
              ),
            ),

            // Storage Savings Banner
            if (_storageStats.spaceSaved > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFC8E6C9),
                child: Text(
                  '💰 Storage Saved: ${(_storageStats.spaceSaved / 1024 / 1024).toStringAsFixed(1)}MB with compression!',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Offline Banner
            if (_networkChecked && !_isOnline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFFFE082),
                child: const Text(
                  '📴 You\'re offline. Click materials to open downloaded files.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFD84315),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Classes List Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Classes (${_classes.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await _loadStorageStats();
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),

            // Classes List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _classes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'No classes yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('Join your first class to get started!'),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/student/join-class'),
                                child: const Text('+ Join Class'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _classes.length,
                          itemBuilder: (context, index) =>
                              _buildClassCard(_classes[index]),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/student/join-class'),
        icon: const Icon(Icons.add),
        label: const Text('Join Class'),
        backgroundColor: const Color(0xFF66BB6A),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF66BB6A),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildClassCard(ClassModel classModel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF66BB6A), width: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    classModel.className,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${classModel.materials.length} materials',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF66BB6A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (classModel.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                classModel.description,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Code: ${classModel.classCode}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '${classModel.students.length} students',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildMaterials(classModel),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterials(ClassModel classModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📚 Learning Materials',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (classModel.materials.isEmpty)
          const Text(
            'No materials available yet.',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          )
        else
          ...classModel.materials.map((material) => 
            _buildMaterialItem(classModel.classCode, material)
          ),
      ],
    );
  }

  Widget _buildMaterialItem(String classCode, ClassMaterial material) {
    return FutureBuilder<bool>(
      future: _isMaterialDownloaded(classCode, material.name),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isDownloaded ? const Color(0xFFE8F5E9) : Colors.white,
          child: ListTile(
            leading: Icon(
              isDownloaded ? Icons.download_done : Icons.picture_as_pdf,
              color: isDownloaded ? Colors.green : Colors.red,
            ),
            title: Text(material.name),
            subtitle: Text(
              isDownloaded 
                ? '✅ Downloaded (tap to open)' 
                : _isOnline 
                  ? '🌐 Tap to open in browser'
                  : '📴 Not available offline',
              style: TextStyle(
                fontSize: 11,
                color: isDownloaded ? Colors.green : Colors.grey,
              ),
            ),
            trailing: isDownloaded
              ? IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () async {
                    final files = await OfflineDB.getOfflineFiles(classCode);
                    final file = files.firstWhere((f) => f.name == material.name);
                    _handleDeleteFile(file);
                  },
                )
              : _isOnline
                ? IconButton(
                    icon: const Icon(Icons.download, color: Colors.blue, size: 20),
                    onPressed: () => _handleDownloadMaterial(classCode, material),
                  )
                : null,
            onTap: () => _handleMaterialClick(classCode, material),
          ),
        );
      },
    );
  }
}