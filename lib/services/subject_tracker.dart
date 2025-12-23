// FILE: lib/services/subject_tracker.dart
import 'subject_vocabulary.dart';

class SubjectTracker {
  // Accumulated scores for each subject across chunks
  final Map<String, double> _subjectScores = {};
  
  // Track term frequency to help disambiguation
  final Map<String, int> _termFrequency = {};
  
  // Context window of recent strong indicators
  final List<String> _recentContext = [];
  static const int _contextWindowSize = 5;

  SubjectTracker() {
    // Initialize scores
    for (final subject in SubjectVocabulary.vocabulary.keys) {
      _subjectScores[subject] = 0.0;
    }
  }

  // Process a chunk of text and update scores
  void processChunk(String text) {
    final textLower = text.toLowerCase();
    final words = textLower.split(RegExp(r'\W+')).where((w) => w.length > 2).toList();
    
    // 1. Update term frequency
    for (final word in words) {
      _termFrequency[word] = (_termFrequency[word] ?? 0) + 1;
    }

    // 2. Score vocabulary terms
    for (final subject in SubjectVocabulary.vocabulary.keys) {
      final vocab = SubjectVocabulary.vocabulary[subject]!;
      
      for (final term in vocab.keys) {
        if (words.contains(term)) {
          int count = 0;
          // Count occurrences in this chunk
          for (final word in words) {
            if (word == term) count++;
          }
          
          if (count > 0) {
            // Base score = weight * count
            double score = (vocab[term]! * count).toDouble();
            
            // Context boost: if related terms were seen recently
            if (_hasContextOverlap(subject)) {
              score *= 1.2;
            }
            
            // Disambiguation penalty for ambiguous terms unless context supports it
            if (SubjectVocabulary.ambiguousTerms.contains(term)) {
              if (!_isSubjectDominant(subject)) {
                score *= 0.5;
              }
            }

            _subjectScores[subject] = (_subjectScores[subject] ?? 0) + score;
            
            // Update context if term is highly specific (weight >= 4)
            if (vocab[term]! >= 4) {
              _addToContext(subject);
            }
          }
        }
      }
    }
  }

  // Add a strong indicator to the sliding context window
  void _addToContext(String subject) {
    _recentContext.add(subject);
    if (_recentContext.length > _contextWindowSize) {
      _recentContext.removeAt(0);
    }
  }

  // Check if the subject is present in recent context
  bool _hasContextOverlap(String subject) {
    return _recentContext.contains(subject);
  }

  // Check if a subject is currently leading significantly
  bool _isSubjectDominant(String subject) {
    final currentScore = _subjectScores[subject] ?? 0;
    if (currentScore == 0) return false;
    
    // Simple heuristic: dominant if score is > 20% higher than average of others
    double sumOthers = 0;
    int countOthers = 0;
    
    for (final other in _subjectScores.keys) {
      if (other != subject) {
        sumOthers += _subjectScores[other]!;
        countOthers++;
      }
    }
    
    if (countOthers == 0) return true;
    final avgOthers = sumOthers / countOthers;
    
    return currentScore > (avgOthers * 1.2);
  }

  // Get the detected subject
  String getDominantSubject() {
    String bestSubject = 'General';
    double maxScore = 0;

    _subjectScores.forEach((subject, score) {
      if (score > maxScore) {
        maxScore = score;
        bestSubject = subject;
      }
    });

    // Threshold: if max score is too low, remain General
    if (maxScore < 5.0) return 'General';

    return bestSubject;
  }
  
  // Get detailed scores (for debugging/confidence)
  Map<String, double> getScores() => Map.unmodifiable(_subjectScores);
  
  // Reset state
  void reset() {
    _subjectScores.clear();
    _termFrequency.clear();
    _recentContext.clear();
    for (final subject in SubjectVocabulary.vocabulary.keys) {
      _subjectScores[subject] = 0.0;
    }
  }
}
