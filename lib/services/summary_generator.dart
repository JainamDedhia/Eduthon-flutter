// FILE: lib/services/summary_generator.dart
import 'dart:io';
import 'dart:math';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive_io.dart';

class SummaryGenerator {
  // Extract text from PDF (handles compressed files)
  static Future<String> extractTextFromPDF(String pdfPath) async {
    try {
      print('📄 Extracting text from: $pdfPath');
      
      final File file = File(pdfPath);
      if (!await file.exists()) {
        throw Exception('PDF file not found: $pdfPath');
      }

      // Check if file is compressed (.gz)
      List<int> pdfBytes;
      if (pdfPath.endsWith('.gz')) {
        print('🗜️ Decompressing gzipped PDF...');
        final compressedBytes = await file.readAsBytes();
        
        try {
          final decoder = GZipDecoder();
          pdfBytes = decoder.decodeBytes(compressedBytes);
          print('✅ Decompressed: ${compressedBytes.length} → ${pdfBytes.length} bytes');
        } catch (decompressionError) {
          print('⚠️ Decompression failed, trying as raw PDF: $decompressionError');
          pdfBytes = compressedBytes;
        }
      } else {
        pdfBytes = await file.readAsBytes();
      }

      // Load PDF document
      PdfDocument? document;
      try {
        document = PdfDocument(inputBytes: pdfBytes);
        print('✅ PDF loaded: ${document.pages.count} pages');
      } catch (e) {
        print('❌ Failed to load PDF: $e');
        throw Exception('Invalid PDF file or corrupted data');
      }
      
      String extractedText = '';
      int successfulPages = 0;
      
      // Extract text from each page individually
      for (int i = 0; i < document.pages.count; i++) {
        try {
          String pageText = PdfTextExtractor(document).extractText(
            startPageIndex: i,
            endPageIndex: i,
          ) ?? '';

          // Fallback extraction method
          if (pageText.trim().isEmpty) {
            try {
              final PdfTextExtractor extractor = PdfTextExtractor(document);
              final result = extractor.extractText(startPageIndex: i);
              if (result != null && result.isNotEmpty) {
                pageText = result;
              }
            } catch (e) {
              print('⚠️ Page ${i + 1}: Text line extraction failed');
            }
          }
          
          // Add page text if not empty
          if (pageText.trim().isNotEmpty) {
            extractedText += pageText.trim() + '\n\n';
            successfulPages++;
            print('✅ Page ${i + 1}: Extracted ${pageText.length} characters');
          } else {
            print('⚠️ Page ${i + 1}: No text extracted (may be image-only)');
          }
        } catch (pageError) {
          print('⚠️ Page ${i + 1}: Error - $pageError');
          continue;
        }
      }
      
      final totalPages = document.pages.count;
      document.dispose();
      
      // Check if any text was extracted
      if (extractedText.trim().isEmpty) {
        throw Exception(
          'Could not extract any text from this PDF.\n\n'
          'Possible reasons:\n'
          '• PDF contains only images (scanned document)\n'
          '• PDF is encrypted or password-protected\n'
          '• PDF structure is corrupted\n\n'
          'Pages checked: $totalPages\n'
          'Text found: 0 characters'
        );
      }
      
      print('✅ Successfully extracted ${extractedText.length} characters from $successfulPages/$totalPages pages');
      return extractedText.trim();
    } catch (e) {
      print('❌ PDF extraction error: $e');
      rethrow;
    }
  }

  // Clean text
  static String cleanText(String text) {
    if (text.isEmpty) return '';

    // Step 1: Basic normalization
    text = text.replaceAll('\r\n', '\n');
    text = text.replaceAll('\u00A0', ' ');
    text = text.replaceAll('\t', ' ');

    // Step 2: Remove bracketed citations
    text = text.replaceAll(RegExp(r'\[[^\]]{1,200}\]'), ' ');

    // Step 3: Remove short parenthetical notes
    text = text.replaceAll(RegExp(r'\(\s*[^\)]{1,120}\s*\)'), ' ');

    // Step 4: Remove explicit junk headers
    text = text.replaceAll(
      RegExp(r'\b(Reprint|Re-Print|Chapter|Chapter Reprint|EXERCISES?|KEYWORDS)\b', caseSensitive: false),
      ' ',
    );

    // Step 5: Remove ALL CAPS lines - FIXED REGEX
    text = text.replaceAll(RegExp(r'^[A-Z0-9\s\-]{6,}$', multiLine: true), ' ');

    // Step 6: Remove sequences of very short tokens (OCR artifacts)
    text = text.replaceAll(RegExp(r'(\b[a-zA-Z]{1,3}\b[\s,;:-]?){3,}'), ' ');

    // Step 7: Remove page numbers and year ranges
    text = text.replaceAll(RegExp(r'\bPage\s*\d+\b', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'\b202\d[-\–]\d{2}\b'), ' ');

    // Step 8: Remove numbered bullets at line starts
    text = text.replaceAll(RegExp(r'^\s*\(?[0-9]+(?:\.[0-9]+)*\)?\s*', multiLine: true), ' ');
    text = text.replaceAll(RegExp(r'\(\s*[ivx]+\s*\)\s*', caseSensitive: false), ' ');

    // Step 9: Split into lines and keep only useful ones
    final lines = text.split('\n').where((line) {
      final ln = line.trim();
      if (ln.isEmpty) return false;
      if (ln.length < 10) return false;
      
      // Check alpha ratio
      final alphaCount = ln.split('').where((c) => RegExp(r'[a-zA-Z]').hasMatch(c)).length;
      final alphaRatio = alphaCount / max(1, ln.length);
      if (alphaRatio < 0.35) return false;

      // Drop header-like all-caps lines
      final tokens = RegExp(r'[A-Za-z]{2,}').allMatches(ln).map((m) => m.group(0)!).toList();
      if (tokens.isNotEmpty) {
        final uppercaseCount = tokens.where((t) => t == t.toUpperCase()).length;
        if (uppercaseCount >= max(2, tokens.length ~/ 2) && ln.length > 8) {
          return false;
        }
      }
      
      return true;
    }).map((line) => line.trim());

    text = lines.join(' ');

    // Step 10: Remove immediate duplicate adjacent words (OCR errors)
    text = text.replaceAllMapped(
      RegExp(r'\b([A-Za-z]{3,})\s+\1\b', caseSensitive: false),
      (match) => match.group(1)!,
    );

    // Step 11: Remove near-duplicates
    text = text.replaceAllMapped(
      RegExp(r'\b([A-Za-z]{4,})\s+([A-Za-z]{4,})\b'),
      (match) {
        final word1 = match.group(1)!;
        final word2 = match.group(2)!;
        if (_isNearDuplicate(word1, word2)) {
          return word1;
        }
        return match.group(0)!;
      },
    );

    // Step 12: Collapse repeated sequences
    text = text.replaceAllMapped(
      RegExp(r'\b([A-Za-z]{2,})(?:\s+\1){2,}\b', caseSensitive: false),
      (match) => match.group(1)!,
    );

    // Step 13: Final whitespace normalization
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return text;
  }

  // Helper: Check if two words are near-duplicates
  static bool _isNearDuplicate(String a, String b) {
    final aLower = a.toLowerCase();
    final bLower = b.toLowerCase();
    
    if (aLower == bLower) return true;
    if ((aLower.length - bLower.length).abs() > 1) return false;
    
    int mismatches = 0;
    int i = 0, j = 0;
    
    while (i < aLower.length && j < bLower.length) {
      if (aLower[i] == bLower[j]) {
        i++;
        j++;
      } else {
        mismatches++;
        if (mismatches > 1) return false;
        
        if (aLower.length > bLower.length) {
          i++;
        } else if (bLower.length > aLower.length) {
          j++;
        } else {
          i++;
          j++;
        }
      }
    }
    
    mismatches += (aLower.length - i) + (bLower.length - j);
    return mismatches <= 1;
  }

  // Extract top keywords
  static List<String> extractKeywords(String text, {int topK = 12, int minWordLen = 5}) {
    final textLower = text.toLowerCase();
    final stopwords = {
      'the', 'and', 'for', 'with', 'from', 'this', 'that', 'which', 'are', 
      'was', 'were', 'have', 'has', 'had', 'their', 'there', 'they', 'these',
      'those', 'been', 'also', 'such', 'but', 'not', 'can', 'will', 'may',
      'you', 'your', 'into', 'about', 'between', 'during', 'each', 'per',
      'include', 'including', 'other', 'use', 'uses', 'used', 'using',
      'some', 'many', 'most', 'more', 'much', 'one', 'two', 'three'
    };

    final words = RegExp(r'\b[a-z]{' + minWordLen.toString() + r',}\b')
        .allMatches(textLower)
        .map((m) => m.group(0)!)
        .where((w) => !stopwords.contains(w) && !RegExp(r'^\d+$').hasMatch(w));

    final freq = <String, int>{};
    for (final word in words) {
      freq[word] = (freq[word] ?? 0) + 1;
    }

    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(topK).map((e) => e.key).toList();
  }

  // Score sentence
  static int scoreSentence(String sentence) {
    final cleaned = sentence.replaceAll(RegExp(r'[^A-Za-z0-9\s]'), '').toLowerCase();
    final words = cleaned.split(RegExp(r'\s+'));
    if (words.isEmpty) return 0;

    int score = words.length;

    final keywords = [
      'important', 'conclusion', 'therefore', 'however', 'because', 'result',
      'results', 'study', 'shows', 'found', 'evidence', 'purpose', 'objective',
      'method', 'analysis', 'gravitation', 'force', 'mass', 'acceleration',
      'velocity', 'motion', 'energy', 'law', 'principle'
    ];

    for (final keyword in keywords) {
      if (cleaned.contains(keyword)) {
        score += 6;
      }
    }

    if (RegExp(r'\d').hasMatch(sentence)) {
      score += 3;
    }

    final caps = RegExp(r'\b[A-Z][a-z]{2,}\b').allMatches(sentence).length;
    score += caps;

    return score;
  }

  // Generate summary
  static Future<String> generateSummary(
    String text, {
    int targetChars = 2600,
    int targetLines = 18,
  }) async {
    text = cleanText(text);
    if (text.isEmpty) {
      return 'No extractable text found in this PDF.';
    }

    // Split into paragraphs
    final paras = text.split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.split(RegExp(r'\s+')).length >= 8)
        .toList();

    if (paras.isEmpty) {
      final sents = text.split(RegExp(r'(?<=[.!?])\s+'))
          .where((s) => s.split(RegExp(r'\s+')).length >= 6)
          .toList();
      final snippet = sents.take(targetLines).join(' ');
      return snippet.substring(0, min(targetChars, snippet.length));
    }

    // Extract keywords
    final keywords = extractKeywords(paras.join(' '), topK: 12);
    if (keywords.isEmpty) {
      return text.substring(0, min(targetChars, text.length));
    }

    print('📊 Keywords extracted: ${keywords.take(5).join(", ")}...');

    // Assign paragraphs to keywords
    final clusters = <String, List<String>>{};
    for (final kw in keywords) {
      clusters[kw] = [];
    }
    clusters['other'] = [];

    for (final para in paras) {
      final paraLower = para.toLowerCase();
      String? bestKw;
      int bestScore = 0;

      for (final kw in keywords) {
        try {
          final escapedKw = RegExp.escape(kw);
          final count = RegExp(r'\b' + escapedKw + r'\b').allMatches(paraLower).length;
          if (count > bestScore) {
            bestScore = count;
            bestKw = kw;
          }
        } catch (e) {
          print('⚠️ Regex error for keyword "$kw": $e');
          continue;
        }
      }

      if (bestKw != null && clusters.containsKey(bestKw)) {
        clusters[bestKw]!.add(para);
      } else if (clusters.containsKey('other')) {
        clusters['other']!.add(para);
      }
    }

    // Extract top sentences
    final selectedSents = <String>[];
    final seen = <String>{};

    for (final kw in keywords) {
      final paraList = clusters[kw];
      if (paraList == null || paraList.isEmpty) continue;
      
      for (final para in paraList) {
        final sents = para.split(RegExp(r'(?<=[.!?])\s+'))
            .where((s) => s.split(RegExp(r'\s+')).length >= 6)
            .toList();

        if (sents.isEmpty) continue;

        final scored = sents.map((s) => MapEntry(scoreSentence(s), s)).toList()
          ..sort((a, b) => b.key.compareTo(a.key));

        for (final entry in scored.take(2)) {
          final key = entry.value.toLowerCase();
          if (seen.contains(key)) continue;
          selectedSents.add(entry.value);
          seen.add(key);
          if (selectedSents.length >= targetLines) break;
        }
        if (selectedSents.length >= targetLines) break;
      }
      if (selectedSents.length >= targetLines) break;
    }

    // Compose summary
    String summary = selectedSents.join(' ');
    if (summary.length > targetChars) {
      summary = summary.substring(0, targetChars);
      final lastPeriod = summary.lastIndexOf('.');
      if (lastPeriod > 0) {
        summary = summary.substring(0, lastPeriod + 1);
      }
    }

    // Ensure ends with sentence
    if (!RegExp(r'[.!?]$').hasMatch(summary.trim())) {
      final match = RegExp(r'([.!?])').allMatches(summary).lastOrNull;
      if (match != null) {
        final idx = match.start;
        summary = summary.substring(0, idx + 1);
      }
    }

    final lines = summary.split(RegExp(r'(?<=[.!?])\s+'))
        .where((ln) => ln.split(RegExp(r'\s+')).length >= 4)
        .take(targetLines);

    return lines.join('\n').trim();
  }

  // Generate MCQ quiz
  static Future<List<Map<String, dynamic>>> generateQuiz(
    String summary, {
    int numQuestions = 7,
  }) async {
    if (summary.isEmpty) return [];

    final sentences = summary.split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().split(RegExp(r'\s+')).length >= 6)
        .toList();

    final candidates = _findCandidatePhrases(summary);
    if (candidates.isEmpty) return [];

    print('📝 Candidate phrases found: ${candidates.length}');

    final mcqs = <Map<String, dynamic>>[];
    final usedAnswers = <String>{};
    final random = Random();

    for (final sent in sentences) {
      if (mcqs.length >= numQuestions) break;

      candidates.shuffle();
      String? chosen;
      
      for (final cand in candidates) {
        try {
          if (RegExp(r'\b' + RegExp.escape(cand) + r'\b', caseSensitive: false).hasMatch(sent)) {
            if (usedAnswers.contains(cand.toLowerCase())) continue;
            chosen = cand;
            break;
          }
        } catch (e) {
          print('⚠️ Regex error for candidate "$cand": $e');
          continue;
        }
      }

      if (chosen == null) {
        final words = RegExp(r'\b[A-Za-z]{6,}\b').allMatches(sent).map((m) => m.group(0)).whereType<String>().toList();
        if (words.isEmpty) continue;
        chosen = words.reduce((a, b) => a.length > b.length ? a : b);
      }

      // FIXED: Add null check before using chosen
      if (chosen == null) continue;

      try {
        final question = sent.replaceFirst(RegExp(RegExp.escape(chosen), caseSensitive: false), '_____');

        final distractors = <String>[];
        
        // FIXED: Safe null handling for chosen.toLowerCase()
        final pool = candidates.where((c) {
          final chosenLower = chosen!.toLowerCase();
          final cLower = c.toLowerCase();
          return cLower != chosenLower;
        }).toList();
        
        pool.shuffle();
        
        for (final p in pool.take(3)) {
          distractors.add(p);
        }

        while (distractors.length < 3) {
          final mutated = _mutateWord(chosen);
          final mutatedLower = mutated.toLowerCase();
          final chosenLower = chosen.toLowerCase();
          if (mutatedLower != chosenLower && !distractors.contains(mutated)) {
            distractors.add(mutated);
          }
        }

        final options = [...distractors.take(3), chosen];
        options.shuffle();

        final labeled = options.asMap().entries.map((e) => {
          'label': String.fromCharCode(65 + e.key), // A, B, C, D
          'text': e.value,
        }).toList();

        final correctOption = labeled.firstWhere(
          (item) => item['text'] == chosen,
          orElse: () => labeled.last,
        );
        final correctLabel = correctOption['label'] as String;

        mcqs.add({
          'question': question.trim(),
          'options': labeled,
          'answer_label': correctLabel,
          'answer_text': chosen,
        });

        usedAnswers.add(chosen.toLowerCase());
      } catch (e) {
        print('⚠️ Error creating quiz for sentence: $e');
        continue;
      }
    }

    print('✅ Generated ${mcqs.length} quiz questions');
    return mcqs;
  }

  static List<String> _findCandidatePhrases(String text, {int minWordLen = 5}) {
    try {
      final named = RegExp(r'\b([A-Z][a-z]{2,}(?:\s+[A-Z][a-z]{2,}){0,2})\b')
          .allMatches(text)
          .map((m) => m.group(1))
          .whereType<String>()
          .where((n) => n.length >= minWordLen && n.split(' ').length <= 3)
          .toList();

      final words = RegExp(r'\b[A-Za-z]{' + minWordLen.toString() + r',}\b')
          .allMatches(text)
          .map((m) => m.group(0))
          .whereType<String>()
          .toList();

      final candidates = {...named, ...words}.toList();
      
      final stops = {'therefore', 'however', 'because', 'throughout', 'between', 'including'};
      return candidates.where((c) => !stops.contains(c.toLowerCase())).toList();
    } catch (e) {
      print('⚠️ Error finding candidate phrases: $e');
      return [];
    }
  }

  static String _mutateWord(String word) {
    final random = Random();
    if (word.length <= 4) {
      return word + ['a', 'e'][random.nextInt(2)];
    }
    if (word.contains(' ')) {
      final parts = word.split(' ');
      final i = random.nextInt(parts.length);
      parts[i] = parts[i].substring(0, parts[i].length - 1) + ['a', 'e', 'i', 'o', 'u'][random.nextInt(5)];
      return parts.join(' ');
    }
    return word.substring(0, word.length - 1) + ['a', 'e', 'i', 'o', 'u'][random.nextInt(5)];
  }
}