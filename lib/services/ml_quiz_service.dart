// FILE: lib/services/ml_quiz_service.dart
import 'dart:math';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';

/// ML-powered quiz service using Google ML Kit for semantic understanding
/// Uses entity extraction to identify key concepts and improve distractor quality
class MLQuizService {
  static MLQuizService? _instance;
  EntityExtractor? _entityExtractor;
  LanguageIdentifier? _languageIdentifier;
  bool _isInitialized = false;

  // Singleton pattern
  static MLQuizService get instance {
    _instance ??= MLQuizService._();
    return _instance!;
  }

  MLQuizService._();

  /// Check if ML service is initialized and ready
  bool get isReady => _isInitialized;

  /// Initialize Google ML Kit services
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('✅ [MLQuizService] Already initialized');
      return true;
    }

    try {
      print('🔄 [MLQuizService] Initializing Google ML Kit...');

      // Initialize language identifier
      _languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);

      // Initialize entity extractor for English
      _entityExtractor = EntityExtractor(language: EntityExtractorLanguage.english);

      _isInitialized = true;
      print('✅ [MLQuizService] Google ML Kit initialized successfully');
      print('📊 [MLQuizService] Entity extraction ready for English text');
      
      return true;
    } catch (e) {
      print('⚠️ [MLQuizService] Failed to initialize ML Kit: $e');
      print('💡 [MLQuizService] Will fall back to TF-IDF approach');
      _isInitialized = false;
      return false;
    }
  }

  /// Extract entities (key concepts) from text using ML Kit
  Future<List<String>> extractEntities(String text) async {
    if (!isReady || _entityExtractor == null) {
      print('⚠️ [MLQuizService] Entity extractor not ready');
      return [];
    }

    try {
      final annotations = await _entityExtractor!.annotateText(text);
      final entities = <String>[];

      for (final annotation in annotations) {
        // Get the actual text that was annotated
        final entityText = annotation.text;
        
        // Add entities based on their type
        for (final entity in annotation.entities) {
          // We're interested in various entity types for quiz generation
          if (entity.type == EntityType.address ||
              entity.type == EntityType.dateTime ||
              entity.type == EntityType.email ||
              entity.type == EntityType.flightNumber ||
              entity.type == EntityType.iban ||
              entity.type == EntityType.isbn ||
              entity.type == EntityType.paymentCard ||
              entity.type == EntityType.phone ||
              entity.type == EntityType.trackingNumber ||
              entity.type == EntityType.url ||
              entity.type == EntityType.money) {
            // Skip these types as they're not good for educational quiz
            continue;
          }
          
          // Add the entity text
          if (entityText.isNotEmpty && entityText.length >= 3) {
            entities.add(entityText);
          }
        }
      }

      print('✅ [MLQuizService] Extracted ${entities.length} entities from text');
      return entities.toSet().toList(); // Remove duplicates
    } catch (e) {
      print('⚠️ [MLQuizService] Error extracting entities: $e');
      return [];
    }
  }

  /// Rank distractors using entity-based semantic similarity
  /// This is simpler than embedding-based but still ML-powered
  Future<List<String>> rankDistractors({
    required String correctAnswer,
    required List<String> candidates,
    required String context,
  }) async {
    if (!isReady || candidates.isEmpty) {
      print('⚠️ [MLQuizService] Cannot rank distractors - service not ready or no candidates');
      return candidates;
    }

    try {
      print('🎯 [MLQuizService] Ranking ${candidates.length} candidates using ML Kit');

      // Extract entities from the context to understand topic
      final contextEntities = await extractEntities(context);
      
      // Calculate scores for each candidate
      final scoredCandidates = <Map<String, dynamic>>[];
      
      for (final candidate in candidates) {
        if (candidate.toLowerCase() == correctAnswer.toLowerCase()) {
          continue; // Skip the correct answer
        }

        // Calculate quality score based on:
        // 1. Length similarity to correct answer
        // 2. Whether it's mentioned in context entities
        // 3. Character overlap (Levenshtein-like)
        
        final lengthDiff = (candidate.length - correctAnswer.length).abs();
        final lengthScore = 1.0 - (lengthDiff / max(candidate.length, correctAnswer.length));
        
        // Check if candidate appears in extracted entities
        final isEntity = contextEntities.any(
          (e) => e.toLowerCase().contains(candidate.toLowerCase()) ||
                 candidate.toLowerCase().contains(e.toLowerCase())
        );
        final entityScore = isEntity ? 0.8 : 0.3;
        
        // Calculate character overlap
        final overlapScore = _calculateCharacterOverlap(correctAnswer, candidate);
        
        // Weighted quality score
        final quality = (lengthScore * 0.3) + (entityScore * 0.4) + (overlapScore * 0.3);
        
        scoredCandidates.add({
          'text': candidate,
          'quality': quality,
          'isEntity': isEntity,
        });
      }

      // Sort by quality (highest first)
      scoredCandidates.sort((a, b) => 
        (b['quality'] as double).compareTo(a['quality'] as double));

      final ranked = scoredCandidates.map((c) => c['text'] as String).toList();

      print('✅ [MLQuizService] Ranked ${ranked.length} distractors');
      if (ranked.isNotEmpty) {
        final topCandidate = scoredCandidates.first;
        print('   Top distractor: "${topCandidate['text']}" (quality: ${(topCandidate['quality'] as double).toStringAsFixed(2)}, entity: ${topCandidate['isEntity']})');
      }

      return ranked;
    } catch (e) {
      print('⚠️ [MLQuizService] Error ranking distractors: $e');
      return candidates;
    }
  }

  /// Calculate character overlap between two strings (simplified Levenshtein)
  double _calculateCharacterOverlap(String s1, String s2) {
    final set1 = s1.toLowerCase().split('').toSet();
    final set2 = s2.toLowerCase().split('').toSet();
    
    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;
    
    return union > 0 ? intersection / union : 0.0;
  }

  /// Check if text is in English
  Future<bool> isEnglish(String text) async {
    if (_languageIdentifier == null) return true; // Assume English
    
    try {
      final languageTag = await _languageIdentifier!.identifyLanguage(text);
      return languageTag == 'en';
    } catch (e) {
      print('⚠️ [MLQuizService] Language detection failed: $e');
      return true; // Default to English
    }
  }

  /// Dispose of resources
  void dispose() {
    _entityExtractor?.close();
    _languageIdentifier?.close();
    _entityExtractor = null;
    _languageIdentifier = null;
    _isInitialized = false;
    print('🔄 [MLQuizService] ML Kit services disposed');
  }
}
