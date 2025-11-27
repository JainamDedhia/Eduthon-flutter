// FILE: lib/services/model_downloader.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelDownloader {
  static final Dio _dio = Dio();
  static CancelToken? _cancelToken;
  
  // CHANGE THIS TO YOUR S3 URL AFTER UPLOADING
  static const String MODEL_URL = 'https://study2material.s3.eu-north-1.amazonaws.com/model/model.gguf';
  static const String MODEL_FILENAME = 'model.gguf';
  static const int EXPECTED_SIZE = 678 * 1024 * 1024; // 678 MB in bytes
  
  // Check if model is already downloaded
  static Future<bool> isModelDownloaded() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/$MODEL_FILENAME';
      final file = File(modelPath);
      
      if (!await file.exists()) return false;
      
      final fileSize = await file.length();
      print('📊 [ModelDownloader] Model file size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      // If file is at least 600MB (accounting for variations), consider it downloaded
      return fileSize > 600 * 1024 * 1024;
    } catch (e) {
      print('❌ [ModelDownloader] Error checking model: $e');
      return false;
    }
  }
  
  // Get model path
  static Future<String> getModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$MODEL_FILENAME';
  }
  
  // Get current download progress from file
  static Future<int> getCurrentProgress() async {
    try {
      final modelPath = await getModelPath();
      final file = File(modelPath);
      
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
  
  // Download model with PAUSE/RESUME support
  static Future<void> downloadModel({
    required Function(int received, int total, double speed) onProgress,
    required Function(String error) onError,
    required Function() onComplete,
    required Function() onPaused,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/$MODEL_FILENAME';
      final file = File(modelPath);
      
      print('🚀 [ModelDownloader] Starting download...');
      print('📂 [ModelDownloader] Save path: $modelPath');
      
      // Check if partial download exists
      int existingBytes = 0;
      if (await file.exists()) {
        existingBytes = await file.length();
        print('📥 [ModelDownloader] Resuming from: ${(existingBytes / 1024 / 1024).toStringAsFixed(2)} MB');
      }
      
      // Create new cancel token for this download session
      _cancelToken = CancelToken();
      
      // Track download speed
      int lastReceived = existingBytes;
      DateTime lastTime = DateTime.now();
      
      // Configure Dio for resume support
      final options = Options(
        headers: {
          if (existingBytes > 0) 'Range': 'bytes=$existingBytes-',
        },
      );
      
      // Download with resume support
      await _dio.download(
        MODEL_URL,
        modelPath,
        options: options,
        deleteOnError: false, // CRITICAL: Keep partial file for resume
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          final totalReceived = existingBytes + received;
          final totalSize = existingBytes + total;
          
          // Calculate download speed (KB/s)
          final now = DateTime.now();
          final timeDiff = now.difference(lastTime).inMilliseconds / 1000.0;
          
          double speed = 0;
          if (timeDiff > 0.5) { // Update speed every 0.5 seconds
            final bytesDiff = totalReceived - lastReceived;
            speed = (bytesDiff / 1024) / timeDiff; // KB/s
            lastReceived = totalReceived;
            lastTime = now;
          }
          
          print('📥 Download: ${(totalReceived / 1024 / 1024).toStringAsFixed(1)}MB / ${(totalSize / 1024 / 1024).toStringAsFixed(1)}MB @ ${speed.toStringAsFixed(1)} KB/s');
          
          onProgress(totalReceived, totalSize, speed);
        },
      );
      
      // Verify download
      final fileSize = await file.length();
      print('✅ [ModelDownloader] Download complete! Size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      // Save download status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('model_downloaded', true);
      await prefs.setString('model_download_date', DateTime.now().toIso8601String());
      
      onComplete();
      
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // Download was paused by user
        print('⏸️ [ModelDownloader] Download paused by user');
        onPaused();
      } else {
        print('❌ [ModelDownloader] Download failed: $e');
        
        // Check if it's a resume error
        if (e.response?.statusCode == 416) {
          print('⚠️ [ModelDownloader] Server doesn\'t support resume, starting fresh...');
          
          // Delete partial file and try again
          final appDir = await getApplicationDocumentsDirectory();
          final modelPath = '${appDir.path}/$MODEL_FILENAME';
          final file = File(modelPath);
          if (await file.exists()) {
            await file.delete();
          }
          
          // Show error to user
          onError('Server doesn\'t support resume. Restarting download from beginning...');
        } else {
          onError(e.toString());
        }
      }
    } catch (e) {
      print('❌ [ModelDownloader] Unexpected error: $e');
      onError(e.toString());
    }
  }
  
  // PAUSE download
  static void pauseDownload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      print('⏸️ [ModelDownloader] Pausing download...');
      _cancelToken!.cancel('Download paused by user');
    }
  }
  
  // Check if download is currently active
  static bool isDownloading() {
    return _cancelToken != null && !_cancelToken!.isCancelled;
  }
  
  // Delete model (for testing or if corrupted)
  static Future<void> deleteModel() async {
    try {
      // Cancel any ongoing download first
      if (_cancelToken != null) {
        _cancelToken!.cancel();
      }
      
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/$MODEL_FILENAME';
      final file = File(modelPath);
      
      if (await file.exists()) {
        await file.delete();
        print('🗑️ [ModelDownloader] Model deleted');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('model_downloaded');
      await prefs.remove('model_download_date');
      
    } catch (e) {
      print('❌ [ModelDownloader] Error deleting model: $e');
      rethrow;
    }
  }
  
  // Get download info including partial progress
  static Future<Map<String, dynamic>> getDownloadInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDownloaded = prefs.getBool('model_downloaded') ?? false;
      final downloadDate = prefs.getString('model_download_date');
      
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/$MODEL_FILENAME';
      final file = File(modelPath);
      
      if (await file.exists()) {
        final fileSize = await file.length();
        final sizeMB = fileSize / 1024 / 1024;
        final progressPercent = (fileSize / EXPECTED_SIZE * 100).clamp(0, 100);
        
        return {
          'downloaded': isDownloaded,
          'size_mb': sizeMB.toStringAsFixed(2),
          'size_bytes': fileSize,
          'download_date': downloadDate,
          'path': modelPath,
          'progress_percent': progressPercent.toStringAsFixed(1),
          'is_partial': !isDownloaded && fileSize > 0,
        };
      }
      
      return {
        'downloaded': false,
        'size_mb': '0',
        'size_bytes': 0,
        'download_date': null,
        'path': null,
        'progress_percent': '0',
        'is_partial': false,
      };
    } catch (e) {
      print('❌ [ModelDownloader] Error getting download info: $e');
      return {
        'downloaded': false,
        'size_mb': '0',
        'size_bytes': 0,
        'download_date': null,
        'path': null,
        'progress_percent': '0',
        'is_partial': false,
      };
    }
  }
  
  // Calculate estimated time remaining
  static String getEstimatedTimeRemaining(int remainingBytes, double speedKBps) {
    if (speedKBps <= 0) return 'Calculating...';
    
    final seconds = (remainingBytes / 1024) / speedKBps;
    
    if (seconds < 60) {
      return '${seconds.toInt()} seconds';
    } else if (seconds < 3600) {
      return '${(seconds / 60).toInt()} minutes';
    } else {
      return '${(seconds / 3600).toInt()} hours ${((seconds % 3600) / 60).toInt()} minutes';
    }
  }
}