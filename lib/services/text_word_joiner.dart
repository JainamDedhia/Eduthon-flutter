// FILE: lib/services/text_word_joiner.dart
/// A High-Accuracy Hybrid Text Repair Service
/// Calibrated for Physics and Agriculture PDF extraction artifacts.
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

    // 3. TARGETED HARD-CODED REPAIR (NCERT Calibration)
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

    // 4. STRUCTURAL SPLITTING & CLEANUP
    return cur.split('\n').map(_structuralCleanup).join('\n');
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
}
