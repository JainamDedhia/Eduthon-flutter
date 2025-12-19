/// Explanation Parser Service
/// Extracts explanations from PDF/summary text using regex patterns (offline)
class ExplanationParser {
  // Regex patterns for finding explanations
  static final List<RegExp> _explanationPatterns = [
    // Matches "Explanation:" followed by text until new paragraph or end
    RegExp(r'Explanation[:\s]+(.+?)(?=\n\n|\n[A-Z][a-z]+:|$)', caseSensitive: false, dotAll: true),
    // Matches "Reason:" patterns
    RegExp(r'Reason[:\s]+(.+?)(?=\n|$)', caseSensitive: false, dotAll: true),
    // Matches "Because:" patterns
    RegExp(r'Because[:\s]+(.+?)(?=\n|$)', caseSensitive: false, dotAll: true),
    // Matches "Note:" patterns
    RegExp(r'Note[:\s]+(.+?)(?=\n|$)', caseSensitive: false, dotAll: true),
    // Matches "Why:" patterns
    RegExp(r'Why[:\s]+(.+?)(?=\n|$)', caseSensitive: false, dotAll: true),
    // Matches "This is because" patterns
    RegExp(r'This is because[:\s]+(.+?)(?=\n|\.\s+[A-Z]|$)', caseSensitive: false, dotAll: true),
  ];

  /// Parse explanation for a quiz question from source text
  /// 
  /// [question] - The quiz question text
  /// [sourceText] - The PDF/summary text to search in
  /// [correctAnswer] - The correct answer text
  /// 
  /// Returns explanation string or null if not found
  static String? parseExplanation(
    String question,
    String sourceText,
    String correctAnswer,
  ) {
    try {
      // Clean inputs
      final cleanQuestion = question.trim();
      final cleanSource = sourceText.trim();
      final cleanAnswer = correctAnswer.trim();

      if (cleanSource.isEmpty) {
        return null;
      }

      // Strategy 1: Look for explicit explanation patterns near the question
      final explanation = _findExplicitExplanation(cleanQuestion, cleanSource);
      if (explanation != null && explanation.isNotEmpty) {
        return _cleanExplanation(explanation);
      }

      // Strategy 2: Extract context around the correct answer
      final contextExplanation = _extractContextAroundAnswer(
        cleanSource,
        cleanAnswer,
        contextLength: 200,
      );
      if (contextExplanation != null && contextExplanation.isNotEmpty) {
        return _cleanExplanation(contextExplanation);
      }

      // Strategy 3: Find relevant section based on question keywords
      final keywordExplanation = _findExplanationByKeywords(
        cleanQuestion,
        cleanSource,
      );
      if (keywordExplanation != null && keywordExplanation.isNotEmpty) {
        return _cleanExplanation(keywordExplanation);
      }

      return null;
    } catch (e) {
      print('❌ [ExplanationParser] Error parsing explanation: $e');
      return null;
    }
  }

  /// Find explicit explanation patterns in the source text
  static String? _findExplicitExplanation(String question, String sourceText) {
    // Search for explanation patterns
    for (final pattern in _explanationPatterns) {
      final matches = pattern.allMatches(sourceText);
      for (final match in matches) {
        if (match.groupCount > 0) {
          final explanation = match.group(1)?.trim();
          if (explanation != null && explanation.length > 20) {
            // Check if explanation is relevant to the question
            if (_isRelevantToQuestion(question, explanation)) {
              return explanation;
            }
          }
        }
      }
    }
    return null;
  }

  /// Extract context around the correct answer in source text
  static String? _extractContextAroundAnswer(
    String sourceText,
    String answerText, {
    int contextLength = 200,
  }) {
    try {
      // Find answer text in source (case-insensitive)
      final answerLower = answerText.toLowerCase();
      final sourceLower = sourceText.toLowerCase();

      final answerIndex = sourceLower.indexOf(answerLower);
      if (answerIndex == -1) {
        return null;
      }

      // Extract context before and after the answer
      final startIndex = (answerIndex - contextLength).clamp(0, sourceText.length);
      final endIndex = (answerIndex + answerText.length + contextLength)
          .clamp(0, sourceText.length);

      final context = sourceText.substring(startIndex, endIndex);

      // Try to extract complete sentences
      final sentences = _extractSentences(context);
      if (sentences.length >= 2) {
        // Return 2-3 sentences around the answer
        final start = sentences.length > 3 ? sentences.length - 3 : 0;
        return sentences.sublist(start).join(' ').trim();
      }

      return context.trim();
    } catch (e) {
      print('❌ [ExplanationParser] Error extracting context: $e');
      return null;
    }
  }

  /// Find explanation based on question keywords
  static String? _findExplanationByKeywords(String question, String sourceText) {
    try {
      // Extract keywords from question (remove common words)
      final keywords = _extractKeywords(question);
      if (keywords.isEmpty) {
        return null;
      }

      // Split source into sentences
      final sentences = _extractSentences(sourceText);

      // Find sentences that contain multiple keywords
      final relevantSentences = <String>[];
      for (final sentence in sentences) {
        final sentenceLower = sentence.toLowerCase();
        int keywordMatches = 0;
        for (final keyword in keywords) {
          if (sentenceLower.contains(keyword.toLowerCase())) {
            keywordMatches++;
          }
        }
        // If sentence contains at least 2 keywords, it's relevant
        if (keywordMatches >= 2) {
          relevantSentences.add(sentence);
        }
      }

      if (relevantSentences.isNotEmpty) {
        // Return 2-3 most relevant sentences
        final count = relevantSentences.length > 3 ? 3 : relevantSentences.length;
        return relevantSentences.sublist(0, count).join(' ').trim();
      }

      return null;
    } catch (e) {
      print('❌ [ExplanationParser] Error finding by keywords: $e');
      return null;
    }
  }

  /// Extract keywords from question (remove common stop words)
  static List<String> _extractKeywords(String question) {
    final stopWords = {
      'what', 'which', 'who', 'when', 'where', 'why', 'how',
      'is', 'are', 'was', 'were', 'the', 'a', 'an', 'and', 'or', 'but',
      'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'from',
      'this', 'that', 'these', 'those', 'it', 'they', 'we', 'you',
      'do', 'does', 'did', 'can', 'could', 'should', 'would',
    };

    // Remove punctuation and split into words
    final words = question
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 3) // Only words longer than 3 chars
        .where((word) => !stopWords.contains(word))
        .toList();

    return words;
  }

  /// Extract sentences from text
  static List<String> _extractSentences(String text) {
    // Split by sentence endings
    final sentences = text
        .split(RegExp(r'[.!?]+\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 10)
        .toList();
    return sentences;
  }

  /// Check if explanation is relevant to the question
  static bool _isRelevantToQuestion(String question, String explanation) {
    final questionKeywords = _extractKeywords(question);
    if (questionKeywords.isEmpty) {
      return true; // If no keywords, assume relevant
    }

    final explanationLower = explanation.toLowerCase();
    int matches = 0;
    for (final keyword in questionKeywords) {
      if (explanationLower.contains(keyword.toLowerCase())) {
        matches++;
      }
    }

    // If at least one keyword matches, consider it relevant
    return matches > 0;
  }

  /// Clean and format explanation text
  static String _cleanExplanation(String explanation) {
    return explanation
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single
        .replaceAll(RegExp(r'\n+'), ' ') // Newlines to space
        .trim()
        .substring(0, explanation.length > 500 ? 500 : explanation.length) // Limit length
        .trim();
  }

  /// Batch parse explanations for multiple questions
  static Map<int, String?> parseExplanationsForQuiz(
    List<Map<String, dynamic>> quiz,
    String sourceText,
  ) {
    final explanations = <int, String?>{};

    for (int i = 0; i < quiz.length; i++) {
      try {
        final question = quiz[i];
        final questionText = question['question'] as String? ?? '';
        final answerLabel = question['answer_label'] as String? ?? '';
        final options = question['options'] as List<dynamic>? ?? [];

        // Find correct answer text
        String? correctAnswerText;
        for (final opt in options) {
          if (opt is Map<String, dynamic>) {
            final label = opt['label'] as String? ?? '';
            if (label == answerLabel) {
              correctAnswerText = opt['text'] as String? ?? '';
              break;
            }
          }
        }

        if (correctAnswerText != null && correctAnswerText.isNotEmpty) {
          final explanation = parseExplanation(
            questionText,
            sourceText,
            correctAnswerText,
          );
          explanations[i] = explanation;
        } else {
          explanations[i] = null;
        }
      } catch (e) {
        print('❌ [ExplanationParser] Error parsing explanation for question $i: $e');
        explanations[i] = null;
      }
    }

    return explanations;
  }
}

