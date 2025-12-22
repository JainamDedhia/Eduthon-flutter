// FILE: lib/services/summary_generator.dart
import 'dart:io';
import 'dart:math';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive_io.dart';

class SummaryGenerator {
  // Extract text from PDF (handles compressed files) - UNCHANGED
  static Future<String> extractTextFromPDF(String pdfPath) async {
    try {
      print('📄 Extracting text from: $pdfPath');
      
      final File file = File(pdfPath);
      if (!await file.exists()) {
        throw Exception('PDF file not found: $pdfPath');
      }

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
      
      for (int i = 0; i < document.pages.count; i++) {
        try {
          String pageText = PdfTextExtractor(document).extractText(
            startPageIndex: i,
            endPageIndex: i,
          ) ?? '';

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

  // ENHANCED: Clean text - improved algorithm
  static String cleanText(String text) {
    if (text.isEmpty) return '';

    // Step 1: Normalize whitespace
    text = text.replaceAll('\r\n', '\n');
    text = text.replaceAll('\u00A0', ' ');
    text = text.replaceAll('\t', ' ');

    // Step 2: Remove citations and references
    text = text.replaceAll(RegExp(r'\[[^\]]{1,200}\]'), ' ');
    text = text.replaceAll(RegExp(r'\(\s*[^\)]{1,120}\s*\)'), ' ');

    // Step 3: Remove headers and metadata
    text = text.replaceAll(
      RegExp(r'\b(Reprint|Re-Print|Chapter|EXERCISES?|KEYWORDS?|Bibliography|References)\b', caseSensitive: false),
      ' ',
    );

    // Step 4: Remove ALL CAPS lines (likely headers)
    text = text.replaceAll(RegExp(r'^[A-Z0-9\s\-]{6,}$', multiLine: true), ' ');

    // Step 5: Remove OCR artifacts (short token sequences)
    text = text.replaceAll(RegExp(r'(\b[a-zA-Z]{1,3}\b[\s,;:-]?){3,}'), ' ');

    // Step 6: Remove page numbers and dates
    text = text.replaceAll(RegExp(r'\bPage\s*\d+\b', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'\b202\d[-\–]\d{2}\b'), ' ');

    // Step 7: Remove list markers
    text = text.replaceAll(RegExp(r'^\s*\(?[0-9]+(?:\.[0-9]+)*\)?\s*', multiLine: true), ' ');

    // Step 8: Filter meaningful lines
    final lines = text.split('\n').where((line) {
      final ln = line.trim();
      if (ln.isEmpty || ln.length < 15) return false;
      
      // Check alpha ratio
      final alphaCount = ln.split('').where((c) => RegExp(r'[a-zA-Z]').hasMatch(c)).length;
      final alphaRatio = alphaCount / max(1, ln.length);
      if (alphaRatio < 0.4) return false;

      // Filter header-like lines
      final tokens = RegExp(r'[A-Za-z]{2,}').allMatches(ln).map((m) => m.group(0)!).toList();
      if (tokens.isNotEmpty) {
        final uppercaseCount = tokens.where((t) => t == t.toUpperCase()).length;
        if (uppercaseCount >= max(2, tokens.length ~/ 2)) return false;
      }
      
      return true;
    }).map((line) => line.trim());

    text = lines.join(' ');

    // Step 9: Remove duplicate words
    text = text.replaceAllMapped(
      RegExp(r'\b([A-Za-z]{3,})\s+\1\b', caseSensitive: false),
      (match) => match.group(1)!,
    );

    // Step 10: Collapse whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return text;
  }

  // ENHANCED: Extract keywords with better scoring
  static List<String> extractKeywords(String text, {int topK = 15, int minWordLen = 5}) {
    final textLower = text.toLowerCase();
    final stopwords = {
      'the', 'and', 'for', 'with', 'from', 'this', 'that', 'which', 'are', 
      'was', 'were', 'have', 'has', 'had', 'their', 'there', 'they', 'these',
      'those', 'been', 'also', 'such', 'but', 'not', 'can', 'will', 'may',
      'you', 'your', 'into', 'about', 'between', 'during', 'each', 'per'
    };

    final words = RegExp(r'\b[a-z]{' + minWordLen.toString() + r',}\b')
        .allMatches(textLower)
        .map((m) => m.group(0)!)
        .where((w) => !stopwords.contains(w) && !RegExp(r'^\d+$').hasMatch(w));

    // TF-IDF style scoring
    final freq = <String, int>{};
    final docFreq = <String, Set<int>>{};
    final sentences = text.split(RegExp(r'[.!?]'));
    
    for (int i = 0; i < sentences.length; i++) {
      final sentWords = sentences[i].toLowerCase().split(RegExp(r'\s+'));
      for (final word in sentWords) {
        if (word.length >= minWordLen && !stopwords.contains(word)) {
          freq[word] = (freq[word] ?? 0) + 1;
          docFreq.putIfAbsent(word, () => {}).add(i);
        }
      }
    }

    // Score = freq * log(total_sentences / doc_freq)
    final scored = freq.entries.map((e) {
      final tf = e.value;
      final df = docFreq[e.key]!.length;
      final idf = log(sentences.length / df);
      return MapEntry(e.key, tf * idf);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return scored.take(topK).map((e) => e.key).toList();
  }

  // ENHANCED: Better sentence scoring
  static int scoreSentence(String sentence, List<String> keywords) {
    final cleaned = sentence.replaceAll(RegExp(r'[^A-Za-z0-9\s]'), '').toLowerCase();
    final words = cleaned.split(RegExp(r'\s+'));
    if (words.isEmpty) return 0;

    int score = words.length;

    // Keyword presence (highest weight)
    for (final keyword in keywords) {
      if (cleaned.contains(keyword)) {
        score += 10;
      }
    }

    // Important terms
    final importantTerms = [
      'important', 'conclusion', 'therefore', 'however', 'because', 'result',
      'shows', 'found', 'evidence', 'purpose', 'objective', 'method'
    ];
    for (final term in importantTerms) {
      if (cleaned.contains(term)) score += 5;
    }

    // Has numbers/data
    if (RegExp(r'\d').hasMatch(sentence)) score += 4;

    // Proper nouns
    final caps = RegExp(r'\b[A-Z][a-z]{2,}\b').allMatches(sentence).length;
    score += caps * 2;

    return score;
  }

  // ENHANCED: Generate summary with better algorithm
  static Future<String> generateSummary(
    String text, {
    int targetChars = 2800,
    int targetLines = 20,
  }) async {
    text = cleanText(text);
    if (text.isEmpty) {
      return 'No extractable text found in this PDF.';
    }

    // Extract keywords first
    final keywords = extractKeywords(text, topK: 15);
    if (keywords.isEmpty) {
      return text.substring(0, min(targetChars, text.length));
    }

    print('📊 Top keywords: ${keywords.take(8).join(", ")}');

    // Split into sentences
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.split(RegExp(r'\s+')).length >= 8)
        .toList();

    if (sentences.isEmpty) {
      return text.substring(0, min(targetChars, text.length));
    }

    // Score and rank sentences
    final scoredSentences = sentences.map((s) {
      return MapEntry(scoreSentence(s, keywords), s);
    }).toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    // Select top sentences
    final selectedSents = <String>[];
    final seen = <String>{};
    
    for (final entry in scoredSentences) {
      final sentKey = entry.value.toLowerCase().substring(0, min(50, entry.value.length));
      if (seen.contains(sentKey)) continue;
      
      selectedSents.add(entry.value);
      seen.add(sentKey);
      
      if (selectedSents.length >= targetLines) break;
    }

    // Compose summary
    String summary = selectedSents.join(' ');
    
    // Trim to target length
    if (summary.length > targetChars) {
      summary = summary.substring(0, targetChars);
      final lastPeriod = summary.lastIndexOf('.');
      if (lastPeriod > targetChars * 0.7) {
        summary = summary.substring(0, lastPeriod + 1);
      }
    }

    // Ensure ends with punctuation
    if (!RegExp(r'[.!?]$').hasMatch(summary.trim())) {
      final match = RegExp(r'([.!?])').allMatches(summary).lastOrNull;
      if (match != null) {
        summary = summary.substring(0, match.start + 1);
      }
    }

    return summary.trim();
  }

  // ENHANCED: Generate quiz with better quality
  static Future<List<Map<String, dynamic>>> generateQuiz(
    String summary, {
    int numQuestions = 7,
  }) async {
    if (summary.isEmpty) return [];

    final sentences = summary.split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().split(RegExp(r'\s+')).length >= 8)
        .toList();

    final candidates = _findCandidatePhrases(summary);
    if (candidates.isEmpty) return [];

    print('📝 Found ${candidates.length} candidate phrases for quiz');

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
          continue;
        }
      }

      if (chosen == null) {
        final words = RegExp(r'\b[A-Za-z]{6,}\b').allMatches(sent).map((m) => m.group(0)).whereType<String>().toList();
        if (words.isEmpty) continue;
        chosen = words.reduce((a, b) => a.length > b.length ? a : b);
      }

      if (chosen == null) continue;

      try {
        final question = sent.replaceFirst(RegExp(RegExp.escape(chosen), caseSensitive: false), '_____');

        // Generate better distractors
        final distractors = <String>[];
        final pool = candidates.where((c) => c.toLowerCase() != chosen!.toLowerCase()).toList();
        pool.shuffle();
        
        for (final p in pool.take(3)) {
          distractors.add(p);
        }

        // Fill remaining with mutations
        while (distractors.length < 3) {
          final mutated = _mutateWord(chosen);
          if (mutated.toLowerCase() != chosen.toLowerCase() && !distractors.contains(mutated)) {
            distractors.add(mutated);
          }
        }

        final options = [...distractors.take(3), chosen];
        options.shuffle();

        final labeled = options.asMap().entries.map((e) => {
          'label': String.fromCharCode(65 + e.key),
          'text': e.value,
        }).toList();

        final correctOption = labeled.firstWhere(
          (item) => item['text'] == chosen,
          orElse: () => labeled.last,
        );

        mcqs.add({
          'question': question.trim(),
          'options': labeled,
          'answer_label': correctOption['label'],
          'answer_text': chosen,
        });

        usedAnswers.add(chosen.toLowerCase());
      } catch (e) {
        print('⚠️ Error creating quiz question: $e');
        continue;
      }
    }

    print('✅ Generated ${mcqs.length} quiz questions');
    return mcqs;
  }

  // Helper methods - UNCHANGED
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
      print('⚠️ Error finding candidates: $e');
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
      parts[i] = parts[i].substring(0, parts[i].length - 1) + ['a', 'e', 'i'][random.nextInt(3)];
      return parts.join(' ');
    }
    return word.substring(0, word.length - 1) + ['a', 'e', 'i', 'o'][random.nextInt(4)];
  }
}