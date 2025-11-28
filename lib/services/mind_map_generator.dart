// FILE: lib/services/mindmap_generator.dart
import 'dart:math';

class MindMapNode {
  final String title;
  final List<MindMapNode> children;
  final int level;

  MindMapNode({
    required this.title,
    this.children = const [],
    this.level = 0,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'children': children.map((c) => c.toJson()).toList(),
    'level': level,
  };

  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    final childrenData = json['children'] as List<dynamic>? ?? [];
    return MindMapNode(
      title: json['title'] ?? '',
      children: childrenData
          .map((c) => MindMapNode.fromJson(c as Map<String, dynamic>))
          .toList(),
      level: json['level'] ?? 0,
    );
  }
}

class MindMapGenerator {
  // Main method: Generate mind map from summary and quiz
  static Future<MindMapNode> generateMindMap({
    required String summary,
    required List<Map<String, dynamic>> quiz,
    String? fileName,
  }) async {
    try {
      print('🧠 [MindMap] Generating mind map...');
      
      // Step 1: Extract main topic from filename or summary
      final mainTopic = _extractMainTopic(fileName, summary);
      print('📌 [MindMap] Main topic: $mainTopic');
      
      // Step 2: Extract key concepts from summary
      final summaryPoints = _extractKeyPointsFromSummary(summary);
      print('📝 [MindMap] Extracted ${summaryPoints.length} points from summary');
      
      // Step 3: Extract concepts from quiz (these are important terms)
      final quizConcepts = _extractConceptsFromQuiz(quiz);
      print('❓ [MindMap] Extracted ${quizConcepts.length} concepts from quiz');
      
      // Step 4: Merge and deduplicate concepts
      final allConcepts = _mergeAndDeduplicate(summaryPoints, quizConcepts);
      print('🔀 [MindMap] Total unique concepts: ${allConcepts.length}');
      
      // Step 5: Organize into hierarchical structure
      final mindMap = _buildHierarchy(mainTopic, allConcepts);
      print('✅ [MindMap] Mind map generated successfully');
      
      return mindMap;
    } catch (e) {
      print('❌ [MindMap] Error generating mind map: $e');
      rethrow;
    }
  }

  // Extract main topic from filename or first sentence
  static String _extractMainTopic(String? fileName, String summary) {
    if (fileName != null && fileName.isNotEmpty) {
      // Clean filename: remove extension and format
      String topic = fileName
          .replaceAll(RegExp(r'\.(pdf|PDF)$'), '')
          .replaceAll(RegExp(r'[_-]'), ' ')
          .trim();
      
      // If reasonable length, use it
      if (topic.length > 3 && topic.length < 50) {
        return _capitalizeWords(topic);
      }
    }
    
    // Fallback: Extract from first sentence of summary
    final firstSentence = summary
        .split(RegExp(r'[.!?]'))
        .firstWhere((s) => s.trim().length > 10, orElse: () => summary)
        .trim();
    
    final words = firstSentence.split(RegExp(r'\s+'));
    final topic = words.take(min(6, words.length)).join(' ');
    
    return _capitalizeWords(topic.length > 50 ? topic.substring(0, 50) : topic);
  }

  // Extract key points from summary text
  static List<String> _extractKeyPointsFromSummary(String summary) {
    final points = <String>[];
    
    // Split into sentences
    final sentences = summary
        .split(RegExp(r'[.!?]\s+'))
        .where((s) => s.trim().length > 20)
        .toList();
    
    for (final sentence in sentences) {
      // Extract important phrases (noun phrases, key terms)
      final phrases = _extractImportantPhrases(sentence);
      points.addAll(phrases);
    }
    
    return points.take(12).toList(); // Limit to top 12 points
  }

  // Extract important phrases from a sentence
  static List<String> _extractImportantPhrases(String sentence) {
    final phrases = <String>[];
    
    // Method 1: Extract capitalized terms (proper nouns, key concepts)
    final capitalizedTerms = RegExp(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})\b')
        .allMatches(sentence)
        .map((m) => m.group(1)!)
        .where((term) => term.length > 3 && term.split(' ').length <= 4)
        .toList();
    
    phrases.addAll(capitalizedTerms);
    
    // Method 2: Extract phrases around keywords
    final keywords = [
      'important', 'significant', 'key', 'essential', 'primary', 'main',
      'principle', 'concept', 'theory', 'law', 'method', 'process', 'system',
      'force', 'energy', 'motion', 'acceleration', 'velocity', 'mass'
    ];
    
    for (final keyword in keywords) {
      if (sentence.toLowerCase().contains(keyword)) {
        // Extract phrase around keyword (5 words before and after)
        final words = sentence.split(RegExp(r'\s+'));
        final keywordIndex = words
            .indexWhere((w) => w.toLowerCase().contains(keyword));
        
        if (keywordIndex != -1) {
          final start = max(0, keywordIndex - 2);
          final end = min(words.length, keywordIndex + 3);
          final phrase = words.sublist(start, end).join(' ')
              .replaceAll(RegExp(r'[^A-Za-z0-9\s]'), '')
              .trim();
          
          if (phrase.length > 5 && phrase.length < 60) {
            phrases.add(_capitalizeWords(phrase));
          }
        }
      }
    }
    
    // Method 3: Extract long meaningful words (6+ characters)
    final longWords = RegExp(r'\b[A-Za-z]{6,}\b')
        .allMatches(sentence)
        .map((m) => m.group(0)!)
        .where((w) {
          final lower = w.toLowerCase();
          return !_isStopWord(lower) && !lower.contains('however');
        })
        .take(3)
        .toList();
    
    phrases.addAll(longWords.map((w) => _capitalizeWords(w)));
    
    return phrases;
  }

  // Extract key concepts from quiz questions
  static List<String> _extractConceptsFromQuiz(List<Map<String, dynamic>> quiz) {
    final concepts = <String>[];
    
    for (final question in quiz) {
      try {
        // Extract the answer (correct concept)
        final answer = question['answer_text'] as String?;
        if (answer != null && answer.length > 3) {
          concepts.add(_capitalizeWords(answer));
        }
        
        // Extract key terms from question text
        final questionText = question['question'] as String? ?? '';
        final keyTerms = _extractKeyTermsFromQuestion(questionText);
        concepts.addAll(keyTerms);
        
      } catch (e) {
        print('⚠️ [MindMap] Error extracting from quiz question: $e');
        continue;
      }
    }
    
    return concepts;
  }

  // Extract key terms from question text
  static List<String> _extractKeyTermsFromQuestion(String question) {
    final terms = <String>[];
    
    // Extract capitalized terms
    final capitalizedTerms = RegExp(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\b')
        .allMatches(question)
        .map((m) => m.group(1)!)
        .where((term) => term.length > 3)
        .toList();
    
    terms.addAll(capitalizedTerms);
    
    // Extract words before and after blank
    final blankContext = RegExp(r'(\w+)\s+_____\s+(\w+)')
        .firstMatch(question);
    
    if (blankContext != null) {
      final before = blankContext.group(1);
      final after = blankContext.group(2);
      if (before != null && before.length > 3) {
        terms.add(_capitalizeWords(before));
      }
      if (after != null && after.length > 3) {
        terms.add(_capitalizeWords(after));
      }
    }
    
    return terms;
  }

  // Merge and deduplicate concepts
  static List<String> _mergeAndDeduplicate(
    List<String> summaryPoints,
    List<String> quizConcepts,
  ) {
    final allConcepts = <String>[...summaryPoints, ...quizConcepts];
    final uniqueConcepts = <String>{};
    
    for (final concept in allConcepts) {
      final normalized = concept.toLowerCase().trim();
      
      // Skip if too short or too long
      if (normalized.length < 3 || normalized.length > 60) continue;
      
      // Skip stop words
      if (_isStopWord(normalized)) continue;
      
      // Check for duplicates (exact or substring)
      bool isDuplicate = false;
      for (final existing in uniqueConcepts) {
        final existingNorm = existing.toLowerCase();
        
        // Check if one is substring of other
        if (existingNorm.contains(normalized) || normalized.contains(existingNorm)) {
          // Keep the longer, more specific one
          if (normalized.length > existingNorm.length) {
            uniqueConcepts.remove(existing);
            break;
          } else {
            isDuplicate = true;
            break;
          }
        }
      }
      
      if (!isDuplicate) {
        uniqueConcepts.add(concept);
      }
    }
    
    return uniqueConcepts.toList();
  }

  // Build hierarchical mind map structure
  static MindMapNode _buildHierarchy(String mainTopic, List<String> concepts) {
    // Sort concepts by length (shorter = more general, longer = more specific)
    final sortedConcepts = List<String>.from(concepts)
      ..sort((a, b) => a.length.compareTo(b.length));
    
    // Group concepts into categories
    final categories = _categorizeConceptsIntelligently(sortedConcepts);
    
    // Build child nodes
    final children = <MindMapNode>[];
    
    for (final category in categories.entries) {
      final categoryNode = MindMapNode(
        title: category.key,
        level: 1,
        children: category.value
            .map((concept) => MindMapNode(
                  title: concept,
                  level: 2,
                ))
            .toList(),
      );
      children.add(categoryNode);
    }
    
    // Create root node
    return MindMapNode(
      title: mainTopic,
      level: 0,
      children: children,
    );
  }

  // Intelligently categorize concepts
  static Map<String, List<String>> _categorizeConceptsIntelligently(
    List<String> concepts,
  ) {
    // If few concepts, group by first letter
    if (concepts.length <= 8) {
      return _groupByFirstLetter(concepts);
    }
    
    // Try to find semantic categories
    final categories = <String, List<String>>{};
    
    // Category keywords
    final categoryKeywords = {
      'Key Concepts': ['principle', 'concept', 'theory', 'law', 'rule'],
      'Methods & Processes': ['method', 'process', 'procedure', 'technique', 'approach'],
      'Properties & Characteristics': ['property', 'characteristic', 'feature', 'attribute'],
      'Components & Parts': ['component', 'part', 'element', 'section', 'unit'],
      'Effects & Results': ['effect', 'result', 'outcome', 'impact', 'consequence'],
    };
    
    final uncategorized = <String>[];
    
    for (final concept in concepts) {
      final lower = concept.toLowerCase();
      bool categorized = false;
      
      for (final category in categoryKeywords.entries) {
        for (final keyword in category.value) {
          if (lower.contains(keyword)) {
            categories.putIfAbsent(category.key, () => []);
            categories[category.key]!.add(concept);
            categorized = true;
            break;
          }
        }
        if (categorized) break;
      }
      
      if (!categorized) {
        uncategorized.add(concept);
      }
    }
    
    // If too many uncategorized, split by length
    if (uncategorized.length > 5) {
      final short = uncategorized.where((c) => c.length < 20).toList();
      final long = uncategorized.where((c) => c.length >= 20).toList();
      
      if (short.isNotEmpty) {
        categories['Key Terms'] = short.take(5).toList();
      }
      if (long.isNotEmpty) {
        categories['Detailed Information'] = long.take(5).toList();
      }
    } else {
      if (uncategorized.isNotEmpty) {
        categories['Other Concepts'] = uncategorized;
      }
    }
    
    // Limit each category to max 5 items
    for (final key in categories.keys.toList()) {
      if (categories[key]!.length > 5) {
        categories[key] = categories[key]!.take(5).toList();
      }
    }
    
    return categories;
  }

  // Fallback: Group by first letter
  static Map<String, List<String>> _groupByFirstLetter(List<String> concepts) {
    final groups = <String, List<String>>{};
    
    for (final concept in concepts) {
      final firstChar = concept[0].toUpperCase();
      final groupName = 'Group $firstChar';
      
      groups.putIfAbsent(groupName, () => []);
      groups[groupName]!.add(concept);
    }
    
    return groups;
  }

  // Helper: Check if word is a stop word
  static bool _isStopWord(String word) {
    final stopWords = {
      'the', 'and', 'for', 'with', 'from', 'this', 'that', 'which',
      'are', 'was', 'were', 'have', 'has', 'had', 'their', 'there',
      'they', 'these', 'those', 'been', 'also', 'such', 'but', 'not',
      'can', 'will', 'may', 'you', 'your', 'into', 'about', 'between',
      'therefore', 'however', 'because', 'while', 'during', 'after',
      'before', 'through', 'over', 'under', 'above', 'below'
    };
    
    return stopWords.contains(word.toLowerCase());
  }

  // Helper: Capitalize first letter of each word
  static String _capitalizeWords(String text) {
    return text.split(' ')
        .map((word) => word.isEmpty 
            ? word 
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}