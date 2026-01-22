// FILE: lib/services/model_downloader.dart
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ModelDownloader {
  static final Dio _dio = Dio();
  static CancelToken? _cancelToken;
  static bool _isDownloading = false; // Separate flag for download state tracking
 
  // CHANGE THIS TO YOUR S3 URL AFTER UPLOADING
  static const String MODEL_URL ='https://f003.backblazeb2.com/b2api/v1/b2_download_file_by_id?fileId=4_zb4447856b1c3ec4499b80213_f240a004d54c648c4_d20260122_m084313_c003_v0312010_t0019_u01769071393798';
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
 
  // Parse total size from Content-Range header
  // Format: "bytes 100-678000000/678000000" or "bytes */678000000"
  static int? _parseTotalSizeFromContentRange(String? contentRange) {
    if (contentRange == null) return null;
   
    try {
      // Extract the total size after the slash
      final parts = contentRange.split('/');
      if (parts.length == 2) {
        return int.tryParse(parts[1].trim());
      }
    } catch (e) {
      print('⚠️ [ModelDownloader] Error parsing Content-Range: $e');
    }
    return null;
  }


  // Download model with PAUSE/RESUME support using stream-based approach
  static Future<void> downloadModel({
    required Function(int received, int total, double speed) onProgress,
    required Function(String error) onError,
    required Function() onComplete,
    required Function() onPaused,
  }) async {
    IOSink? fileSink;
   
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
      _isDownloading = true;
     
      // Save progress state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('model_download_progress', existingBytes);
     
      // Configure Dio for resume support with stream response
      final options = Options(
        responseType: ResponseType.stream,
        headers: {
          if (existingBytes > 0) 'Range': 'bytes=$existingBytes-',
        },
        receiveTimeout: const Duration(minutes: 30), // Long timeout for large files
      );
     
      // Get response as stream
      final response = await _dio.get(
  MODEL_URL,
  options: options.copyWith(
    headers: {
      ...?options.headers,
      'Authorization': '4_003448613c498230000000001_01c1eb89_e40fa5_acct_opmqAYaeV5Fm5rL6w0SMVyYdJIU=',
    },
  ),
  cancelToken: _cancelToken,
);


     
      // Check response status
      final statusCode = response.statusCode ?? 0;
      if (statusCode != 200 && statusCode != 206) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Unexpected status code: $statusCode',
        );
      }
     
      // Handle 416 Range Not Satisfiable - delete partial file and restart
      if (statusCode == 416) {
        print('⚠️ [ModelDownloader] Server returned 416, deleting partial file and restarting...');
        if (await file.exists()) {
          await file.delete();
        }
        await prefs.remove('model_download_progress');
        onError('Server doesn\'t support resume. Please restart download from beginning.');
        _isDownloading = false;
        return;
      }
     
      // Parse total file size from headers
      int totalSize = EXPECTED_SIZE; // Default fallback
     
      // Try Content-Range header first (for partial content responses)
      final contentRange = response.headers.value('content-range');
      if (contentRange != null) {
        final parsedTotal = _parseTotalSizeFromContentRange(contentRange);
        if (parsedTotal != null) {
          totalSize = parsedTotal;
          print('📊 [ModelDownloader] Total size from Content-Range: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB');
        }
      }
     
      // Fallback to Content-Length header
      if (totalSize == EXPECTED_SIZE) {
        final contentLength = response.headers.value('content-length');
        if (contentLength != null) {
          final parsedLength = int.tryParse(contentLength);
          if (parsedLength != null) {
            // For partial content, Content-Length is the remaining bytes
            // So total = existing + contentLength
            if (statusCode == 206 && existingBytes > 0) {
              totalSize = existingBytes + parsedLength;
            } else {
              totalSize = parsedLength;
            }
            print('📊 [ModelDownloader] Total size from Content-Length: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB');
          }
        }
      }
     
      // Open file in append mode if resuming, write mode if starting fresh
      fileSink = file.openWrite(mode: existingBytes > 0 ? FileMode.append : FileMode.write);
     
      // Track download progress
      int bytesReceived = 0;
      int lastReceived = existingBytes;
      DateTime lastTime = DateTime.now();
     
      // Stream chunks to file using listen for better cancellation control
      final completer = Completer<void>();
      late StreamSubscription subscription;
      subscription = response.data.stream.listen(
        (chunk) {
          // Check if cancelled
          if (_cancelToken?.isCancelled ?? false) {
            subscription.cancel();
            completer.completeError(
              DioException(
                requestOptions: response.requestOptions,
                type: DioExceptionType.cancel,
                error: 'Download cancelled',
              ),
            );
            return;
          }
         
          fileSink!.add(chunk);
          bytesReceived += chunk.length as int;
         
          final totalReceived = existingBytes + bytesReceived;
         
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
         
          // Ensure progress never exceeds 100%
          final progressTotal = totalSize > 0 ? totalSize : EXPECTED_SIZE;
          final clampedReceived = totalReceived > progressTotal ? progressTotal : totalReceived;
         
          print('📥 Download: ${(clampedReceived / 1024 / 1024).toStringAsFixed(1)}MB / ${(progressTotal / 1024 / 1024).toStringAsFixed(1)}MB @ ${speed.toStringAsFixed(1)} KB/s');
         
          onProgress(clampedReceived, progressTotal, speed);
         
          // Save progress periodically (fire-and-forget to avoid blocking stream)
          if (bytesReceived % (1024 * 1024) == 0) { // Every MB
            unawaited(prefs.setInt('model_download_progress', totalReceived));
          }
        },
        onError: (error) {
          completer.completeError(error);
        },
        onDone: () {
          completer.complete();
        },
        cancelOnError: true,
      );
     
      // Wait for stream to complete
      await completer.future;
     
      // Close file sink
      await fileSink.close();
      fileSink = null;
     
      // Verify download
      final fileSize = await file.length();
      print('✅ [ModelDownloader] Download complete! Size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
     
      // Save download status
      await prefs.setBool('model_downloaded', true);
      await prefs.setString('model_download_date', DateTime.now().toIso8601String());
      await prefs.remove('model_download_progress');
     
      _isDownloading = false;
      onComplete();
     
    } on DioException catch (e) {
      // Close file sink if still open
      await fileSink?.close();
      fileSink = null;
     
      if (CancelToken.isCancel(e)) {
        // Download was paused by user
        print('⏸️ [ModelDownloader] Download paused by user');
        _isDownloading = false;
       
        // Save current progress
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final modelPath = '${appDir.path}/$MODEL_FILENAME';
          final file = File(modelPath);
          if (await file.exists()) {
            final currentProgress = await file.length();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('model_download_progress', currentProgress);
          }
        } catch (e) {
          print('⚠️ [ModelDownloader] Error saving progress: $e');
        }
       
        onPaused();
      } else {
        print('❌ [ModelDownloader] Download failed: $e');
        _isDownloading = false;
       
        // Handle specific error cases
        if (e.response?.statusCode == 416) {
          print('⚠️ [ModelDownloader] Server doesn\'t support resume, deleting partial file...');
         
          final appDir = await getApplicationDocumentsDirectory();
          final modelPath = '${appDir.path}/$MODEL_FILENAME';
          final file = File(modelPath);
          if (await file.exists()) {
            await file.delete();
          }
         
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('model_download_progress');
         
          onError('Server doesn\'t support resume. Please restart download from beginning.');
        } else if (e.type == DioExceptionType.connectionTimeout ||
                   e.type == DioExceptionType.receiveTimeout ||
                   e.type == DioExceptionType.connectionError) {
          // Network error - save progress for resume
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final modelPath = '${appDir.path}/$MODEL_FILENAME';
            final file = File(modelPath);
            if (await file.exists()) {
              final currentProgress = await file.length();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('model_download_progress', currentProgress);
            }
          } catch (e) {
            print('⚠️ [ModelDownloader] Error saving progress: $e');
          }
         
          onError('Network error: ${e.message}. You can resume from where you left off.');
        } else {
          onError('Download failed: ${e.message ?? e.toString()}');
        }
      }
    } catch (e) {
      // Close file sink if still open
      await fileSink?.close();
      fileSink = null;
     
      print('❌ [ModelDownloader] Unexpected error: $e');
      _isDownloading = false;
     
      // Save progress if possible
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final modelPath = '${appDir.path}/$MODEL_FILENAME';
        final file = File(modelPath);
        if (await file.exists()) {
          final currentProgress = await file.length();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('model_download_progress', currentProgress);
        }
      } catch (e) {
        print('⚠️ [ModelDownloader] Error saving progress: $e');
      }
     
      onError('Unexpected error: $e');
    }
  }
 
  // PAUSE download
  static void pauseDownload() {
    if (_isDownloading && _cancelToken != null && !_cancelToken!.isCancelled) {
      print('⏸️ [ModelDownloader] Pausing download...');
      _cancelToken!.cancel('Download paused by user');
      // Note: _isDownloading will be set to false in the catch block
    }
  }
 
  // Check if download is currently active
  static bool isDownloading() {
    return _isDownloading;
  }
 
  // Delete model (for testing or if corrupted)
  static Future<void> deleteModel() async {
    try {
      // Cancel any ongoing download first
      if (_cancelToken != null) {
        _cancelToken!.cancel();
      }
      _isDownloading = false;
     
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
      await prefs.remove('model_download_progress');
     
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
