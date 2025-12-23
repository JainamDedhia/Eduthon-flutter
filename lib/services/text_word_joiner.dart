// FILE: lib/services/text_word_joiner.dart
//
// Dynamic Text Repair Service for PDF Extraction
// 
// Fixes common PDF text extraction issues:
// - Split words (e.g., "seas on" → "season")  
// - Merged words (e.g., "earthThe" → "earth The")
// - Repeating characters (e.g., "GGGG" → "G")
// 
// Works generically across all PDF types without hard-coded patterns.

class TextWordJoiner {
  // Common English word suffixes
  static const List<String> _commonSuffixes = [
    'tion', 'sion', 'ment', 'ness', 'able', 'ible', 'ing', 'ed', 'er', 'est',
    'ly', 'ous', 'ious', 'eous', 'al', 'ial', 'ual', 'ful', 'less', 'ity',
    'ty', 'ism', 'ist', 'ite', 'ive', 'ative', 'itive', 'on', 'an', 'in', 
    'and', 'ent', 'ence', 'ance', 'ure', 'age', 'ate'
  ];

  // Standalone words that should not be joined
  static const List<String> _dontJoin = [
    'the', 'is', 'at', 'it', 'be', 'by', 'do',
    'go', 'he', 'i', 'if', 'me', 'my', 'no', 'of', 'so', 'up', 'us', 'we'
  ];

  /// Fix split, merged, and repeating words dynamically
  static String fixSplitWords(String text) {
    if (text.isEmpty) return text;

    // Phase 1: Remove excessive character repetition
    String cur = _deduplicateContent(text);

    // Phase 2: Normalize whitespace and special characters
    cur = cur
        .replaceAll('\u00A0', ' ')  // Non-breaking spaces
        .replaceAll('\r\n', '\n')   // Windows newlines
        .replaceAll(RegExp(r' {2,}'), ' ');  // Multiple spaces to single

    // Phase 3: Fix split words dynamically using suffix analysis
    cur = _fixSplitWordsDynamic(cur);

    // Phase 4: Fix merged words using case transitions and patterns
    cur = _fixMergedWordsDynamic(cur);

    return cur.trim();
  }

  /// Fix split words by analyzing suffix patterns
  static String _fixSplitWordsDynamic(String text) {
    final words = text.split(' ');
    final result = <String>[];
    int i = 0;

    while (i < words.length) {
      final currentWord = words[i];
      final currentLower = currentWord.toLowerCase();
      bool merged = false;
      
      // Try to merge with next word if it exists and matches suffix pattern
      if (i + 1 < words.length) {
        final nextWord = words[i + 1];
        final nextLower = nextWord.toLowerCase();
        
        if (_shouldMergeWords(currentLower, nextLower)) {
          // Merge: keep first word's case, make second lowercase
          result.add(currentWord + nextWord.toLowerCase());
          i += 2;
          merged = true;
        }
      }

      if (!merged) {
        result.add(currentWord);
        i++;
      }
    }

    return result.join(' ');
  }

  /// Determine if two consecutive words should be merged
  static bool _shouldMergeWords(String word1, String word2) {
    // Don't merge if either is a common standalone word
    if (_dontJoin.contains(word1) || _dontJoin.contains(word2)) {
      return false;
    }

    // Don't merge if word2 is too long (probably not a suffix)
    if (word2.length >= 4 && !_commonSuffixes.contains(word2)) {
      return false;
    }

    // Check if word2 is a recognized suffix
    if (_commonSuffixes.contains(word2)) {
      // Stricter rules for very short, ambiguous suffixes
      if (word2 == 'on' || word2 == 'in' || word2 == 'an') {
        return _looksIncomplete(word1, word2);
      }

      // For other suffixes, apply length-based rules
      if (word2.length <= 2) {
        return word1.length >= 3;
      }
      if (word2.length == 3) {
        return word1.length >= 3;
      }
      // Longer suffixes merge with shorter words
      return word1.length >= 2;
    }

    return false;
  }

  /// Check if a word looks incomplete and would benefit from a suffix
  static bool _looksIncomplete(String word, String suffix) {
    if (word.isEmpty) return false;

    final lastChar = word[word.length - 1].toLowerCase();
    final isVowel = 'aeiou'.contains(lastChar);

    switch (suffix) {
      case 'on':
        // Patterns like "seas" + "on" = "season", "gravitati" + "on" = "gravitation"
        // Accept if ends with vowel (partial) or short word ending in 's'
        return isVowel || (word.length >= 4 && word.length <= 6 && word.endsWith('s'));

      case 'in':
        // Patterns like "In" + "dia" = "India", "orig" + "in" = "origin"
        return word.length <= 4 && isVowel;

      case 'an':
        // Patterns like "hum" + "an" = "human"
        return word.length >= 3 && word.length <= 5;

      default:
        return false;
    }
  }

  /// Fix merged words using case transitions
  static String _fixMergedWordsDynamic(String text) {
    // Pattern 1: lowercase word followed by TitleCase word
    // e.g., "earthThe" → "earth The"
    text = text.replaceAllMapped(
      RegExp(r'([a-z]{3,})([A-Z][a-z]{2,})', multiLine: true),
      (match) {
        // Don't split if preceded by a digit (chemical formulas)
        if (match.start > 0 && RegExp(r'\d').hasMatch(text[match.start - 1])) {
          return match.group(0)!;
        }
        return '${match.group(1)} ${match.group(2)}';
      },
    );

    // Pattern 2: UPPERCASE followed by TitleCase
    // e.g., "GRAVITATIONThe" → "GRAVITATION The"
    text = text.replaceAllMapped(
      RegExp(r'([A-Z]{3,})([A-Z][a-z]+)', multiLine: true),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    // Pattern 3: Number boundaries
    // e.g., "9.1.2IMPORTANCE" → "9.1.2 IMPORTANCE"
    text = text.replaceAllMapped(
      RegExp(r'(\d+\.?\d*\.?\d*)([A-Z][A-Za-z]{2,})', multiLine: true),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    // Pattern 4: Abbreviations before numbers
    // e.g., "Eq.10" → "Eq. 10"
    text = text.replaceAllMapped(
      RegExp(r'([A-Za-z]{1,3})\.(\d)', multiLine: true),
      (match) => '${match.group(1)}. ${match.group(2)}',
    );

    // Pattern 5: List markers
    // e.g., "(i)Text" → "(i) Text"
    text = text.replaceAllMapped(
      RegExp(r'(\([ivx]+\))([A-Za-z])', multiLine: true),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    return text;
  }

  /// Remove excessive character repetition
  static String _deduplicateContent(String text) {
    if (text.isEmpty) return text;

    // Fix repeating uppercase (only if 4+ same chars)
    // e.g., "GGGGG" → "G", but "GG" stays as "GG"
    String cleaned = text.replaceAllMapped(
      RegExp(r'([A-Z])\1{4,}'),
      (m) => m.group(1)!,
    );

    // Fix repeating lowercase (only if 5+ same chars)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([a-z])\1{4,}'),
      (m) => m.group(1)!,
    );

    // Fix doubled punctuation
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(\.\s*){2,}'),
      (m) => '. ',
    );

    return cleaned;
  }
}
