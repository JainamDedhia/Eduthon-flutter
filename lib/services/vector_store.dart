// FILE: lib/services/vector_store.dart
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rag_models.dart';
import 'knowledge_indexer.dart';

class VectorStore {
  static const String CHUNK_PREFIX = 'rag_chunk_';

  // Search for similar chunks using TF-IDF cosine similarity
  static Future<List<SearchResult>> searchSimilar(
    String query,
    int topK, {
    String? classCode,
    String? fileName,
  }) async {
    try {
      print('🔍 [VectorStore] Searching for: "$query" (topK=$topK)');

      // Tokenize query (using same method as indexer)
      final queryTerms = _tokenize(query);
      if (queryTerms.isEmpty) {
        print('⚠️ [VectorStore] Empty query after tokenization');
        return [];
      }

      // Get document frequencies
      final docFreq = await _getDocumentFrequencies();
      final totalDocs = docFreq.values.isEmpty ? 1 : docFreq.values.reduce(max);

      // Compute query TF-IDF vector
      final queryTF = <String, int>{};
      for (final term in queryTerms) {
        queryTF[term] = (queryTF[term] ?? 0) + 1;
      }

      final maxQueryFreq = queryTF.values.isEmpty ? 1 : queryTF.values.reduce(max);
      final queryVector = <String, double>{};
      
      for (final entry in queryTF.entries) {
        final term = entry.key;
        final tf = entry.value / maxQueryFreq;
        final df = docFreq[term] ?? 1;
        final idf = log(totalDocs / df) / log(2);
        queryVector[term] = tf * idf;
      }

      // Get all chunks
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys()
          .where((k) => k.startsWith(CHUNK_PREFIX))
          .toList();

      final results = <SearchResult>[];

      // Compute cosine similarity for each chunk
      for (final key in allKeys) {
        try {
          final chunkJson = prefs.getString(key);
          if (chunkJson == null) continue;

          final chunk = KnowledgeChunk.fromJson(jsonDecode(chunkJson));

          // Filter by classCode or fileName if specified
          if (classCode != null && chunk.classCode != classCode) continue;
          if (fileName != null && chunk.fileName != fileName) continue;

          // Compute cosine similarity
          final similarity = _cosineSimilarity(queryVector, chunk.tfidfVector);

          if (similarity > 0) {
            results.add(SearchResult(
              chunk: chunk,
              similarityScore: similarity,
            ));
          }
        } catch (e) {
          print('⚠️ [VectorStore] Error processing chunk $key: $e');
          continue;
        }
      }

      // Sort by similarity score (descending)
      results.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));

      // Return top-K results
      final topResults = results.take(topK).toList();
      print('✅ [VectorStore] Found ${topResults.length} similar chunks');
      
      return topResults;
    } catch (e) {
      print('❌ [VectorStore] Error during search: $e');
      return [];
    }
  }

  // Compute cosine similarity between two TF-IDF vectors
  static double _cosineSimilarity(
    Map<String, double> vector1,
    Map<String, double> vector2,
  ) {
    if (vector1.isEmpty || vector2.isEmpty) return 0.0;

    // Get all unique terms
    final allTerms = <String>{};
    allTerms.addAll(vector1.keys);
    allTerms.addAll(vector2.keys);

    // Compute dot product and magnitudes
    double dotProduct = 0.0;
    double magnitude1 = 0.0;
    double magnitude2 = 0.0;

    for (final term in allTerms) {
      final v1 = vector1[term] ?? 0.0;
      final v2 = vector2[term] ?? 0.0;

      dotProduct += v1 * v2;
      magnitude1 += v1 * v1;
      magnitude2 += v2 * v2;
    }

    // Avoid division by zero
    if (magnitude1 == 0.0 || magnitude2 == 0.0) {
      return 0.0;
    }

    return dotProduct / (sqrt(magnitude1) * sqrt(magnitude2));
  }

  // Get a chunk by ID
  static Future<KnowledgeChunk?> getChunk(String chunkId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chunkJson = prefs.getString('${CHUNK_PREFIX}$chunkId');

      if (chunkJson == null) {
        return null;
      }

      return KnowledgeChunk.fromJson(jsonDecode(chunkJson));
    } catch (e) {
      print('❌ [VectorStore] Error getting chunk $chunkId: $e');
      return null;
    }
  }

  // Get all chunks for a specific file
  static Future<List<KnowledgeChunk>> getChunksByFile(
    String classCode,
    String fileName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys()
          .where((k) => k.startsWith(CHUNK_PREFIX))
          .toList();

      final chunks = <KnowledgeChunk>[];

      for (final key in allKeys) {
        try {
          final chunkJson = prefs.getString(key);
          if (chunkJson == null) continue;

          final chunk = KnowledgeChunk.fromJson(jsonDecode(chunkJson));

          if (chunk.classCode == classCode && chunk.fileName == fileName) {
            chunks.add(chunk);
          }
        } catch (e) {
          continue;
        }
      }

      // Sort by chunk index
      chunks.sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));

      return chunks;
    } catch (e) {
      print('❌ [VectorStore] Error getting chunks for file: $e');
      return [];
    }
  }

  // Tokenize text (same as KnowledgeIndexer)
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

  // Get document frequencies (helper method)
  static Future<Map<String, int>> _getDocumentFrequencies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final docFreqJson = prefs.getString(KnowledgeIndexer.DOC_FREQ_KEY);

      if (docFreqJson == null) {
        return {};
      }

      final Map<String, dynamic> decoded = jsonDecode(docFreqJson);
      return decoded.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      return {};
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
}

