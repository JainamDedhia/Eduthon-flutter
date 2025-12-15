// FILE: lib/services/offline_rag_service.dart
import 'dart:math';

class OfflineRAGService {
  // BM25 parameters
  static const double k1 = 1.5;
  static const double b = 0.75;
  
  // Cache for processed documents
  static ProcessedDocument? _cachedDoc;
  static String? _cachedDocHash;
  
  /// Main entry point - Answer question using RAG
  /// Returns response or null if it can't process (for fallback)
  static Future<String?> answerQuestion({
    required String question,
    required String? documentText, // Make optional
    required List<Map<String, String>> conversationHistory,
  }) async {
    try {
      // If no document text, we can't use RAG
      if (documentText == null || documentText.isEmpty) {
        print('📄 [OfflineRAG] No document available for RAG');
        return null;
      }
      
      print('🤖 [OfflineRAG] Processing: ${question.substring(0, min(50, question.length))}...');
      
      // Process document if not cached
      final docHash = documentText.hashCode.toString();
      if (_cachedDocHash != docHash || _cachedDoc == null) {
        print('📄 [OfflineRAG] Processing document...');
        _cachedDoc = _processDocument(documentText);
        _cachedDocHash = docHash;
      }
      
      final processedDoc = _cachedDoc!;
      
      // Extract key terms
      final queryTerms = _extractKeyTerms(question);
      
      // Retrieve relevant passages
      final relevantPassages = _retrieveRelevantPassages(
        queryTerms: queryTerms,
        processedDoc: processedDoc,
        topK: 5,
      );
      
      if (relevantPassages.isEmpty) {
        print('📝 [OfflineRAG] No relevant passages found');
        return null;
      }
      
      print('📝 [OfflineRAG] Found ${relevantPassages.length} relevant passages');
      
      // Generate response
      final response = _generateResponse(
        question: question,
        relevantPassages: relevantPassages,
        conversationHistory: conversationHistory,
      );
      
      print('✅ [OfflineRAG] Response generated');
      return response;
      
    } catch (e) {
      print('❌ [OfflineRAG] Error: $e');
      return null; // Return null to trigger fallback
    }
  }
  
  /// Process document into searchable structure
  static ProcessedDocument _processDocument(String text) {
    final sentences = _splitIntoSentences(text);
    final passages = _createPassages(sentences);
    final invertedIndex = _buildInvertedIndex(passages);
    final idfScores = _calculateIDF(invertedIndex, passages.length);
    
    return ProcessedDocument(
      passages: passages,
      invertedIndex: invertedIndex,
      idfScores: idfScores,
      avgPassageLength: passages.isEmpty ? 0 : 
          passages.map((p) => p.terms.length).reduce((a, b) => a + b) / passages.length,
    );
  }
  
  static List<String> _splitIntoSentences(String text) {
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty && s.split(RegExp(r'\s+')).length >= 5)
        .map((s) => s.trim())
        .toList();
  }
  
  static List<Passage> _createPassages(List<String> sentences) {
    final passages = <Passage>[];
    for (int i = 0; i < sentences.length; i += 2) {
      final end = min(i + 4, sentences.length);
      final passageText = sentences.sublist(i, end).join(' ');
      final terms = _extractTerms(passageText);
      if (terms.isNotEmpty) {
        passages.add(Passage(
          text: passageText,
          terms: terms,
          sentenceIndices: List.generate(end - i, (idx) => i + idx),
        ));
      }
    }
    return passages;
  }
  
  static List<String> _extractTerms(String text) {
    final stopWords = {
      'the', 'and', 'for', 'with', 'from', 'this', 'that', 'which',
      'are', 'was', 'were', 'have', 'has', 'had', 'their', 'there',
      'they', 'these', 'those', 'been', 'also', 'such', 'but', 'not',
      'can', 'will', 'may', 'you', 'your', 'into', 'about', 'what',
      'how', 'why', 'when', 'where', 'who', 'does', 'did'
    };
    
    return RegExp(r'\b[a-z]{3,}\b')
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .where((term) => !stopWords.contains(term))
        .toList();
  }
  
  static List<String> _extractKeyTerms(String question) {
    final terms = _extractTerms(question);
    final capitalizedTerms = RegExp(r'\b[A-Z][a-z]{2,}\b')
        .allMatches(question)
        .map((m) => m.group(0)!.toLowerCase())
        .toList();
    return {...terms, ...capitalizedTerms}.toList();
  }
  
  static Map<String, List<int>> _buildInvertedIndex(List<Passage> passages) {
    final index = <String, List<int>>{};
    for (int i = 0; i < passages.length; i++) {
      for (final term in passages[i].terms.toSet()) {
        index.putIfAbsent(term, () => []);
        index[term]!.add(i);
      }
    }
    return index;
  }
  
  static Map<String, double> _calculateIDF(
    Map<String, List<int>> invertedIndex,
    int totalPassages,
  ) {
    final idfScores = <String, double>{};
    for (final entry in invertedIndex.entries) {
      final term = entry.key;
      final docFreq = entry.value.length;
      idfScores[term] = log((totalPassages - docFreq + 0.5) / (docFreq + 0.5) + 1);
    }
    return idfScores;
  }
  
  static List<RankedPassage> _retrieveRelevantPassages({
    required List<String> queryTerms,
    required ProcessedDocument processedDoc,
    required int topK,
  }) {
    final scores = <int, double>{};
    for (int i = 0; i < processedDoc.passages.length; i++) {
      scores[i] = _calculateBM25Score(
        queryTerms: queryTerms,
        passage: processedDoc.passages[i],
        idfScores: processedDoc.idfScores,
        avgPassageLength: processedDoc.avgPassageLength,
      );
    }
    
    final rankedIndices = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return rankedIndices
        .take(topK)
        .where((entry) => entry.value > 0)
        .map((entry) => RankedPassage(
              passage: processedDoc.passages[entry.key],
              score: entry.value,
            ))
        .toList();
  }
  
  static double _calculateBM25Score({
    required List<String> queryTerms,
    required Passage passage,
    required Map<String, double> idfScores,
    required double avgPassageLength,
  }) {
    double score = 0.0;
    final termFreq = <String, int>{};
    for (final term in passage.terms) {
      termFreq[term] = (termFreq[term] ?? 0) + 1;
    }
    
    final passageLength = passage.terms.length;
    for (final term in queryTerms) {
      final tf = termFreq[term] ?? 0;
      if (tf == 0) continue;
      final idf = idfScores[term] ?? 0;
      final numerator = tf * (k1 + 1);
      final denominator = tf + k1 * (1 - b + b * (passageLength / avgPassageLength));
      score += idf * (numerator / denominator);
    }
    return score;
  }
  
  static String _generateResponse({
    required String question,
    required List<RankedPassage> relevantPassages,
    required List<Map<String, String>> conversationHistory,
  }) {
    if (relevantPassages.isEmpty) {
      return "I found some information in your document:\n\n${relevantPassages.first.passage.text}\n\nIs there something specific you'd like to know?";
    }
    
    final questionType = _determineQuestionType(question);
    
    switch (questionType) {
      case QuestionType.definition:
        return _generateDefinitionResponse(question, relevantPassages);
      case QuestionType.explanation:
        return _generateExplanationResponse(question, relevantPassages);
      case QuestionType.comparison:
        return _generateComparisonResponse(question, relevantPassages);
      case QuestionType.factual:
        return _generateFactualResponse(question, relevantPassages);
      case QuestionType.howTo:
        return _generateHowToResponse(question, relevantPassages);
      default:
        return _generateGenericResponse(question, relevantPassages);
    }
  }
  
  static QuestionType _determineQuestionType(String question) {
    final lowerQuestion = question.toLowerCase();
    if (lowerQuestion.startsWith('what is') || lowerQuestion.startsWith('define')) {
      return QuestionType.definition;
    }
    if (lowerQuestion.startsWith('why') || lowerQuestion.contains('explain')) {
      return QuestionType.explanation;
    }
    if (lowerQuestion.contains('difference') || lowerQuestion.contains('compare')) {
      return QuestionType.comparison;
    }
    if (lowerQuestion.startsWith('how to') || lowerQuestion.contains('steps')) {
      return QuestionType.howTo;
    }
    if (lowerQuestion.startsWith('what') || lowerQuestion.startsWith('when') || 
        lowerQuestion.startsWith('where') || lowerQuestion.startsWith('who')) {
      return QuestionType.factual;
    }
    return QuestionType.generic;
  }
  
  static String _generateDefinitionResponse(String question, List<RankedPassage> passages) {
    return "Based on your document:\n\n${passages.first.passage.text}";
  }
  
  static String _generateExplanationResponse(String question, List<RankedPassage> passages) {
    return "Here's what your document says:\n\n${passages.take(2).map((p) => p.passage.text).join('\n\n')}";
  }
  
  static String _generateComparisonResponse(String question, List<RankedPassage> passages) {
    if (passages.length >= 2) {
      return "From your document:\n\n${passages[0].passage.text}\n\nAlso:\n\n${passages[1].passage.text}";
    }
    return "According to your document:\n\n${passages.first.passage.text}";
  }
  
  static String _generateFactualResponse(String question, List<RankedPassage> passages) {
    return "Based on your document:\n\n${passages.first.passage.text}";
  }
  
  static String _generateHowToResponse(String question, List<RankedPassage> passages) {
    return "Your document mentions:\n\n${passages.first.passage.text}";
  }
  
  static String _generateGenericResponse(String question, List<RankedPassage> passages) {
    return "From your document:\n\n${passages.first.passage.text}";
  }
}

class ProcessedDocument {
  final List<Passage> passages;
  final Map<String, List<int>> invertedIndex;
  final Map<String, double> idfScores;
  final double avgPassageLength;
  
  ProcessedDocument({
    required this.passages,
    required this.invertedIndex,
    required this.idfScores,
    required this.avgPassageLength,
  });
}

class Passage {
  final String text;
  final List<String> terms;
  final List<int> sentenceIndices;
  
  Passage({
    required this.text,
    required this.terms,
    required this.sentenceIndices,
  });
}

class RankedPassage {
  final Passage passage;
  final double score;
  
  RankedPassage({
    required this.passage,
    required this.score,
  });
}

enum QuestionType {
  definition,
  explanation,
  comparison,
  factual,
  howTo,
  generic,
}