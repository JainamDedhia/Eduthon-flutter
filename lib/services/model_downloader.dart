// FILE: lib/services/model_downloader.dart
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelDownloader {
  static final Dio _dio = Dio();
  static CancelToken? _cancelToken;
  static bool _isDownloading =
      false; // Separate flag for download state tracking

  // CHANGE THIS TO YOUR S3 URL AFTER UPLOADING
  static const String MODEL_URL =
      'https://study2material1.s3.eu-north-1.amazonaws.com/model.gguf';
  static const String MODEL_FILENAME = 'model.gguf';
  static const int EXPECTED_SIZE = 408 * 1024 * 1024; // 408 MB in bytes
  static const Map<String, Map<String, dynamic>> _REGISTRY = {
    'general': {
      'url': MODEL_URL,
      'filename': MODEL_FILENAME,
      'expected': EXPECTED_SIZE,
      'display': 'Qwen 2.5 AI Model',
    },
    'summary': {
      'url':
          'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_0.gguf?download=1',
      'filename': 'summary.gguf',
      'expected': 409 * 1024 * 1024,
      'display': 'Summary Specialist',
    },
    'quiz': {
      'url':
          'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q3_k_m.gguf?download=1',
      'filename': 'quiz.gguf',
      'expected': 280 * 1024 * 1024,
      'display': 'Quiz Specialist',
    },
  };
  static Map<String, dynamic> _cfg(String id) =>
      _REGISTRY[id] ?? _REGISTRY['general']!;

  // Check if model is already downloaded
  static Future<bool> isModelDownloaded() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/$MODEL_FILENAME';
      final file = File(modelPath);

      if (!await file.exists()) return false;

      final fileSize = await file.length();
      print(
        '📊 [ModelDownloader] Model file size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      // Consider downloaded if size is at least 85% of expected
      return fileSize >= (EXPECTED_SIZE * 0.85).toInt();
    } catch (e) {
      print('❌ [ModelDownloader] Error checking model: $e');
      return false;
    }
  }

  static Future<bool> isModelDownloadedFor(String id) async {
    try {
      final cfg = _cfg(id);
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/${cfg['filename']}';
      final file = File(modelPath);
      if (!await file.exists()) return false;
      final fileSize = await file.length();
      final expect = (cfg['expected'] as int);
      return fileSize >= (expect * 0.85).toInt();
    } catch (e) {
      print('❌ [ModelDownloader] Error checking model($id): $e');
      return false;
    }
  }

  // Get model path
  static Future<String> getModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$MODEL_FILENAME';
  }

  static Future<String> getModelPathFor(String id) async {
    final cfg = _cfg(id);
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/${cfg['filename']}';
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

  static Future<int> getCurrentProgressFor(String id) async {
    try {
      final modelPath = await getModelPathFor(id);
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
        print(
          '📥 [ModelDownloader] Resuming from: ${(existingBytes / 1024 / 1024).toStringAsFixed(2)} MB',
        );
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
        headers: {if (existingBytes > 0) 'Range': 'bytes=$existingBytes-'},
        receiveTimeout: const Duration(
          minutes: 30,
        ), // Long timeout for large files
      );

      // Get response as stream
      final response = await _dio.get(
        MODEL_URL,
        options: options,
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
        print(
          '⚠️ [ModelDownloader] Server returned 416, deleting partial file and restarting...',
        );
        if (await file.exists()) {
          await file.delete();
        }
        await prefs.remove('model_download_progress');
        onError(
          'Server doesn\'t support resume. Please restart download from beginning.',
        );
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
          print(
            '📊 [ModelDownloader] Total size from Content-Range: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB',
          );
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
            print(
              '📊 [ModelDownloader] Total size from Content-Length: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB',
            );
          }
        }
      }

      // Open file in append mode if resuming, write mode if starting fresh
      fileSink = file.openWrite(
        mode: existingBytes > 0 ? FileMode.append : FileMode.write,
      );

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
          if (timeDiff > 0.5) {
            // Update speed every 0.5 seconds
            final bytesDiff = totalReceived - lastReceived;
            speed = (bytesDiff / 1024) / timeDiff; // KB/s
            lastReceived = totalReceived;
            lastTime = now;
          }

          // Ensure progress never exceeds 100%
          final progressTotal = totalSize > 0 ? totalSize : EXPECTED_SIZE;
          final clampedReceived =
              totalReceived > progressTotal ? progressTotal : totalReceived;

          print(
            '📥 Download: ${(clampedReceived / 1024 / 1024).toStringAsFixed(1)}MB / ${(progressTotal / 1024 / 1024).toStringAsFixed(1)}MB @ ${speed.toStringAsFixed(1)} KB/s',
          );

          onProgress(clampedReceived, progressTotal, speed);

          // Save progress periodically (fire-and-forget to avoid blocking stream)
          if (bytesReceived % (1024 * 1024) == 0) {
            // Every MB
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
      print(
        '✅ [ModelDownloader] Download complete! Size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      // Save download status
      await prefs.setBool('model_downloaded', true);
      await prefs.setString(
        'model_download_date',
        DateTime.now().toIso8601String(),
      );
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
          print(
            '⚠️ [ModelDownloader] Server doesn\'t support resume, deleting partial file...',
          );

          final appDir = await getApplicationDocumentsDirectory();
          final modelPath = '${appDir.path}/$MODEL_FILENAME';
          final file = File(modelPath);
          if (await file.exists()) {
            await file.delete();
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('model_download_progress');

          onError(
            'Server doesn\'t support resume. Please restart download from beginning.',
          );
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

          onError(
            'Network error: ${e.message}. You can resume from where you left off.',
          );
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

  static Future<void> downloadModelFor({
    required String modelId,
    required Function(int received, int total, double speed) onProgress,
    required Function(String error) onError,
    required Function() onComplete,
    required Function() onPaused,
  }) async {
    IOSink? fileSink;
    final cfg = _cfg(modelId);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/${cfg['filename']}';
      final file = File(modelPath);
      int existingBytes = 0;
      if (await file.exists()) {
        existingBytes = await file.length();
      }
      _cancelToken = CancelToken();
      _isDownloading = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${modelId}_download_progress', existingBytes);
      final options = Options(
        responseType: ResponseType.stream,
        headers: {if (existingBytes > 0) 'Range': 'bytes=$existingBytes-'},
        receiveTimeout: const Duration(minutes: 30),
      );
      final response = await _dio.get(
        cfg['url'] as String,
        options: options,
        cancelToken: _cancelToken,
      );
      final statusCode = response.statusCode ?? 0;
      if (statusCode != 200 && statusCode != 206) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Unexpected status code: $statusCode',
        );
      }
      if (statusCode == 416) {
        if (await file.exists()) {
          await file.delete();
        }
        await prefs.remove('${modelId}_download_progress');
        _isDownloading = false;
        onError('Server doesn\'t support resume. Please restart download.');
        return;
      }
      int totalSize = (cfg['expected'] as int);
      final contentRange = response.headers.value('content-range');
      if (contentRange != null) {
        final parsedTotal = _parseTotalSizeFromContentRange(contentRange);
        if (parsedTotal != null) {
          totalSize = parsedTotal;
        }
      }
      if (totalSize == (cfg['expected'] as int)) {
        final contentLength = response.headers.value('content-length');
        if (contentLength != null) {
          final parsedLength = int.tryParse(contentLength);
          if (parsedLength != null) {
            if (statusCode == 206 && existingBytes > 0) {
              totalSize = existingBytes + parsedLength;
            } else {
              totalSize = parsedLength;
            }
          }
        }
      }
      fileSink = file.openWrite(
        mode: existingBytes > 0 ? FileMode.append : FileMode.write,
      );
      int bytesReceived = 0;
      int lastReceived = existingBytes;
      DateTime lastTime = DateTime.now();
      final completer = Completer<void>();
      late StreamSubscription subscription;
      subscription = response.data.stream.listen(
        (chunk) {
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
          final now = DateTime.now();
          final timeDiff = now.difference(lastTime).inMilliseconds / 1000.0;
          double speed = 0;
          if (timeDiff > 0.5) {
            final bytesDiff = totalReceived - lastReceived;
            speed = (bytesDiff / 1024) / timeDiff;
            lastReceived = totalReceived;
            lastTime = now;
          }
          final progressTotal =
              totalSize > 0 ? totalSize : (cfg['expected'] as int);
          final clampedReceived =
              totalReceived > progressTotal ? progressTotal : totalReceived;
          onProgress(clampedReceived, progressTotal, speed);
          if (bytesReceived % (1024 * 1024) == 0) {
            unawaited(
              prefs.setInt('${modelId}_download_progress', totalReceived),
            );
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
      await completer.future;
      await fileSink.close();
      fileSink = null;
      final fileSize = await file.length();
      await prefs.setBool('${modelId}_downloaded', true);
      await prefs.setString(
        '${modelId}_download_date',
        DateTime.now().toIso8601String(),
      );
      await prefs.remove('${modelId}_download_progress');
      _isDownloading = false;
      onComplete();
    } on DioException catch (e) {
      await fileSink?.close();
      fileSink = null;
      if (CancelToken.isCancel(e)) {
        _isDownloading = false;
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final modelPath = '${appDir.path}/${_cfg(modelId)['filename']}';
          final file = File(modelPath);
          if (await file.exists()) {
            final currentProgress = await file.length();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('${modelId}_download_progress', currentProgress);
          }
        } catch (_) {}
        onPaused();
      } else {
        _isDownloading = false;
        if (e.response?.statusCode == 416) {
          final appDir = await getApplicationDocumentsDirectory();
          final modelPath = '${appDir.path}/${_cfg(modelId)['filename']}';
          final file = File(modelPath);
          if (await file.exists()) {
            await file.delete();
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('${modelId}_download_progress');
          onError('Server doesn\'t support resume. Please restart download.');
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final modelPath = '${appDir.path}/${_cfg(modelId)['filename']}';
            final file = File(modelPath);
            if (await file.exists()) {
              final currentProgress = await file.length();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt(
                '${modelId}_download_progress',
                currentProgress,
              );
            }
          } catch (_) {}
          onError('Network error: ${e.message}. You can resume later.');
        } else {
          onError('Download failed: ${e.message ?? e.toString()}');
        }
      }
    } catch (e) {
      await fileSink?.close();
      fileSink = null;
      _isDownloading = false;
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final modelPath = '${appDir.path}/${_cfg(modelId)['filename']}';
        final file = File(modelPath);
        if (await file.exists()) {
          final currentProgress = await file.length();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('${modelId}_download_progress', currentProgress);
        }
      } catch (_) {}
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

  static void pauseDownloadFor(String id) {
    pauseDownload();
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

  static Future<void> deleteModelFor(String id) async {
    try {
      if (_cancelToken != null) {
        _cancelToken!.cancel();
      }
      _isDownloading = false;
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/${_cfg(id)['filename']}';
      final file = File(modelPath);
      if (await file.exists()) {
        await file.delete();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${id}_downloaded');
      await prefs.remove('${id}_download_date');
      await prefs.remove('${id}_download_progress');
    } catch (e) {
      print('❌ [ModelDownloader] Error deleting model($id): $e');
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

  static Future<Map<String, dynamic>> getDownloadInfoFor(String id) async {
    try {
      final cfg = _cfg(id);
      final prefs = await SharedPreferences.getInstance();
      final isDownloaded = prefs.getBool('${id}_downloaded') ?? false;
      final downloadDate = prefs.getString('${id}_download_date');
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/${cfg['filename']}';
      final file = File(modelPath);
      if (await file.exists()) {
        final fileSize = await file.length();
        final sizeMB = fileSize / 1024 / 1024;
        final expect = (cfg['expected'] as int);
        final progressPercent = (fileSize / expect * 100).clamp(0, 100);
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
      print('❌ [ModelDownloader] Error getting download info($id): $e');
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
  static String getEstimatedTimeRemaining(
    int remainingBytes,
    double speedKBps,
  ) {
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
