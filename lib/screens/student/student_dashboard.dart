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
                Text('Opening downloaded file...'),
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
                Text('Downloading and compressing...', textAlign: TextAlign.center),
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
                  Expanded(child: Text('✅ "${material.name}" downloaded!')),
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
        title: Text('Delete Offline File'),
        content: Text('Delete "${file.name}" from offline storage?'),
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
                    SnackBar(content: Text('✅ "${file.name}" deleted')),
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
        title: Text('Confirm Logout'),
        content: Text('Are you sure you want to logout?'),
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
      body: SafeArea(
        child: Column(
          children: [
            // REDESIGNED HEADER
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top Row: Welcome + Logout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome! 👋',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              authProvider.user?.email ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.logout, color: Colors.white, size: 28),
                        onPressed: _handleLogout,
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.class_,
                          value: _classes.length.toString(),
                          label: 'Classes',
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.file_present,
                          value: _classes.fold<int>(0, (sum, c) => sum + c.materials.length).toString(),
                          label: 'Materials',
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: _isOnline ? Icons.wifi : Icons.wifi_off,
                          value: _isOnline ? 'Online' : 'Offline',
                          label: 'Status',
                          color: _isOnline ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          icon: Icons.auto_awesome,
                          label: 'AI Summary',
                          color: Color(0xFF66BB6A),
                          onTap: () => Navigator.pushNamed(context, '/student/summary-quiz'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickActionButton(
                          icon: Icons.smart_toy,
                          label: 'AI Model',
                          color: Color(0xFFFF9800),
                          onTap: () => Navigator.pushNamed(context, '/student/model-download'),
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
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF66BB6A), Color(0xFF4CAF50)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.savings, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Storage Saved: ${(_storageStats.spaceSaved / 1024 / 1024).toStringAsFixed(1)}MB',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Offline Banner
            if (_networkChecked && !_isOnline)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFF9800),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You\'re offline. Tap materials to open downloaded files.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Classes Section Header
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Classes (${_classes.length})',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Color(0xFF4A90E2)),
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
                  ? Center(child: CircularProgressIndicator())
                  : _classes.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 80),
                          itemCount: _classes.length,
                          itemBuilder: (context, index) => _buildClassCard(_classes[index]),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/student/join-class'),
        icon: Icon(Icons.add, size: 28),
        label: Text('Join Class', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF66BB6A),
        elevation: 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.class_, size: 100, color: Colors.grey[300]),
          SizedBox(height: 20),
          Text(
            'No classes yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Join your first class to get started!',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/student/join-class'),
            icon: Icon(Icons.add),
            label: Text('Join Class'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF66BB6A),
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 16),
              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(ClassModel classModel) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFF5F5F5)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Class Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF4A90E2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.class_, color: Color(0xFF4A90E2), size: 28),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classModel.className,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Code: ${classModel.classCode}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4A90E2),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF66BB6A).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${classModel.materials.length} files',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF66BB6A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              if (classModel.description.isNotEmpty) ...[
                SizedBox(height: 12),
                Text(
                  classModel.description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
              
              Divider(height: 24, thickness: 1),
              
              // Materials Section
              Text(
                '📚 Learning Materials',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              SizedBox(height: 12),
              
              if (classModel.materials.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No materials available yet.',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...classModel.materials.map((material) => 
                  _buildMaterialItem(classModel.classCode, material)
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialItem(String classCode, ClassMaterial material) {
    return FutureBuilder<bool>(
      future: _isMaterialDownloaded(classCode, material.name),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDownloaded ? Color(0xFFE8F5E9) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isDownloaded ? Color(0xFF66BB6A) : Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDownloaded 
                  ? Color(0xFF66BB6A).withOpacity(0.2)
                  : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDownloaded ? Icons.download_done : Icons.picture_as_pdf,
                color: isDownloaded ? Color(0xFF66BB6A) : Colors.red,
                size: 28,
              ),
            ),
            title: Text(
              material.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                isDownloaded 
                  ? '✅ Downloaded (tap to open)' 
                  : _isOnline 
                    ? '🌐 Tap to open in browser'
                    : '📴 Not available offline',
                style: TextStyle(
                  fontSize: 12,
                  color: isDownloaded ? Color(0xFF66BB6A) : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing: isDownloaded
              ? IconButton(
                  icon: Icon(Icons.delete, color: Colors.red, size: 24),
                  onPressed: () async {
                    final files = await OfflineDB.getOfflineFiles(classCode);
                    final file = files.firstWhere((f) => f.name == material.name);
                    _handleDeleteFile(file);
                  },
                )
              : _isOnline
                ? IconButton(
                    icon: Icon(Icons.download, color: Color(0xFF4A90E2), size: 24),
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