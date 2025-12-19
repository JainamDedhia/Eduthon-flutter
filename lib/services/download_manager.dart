import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:open_file/open_file.dart';
import '../models/models.dart';
import 'offline_db.dart';
import '../config/aws_config.dart';
import 'aws_s3_service.dart';

class DownloadManager {
  static final Dio _dio = Dio(
    BaseOptions(
      headers: {
        'User-Agent': 'GYAANSETU-Mobile/1.0',
        'Accept': '*/*',
        'Accept-Encoding': 'gzip, deflate',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      followRedirects: true,
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  // Download and store file with compression
  static Future<String> downloadAndStore(
      String classCode, ClassMaterial material) async {
    print(
        '🚀 [downloadManager] Starting download with compression for: ${material.name}');

    try {
      print('📥 [downloadManager] Step 1: Checking if file already exists...');

      // Check if file already exists
      final exists = await OfflineDB.checkFileExists(classCode, material.name);
      if (exists) {
        print('⚠️ [downloadManager] File already exists: ${material.name}');
        throw Exception('File already downloaded. Check offline materials.');
      }

      print('✅ [downloadManager] Step 1: File doesn\'t exist, proceeding...');

      // Get directories
      final appDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${appDir.path}/offlineFiles');
      final tempDir = Directory('${appDir.path}/temp');

      // Create directories
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }

      print(
          '📁 [downloadManager] Using directories:\n- Download: ${downloadDir.path}\n- Temp: ${tempDir.path}');

      // Sanitize filename
      final sanitizedName = material.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final tempPath = '${tempDir.path}/$sanitizedName';
      final compressedPath = '${downloadDir.path}/$sanitizedName.gz';

      print(
          '📝 [downloadManager] File paths:\n- Temp: $tempPath\n- Compressed: $compressedPath');

      // Check if URL is valid
      if (!material.url.startsWith('http')) {
        print('❌ [downloadManager] Invalid URL: ${material.url}');
        throw Exception('Invalid file URL');
      }

      // Optionally generate signed URL if it's from our S3 bucket
      String downloadUrl = material.url;
      if (_isS3Url(material.url)) {
        try {
          final objectKey = _extractS3ObjectKey(material.url);
          if (objectKey != null) {
            // Generate presigned URL for secure access
            downloadUrl = AwsS3Service.generatePresignedUrl(objectKey);
            print('🔐 [downloadManager] Using presigned URL for S3 object');
          }
        } catch (e) {
          print('⚠️ [downloadManager] Failed to generate presigned URL, using original: $e');
          // Fallback to original URL
        }
      }

      print('🌐 [downloadManager] Step 2: Downloading from: $downloadUrl');

      // Download file with proper error handling
      print('⏳ [downloadManager] Download in progress...');
      try {
        await _dio.download(
          downloadUrl,
          tempPath,
          options: Options(
            headers: {
              'User-Agent': 'GYAANSETU-Mobile/1.0',
              'Accept': '*/*',
            },
            followRedirects: true,
            validateStatus: (status) => status != null && status < 500,
          ),
          onReceiveProgress: (received, total) {
            if (total != -1) {
              final progress = (received / total * 100).toStringAsFixed(0);
              print('📥 Download progress: $progress%');
            }
          },
        );
      } on DioException catch (dioError) {
        print('❌ [downloadManager] DioException: ${dioError.type}');
        print('   Status Code: ${dioError.response?.statusCode}');
        print('   Message: ${dioError.message}');
        
        // Handle specific error types
        if (dioError.response?.statusCode == 403) {
          throw Exception(
            'Access denied (403). The file may be private or the URL has expired. '
            'Please contact your teacher to get a new download link.'
          );
        } else if (dioError.response?.statusCode == 404) {
          throw Exception(
            'File not found (404). The file may have been moved or deleted. '
            'Please contact your teacher.'
          );
        } else if (dioError.type == DioExceptionType.connectionTimeout) {
          throw Exception(
            'Connection timeout. Please check your internet connection and try again.'
          );
        } else if (dioError.type == DioExceptionType.receiveTimeout) {
          throw Exception(
            'Download timeout. The file may be too large. Please try again.'
          );
        } else {
          throw Exception(
            'Download failed: ${dioError.message ?? dioError.toString()}. '
            'Status code: ${dioError.response?.statusCode ?? "unknown"}'
          );
        }
      }

      print('✅ [downloadManager] Download successful: $tempPath');

      // Get original file size
      final tempFile = File(tempPath);
      final originalSize = await tempFile.length();
      print(
          '📊 [downloadManager] Original file size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');

      print('🗜️ [downloadManager] Step 3: Compressing file...');

      int compressedSize = 0;
      try {
        // Read and compress file
        final bytes = await tempFile.readAsBytes();
        final encoder = GZipEncoder();
        final compressedBytes = encoder.encode(bytes);

        if (compressedBytes != null) {
          // Write compressed file
          final compressedFile = File(compressedPath);
          await compressedFile.writeAsBytes(compressedBytes);

          compressedSize = compressedBytes.length;

          final spaceSaved = originalSize - compressedSize;
          final compressionRatio =
              ((spaceSaved / originalSize) * 100).toStringAsFixed(1);

          print('📊 [downloadManager] Compression results:');
          print(
              '  - Original: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
          print(
              '  - Compressed: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');
          print(
              '  - Space saved: ${(spaceSaved / 1024 / 1024).toStringAsFixed(2)} MB ($compressionRatio%)');
        }
      } catch (compressionError) {
        print('❌ [downloadManager] Compression failed: $compressionError');

        // Fallback: Copy original file without compression
        print('🔄 [downloadManager] Using fallback (no compression)');
        await tempFile.copy(compressedPath);

        final compressedFile = File(compressedPath);
        compressedSize = await compressedFile.length();
        print('✅ [downloadManager] Fallback copy completed');
      }

      // Clean up temp file
      try {
        await tempFile.delete();
        print('✅ [downloadManager] Temp file cleaned up');
      } catch (cleanupError) {
        print('⚠️ [downloadManager] Failed to clean up temp file: $cleanupError');
      }

      print('💾 [downloadManager] Step 4: Saving to database...');

      // Save to database with compression info
      await OfflineDB.saveFileRecord(
        classCode,
        material.name,
        compressedPath,
        url: material.url,
        compressedSize: compressedSize,
        originalSize: originalSize,
      );

      print('✅ [downloadManager] Successfully saved to database');
      return compressedPath;
    } catch (e) {
      print('❌ [downloadManager] Download process failed completely: $e');

      // Clean up on failure
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final tempDir = Directory('${appDir.path}/temp');
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (cleanupError) {
        print('⚠️ [downloadManager] Cleanup on failure error: $cleanupError');
      }

      // Provide user-friendly error messages
      if (e.toString().contains('already downloaded')) {
        rethrow;
      } else if (e.toString().contains('Access denied') || 
                 e.toString().contains('403')) {
        rethrow; // Already has user-friendly message
      } else if (e.toString().contains('File not found') || 
                 e.toString().contains('404')) {
        rethrow; // Already has user-friendly message
      } else if (e.toString().contains('Network') ||
          e.toString().contains('Connection') ||
          e.toString().contains('timeout')) {
        throw Exception('Network error. Please check your internet connection and try again.');
      } else if (e is DioException) {
        // DioException already handled above
        rethrow;
      } else {
        throw Exception('Download failed: ${e.toString()}');
      }
    }
  }

  // Open compressed file - FIXED VERSION
  static Future<void> openFile(String compressedPath, String originalName) async {
    print('📂 [downloadManager] Opening compressed file: $originalName');

    try {
      // Check if compressed file exists
      final compressedFile = File(compressedPath);
      if (!await compressedFile.exists()) {
        print('❌ [downloadManager] Compressed file not found: $compressedPath');
        throw Exception('File not found. It may have been deleted.');
      }

      final compressedSize = await compressedFile.length();
      print(
          '✅ [downloadManager] Compressed file exists: ${(compressedSize / 1024).toStringAsFixed(1)} KB');

      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory('${appDir.path}/temp');
      final decompressedPath = '${tempDir.path}/$originalName';

      // Create temp directory
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }

      print('🗜️ [downloadManager] Decompressing file...');

      try {
        // Read and decompress file
        final compressedBytes = await compressedFile.readAsBytes();
        final decoder = GZipDecoder();
        final decompressedBytes = decoder.decodeBytes(compressedBytes);

        // Write decompressed file
        final decompressedFile = File(decompressedPath);
        await decompressedFile.writeAsBytes(decompressedBytes);

        print(
            '✅ [downloadManager] File decompressed successfully: $decompressedPath');
      } catch (decompressionError) {
        print('❌ [downloadManager] Decompression failed: $decompressionError');

        // Fallback: Assume file is not compressed
        print('🔄 [downloadManager] Using fallback (no decompression)');
        await compressedFile.copy(decompressedPath);
        print('✅ [downloadManager] Fallback copy completed');
      }

      // Verify decompressed file exists
      final decompressedFile = File(decompressedPath);
      if (!await decompressedFile.exists()) {
        throw Exception('Decompressed file not found');
      }

      final decompressedSize = await decompressedFile.length();
      print(
          '✅ [downloadManager] Decompressed file ready: ${(decompressedSize / 1024).toStringAsFixed(1)} KB');

      // Open the file with system default app
      print('📱 [downloadManager] Opening file with system viewer...');
      final result = await OpenFile.open(decompressedPath);

      if (result.type != ResultType.done) {
        print('⚠️ [downloadManager] OpenFile result: ${result.message}');
        
        // If OpenFile fails, the file might still be there
        // User can manually open it from file manager
        if (result.message.toLowerCase().contains('no app')) {
          throw Exception(
              'No PDF reader app installed. Please install Google Drive, Adobe Reader, or any PDF viewer from Play Store.');
        } else {
          throw Exception('Could not open file: ${result.message}');
        }
      }

      print('✅ [downloadManager] File opened successfully');

      // Schedule cleanup of decompressed file after delay
      Future.delayed(const Duration(seconds: 60), () async {
        try {
          if (await decompressedFile.exists()) {
            await decompressedFile.delete();
            print(
                '🧹 [downloadManager] Cleaned up decompressed file: $decompressedPath');
          }
        } catch (cleanupError) {
          print(
              '⚠️ [downloadManager] Failed to clean up decompressed file: $cleanupError');
        }
      });
    } catch (e) {
      print('❌ [downloadManager] Failed to open file: $e');

      // Clean up on error
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final tempDir = Directory('${appDir.path}/temp');
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (cleanupError) {
        print('⚠️ [downloadManager] Cleanup on error failed: $cleanupError');
      }

      rethrow;
    }
  }

  // Delete file
  static Future<void> deleteFile(String filePath) async {
    try {
      print('🗑️ [downloadManager] Deleting file: $filePath');
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('✅ [downloadManager] Deleted file: $filePath');
      }
    } catch (e) {
      print('❌ [downloadManager] Failed to delete file: $e');
      rethrow;
    }
  }

  // Get file size
  static Future<int> getFileSize(String filePath) async {
    try {
      print('📊 [downloadManager] Getting file size: $filePath');
      final file = File(filePath);
      if (await file.exists()) {
        final size = await file.length();
        print('✅ [downloadManager] File size: $size bytes');
        return size;
      }
      print('⚠️ [downloadManager] File size not available: $filePath');
      return 0;
    } catch (e) {
      print('❌ [downloadManager] Failed to get file size: $e');
      return 0;
    }
  }

  /// Check if URL is from the configured S3 bucket
  static bool _isS3Url(String url) {
    final baseUrl = AwsConfig.getBaseUrl();
    return url.startsWith(baseUrl) || url.contains(AwsConfig.bucketName);
  }

  /// Extract S3 object key from URL
  static String? _extractS3ObjectKey(String url) {
    try {
      final baseUrl = AwsConfig.getBaseUrl();
      if (url.startsWith(baseUrl)) {
        return url.substring(baseUrl.length).split('?').first;
      }
      // Try to extract from full S3 URL pattern
      final uri = Uri.parse(url);
      if (uri.host.contains(AwsConfig.bucketName)) {
        return uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
      }
      return null;
    } catch (e) {
      print('⚠️ [downloadManager] Error extracting S3 object key: $e');
      return null;
    }
  }
}