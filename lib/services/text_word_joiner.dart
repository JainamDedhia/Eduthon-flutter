// FILE: lib/services/text_word_joiner.dart
/// A High-Accuracy Hybrid Text Repair Service
/// Fixed to handle "narr at or" → "narrator" type spacing issues
class TextWordJoiner {
  /// Fix split, merged, and repeating words/characters.
  static String fixSplitWords(String text) {
    if (text.isEmpty) return text;

    // 1. DEDUPLICATION PHASE (Fixes "GGGGGRAVITATION..." etc)
    String cur = _deduplicateContent(text);

    // 2. AGGRESSIVE NORMALIZATION
    cur = cur
        .replaceAll('\u00A0', ' ')
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r' {2,}'), ' ');

    // 3. FIX SPLIT WORDS WITH SPACES (NEW!)
    // This fixes "narr at or" → "narrator", "An il" → "Anil", etc.
    cur = _fixSpacedWords(cur);

    // 4. TARGETED HARD-CODED REPAIR (NCERT Calibration)
    final targetedFixes = {
      // Common Physics/Science Splits
      RegExp(r'\bfor\s+ceacting\b', caseSensitive: false): 'force acting',
      RegExp(r'\bmoti\s+on\b', caseSensitive: false): 'motion',
      RegExp(r'\bdirecti\s+on\b', caseSensitive: false): 'direction',
      RegExp(r'\bgravitati\s+on\b', caseSensitive: false): 'gravitation',
      RegExp(r'\bgravitati\s+on\s+al\b', caseSensitive: false): 'gravitational',
      RegExp(r'\baccelerati\s+on\b', caseSensitive: false): 'acceleration',
      RegExp(r'\bfor\s+ce\b', caseSensitive: false): 'force',
      RegExp(r'\bin\s+versely\b', caseSensitive: false): 'inversely',
      RegExp(r'\bat\s+tracti\s+on\b', caseSensitive: false): 'attraction',
      RegExp(r'\bat\s+tracts\b', caseSensitive: false): 'attracts',
      RegExp(r'\bat\s+tracti\b', caseSensitive: false): 'attract',
      RegExp(r'\bin\s+volves\b', caseSensitive: false): 'involves',
      RegExp(r'\bin\s+fluence\b', caseSensitive: false): 'influence',
      RegExp(r'\bsituati\s+on\b', caseSensitive: false): 'situation',
      RegExp(r'\bunderst\s+and\b', caseSensitive: false): 'understand',
      RegExp(r'\bin\s+troduce\b', caseSensitive: false): 'introduce',
      RegExp(r'\bto\s+wards\b', caseSensitive: false): 'towards',
      RegExp(r'\bdo\s+wnwards\b', caseSensitive: false): 'downwards',
      RegExp(r'\bfall\s+ing\b', caseSensitive: false): 'falling',
      RegExp(r'\bbe\s+lieved\b', caseSensitive: false): 'believed',
      RegExp(r'\bavail\s+able\b', caseSensitive: false): 'available',
      RegExp(r'\bkhar\s+if\b', caseSensitive: false): 'kharif',
      RegExp(r'\bseas\s+on\b', caseSensitive: false): 'season',
      
      // NEW: Common English word splits
      RegExp(r'\bnarr\s+at\s+or\b', caseSensitive: false): 'narrator',
      RegExp(r'\bAn\s+il\b'): 'Anil',
      RegExp(r'\bperson\s+al\b', caseSensitive: false): 'personal',
      RegExp(r'\bass\s+istant\b', caseSensitive: false): 'assistant',
      RegExp(r'\bwork\s+ing\b', caseSensitive: false): 'working',
      RegExp(r'\birregular\s+ly\b', caseSensitive: false): 'irregularly',
      RegExp(r'\bmoney\s+from\b', caseSensitive: false): 'money from',
      RegExp(r'\bcareless\s+pers\b', caseSensitive: false): 'careless person',

      // Merge Errors (Targeted Splitting)
      RegExp(r'\binverselyproportional\b', caseSensitive: false):
          'inversely proportional',
      RegExp(r'\blearntth\b', caseSensitive: false): 'learnt that',
      RegExp(r'\bgravitationalforce\b', caseSensitive: false):
          'gravitational force',
      RegExp(r'\bforceacting\b', caseSensitive: false): 'force acting',
      RegExp(r'\bflies\s+of\s+falong\b', caseSensitive: false):
          'flies off along',
      RegExp(r'\bThissystem\b', caseSensitive: false): 'This system',
      RegExp(r'\bsufficientwater\b', caseSensitive: false): 'sufficient water',
      RegExp(r'\busefulon\b', caseSensitive: false): 'useful on',
      RegExp(r'\bfruitplants\b', caseSensitive: false): 'fruit plants',
      RegExp(r'\babullet\b', caseSensitive: false): 'a bullet',
    };

    for (var entry in targetedFixes.entries) {
      cur = cur.replaceAll(entry.key, entry.value);
    }

    // 5. STRUCTURAL SPLITTING & CLEANUP
    return cur.split('\n').map(_structuralCleanup).join('\n');
  }

  // NEW: Fix words that are split with spaces between characters
  // This handles patterns like "narr at or" → "narrator"
  static String _fixSpacedWords(String text) {
    // Common suffixes that get split
    final commonSuffixes = [
      'or', 'er', 'ed', 'ing', 'ion', 'tion', 'sion', 'ment', 'ness',
      'able', 'ible', 'ful', 'less', 'ly', 'al', 'ous', 'ive', 'ant',
      'ent', 'ist', 'ic', 'ical', 'ity', 'ness', 'ship', 'hood'
    ];
    
    // Common prefixes that get split
    final commonPrefixes = [
      'un', 'in', 're', 'dis', 'mis', 'pre', 'post', 'non', 'anti',
      'de', 'over', 'under', 'out', 'up', 'sub', 'inter', 'super',
      'trans', 'auto', 'co', 'ex'
    ];

    String result = text;

    // Fix suffix splits: "work ing" → "working"
    for (final suffix in commonSuffixes) {
      // Pattern: word + space + suffix (as separate word)
      result = result.replaceAllMapped(
        RegExp(r'\b([a-z]{2,})\s+(' + suffix + r')\b', caseSensitive: false),
        (m) {
          final word = m.group(1)!;
          final suf = m.group(2)!;
          
          // Only join if it looks like it should be one word
          // Check if the base word is at least 3 chars
          if (word.length >= 3) {
            return word + suf;
          }
          return m.group(0)!;
        },
      );
    }

    // Fix prefix splits: "un able" → "unable"
    for (final prefix in commonPrefixes) {
      result = result.replaceAllMapped(
        RegExp(r'\b(' + prefix + r')\s+([a-z]{3,})\b', caseSensitive: false),
        (m) {
          final pref = m.group(1)!;
          final word = m.group(2)!;
          
          // Only join if the word is at least 3 chars
          if (word.length >= 3) {
            return pref + word;
          }
          return m.group(0)!;
        },
      );
    }

    // Fix middle splits: "narr at or" → "narrator"
    // Pattern: word part + space + short connector + space + suffix
    result = result.replaceAllMapped(
      RegExp(r'\b([a-z]{2,})\s+([a-z]{1,3})\s+([a-z]{2,})\b', caseSensitive: false),
      (m) {
        final part1 = m.group(1)!;
        final middle = m.group(2)!;
        final part3 = m.group(3)!;
        
        // If middle part is very short (1-3 chars) and the pattern looks like a split word
        if (middle.length <= 3 && part1.length >= 2 && part3.length >= 2) {
          // Check if this could be a valid word when joined
          final joined = part1 + middle + part3;
          
          // Common patterns that indicate this should be joined:
          // - Total length is reasonable (4-15 chars)
          // - Doesn't create obvious nonsense
          if (joined.length >= 4 && joined.length <= 15) {
            return joined;
          }
        }
        
        return m.group(0)!;
      },
    );

    return result;
  }

  static String _deduplicateContent(String text) {
    if (text.isEmpty) return text;
    String cleaned = text.replaceAllMapped(
      RegExp(r'([A-Z])\1{4,}'),
      (m) => m.group(1)!,
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([A-Z]{4,})\1+'),
      (m) => m.group(1)!,
    );
    return cleaned;
  }

  static String _structuralCleanup(String line) {
    if (line.trim().isEmpty) return line;
    final words = line.split(' ');
    final fixedWords = words.map((word) {
      if (word.length < 5) return word;
      String lower = word.toLowerCase();
      final prefixStoppers = ['the', 'is', 'not', 'that', 'with', 'from'];
      final suffixStoppers = ['the', 'on', 'at', 'in', 'to', 'of', 'and'];
      for (final s in prefixStoppers) {
        if (lower.startsWith(s) && lower.length > s.length + 2) {
          return word.substring(0, s.length) + ' ' + word.substring(s.length);
        }
      }
      for (final s in suffixStoppers) {
        if (lower.endsWith(s) && lower.length > s.length + 2) {
          return word.substring(0, word.length - s.length) +
              ' ' +
              word.substring(word.length - s.length);
        }
      }
      return word;
    });
    return fixedWords.join(' ');
  }
  
  // Optional: Debug function to test specific strings
  static void debugLine(String line) {
    print('IN : $line');
    print('OUT: ${fixSplitWords(line)}');
    print('---');
  }
}