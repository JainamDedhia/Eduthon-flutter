// FILE: lib/services/knowledge_indexer.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive_io.dart';
import '../models/models.dart';
import '../models/rag_models.dart';
import 'offline_db.dart';

class KnowledgeIndexer {
  static const String INDEXED_FILES_KEY = 'rag_indexed_files';
  static const String CHUNK_PREFIX = 'rag_chunk_';
  static const String DOC_FREQ_KEY = 'rag_doc_freq';
  static const int CHUNK_SIZE = 800; // Target chunk size in characters
  static const int CHUNK_OVERLAP = 150; // Overlap between chunks

  // Index ALL PDFs from offline storage (comprehensive indexing)
  static Future<int> indexAllPDFs({
    Function(String)? onFileProgress,
    Function(double)? onProgress,
  }) async {
    try {
      print('📚 [KnowledgeIndexer] Starting indexing of ALL downloaded PDFs...');
      
      // Get ALL offline files
      final files = await OfflineDB.getAllOfflineFiles();
      print('📚 [KnowledgeIndexer] Total offline files: ${files.length}');
      
      // Filter for PDF files (including compressed)
      final pdfFiles = files.where((f) => 
        f.name.toLowerCase().endsWith('.pdf') || 
        f.name.toLowerCase().endsWith('.pdf.gz') ||
        f.name.toLowerCase().contains('.pdf')
      ).toList();

      if (pdfFiles.isEmpty) {
        print('⚠️ [KnowledgeIndexer] No PDF files found in downloaded content');
        return 0;
      }

      print('📚 [KnowledgeIndexer] Found ${pdfFiles.length} PDF files to index');

      final indexedFiles = await getIndexedFiles();
      int indexedCount = 0;
      int totalFiles = pdfFiles.length;

      for (int i = 0; i < pdfFiles.length; i++) {
        final file = pdfFiles[i];
        final fileKey = '${file.classCode}_${file.name}';

        // Check if file needs re-indexing (skip only if recently indexed)
        if (indexedFiles.contains(fileKey)) {
          // Verify file still exists
          final fileExists = await File(file.localPath).exists();
          if (fileExists) {
            print('⏭️ [KnowledgeIndexer] Already indexed: ${file.name}');
            continue;
          } else {
            print('🔄 [KnowledgeIndexer] File missing, will re-index: ${file.name}');
          }
        }

        try {
          onFileProgress?.call(file.name);
          onProgress?.call(i / totalFiles);

          await indexFile(file);
          indexedCount++;

          print('✅ [KnowledgeIndexer] Indexed: ${file.name}');
        } catch (e) {
          print('❌ [KnowledgeIndexer] Failed to index ${file.name}: $e');
          // Continue with next file
        }
      }

      onProgress?.call(1.0);
      print('✅ [KnowledgeIndexer] Completed indexing. Indexed $indexedCount new files');
      return indexedCount;
    } catch (e) {
      print('❌ [KnowledgeIndexer] Error during indexing: $e');
      rethrow;
    }
  }

  // Index a single file - MEMORY OPTIMIZED: Process page-by-page
  static Future<void> indexFile(FileRecord file) async {
    try {
      print('📄 [KnowledgeIndexer] Indexing file: ${file.name}');

      final prefs = await SharedPreferences.getInstance();
      final docFreq = await _getDocumentFrequencies();
      
      // Process PDF page-by-page to prevent OOM
      int totalChunks = 0;
      int chunkIndex = 0;
      String bufferText = ''; // Small buffer for chunking across pages
      
      // Extract and process pages one at a time
      await _processPDFPages(
        file.localPath,
        onPageExtracted: (String pageText) async {
          // Add page text to buffer
          bufferText += pageText.trim() + '\n\n';
          
          // Process buffer when it reaches chunk size
          while (bufferText.length >= CHUNK_SIZE) {
            // Extract one chunk
            final chunkEnd = _findChunkBoundary(bufferText, CHUNK_SIZE);
            final chunkText = bufferText.substring(0, chunkEnd).trim();
            bufferText = bufferText.substring(chunkEnd - CHUNK_OVERLAP).trim();
            
            if (chunkText.isEmpty) break;
            
            // Process and save this chunk immediately
            await _processAndSaveChunk(
              file,
              chunkIndex,
              chunkText,
              docFreq,
              prefs,
            );
            
            chunkIndex++;
            totalChunks++;
            
            // Free memory by clearing references
            // Dart GC will handle this, but we're being explicit
          }
        },
      );
      
      // Process remaining buffer
      if (bufferText.trim().isNotEmpty) {
        await _processAndSaveChunk(
          file,
          chunkIndex,
          bufferText.trim(),
          docFreq,
          prefs,
        );
        totalChunks++;
      }
      
      if (totalChunks == 0) {
        throw Exception('No text extracted from PDF');
      }

      print('📦 [KnowledgeIndexer] Created $totalChunks chunks');

      // Mark file as indexed
      final indexedFiles = await getIndexedFiles();
      final fileKey = '${file.classCode}_${file.name}';
      if (!indexedFiles.contains(fileKey)) {
        indexedFiles.add(fileKey);
        await prefs.setStringList(INDEXED_FILES_KEY, indexedFiles);
      }

      // Save updated document frequencies
      await _saveDocumentFrequencies(docFreq);

      print('✅ [KnowledgeIndexer] Successfully indexed ${file.name}');
    } catch (e) {
      print('❌ [KnowledgeIndexer] Error indexing file ${file.name}: $e');
      rethrow;
    }
  }

  // Process PDF pages one at a time (memory efficient)
  static Future<void> _processPDFPages(
    String pdfPath,
    {required Function(String) onPageExtracted}
  ) async {
    final File file = File(pdfPath);
    if (!await file.exists()) {
      throw Exception('PDF file not found: $pdfPath');
    }

    // Load PDF bytes (necessary for document loading)
    List<int> pdfBytes;
    if (pdfPath.endsWith('.gz')) {
      final compressedBytes = await file.readAsBytes();
      try {
        final decoder = GZipDecoder();
        pdfBytes = decoder.decodeBytes(compressedBytes);
      } catch (e) {
        pdfBytes = compressedBytes;
      }
    } else {
      pdfBytes = await file.readAsBytes();
    }

    // Load PDF document
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: pdfBytes);
      print('✅ PDF loaded: ${document.pages.count} pages');
    } catch (e) {
      throw Exception('Invalid PDF file: $e');
    }

    try {
      // Process each page individually
      for (int i = 0; i < document.pages.count; i++) {
        try {
          // Extract text from single page
          String pageText = PdfTextExtractor(document).extractText(
            startPageIndex: i,
            endPageIndex: i,
          ) ?? '';

          if (pageText.trim().isEmpty) {
            try {
              final PdfTextExtractor extractor = PdfTextExtractor(document);
              final result = extractor.extractText(startPageIndex: i);
              if (result != null && result.isNotEmpty) {
                pageText = result;
              }
            } catch (e) {
              // Skip this page
              continue;
            }
          }

          if (pageText.trim().isNotEmpty) {
            // Process page immediately - don't accumulate
            await onPageExtracted(pageText.trim());
            print('✅ Page ${i + 1}: Processed ${pageText.length} characters');
          }
        } catch (pageError) {
          print('⚠️ Page ${i + 1}: Error - $pageError');
          continue;
        }
      }
    } finally {
      // CRITICAL: Dispose document immediately to free memory
      document.dispose();
      pdfBytes = []; // Help GC
    }
  }

  // Find optimal chunk boundary (sentence/paragraph break)
  static int _findChunkBoundary(String text, int targetSize) {
    if (text.length <= targetSize) return text.length;
    
    // Try to break at sentence boundary
    final lastPeriod = text.lastIndexOf('.', targetSize);
    final lastNewline = text.lastIndexOf('\n', targetSize);
    final breakPoint = max(lastPeriod, lastNewline);
    
    if (breakPoint > targetSize ~/ 2) {
      return breakPoint + 1;
    }
    
    return targetSize;
  }

  // Process and save a single chunk immediately
  static Future<void> _processAndSaveChunk(
    FileRecord file,
    int chunkIndex,
    String chunkText,
    Map<String, int> docFreq,
    SharedPreferences prefs,
  ) async {
    final chunkId = '${file.classCode}_${file.name}_chunk_$chunkIndex';
    
    // Update document frequencies for this chunk
    final terms = _tokenize(chunkText);
    final seenTerms = <String>{};
    for (final term in terms) {
      if (!seenTerms.contains(term)) {
        docFreq[term] = (docFreq[term] ?? 0) + 1;
        seenTerms.add(term);
      }
    }
    
    // Get total docs for TF-IDF (approximate - use current docFreq size)
    final totalDocs = docFreq.values.isEmpty ? 1 : docFreq.values.reduce(max);
    
    // Compute TF-IDF vector
    final tfidfVector = await _computeTFIDF(chunkText, docFreq, totalDocs);
    
    // Create and save chunk immediately
    final chunk = KnowledgeChunk(
      id: chunkId,
      classCode: file.classCode,
      fileName: file.name,
      chunkIndex: chunkIndex,
      text: chunkText,
      timestamp: DateTime.now().toIso8601String(),
      tfidfVector: tfidfVector,
    );
    
    await prefs.setString('${CHUNK_PREFIX}$chunkId', jsonEncode(chunk.toJson()));
    
    // Clear references to help GC
    // Dart will handle this, but we're being explicit about memory management
  }

  // Re-index a specific file
  static Future<void> reindexFile(FileRecord file) async {
    try {
      print('🔄 [KnowledgeIndexer] Re-indexing file: ${file.name}');
      
      // Remove old chunks for this file
      await _removeChunksForFile(file.classCode, file.name);
      
      // Remove from indexed files list
      final indexedFiles = await getIndexedFiles();
      final fileKey = '${file.classCode}_${file.name}';
      indexedFiles.remove(fileKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(INDEXED_FILES_KEY, indexedFiles);
      
      // Re-index
      await indexFile(file);
    } catch (e) {
      print('❌ [KnowledgeIndexer] Error re-indexing file: $e');
      rethrow;
    }
  }

  // Chunk text into semantic segments
  static List<String> chunkText(String text, int chunkSize, int overlap) {
    if (text.length <= chunkSize) {
      return [text];
    }

    final chunks = <String>[];
    int start = 0;

    while (start < text.length) {
      int end = (start + chunkSize < text.length) ? start + chunkSize : text.length;
      
      // Try to break at sentence boundaries
      if (end < text.length) {
        final lastPeriod = text.lastIndexOf('.', end);
        final lastNewline = text.lastIndexOf('\n', end);
        final breakPoint = max(lastPeriod, lastNewline);
        
        if (breakPoint > start + chunkSize ~/ 2) {
          end = breakPoint + 1;
        }
      }

      final chunk = text.substring(start, end).trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }

      // Move start position with overlap
      start = end - overlap;
      if (start < 0) start = 0;
      
      // Prevent infinite loop
      if (start >= end) break;
    }

    return chunks;
  }

  // Compute TF-IDF vector for a text chunk
  static Future<Map<String, double>> _computeTFIDF(
    String text,
    Map<String, int> docFreq,
    int totalDocs,
  ) async {
    final terms = _tokenize(text);
    final termFreq = <String, int>{};

    // Count term frequencies
    for (final term in terms) {
      termFreq[term] = (termFreq[term] ?? 0) + 1;
    }

    // Compute TF-IDF
    final tfidfVector = <String, double>{};
    final maxFreq = termFreq.values.isEmpty ? 1 : termFreq.values.reduce(max);

    for (final entry in termFreq.entries) {
      final term = entry.key;
      final tf = entry.value / maxFreq; // Normalized term frequency
      final df = docFreq[term] ?? 1;
      final idf = log(totalDocs / df) / log(2); // Log base 2
      final tfidf = tf * idf;

      if (tfidf > 0) {
        tfidfVector[term] = tfidf;
      }
    }

    return tfidfVector;
  }

  // Tokenize text (simple word-based tokenization)
  static List<String> _tokenize(String text) {
    // Convert to lowercase and split by whitespace/punctuation
    final cleaned = text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    final words = cleaned.split(' ').where((w) => w.length > 2).toList();
    
    // Remove common stop words
    final stopWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'from', 'as', 'is', 'was', 'are', 'were', 'been',
      'be', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'should',
      'this', 'that', 'these', 'those', 'it', 'its', 'they', 'them', 'their',
    };
    
    return words.where((w) => !stopWords.contains(w)).toList();
  }

  // Get document frequencies
  static Future<Map<String, int>> _getDocumentFrequencies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final docFreqJson = prefs.getString(DOC_FREQ_KEY);
      
      if (docFreqJson == null) {
        return {};
      }
      
      final Map<String, dynamic> decoded = jsonDecode(docFreqJson);
      return decoded.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      print('⚠️ [KnowledgeIndexer] Error loading doc frequencies: $e');
      return {};
    }
  }

  // Update document frequencies with new chunks
  static Future<void> _updateDocumentFrequencies(
    List<KnowledgeChunk> chunks,
    Map<String, int> docFreq,
  ) async {
    final seenTerms = <String>{};
    
    for (final chunk in chunks) {
      final terms = _tokenize(chunk.text);
      for (final term in terms) {
        if (!seenTerms.contains(term)) {
          docFreq[term] = (docFreq[term] ?? 0) + 1;
          seenTerms.add(term);
        }
      }
    }
  }

  // Save document frequencies
  static Future<void> _saveDocumentFrequencies(Map<String, int> docFreq) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(DOC_FREQ_KEY, jsonEncode(docFreq));
    } catch (e) {
      print('⚠️ [KnowledgeIndexer] Error saving doc frequencies: $e');
    }
  }

  // Get list of indexed files
  static Future<List<String>> getIndexedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(INDEXED_FILES_KEY) ?? [];
    } catch (e) {
      print('⚠️ [KnowledgeIndexer] Error getting indexed files: $e');
      return [];
    }
  }

  // Remove chunks for a specific file
  static Future<void> _removeChunksForFile(String classCode, String fileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final filePrefix = '${CHUNK_PREFIX}${classCode}_${fileName}_chunk_';
      
      for (final key in allKeys) {
        if (key.startsWith(filePrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('⚠️ [KnowledgeIndexer] Error removing chunks: $e');
    }
  }

  // Get total number of chunks
  static Future<int> getTotalChunks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      return allKeys.where((k) => k.startsWith(CHUNK_PREFIX)).length;
    } catch (e) {
      return 0;
    }
  }

  // Clear all indexed data
  static Future<void> clearAllIndexedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      for (final key in allKeys) {
        if (key.startsWith(CHUNK_PREFIX) || 
            key == INDEXED_FILES_KEY || 
            key == DOC_FREQ_KEY) {
          await prefs.remove(key);
        }
      }
      
      print('✅ [KnowledgeIndexer] Cleared all indexed data');
    } catch (e) {
      print('❌ [KnowledgeIndexer] Error clearing data: $e');
    }
  }
}

