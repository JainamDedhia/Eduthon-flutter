import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'package:claudetest/services/quiz_sync_service.dart';

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

// ADD THESE METHODS TO lib/services/offline_db.dart
// (Add to the existing OfflineDB class)

  // Save mind map
  static Future<void> saveMindMap(
    String classCode,
    String fileName,
    Map<String, dynamic> mindMapData,
  ) async {
    try {
      print('💾 [offlineDB] Saving mind map for: $fileName');

      final key = 'mindmap_${classCode}_$fileName';
      final data = {
        'mindmap': mindMapData,
        'generatedAt': DateTime.now().toIso8601String(),
      };

      await prefs.setString(key, jsonEncode(data));
      print('✅ [offlineDB] Mind map saved: $fileName');
    } catch (e) {
      print('❌ [offlineDB] Failed to save mind map: $e');
      throw Exception('Failed to save mind map: $e');
    }
  }

  // Get mind map
  static Future<Map<String, dynamic>?> getMindMap(
    String classCode,
    String fileName,
  ) async {
    try {
      print('📂 [offlineDB] Getting mind map for: $fileName');

      final key = 'mindmap_${classCode}_$fileName';
      final value = prefs.getString(key);

      if (value == null) {
        print('⚠️ [offlineDB] No mind map found for: $fileName');
        return null;
      }

      final data = jsonDecode(value) as Map<String, dynamic>;
      print('✅ [offlineDB] Mind map retrieved: $fileName');
      return data;
    } catch (e) {
      print('❌ [offlineDB] Failed to get mind map: $e');
      return null;
    }
  }

  // Check if mind map exists
  static Future<bool> hasMindMap(String classCode, String fileName) async {
    final key = 'mindmap_${classCode}_$fileName';
    return prefs.containsKey(key);
  }

  // Delete mind map
  static Future<void> deleteMindMap(String classCode, String fileName) async {
    try {
      print('🗑️ [offlineDB] Deleting mind map for: $fileName');
      final key = 'mindmap_${classCode}_$fileName';
      await prefs.remove(key);
      print('✅ [offlineDB] Deleted mind map: $fileName');
    } catch (e) {
      print('❌ [offlineDB] Failed to delete mind map: $e');
      throw Exception('Failed to delete mind map: $e');
    }
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
  // Save summary and quiz
  // Save summary and quiz
  static Future<void> saveSummaryAndQuiz(
    String classCode,
    String fileName,
    String summary,
    List<Map<String, dynamic>> quiz,
  ) async {
    try {
      print('💾 [offlineDB] Saving summary & quiz for: $fileName');

      final key = 'summary_quiz_${classCode}_$fileName';
      final data = {
        'summary': summary,
        'quiz': quiz,
        'generatedAt': DateTime.now().toIso8601String(),
      };

      await prefs.setString(key, jsonEncode(data));
      print('✅ [offlineDB] Summary & quiz saved: $fileName');
    } catch (e) {
      print('❌ [offlineDB] Failed to save summary & quiz: $e');
      throw Exception('Failed to save: $e');
    }
  }

  // Get summary and quiz
  static Future<Map<String, dynamic>?> getSummaryAndQuiz(
    String classCode,
    String fileName,
  ) async {
    try {
      print('📂 [offlineDB] Getting summary & quiz for: $fileName');

      final key = 'summary_quiz_${classCode}_$fileName';
      final value = prefs.getString(key);

      if (value == null) {
        print('⚠️ [offlineDB] No summary found for: $fileName');
        return null;
      }

      final data = jsonDecode(value) as Map<String, dynamic>;
      print('✅ [offlineDB] Summary & quiz retrieved: $fileName');
      return data;
    } catch (e) {
      print('❌ [offlineDB] Failed to get summary & quiz: $e');
      return null;
    }
  }

  // Check if summary exists
  static Future<bool> hasSummary(String classCode, String fileName) async {
    final key = 'summary_quiz_${classCode}_$fileName';
    return prefs.containsKey(key);
  }

  // Delete summary and quiz
  static Future<void> deleteSummaryAndQuiz(String classCode, String fileName) async {
    try {
      print('🗑️ [offlineDB] Deleting summary & quiz for: $fileName');
      final key = 'summary_quiz_${classCode}_$fileName';
      await prefs.remove(key);
      print('✅ [offlineDB] Deleted: $fileName');
    } catch (e) {
      print('❌ [offlineDB] Failed to delete summary & quiz: $e');
      throw Exception('Failed to delete: $e');
    }
  }

  // Save quiz result locally
  static Future<void> saveQuizResult(dynamic result) async {
    try {
      final key = 'quiz_result_${result.studentId}_${result.classCode}_${result.fileName}_${result.completedAt.replaceAll(RegExp(r'[^0-9]'), '')}';
      await prefs.setString(key, jsonEncode(result.toJson()));
      print('✅ [offlineDB] Quiz result saved: ${result.fileName}');
    } catch (e) {
      print('❌ [offlineDB] Failed to save quiz result: $e');
      throw Exception('Failed to save quiz result: $e');
    }
  }

  // Get all pending (unsynced) quiz results
  static Future<List<dynamic>> getPendingQuizResults() async {
    try {
      final allKeys = prefs.getKeys();
      final quizKeys = allKeys.where((key) => key.startsWith('quiz_result_')).toList();
      
      final results = <dynamic>[];
      for (final key in quizKeys) {
        try {
          final value = prefs.getString(key);
          if (value != null) {
            final data = jsonDecode(value);
            // Only return unsynced results
            if (data['synced'] != true) {
              // Import QuizResult from quiz_sync_service.dart
              final result = QuizResult.fromJson(data);
              results.add(result);
            }
          }
        } catch (e) {
          print('⚠️ [offlineDB] Failed to parse quiz result for key $key: $e');
        }
      }
      
      return results;
    } catch (e) {
      print('❌ [offlineDB] Failed to get pending quiz results: $e');
      return [];
    }
  }

  // Mark quiz result as synced
  static Future<void> markQuizResultAsSynced(dynamic result) async {
    try {
      final key = 'quiz_result_${result.studentId}_${result.classCode}_${result.fileName}_${result.completedAt.replaceAll(RegExp(r'[^0-9]'), '')}';
      final data = result.toJson();
      data['synced'] = true;
      await prefs.setString(key, jsonEncode(data));
      print('✅ [offlineDB] Quiz result marked as synced: ${result.fileName}');
    } catch (e) {
      print('❌ [offlineDB] Failed to mark as synced: $e');
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

