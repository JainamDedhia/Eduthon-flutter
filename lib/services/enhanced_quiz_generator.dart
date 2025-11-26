// FILE: lib/services/enhanced_quiz_generator.dart
import 'dart:math';
import 'ml_quiz_service.dart';

/// Enhanced quiz generator with better question quality and distractor generation
/// This is a significant improvement over the basic rule-based approach
class EnhancedQuizGenerator {
  /// Generate high-quality quiz questions from summary text
  static Future<List<Map<String, dynamic>>> generateQuiz(
    String summary, {
    int numQuestions = 7,
  }) async {
    if (summary.isEmpty) return [];

    print('🎯 [EnhancedQuizGen] Starting enhanced quiz generation...');
    
    // Initialize ML service if not already done
    final mlService = MLQuizService.instance;
    if (!mlService.isReady) {
      print('🔄 [EnhancedQuizGen] Initializing ML service...');
      await mlService.initialize();
    }

    // Split into sentences
    final sentences = summary
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().split(RegExp(r'\s+')).length >= 6)
        .toList();

    if (sentences.isEmpty) {
      print('⚠️ [EnhancedQuizGen] No valid sentences found');
      return [];
    }

    // Calculate TF-IDF scores for better keyword selection
    final tfidfScores = _calculateTFIDF(summary);
    
    // Extract high-quality candidate phrases
    final candidates = _extractQualityCandidates(summary, tfidfScores);
    
    if (candidates.isEmpty) {
      print('⚠️ [EnhancedQuizGen] No candidate phrases found');
      return [];
    }

    print('📊 [EnhancedQuizGen] Found ${candidates.length} quality candidates');

    final mcqs = <Map<String, dynamic>>[];
    final usedAnswers = <String>{};
    final random = Random();

    // Try to generate questions from sentences
    for (final sent in sentences) {
      if (mcqs.length >= numQuestions) break;

      // Find best candidate phrase in this sentence
      String? chosenAnswer;
      double bestScore = 0.0;

      for (final candidate in candidates) {
        if (usedAnswers.contains(candidate.toLowerCase())) continue;
        
        if (sent.contains(candidate)) {
          final score = tfidfScores[candidate.toLowerCase()] ?? 0.0;
          if (score > bestScore) {
            bestScore = score;
            chosenAnswer = candidate;
          }
        }
      }

      // Fallback to longest meaningful word if no candidate found
      if (chosenAnswer == null) {
        final words = RegExp(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b')
            .allMatches(sent)
            .map((m) => m.group(0)!)
            .where((w) => w.length >= 5 && !usedAnswers.contains(w.toLowerCase()))
            .toList();
        
        if (words.isEmpty) continue;
        
        // Pick word with highest TF-IDF score
        words.sort((a, b) {
          final scoreA = tfidfScores[a.toLowerCase()] ?? 0.0;
          final scoreB = tfidfScores[b.toLowerCase()] ?? 0.0;
          return scoreB.compareTo(scoreA);
        });
        
        chosenAnswer = words.first;
      }

      if (chosenAnswer == null || chosenAnswer.isEmpty) continue;

      try {
        // Create fill-in-the-blank question
        final question = sent.replaceFirst(
          RegExp(RegExp.escape(chosenAnswer), caseSensitive: false),
          '_____',
        );

        // Generate smart distractors (now with ML!)
        final distractors = await _generateSmartDistractors(
          chosenAnswer,
          sent,
          candidates,
          tfidfScores,
        );

        if (distractors.length < 3) {
          print('⚠️ [EnhancedQuizGen] Not enough distractors for: $chosenAnswer');
          continue;
        }

        // Create options (3 distractors + 1 correct answer)
        final options = [...distractors.take(3), chosenAnswer];
        options.shuffle();

        final labeled = options.asMap().entries.map((e) => {
          'label': String.fromCharCode(65 + e.key), // A, B, C, D
          'text': e.value,
        }).toList();

        final correctOption = labeled.firstWhere(
          (item) => item['text'] == chosenAnswer,
          orElse: () => labeled.last,
        );
        final correctLabel = correctOption['label'] as String;

        mcqs.add({
          'question': question.trim(),
          'options': labeled,
          'answer_label': correctLabel,
          'answer_text': chosenAnswer,
        });

        usedAnswers.add(chosenAnswer.toLowerCase());
        print('✅ [EnhancedQuizGen] Generated question ${mcqs.length}: ${question.substring(0, min(50, question.length))}...');
      } catch (e) {
        print('⚠️ [EnhancedQuizGen] Error creating question: $e');
        continue;
      }
    }

    print('✅ [EnhancedQuizGen] Generated ${mcqs.length} high-quality questions');
    return mcqs;
  }

  /// Calculate TF-IDF scores for words in the text
  static Map<String, double> _calculateTFIDF(String text) {
    final textLower = text.toLowerCase();
    
    // Common stopwords to ignore
    final stopwords = {
      'the', 'and', 'for', 'with', 'from', 'this', 'that', 'which', 'are',
      'was', 'were', 'have', 'has', 'had', 'their', 'there', 'they', 'these',
      'those', 'been', 'also', 'such', 'but', 'not', 'can', 'will', 'may',
      'you', 'your', 'into', 'about', 'between', 'during', 'each', 'per',
      'include', 'including', 'other', 'use', 'uses', 'used', 'using',
      'some', 'many', 'most', 'more', 'much', 'one', 'two', 'three',
    };

    // Extract all words
    final words = RegExp(r'\b[a-z]{3,}\b')
        .allMatches(textLower)
        .map((m) => m.group(0)!)
        .where((w) => !stopwords.contains(w))
        .toList();

    if (words.isEmpty) return {};

    // Calculate term frequency
    final termFreq = <String, int>{};
    for (final word in words) {
      termFreq[word] = (termFreq[word] ?? 0) + 1;
    }

    // Calculate IDF (simplified - just use log of total words / term frequency)
    final totalWords = words.length;
    final tfidf = <String, double>{};
    
    for (final entry in termFreq.entries) {
      final tf = entry.value / totalWords;
      final idf = log(totalWords / entry.value);
      tfidf[entry.key] = tf * idf;
    }

    return tfidf;
  }

  /// Extract high-quality candidate phrases for questions
  static List<String> _extractQualityCandidates(
    String text,
    Map<String, double> tfidfScores,
  ) {
    final candidates = <String>[];

    // 1. Extract named entities (capitalized phrases)
    final namedEntities = RegExp(r'\b([A-Z][a-z]{2,}(?:\s+[A-Z][a-z]{2,}){0,2})\b')
        .allMatches(text)
        .map((m) => m.group(1)!)
        .where((n) => n.length >= 4 && n.split(' ').length <= 3)
        .toSet()
        .toList();

    candidates.addAll(namedEntities);

    // 2. Extract important single words based on TF-IDF
    final importantWords = tfidfScores.entries
        .where((e) => e.key.length >= 5)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topWords = importantWords
        .take(15)
        .map((e) => _capitalizeFirst(e.key))
        .toList();

    candidates.addAll(topWords);

    // 3. Extract domain-specific terms (words that appear multiple times)
    final textLower = text.toLowerCase();
    final words = RegExp(r'\b[a-z]{5,}\b').allMatches(textLower);
    final wordFreq = <String, int>{};
    
    for (final match in words) {
      final word = match.group(0)!;
      wordFreq[word] = (wordFreq[word] ?? 0) + 1;
    }

    final domainTerms = wordFreq.entries
        .where((e) => e.value >= 2 && e.key.length >= 6)
        .map((e) => _capitalizeFirst(e.key))
        .toList();

    candidates.addAll(domainTerms);

    // Remove duplicates and filter out stopwords
    final filteredCandidates = candidates.toSet().where((c) {
      final lower = c.toLowerCase();
      return lower != 'therefore' &&
          lower != 'however' &&
          lower != 'because' &&
          lower != 'including' &&
          lower != 'throughout' &&
          lower != 'between';
    }).toList();

    return filteredCandidates;
  }

  /// Generate smart distractors based on context and similarity
  /// Now ML-enhanced for semantic understanding!
  static Future<List<String>> _generateSmartDistractors(
    String correctAnswer,
    String context,
    List<String> allCandidates,
    Map<String, double> tfidfScores,
  ) async {
    final distractors = <String>[];
    final correctLower = correctAnswer.toLowerCase();
    final random = Random();
    
    // Strategy 0: ML-powered semantic ranking (if available)
    final mlService = MLQuizService.instance;
    if (mlService.isReady) {
      try {
        print('🤖 [EnhancedQuizGen] Using ML to rank distractors for: $correctAnswer');
        final rankedCandidates = await mlService.rankDistractors(
          correctAnswer: correctAnswer,
          candidates: allCandidates.where((c) => c.toLowerCase() != correctLower).toList(),
          context: context,
        );
        
        // Take top ML-ranked candidates
        if (rankedCandidates.isNotEmpty) {
          distractors.addAll(rankedCandidates.take(3));
          print('✅ [EnhancedQuizGen] Got ${distractors.length} ML-ranked distractors');
          
          // If we have enough good distractors, return early
          if (distractors.length >= 3) {
            return distractors;
          }
        }
      } catch (e) {
        print('⚠️ [EnhancedQuizGen] ML ranking failed: $e, falling back to TF-IDF');
      }
    }

    // Strategy 1: Use similar candidates (same length range)
    final similarLength = allCandidates.where((c) {
      final cLower = c.toLowerCase();
      if (cLower == correctLower) return false;
      final lengthDiff = (c.length - correctAnswer.length).abs();
      return lengthDiff <= 3;
    }).toList();

    similarLength.shuffle();
    distractors.addAll(similarLength.take(2));

    // Strategy 2: Use candidates with similar TF-IDF scores
    final correctScore = tfidfScores[correctLower] ?? 0.0;
    final similarScore = allCandidates.where((c) {
      final cLower = c.toLowerCase();
      if (cLower == correctLower || distractors.contains(c)) return false;
      final score = tfidfScores[cLower] ?? 0.0;
      return (score - correctScore).abs() < 0.1;
    }).toList();

    similarScore.shuffle();
    distractors.addAll(similarScore.take(1));

    // Strategy 3: Use other capitalized words from context
    if (distractors.length < 3) {
      final contextWords = RegExp(r'\b[A-Z][a-z]{4,}\b')
          .allMatches(context)
          .map((m) => m.group(0)!)
          .where((w) => 
              w.toLowerCase() != correctLower &&
              !distractors.contains(w))
          .toList();

      contextWords.shuffle();
      distractors.addAll(contextWords.take(3 - distractors.length));
    }

    // Strategy 4: Use word variations (prefix/suffix changes) - ONLY if needed
    if (distractors.length < 3) {
      final variations = _generateWordVariations(correctAnswer);
      final filtered = variations.where((v) => 
          v.toLowerCase() != correctLower &&
          !distractors.contains(v)).toList();
      
      filtered.shuffle();
      distractors.addAll(filtered.take(3 - distractors.length));
    }

    // Strategy 5: Use random quality candidates as last resort
    if (distractors.length < 3) {
      final remaining = allCandidates.where((c) =>
          c.toLowerCase() != correctLower &&
          !distractors.contains(c)).toList();
      
      remaining.shuffle();
      distractors.addAll(remaining.take(3 - distractors.length));
    }

    return distractors;
  }

  /// Generate plausible word variations (better than simple mutations)
  static List<String> _generateWordVariations(String word) {
    final variations = <String>[];
    
    // Common suffix replacements
    final suffixMap = {
      'tion': ['sion', 'ment'],
      'ness': ['ity', 'ance'],
      'ity': ['ness', 'ation'],
      'ment': ['tion', 'ance'],
      'ance': ['ence', 'ment'],
      'ence': ['ance', 'ancy'],
      'able': ['ible', 'ive'],
      'ible': ['able', 'ive'],
    };

    for (final entry in suffixMap.entries) {
      if (word.endsWith(entry.key)) {
        final base = word.substring(0, word.length - entry.key.length);
        for (final newSuffix in entry.value) {
          variations.add(base + newSuffix);
        }
      }
    }

    // Prefix variations
    final prefixMap = {
      'un': 'in',
      'in': 'un',
      'dis': 'mis',
      'mis': 'dis',
      're': 'pre',
      'pre': 're',
    };

    for (final entry in prefixMap.entries) {
      if (word.toLowerCase().startsWith(entry.key)) {
        final base = word.substring(entry.key.length);
        variations.add(_capitalizeFirst(entry.value + base));
      }
    }

    return variations;
  }

  /// Capitalize first letter of a word
  static String _capitalizeFirst(String word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1);
  }
}
