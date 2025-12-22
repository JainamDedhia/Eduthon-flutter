// FILE: lib/screens/student/library_screen.dart
import 'package:flutter/material.dart';
import '../../services/library_service.dart';
import '../../services/offline_db.dart';
import '../../services/download_manager.dart';
import '../../models/models.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _downloadingFile;
  double _downloadProgress = 0.0;
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Textbooks',
    'Digests',
    'Science',
    'Maths',
    'English',
    'History',
    'Geography',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<LibraryItem> _getFilteredItems() {
    final allItems = LibraryService.getAllItems();
    final selectedCategory = _categories[_tabController.index];

    // Filter by category
    List<LibraryItem> filtered;
    
    if (selectedCategory == 'All') {
      filtered = allItems;
    } else if (selectedCategory == 'Textbooks') {
      // Show all items EXCEPT digests
      filtered = allItems.where((item) => item.category != 'Digests').toList();
    } else if (selectedCategory == 'Digests') {
      // Show only digests
      filtered = allItems.where((item) => item.category == 'Digests').toList();
    } else {
      // Show items for specific subject
      filtered = allItems
          .where((item) => item.category.toLowerCase() == 
              selectedCategory.toLowerCase())
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              item.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return filtered;
  }

  Future<void> _downloadItem(LibraryItem item) async {
    setState(() {
      _downloadingFile = item.title;
      _downloadProgress = 0.0;
    });

    try {
      // Create a ClassMaterial object for download
      final material = ClassMaterial(
        name: item.fileName,
        url: item.downloadUrl,
        uploadedAt: DateTime.now().toIso8601String(),
      );

      // Download using existing DownloadManager
      await DownloadManager.downloadAndStore('library', material);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('✅ ${item.title} downloaded successfully!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ [Library] Download failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingFile = null;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  Future<bool> _isItemDownloaded(LibraryItem item) async {
    return await OfflineDB.checkFileExists('library', item.fileName);
  }

  Future<void> _openDownloadedFile(LibraryItem item) async {
    try {
      final files = await OfflineDB.getOfflineFiles('library');
      final file = files.firstWhere((f) => f.name == item.fileName);
      
      await DownloadManager.openFile(file.localPath, file.name);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('📖 Opening ${item.title}...'),
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
          SnackBar(
            content: Text('❌ Failed to open file: $e'),
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
      body: SafeArea(
        child: Column(
          children: [
            // Header (NO BACK BUTTON)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B46C1), Color(0xFF553C9A)],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_library, color: Colors.white, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '📚 Study Library',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search textbooks, digests...',
                        prefixIcon:
                            Icon(Icons.search, color: Color(0xFF6B46C1)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  // Info Banner
                  Container(
                    margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF2196F3), width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.info_outline,
                              color: Color(0xFF2196F3), size: 20),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📖 How to Use Library',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '• Chapters: Read & Generate AI Summary/Quiz\n• Digests: Read & Reference only',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1565C0),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Category Tabs
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Color(0xFF6B46C1),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFF6B46C1),
                tabs: _categories
                    .map((category) => Tab(text: category))
                    .toList(),
                onTap: (_) => setState(() {}),
              ),
            ),

            // Content
            Expanded(
              child: _downloadingFile != null
                  ? _buildDownloadingIndicator()
                  : _buildLibraryGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadingIndicator() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(32),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation(Color(0xFF6B46C1)),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Downloading...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _downloadingFile!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryGrid() {
    final items = _getFilteredItems();
    final selectedCategory = _categories[_tabController.index];

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selectedCategory == 'Textbooks')
              Icon(Icons.menu_book, size: 80, color: Colors.grey[400])
            else if (selectedCategory == 'Digests')
              Icon(Icons.library_books, size: 80, color: Colors.grey[400])
            else
              Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              selectedCategory == 'Textbooks'
                  ? 'All Textbooks'
                  : selectedCategory == 'Digests'
                      ? 'Master Key Digests'
                      : 'No items found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              selectedCategory == 'Textbooks'
                  ? 'Tap on a subject to view chapters'
                  : selectedCategory == 'Digests'
                      ? 'Reference books for exam preparation'
                      : 'Try adjusting your search or category',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildLibraryCard(items[index]),
    );
  }

  Widget _buildLibraryCard(LibraryItem item) {
    return FutureBuilder<bool>(
      future: _isItemDownloaded(item),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        final isDigest = item.category == 'Digests';

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: isDownloaded
                ? () => _openDownloadedFile(item)
                : () => _downloadItem(item),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: _getCategoryColors(item.category),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Badge
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    SizedBox(height: 8),

                    // Icon
                    Center(
                      child: Icon(
                        _getCategoryIcon(item.category),
                        size: 36,
                        color: Colors.white,
                      ),
                    ),

                    SizedBox(height: 8),

                    // Title
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    SizedBox(height: 4),

                    // Description
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 6),

                    // Download/View Button
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isDownloaded ? Icons.visibility : Icons.download,
                            size: 14,
                            color: isDownloaded
                                ? Colors.green
                                : _getCategoryColors(item.category)[0],
                          ),
                          SizedBox(width: 4),
                          Text(
                            isDownloaded ? 'Read' : 'Download',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDownloaded
                                  ? Colors.green
                                  : _getCategoryColors(item.category)[0],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // AI Tools badge for chapters only
                    if (isDownloaded && !isDigest) ...[
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber[700]!, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 12,
                                color: Colors.amber[700]!),
                            SizedBox(width: 4),
                            Text(
                              'AI Tools',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[900]!,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Color> _getCategoryColors(String category) {
    switch (category.toLowerCase()) {
      case 'science':
        return [Color(0xFF4CAF50), Color(0xFF388E3C)];
      case 'maths':
        return [Color(0xFF2196F3), Color(0xFF1976D2)];
      case 'english':
        return [Color(0xFFFF9800), Color(0xFFF57C00)];
      case 'history':
        return [Color(0xFF795548), Color(0xFF5D4037)];
      case 'geography':
        return [Color(0xFF009688), Color(0xFF00796B)];
      case 'marathi':
        return [Color(0xFFE91E63), Color(0xFFC2185B)];
      case 'digests':
        return [Color(0xFF9C27B0), Color(0xFF7B1FA2)];
      default:
        return [Color(0xFF6B46C1), Color(0xFF553C9A)];
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'science':
        return Icons.science;
      case 'maths':
        return Icons.calculate;
      case 'english':
        return Icons.language;
      case 'history':
        return Icons.history_edu;
      case 'geography':
        return Icons.public;
      case 'marathi':
        return Icons.translate;
      case 'digests':
        return Icons.library_books;
      default:
        return Icons.menu_book;
    }
  }
}