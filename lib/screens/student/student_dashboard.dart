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
  int _currentTab = 0; // Bottom nav index

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
      backgroundColor: Color(0xFFF5F5F5),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case 0:
        return _buildClassesTab();
      case 1:
        return _buildMaterialsTab();
      case 2:
        return _buildAIToolsTab();
      case 3:
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.school, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'My Classes',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isOnline ? Colors.green : Colors.orange,
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
                            style: TextStyle(
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
                        itemBuilder: (context, index) => _buildSimpleClassCard(_classes[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleClassCard(ClassModel classModel) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
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
                    color: Color(0xFF4A90E2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.class_, color: Color(0xFF4A90E2), size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    classModel.className,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Class Code
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tag, size: 16, color: Color(0xFF4A90E2)),
                  SizedBox(width: 4),
                  Text(
                    'Code: ${classModel.classCode}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                ],
              ),
            ),
            
            if (classModel.description.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                classModel.description,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            Divider(height: 24),
            
            // Materials Count
            Row(
              children: [
                Icon(Icons.insert_drive_file, size: 20, color: Color(0xFF66BB6A)),
                SizedBox(width: 8),
                Text(
                  '${classModel.materials.length} Files',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF66BB6A),
                  ),
                ),
              ],
            ),
            
            if (classModel.materials.isNotEmpty) ...[
              SizedBox(height: 12),
              ...classModel.materials.take(3).map((material) =>
                _buildMaterialRow(classModel.classCode, material)
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialRow(String classCode, ClassMaterial material) {
    return FutureBuilder<bool>(
      future: _isMaterialDownloaded(classCode, material.name),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDownloaded ? Color(0xFFE8F5E9) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                isDownloaded ? Icons.download_done : Icons.picture_as_pdf,
                color: isDownloaded ? Color(0xFF66BB6A) : Colors.red,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  material.name,
                  style: TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDownloaded)
                IconButton(
                  icon: Icon(Icons.open_in_new, size: 20, color: Color(0xFF4A90E2)),
                  onPressed: () => _handleMaterialClick(classCode, material),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                )
              else if (_isOnline)
                IconButton(
                  icon: Icon(Icons.download, size: 20, color: Color(0xFF4A90E2)),
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
          Icon(Icons.class_, size: 80, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            'No Classes Yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Join your first class!', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/student/join-class'),
            icon: Icon(Icons.add, size: 24),
            label: Text('Join Class', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF66BB6A),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // 📚 TAB 2: STUDY MATERIALS
  Widget _buildMaterialsTab() {
    return Center(child: Text('Materials Tab - Coming in next update'));
  }

  // 🤖 TAB 3: AI TOOLS
  Widget _buildAIToolsTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '🤖 AI Tools',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            
            _buildBigAIButton(
              icon: Icons.auto_awesome,
              title: 'Summary & Quiz',
              subtitle: 'Generate from PDFs',
              color: Color(0xFF4A90E2),
              onTap: () => Navigator.pushNamed(context, '/student/summary-quiz'),
            ),
            
            SizedBox(height: 16),
            
            _buildBigAIButton(
              icon: Icons.smart_toy,
              title: 'Download AI Model',
              subtitle: 'Better summaries (678MB)',
              color: Color(0xFFFF9800),
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

  // ⚙️ TAB 4: SETTINGS
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
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            
            // Profile Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFF4A90E2),
                      child: Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      authProvider.user?.email ?? '',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Student',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4A90E2),
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
                color: Color(0xFFE8F5E9),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.savings, color: Color(0xFF66BB6A), size: 32),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Storage Saved',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${(_storageStats.spaceSaved / 1024 / 1024).toStringAsFixed(1)} MB',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF66BB6A),
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
              icon: Icon(Icons.logout, size: 24),
              label: Text('Logout', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
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

  // Bottom Navigation
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
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
        selectedItemColor: Color(0xFF4A90E2),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 28),
            label: 'Classes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder, size: 28),
            label: 'Materials',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome, size: 28),
            label: 'AI Tools',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings, size: 28),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}