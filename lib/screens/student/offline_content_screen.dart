import 'package:flutter/material.dart';
import '../../services/offline_db.dart';
import '../../services/download_manager.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/rounded_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_indicator.dart';

class OfflineContentScreen extends StatefulWidget {
  const OfflineContentScreen({super.key});

  @override
  State<OfflineContentScreen> createState() => _OfflineContentScreenState();
}

class _OfflineContentScreenState extends State<OfflineContentScreen> {
  List<FileRecord> _offlineFiles = [];
  StorageStats _storageStats = StorageStats.empty();
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOfflineFiles();
  }

  Future<void> _loadOfflineFiles() async {
    setState(() => _loading = true);
    try {
      final allFiles = await OfflineDB.getAllOfflineFiles();
      final stats = await OfflineDB.getStorageStats();
      setState(() {
        _offlineFiles = allFiles;
        _storageStats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading files: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteFile(FileRecord file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        title: const Text('Delete File'),
        content: Text('Delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DownloadManager.deleteFile(file.localPath);
        await OfflineDB.deleteFileRecord(file.classCode, file.name);
        await _loadOfflineFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ File deleted'),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _openFile(FileRecord file) async {
    try {
      await DownloadManager.openFile(file.localPath, file.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<FileRecord> get _filteredFiles {
    if (_searchQuery.isEmpty) {
      return _offlineFiles;
    }
    return _offlineFiles.where((file) {
      return file.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          file.classCode.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: const Text('Offline Content'),
      ),
      body: Column(
        children: [
          // Storage Stats
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            color: AppTheme.white,
            child: Row(
              children: [
                const Icon(Icons.storage, color: AppTheme.primaryBlue, size: 32),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Storage Used',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      Text(
                        '${(_storageStats.totalSpaceUsed / 1024 / 1024).toStringAsFixed(1)} MB',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_storageStats.spaceSaved > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Space Saved',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      Text(
                        '${(_storageStats.spaceSaved / 1024 / 1024).toStringAsFixed(1)} MB',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successGreen,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Search Bar
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            color: AppTheme.white,
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.lightGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Files List
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : _filteredFiles.isEmpty
                    ? EmptyState(
                        icon: Icons.folder_off,
                        title: _searchQuery.isEmpty
                            ? 'No Offline Files'
                            : 'No Files Found',
                        message: _searchQuery.isEmpty
                            ? 'Download materials to access them offline'
                            : 'Try a different search term',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        itemCount: _filteredFiles.length,
                        itemBuilder: (context, index) {
                          final file = _filteredFiles[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                            child: _buildFileCard(file),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(FileRecord file) {
    final fileSize = file.compressedSize ?? file.originalSize ?? 0;
    final sizeInMB = (fileSize / 1024 / 1024).toStringAsFixed(2);

    return RoundedCard(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              color: AppTheme.errorRed,
              size: 32,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingS,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                      child: Text(
                        file.classCode,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryBlue,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      '$sizeInMB MB',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: AppTheme.primaryBlue),
            onPressed: () => _openFile(file),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
            onPressed: () => _deleteFile(file),
          ),
        ],
      ),
    );
  }
}

