// FILE: lib/services/summary_generator.dart
import 'dart:io';
import 'dart:math';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive_io.dart'; // For GZipDecoder

class SummaryGenerator {
  // Extract text from PDF (handles compressed files) - ROBUST VERSION
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
      
      // Extract text from each page with multiple methods
      for (int i = 0; i < document.pages.count; i++) {
        try {
          String? pageText;
          
          // Method 1: Try standard text extraction
          try {
            final PdfTextExtractor extractor = PdfTextExtractor(document);
            pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
          } catch (e) {
            print('⚠️ Page ${i + 1}: Standard extraction failed');
            pageText = null;
          }
          
          // Method 2: If null or empty, try extracting from the page directly
          if (pageText == null || pageText.trim().isEmpty) {
            try {
              final page = document.pages[i];
              final PdfTextExtractor pageExtractor = PdfTextExtractor(document);
              pageText = pageExtractor.extractText(startPageIndex: i);
            } catch (e) {
              print('⚠️ Page ${i + 1}: Direct page extraction failed');
              pageText = null;
            }
          }
          
          // Method 3: Try extracting all text and manually filter by page
          if (pageText == null || pageText.trim().isEmpty) {
            try {
              final PdfTextExtractor fullExtractor = PdfTextExtractor(document);
              final fullText = fullExtractor.extractText();
              if (fullText != null && fullText.isNotEmpty) {
                // Estimate text per page (crude but works as fallback)
                final avgCharsPerPage = fullText.length ~/ document.pages.count;
                final startIdx = i * avgCharsPerPage;
                final endIdx = min((i + 1) * avgCharsPerPage, fullText.length);
                if (startIdx < fullText.length) {
                  pageText = fullText.substring(startIdx, endIdx);
                }
              }
            } catch (e) {
              print('⚠️ Page ${i + 1}: Full extraction failed');
            }
          }
          
          if (pageText != null && pageText.trim().isNotEmpty) {
            extractedText += pageText + '\n\n';
            successfulPages++;
          } else {
            print('⚠️ Page ${i + 1}: No text extracted (may be image-only)');
          }
        } catch (pageError) {
          print('⚠️ Page ${i + 1}: Extraction error - $pageError');
          continue;
        }
      }
      
      document.dispose();
      
      if (extractedText.trim().isEmpty) {
        throw Exception(
          'No text could be extracted from this PDF. '
          'It may contain only images or be encrypted. '
          'Tried ${document.pages.count} pages, extracted 0.'
        );
      }
      
      print('✅ Extracted ${extractedText.length} characters from $successfulPages/${document.pages.count} pages');
      return extractedText;
    } catch (e) {
      print('❌ PDF extraction error: $e');
      rethrow;
    }
  }

  // Clean text (ported from Python)
  static String cleanText(String text) {
    if (text.isEmpty) return '';

    // Normalize whitespace
    text = text.replaceAll('\r\n', '\n');
    text = text.replaceAll('\u00A0', ' ');
    text = text.replaceAll('\t', ' ');

    // Remove bracketed citations [Fig.], [They...]
    text = text.replaceAll(RegExp(r'\[[^\]]{1,200}\]'), ' ');

    // Remove short parenthetical notes
    text = text.replaceAll(RegExp(r'\(\s*[^\)]{1,120}\s*\)'), ' ');

    // Remove common junk words
    text = text.replaceAll(
      RegExp(r'\b(Reprint|Re-Print|Chapter|EXERCISES?|KEYWORDS)\b', caseSensitive: false),
      ' ',
    );

    // Remove page numbers
    text = text.replaceAll(RegExp(r'\bPage\s*\d+\b', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'\b202\d[-–]\d{2}\b'), ' ');

    // Remove numbered bullets
    text = text.replaceAll(RegExp(r'^\s*\(?[0-9]+(?:\.[0-9]+)*\)?\s*', multiLine: true), ' ');

    // Split into lines and filter
    final lines = text.split('\n').where((line) {
      final trimmed = line.trim();
      if (trimmed.length < 10) return false;
      
      final alphaCount = trimmed.split('').where((c) => RegExp(r'[a-zA-Z]').hasMatch(c)).length;
      final alphaRatio = alphaCount / max(1, trimmed.length);
      if (alphaRatio < 0.35) return false;

      return true;
    }).map((line) => line.trim());

    text = lines.join(' ');

    // Remove duplicate adjacent words
    text = text.replaceAllMapped(
      RegExp(r'\b([A-Za-z]{3,})\s+\1\b', caseSensitive: false),
      (match) => match.group(1)!,
    );

    // Normalize final whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return text;
  }

  // Extract top keywords (ported from Python)
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

  // Score sentence (ported from Python)
  static int scoreSentence(String sentence) {
    final cleaned = sentence.replaceAll(RegExp(r'[^A-Za-z0-9\s]'), '').toLowerCase();
    final words = cleaned.split(RegExp(r'\s+'));
    if (words.isEmpty) return 0;

    int score = words.length;

    final keywords = [
      'important', 'conclusion', 'therefore', 'however', 'because', 'result',
      'results', 'study', 'shows', 'found', 'evidence', 'purpose', 'objective',
      'method', 'analysis', 'harvest', 'irrigation', 'fertiliser', 'manure',
      'storage', 'paddy', 'wheat', 'maize'
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

  // Generate summary (ported from Python)
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
    final paras = text.split(RegExp(r'\n{1,}|\r\n{1,}'))
        .map((p) => p.trim())
        .where((p) => p.split(RegExp(r'\s+')).length >= 8)
        .toList();

    if (paras.isEmpty) {
      final sents = text.split(RegExp(r'(?<=[.!?])\s+'))
          .where((s) => s.split(RegExp(r'\s+')).length >= 6)
          .toList();
      return sents.take(targetLines).join(' ').substring(0, min(targetChars, sents.join(' ').length));
    }

    // Extract keywords
    final keywords = extractKeywords(paras.join(' '), topK: 12);
    if (keywords.isEmpty) {
      return text.substring(0, min(targetChars, text.length));
    }

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
        final count = RegExp(r'\b' + RegExp.escape(kw) + r'\b').allMatches(paraLower).length;
        if (count > bestScore) {
          bestScore = count;
          bestKw = kw;
        }
      }

      if (bestKw != null) {
        clusters[bestKw]!.add(para);
      } else {
        clusters['other']!.add(para);
      }
    }

    // Extract top sentences
    final selectedSents = <String>[];
    final seen = <String>{};

    for (final kw in keywords) {
      final paraList = clusters[kw] ?? [];
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

  // Generate MCQ quiz (ported from Python)
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

    final mcqs = <Map<String, dynamic>>[];
    final usedAnswers = <String>{};
    final random = Random();

    for (final sent in sentences) {
      if (mcqs.length >= numQuestions) break;

      candidates.shuffle();
      String? chosen;
      
      for (final cand in candidates) {
        if (RegExp(r'\b' + RegExp.escape(cand) + r'\b', caseSensitive: false).hasMatch(sent)) {
          if (usedAnswers.contains(cand.toLowerCase())) continue;
          chosen = cand;
          break;
        }
      }

      if (chosen == null) {
        final words = RegExp(r'\b[A-Za-z]{6,}\b').allMatches(sent).map((m) => m.group(0)!).toList();
        if (words.isEmpty) continue;
        chosen = words.reduce((a, b) => a.length > b.length ? a : b);
      }

      final question = sent.replaceFirst(RegExp(RegExp.escape(chosen), caseSensitive: false), '_____');

      final distractors = <String>[];
      final pool = candidates.where((c) => c.toLowerCase() != chosen!.toLowerCase()).toList();
      pool.shuffle();
      
      for (final p in pool.take(3)) {
        distractors.add(p);
      }

      while (distractors.length < 3) {
        final mutated = _mutateWord(chosen!);
        if (mutated.toLowerCase() != chosen.toLowerCase() && !distractors.contains(mutated)) {
          distractors.add(mutated);
        }
      }

      final options = [...distractors.take(3), chosen];
      options.shuffle();

      final labeled = options.asMap().entries.map((e) => {
        'label': String.fromCharCode(65 + e.key), // A, B, C, D
        'text': e.value,
      }).toList();

      final correctLabel = labeled.firstWhere((item) => item['text'] == chosen)['label'];

      mcqs.add({
        'question': question.trim(),
        'options': labeled,
        'answer_label': correctLabel,
        'answer_text': chosen,
      });

      usedAnswers.add(chosen.toLowerCase());
    }

    return mcqs;
  }

  static List<String> _findCandidatePhrases(String text, {int minWordLen = 5}) {
    final named = RegExp(r'\b([A-Z][a-z]{2,}(?:\s+[A-Z][a-z]{2,}){0,2})\b')
        .allMatches(text)
        .map((m) => m.group(1)!)
        .where((n) => n.length >= minWordLen && n.split(' ').length <= 3)
        .toList();

    final words = RegExp(r'\b[A-Za-z]{' + minWordLen.toString() + r',}\b')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();

    final candidates = {...named, ...words}.toList();
    
    final stops = {'therefore', 'however', 'because', 'throughout', 'between', 'including'};
    return candidates.where((c) => !stops.contains(c.toLowerCase())).toList();
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