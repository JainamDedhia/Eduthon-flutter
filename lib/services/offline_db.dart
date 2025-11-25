import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class OfflineDB {
  static SharedPreferences? _prefs;

  // Initialize (SharedPreferences is always ready)
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    print('✅ [offlineDB] SharedPreferences initialized');
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('OfflineDB not initialized. Call OfflineDB.init() first.');
    }
    return _prefs!;
  }

  // Save file record
  static Future<void> saveFileRecord(
    String classCode,
    String name,
    String localPath, {
    String? url,
    int? compressedSize,
    int? originalSize,
  }) async {
    try {
      print('💾 [offlineDB] Saving file record: $name for class $classCode');

      final key = 'offline_file_${classCode}_$name';
      final fileData = FileRecord(
        classCode: classCode,
        name: name,
        localPath: localPath,
        url: url ?? '',
        compressedSize: compressedSize ?? 0,
        originalSize: originalSize ?? 0,
        isCompressed: compressedSize != null,
        savedAt: DateTime.now().toIso8601String(),
      );

      await prefs.setString(key, jsonEncode(fileData.toJson()));
      print('✅ [offlineDB] Successfully saved: $name');
    } catch (e) {
      print('❌ [offlineDB] Failed to save file record: $e');
      throw Exception('Failed to save file: $e');
    }
  }

  // Get offline files for a class
  static Future<List<FileRecord>> getOfflineFiles(String classCode) async {
    try {
      print('📂 [offlineDB] Getting offline files for class: $classCode');

      final allKeys = prefs.getKeys();
      final classKeys = allKeys
          .where((key) => key.startsWith('offline_file_${classCode}_'))
          .toList();

      print('📂 [offlineDB] Found ${classKeys.length} keys for class $classCode');

      final files = <FileRecord>[];
      for (final key in classKeys) {
        try {
          final value = prefs.getString(key);
          if (value != null) {
            final fileData = FileRecord.fromJson(jsonDecode(value));
            files.add(fileData);
          }
        } catch (e) {
          print('⚠️ [offlineDB] Failed to parse file data for key $key: $e');
        }
      }

      // Sort by savedAt date (newest first)
      files.sort((a, b) =>
          DateTime.parse(b.savedAt).compareTo(DateTime.parse(a.savedAt)));

      print('✅ [offlineDB] Returning ${files.length} files for class $classCode');
      return files;
    } catch (e) {
      print('❌ [offlineDB] Failed to get offline files: $e');
      throw Exception('Failed to get files: $e');
    }
  }

  // Check if file exists
  static Future<bool> checkFileExists(String classCode, String name) async {
    try {
      print('🔍 [offlineDB] Checking if file exists: $name in class $classCode');

      final key = 'offline_file_${classCode}_$name';
      final exists = prefs.containsKey(key);

      print('✅ [offlineDB] File $name exists: $exists');
      return exists;
    } catch (e) {
      print('❌ [offlineDB] Failed to check file existence: $e');
      throw Exception('Failed to check file: $e');
    }
  }

  // Delete file record
  static Future<void> deleteFileRecord(String classCode, String name) async {
    try {
      print('🗑️ [offlineDB] Deleting file record: $name from class $classCode');

      final key = 'offline_file_${classCode}_$name';
      await prefs.remove(key);

      print('✅ [offlineDB] Successfully deleted: $name');
    } catch (e) {
      print('❌ [offlineDB] Failed to delete file record: $e');
      throw Exception('Failed to delete file: $e');
    }
  }

  // Get all offline files
  static Future<List<FileRecord>> getAllOfflineFiles() async {
    try {
      print('📂 [offlineDB] Getting all offline files');

      final allKeys = prefs.getKeys();
      final fileKeys =
          allKeys.where((key) => key.startsWith('offline_file_')).toList();

      final files = <FileRecord>[];
      for (final key in fileKeys) {
        try {
          final value = prefs.getString(key);
          if (value != null) {
            final fileData = FileRecord.fromJson(jsonDecode(value));
            files.add(fileData);
          }
        } catch (e) {
          print('⚠️ [offlineDB] Failed to parse file data for key $key: $e');
        }
      }

      // Sort by savedAt date (newest first)
      files.sort((a, b) =>
          DateTime.parse(b.savedAt).compareTo(DateTime.parse(a.savedAt)));

      print('✅ [offlineDB] Found ${files.length} total offline files');
      return files;
    } catch (e) {
      print('❌ [offlineDB] Failed to get all offline files: $e');
      throw Exception('Failed to get all files: $e');
    }
  }

  // Get storage statistics
  static Future<StorageStats> getStorageStats() async {
    try {
      final allFiles = await getAllOfflineFiles();
      final compressedFiles = allFiles
          .where((file) =>
              file.isCompressed &&
              file.compressedSize != null &&
              file.originalSize != null)
          .toList();

      final totalFiles = compressedFiles.length;
      final totalCompressedSize = compressedFiles.fold<int>(
          0, (sum, file) => sum + (file.compressedSize ?? 0));
      final totalOriginalSize = compressedFiles.fold<int>(
          0, (sum, file) => sum + (file.originalSize ?? 0));
      final totalSpaceSaved = totalOriginalSize - totalCompressedSize;

      return StorageStats(
        totalFiles: totalFiles,
        compressedFiles: compressedFiles.length,
        totalSpaceUsed: totalCompressedSize,
        spaceSaved: totalSpaceSaved,
      );
    } catch (e) {
      print('❌ [offlineDB] Failed to calculate space savings: $e');
      return StorageStats.empty();
    }
  }

  // Clear all offline files (for debugging)
  static Future<void> clearAllOfflineFiles() async {
    try {
      final allKeys = prefs.getKeys();
      final fileKeys =
          allKeys.where((key) => key.startsWith('offline_file_')).toList();

      for (final key in fileKeys) {
        await prefs.remove(key);
      }

      print('🧹 [offlineDB] Cleared ${fileKeys.length} offline files');
    } catch (e) {
      print('❌ [offlineDB] Failed to clear files: $e');
      throw Exception('Failed to clear files: $e');
    }
  }
}