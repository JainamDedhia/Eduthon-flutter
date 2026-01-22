// FILE: lib/services/summary_generator.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive_io.dart';
import 'subject_vocabulary.dart';
import 'subject_tracker.dart';
import 'content_structure_service.dart';
import 'text_word_joiner.dart';

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
          print(
            '✅ Decompressed: ${compressedBytes.length} → ${pdfBytes.length} bytes',
          );
        } catch (decompressionError) {
          print(
            '⚠️ Decompression failed, trying as raw PDF: $decompressionError',
          );
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
          String pageText = PdfTextExtractor(
            document,
          ).extractText(startPageIndex: i, endPageIndex: i);

          // Fallback extraction method
          if (pageText.trim().isEmpty) {
            try {
              final PdfTextExtractor extractor = PdfTextExtractor(document);
              final result = extractor.extractText(startPageIndex: i);
              if (result.isNotEmpty) {
                pageText = result;
              }
            } catch (e) {
              print('⚠️ Page ${i + 1}: Text line extraction failed');
            }
          }

          // Add page text if not empty
          if (pageText.trim().isNotEmpty) {
            extractedText += '${pageText.trim()}\n\n';
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
          'Text found: 0 characters',
        );
      }

      print(
        '✅ Successfully extracted ${extractedText.length} characters from $successfulPages/$totalPages pages',
      );
      return extractedText.trim();
    } catch (e) {
      print('❌ PDF extraction error: $e');
      rethrow;
    }
  }

  // Universal "Glue" words for subject-agnostic splitting
  static const _glueWords = {
    'the',
    'and',
    'of',
    'to',
    'in',
    'is',
    'are',
    'was',
    'were',
    'that',
    'with',
    'from',
    'by',
    'on',
    'at',
    'for',
    'as',
    'an',
    'it',
    'its',
    'or',
    'be',
    'this',
    'these',
    'those',
    'which',
    'who',
    'whom',
    'whose',
    'but',
    'not',
    'if',
    'then',
    'else',
    'when',
    'where',
    'how',
    'why',
    'all',
    'any',
    'both',
    'each',
    'few',
    'more',
    'most',
    'other',
    'some',
    'such',
    'no',
    'nor',
    'too',
    'very',
    'can',
    'will',
    'just',
    'should',
    'now',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'get',
    'gets',
    'got',
    'make',
    'makes',
    'made',
    'take',
    'takes',
    'took',
    'see',
    'sees',
    'saw',
    'know',
    'knows',
    'knew',
    'think',
    'thinks',
    'thought',
    'come',
    'comes',
    'came',
    'give',
    'gives',
    'gave',
    'use',
    'uses',
    'used',
    'find',
    'finds',
    'found',
    'tell',
    'tells',
    'told',
    'ask',
    'asks',
    'asked',
    'work',
    'works',
    'worked',
    'seem',
    'seems',
    'seemed',
    'feel',
    'feels',
    'felt',
    'try',
    'tries',
    'tried',
    'leave',
    'leaves',
    'left',
    'call',
    'calls',
    'called',
    'successfully',
    'explained',
    'between',
    'around',
    'following',
    'magnitude',
    'force',
    'motion',
    'object',
    'earth',
    'equation',
    'learnt',
    'needed',
    'change',
    'speed',
    'direction',
    'surface',
    'importance',
    'universal',
    'law',
    'gravitation',
    'phenomena',
    'unconnected',
    'binds',
    'planets',
    'tides',
    'free',
    'fall',
    'meaning',
    'activity',
    'unit',
    'obtained',
    'substituting',
    'address',
    'understand',
    'involved',
    'introduce',
    'concepts',
    'particular',
    'thrust',
    'pressure',
    'acting',
    'concerned',
    'considering',
    'another',
    'together',
    'theory',
    'within',
    'without',
    'through',
    'during',
    'before',
    'after',
    'above',
    'below',
    'under',
    'over',
    'again',
    'further',
    'once',
    'twice',
    'always',
    'never',
    'often',
    'sometimes',
    'usually',
    'generally',
  };

  // Words that should NEVER be split even if they contain glue words
  static const _doNotSplit = {
    'almost',
    'already',
    'also',
    'although',
    'always',
    'among',
    'another',
    'anybody',
    'anyone',
    'anything',
    'anywhere',
    'axis',
    'backward',
    'basis',
    'became',
    'become',
    'becomes',
    'becoming',
    'been',
    'before',
    'behind',
    'being',
    'below',
    'beside',
    'besides',
    'between',
    'beyond',
    'binds',
    'cannot',
    'carbon',
    'could',
    'did',
    'do',
    'does',
    'doing',
    'done',
    'down',
    'downward',
    'during',
    'each',
    'either',
    'electron',
    'enough',
    'equation',
    'even',
    'ever',
    'every',
    'everyone',
    'everything',
    'everywhere',
    'few',
    'for',
    'format',
    'forward',
    'from',
    'further',
    'generally',
    'had',
    'has',
    'have',
    'having',
    'he',
    'her',
    'here',
    'hers',
    'herself',
    'him',
    'himself',
    'his',
    'how',
    'however',
    'i',
    'if',
    'in',
    'into',
    'ion',
    'iron',
    'is',
    'it',
    'its',
    'itself',
    'just',
    'keep',
    'keeps',
    'kept',
    'know',
    'known',
    'knows',
    'last',
    'least',
    'less',
    'let',
    'lets',
    'like',
    'likely',
    'long',
    'look',
    'looking',
    'looks',
    'made',
    'make',
    'makes',
    'making',
    'many',
    'margin',
    'may',
    'me',
    'mean',
    'means',
    'meant',
    'might',
    'more',
    'most',
    'mostly',
    'motion',
    'much',
    'must',
    'my',
    'myself',
    'near',
    'nearly',
    'need',
    'needs',
    'needed',
    'neither',
    'neutron',
    'never',
    'next',
    'no',
    'nobody',
    'none',
    'noone',
    'nor',
    'not',
    'nothing',
    'now',
    'nowhere',
    'of',
    'off',
    'often',
    'on',
    'once',
    'one',
    'only',
    'onto',
    'or',
    'origin',
    'other',
    'others',
    'otherwise',
    'our',
    'ours',
    'ourselves',
    'out',
    'over',
    'own',
    'part',
    'parts',
    'perhaps',
    'photosynthesis',
    'place',
    'places',
    'point',
    'points',
    'position',
    'protein',
    'proton',
    'put',
    'puts',
    'quite',
    'rather',
    'really',
    'right',
    'said',
    'same',
    'saw',
    'say',
    'says',
    'see',
    'seem',
    'seemed',
    'seems',
    'seen',
    'self',
    'selves',
    'sent',
    'several',
    'shall',
    'she',
    'should',
    'show',
    'shows',
    'side',
    'sides',
    'since',
    'small',
    'so',
    'solution',
    'some',
    'somebody',
    'someone',
    'something',
    'somewhere',
    'sometimes',
    'still',
    'stratosphere',
    'such',
    'sure',
    'take',
    'taken',
    'takes',
    'tell',
    'tells',
    'than',
    'that',
    'the',
    'their',
    'theirs',
    'them',
    'themselves',
    'then',
    'there',
    'therefore',
    'these',
    'they',
    'thing',
    'things',
    'think',
    'thinks',
    'this',
    'those',
    'though',
    'thought',
    'three',
    'through',
    'throughout',
    'thus',
    'to',
    'together',
    'too',
    'took',
    'toward',
    'towards',
    'tried',
    'tries',
    'try',
    'trying',
    'turn',
    'turned',
    'turns',
    'two',
    'under',
    'until',
    'up',
    'upon',
    'upward',
    'us',
    'use',
    'used',
    'uses',
    'using',
    'usually',
    'very',
    'vitamin',
    'was',
    'way',
    'ways',
    'we',
    'well',
    'went',
    'were',
    'what',
    'whatever',
    'when',
    'whenever',
    'where',
    'wherever',
    'whether',
    'which',
    'while',
    'who',
    'whole',
    'whom',
    'whose',
    'why',
    'will',
    'with',
    'within',
    'without',
    'work',
    'worked',
    'works',
    'would',
    'yet',
    'you',
    'your',
    'yours',
    'yourself',
    'yourselves',
    'formed',
    'preparation',
    'production',
    'irrigation',
    'digestion',
    'respiration',
    'excretion',
    'substances',
    'converted',
    'different',
    'magnesium',
    'oxygen',
    'combination',
    'represented',
    'catalysts',
    'consumed',
    'accompany',
    'reactions',
    'bonds',
    'gravitation',
    'phenomena',
    'importance',
    'universal',
    'successfully',
    'explained',
    'involve',
    'forming',
    'breaking',
    'undergo',
    'process',
    'reaction',
    'ribbon',
    'heated',
    'oxide',
    'energy',
    'changes',
    'chemical',
    'beautiful',
  };

  // Clean text with aggressive artifact removal
  static String cleanText(String text) {
    if (text.isEmpty) return '';

    // Phase 1: Basic normalization
    text = text.replaceAll('\r\n', '\n');
    text = text.replaceAll('\u00A0', ' ');
    text = text.replaceAll('\t', ' ');

    // Phase 1.5: De-spacing logic for headers (e.g., "E X E R C I S E S" -> "EXERCISES")
    // This catches spaced-out uppercase headers common in PDF extractions
    text = text.replaceAllMapped(
      RegExp(r'\b([A-Z])\s+([A-Z])(\s+[A-Z])+\b'),
      (m) => m.group(0)!.replaceAll(' ', ''),
    );

    // Phase 2: REMOVE EXERCISE SECTIONS FIRST (before any word manipulation!)
    // This MUST happen before word splitting to catch "EXERCISES" before it becomes "E X E R C I S E S"

    // Markers that indicate the start of a large exercise/structural section
    final sectionMarkers = [
      'EXERCISES',
      'QUESTIONS',
      'PRACTICE',
      'TEST YOURSELF',
      'Extended Learning',
      'Activities and Projects',
    ];

    for (final marker in sectionMarkers) {
      // Remove from marker (at start of line) to next major section or end
      text = text.replaceAll(
        RegExp(
          r'(?<=^|\n)\s*' +
              RegExp.escape(marker) +
              r'.*?(?=(CHAPTER|Chapter|\d+\.\d+\s+[A-Z]|$))',
          caseSensitive: false,
          multiLine: true,
          dotAll: true,
        ),
        '',
      );
    }

    // Remove fill-in-the-blank question blocks
    text = text.replaceAll(
      RegExp(
        r'(Select the correct word|fill in the blank|Complete the following).*?(?=\n\n[A-Z]|$)',
        caseSensitive: false,
        multiLine: true,
        dotAll: true,
      ),
      '',
    );

    // Remove numbered question lists (e.g., "1. Why should...", "2. Write the...")
    text = text.replaceAll(
      RegExp(r'(\n\d+\.\s+[^\n]*\?[^\n]*)+', multiLine: true),
      '',
    );

    // Phase 3: Aggressive artifact removal
    // Remove repeated patterns (e.g., "CHEMIC1.2 CHEMIC1.2 CHEMIC1.2")
    text = text.replaceAllMapped(
      RegExp(r'\b(\S+)\s+\1(\s+\1)+', caseSensitive: false),
      (m) => m.group(1)!,
    );

    // Remove specific garbage strings from screenshots
    text = text.replaceAll(
      RegExp(r'\bCHEMIC\d*(\.\d+)?\b', caseSensitive: false),
      '',
    );
    // Only remove CHEMICAL if it's all caps (likely an artifact)
    text = text.replaceAll(RegExp(r'\bCHEMICAL\b'), '');
    text = text.replaceAll(RegExp(r'REAAL+', caseSensitive: false), 'REAL');
    text = text.replaceAll(RegExp(r'EQUA+L+', caseSensitive: false), '=');
    text = text.replaceAll(RegExp(r'EQUATION', caseSensitive: false), '');

    // Fix ".n" artifact (e.g. "tubes.n Is" -> "tubes. Is")
    // This is a common PDF extraction artifact where newlines are misinterpreted
    text = text.replaceAllMapped(
      RegExp(r'([.!?])n\s+([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'([.!?])n([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    // Remove digit sequences (99999, etc.)
    // Removed word boundaries to catch merged sequences like "88888Figure"
    text = text.replaceAll(RegExp(r'\d{5,}'), '');

    // Remove repeated suffix patterns more aggressively
    text = text.replaceAll(
      RegExp(r'(CTION|STION){2,}S?', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'(CTIONS+){2,}', caseSensitive: false), '');

    // Phase 4: Chemical placeholder replacement
    text = text.replaceAll(
      RegExp(r'arrow\s*right', caseSensitive: false),
      ' → ',
    );
    text = text.replaceAll(
      RegExp(r'arrow\s*horiz\w*', caseSensitive: false),
      ' → ',
    );
    text = text.replaceAll(RegExp(r'arrowright', caseSensitive: false), ' → ');
    text = text.replaceAll(RegExp(r'arrowhoriz', caseSensitive: false), ' → ');

    // Phase 5: Fix specific merged words (from screenshots)
    final mergedWordFixes = {
      'nitratesolution': 'nitrate solution',
      'testtube': 'test tube',
      'testtubes': 'test tubes',
      'inoxygen': 'in oxygen',
      'formedbetween': 'formed between',
      'decompositionreaction': 'decomposition reaction',
      'singleproduct': 'single product',
      'productsiron': 'products iron',
      'solutionto': 'solution to',
      'closeto': 'close to',
      'Oxygenarrow': 'Oxygen →',
      'Heatarrow': 'Heat →',
      'removethem': 'remove them',
      'thetest': 'the test',
      'thetube': 'the tube',
      'themouth': 'the mouth',
      'dropsof': 'drops of',
    };

    for (final entry in mergedWordFixes.entries) {
      text = text.replaceAll(
        RegExp(entry.key, caseSensitive: false),
        entry.value,
      );
    }

    // Phase 6: Fix split words (e.g., "In dia" -> "India", "call ed" -> "called")
    // Using dynamic word joiner that works on any PDF
    text = TextWordJoiner.fixSplitWords(text);

    // Phase 7: Fix remaining merged words (generic patterns)
    // Re-enabled with strict safety checks
    text = _fixMergedWords(text);

    // Phase 8: Fix spacing after punctuation
    text = text.replaceAllMapped(
      RegExp(r'\.([A-Z])'),
      (m) => '. ${m.group(1)}',
    );
    text = text.replaceAllMapped(RegExp(r',([A-Z])'), (m) => ', ${m.group(1)}');
    text = text.replaceAllMapped(
      RegExp(r'\?([A-Z])'),
      (m) => '? ${m.group(1)}',
    );
    text = text.replaceAllMapped(RegExp(r'!([A-Z])'), (m) => '! ${m.group(1)}');

    // Phase 9: Line-by-line classification and filtering
    final lines = text.split('\n');
    final contentLines = <String>[];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Score line as content vs structural/junk
      if (_isContentLine(line)) {
        contentLines.add(line);
      }
    }

    // Phase 9: Reconstruct paragraphs (preserve chunking logic)
    final sb = StringBuffer();
    for (int i = 0; i < contentLines.length; i++) {
      final line = contentLines[i];
      sb.write(line);

      // If line ends with sentence punctuation, add paragraph break
      if (RegExp(r'[.!?]$').hasMatch(line)) {
        sb.write('\n\n');
      } else {
        // Otherwise join with space (wrapped line)
        sb.write(' ');
      }
    }

    text = sb.toString();

    // Phase 10: Final cleanup
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n'); // Max 2 newlines
    text = text.replaceAll(RegExp(r' +'), ' '); // Collapse spaces
    text = text.replaceAll(RegExp(r' →  → '), ' → '); // Fix doubled arrows

    return text.trim();
  }

  // Fix split words like "equa TION" -> "equation"
  static String _fixSplitWords(String text) {
    // Pattern: lowercase word + space + UPPERCASE word
    // Common in PDF artifacts where words are split across formatting
    final splitWordPatterns = [
      // Common suffixes that get split
      RegExp(r'\b(equa)\s+(TION)\b', caseSensitive: false),
      RegExp(r'\b(reac)\s+(TION)\b', caseSensitive: false),
      RegExp(r'\b(situa)\s+(TION)\b', caseSensitive: false),
      RegExp(r'\b(forma)\s+(TION)\b', caseSensitive: false),
      RegExp(r'\b(observa)\s+(TION)\b', caseSensitive: false),
      RegExp(r'\b(representa)\s+(TION)\b', caseSensitive: false),
      RegExp(r'\b(evolu)\s+(TION)\b', caseSensitive: false),
      RegExp(r'\b(solu)\s+(TION)\b', caseSensitive: false),
      RegExp(r'\b(preparati)\s+(on)\b', caseSensitive: false),
      RegExp(r'\b(irrigati)\s+(on)\b', caseSensitive: false),
      RegExp(r'\b(producti)\s+(on)\b', caseSensitive: false),
      RegExp(r'\b(digesti)\s+(on)\b', caseSensitive: false),
      RegExp(r'\b(respirati)\s+(on)\b', caseSensitive: false),
      RegExp(r'\b(excreti)\s+(on)\b', caseSensitive: false),
      RegExp(r'\b(protecti)\s+(on)\b', caseSensitive: false),
      RegExp(r'\b(selec)\s+(tion)\b', caseSensitive: false),
      RegExp(r'\b(combina)\s+(tion)\b', caseSensitive: false),
      RegExp(r'\b(decomposi)\s+(tion)\b', caseSensitive: false),
    ];

    for (final pattern in splitWordPatterns) {
      text = text.replaceAllMapped(pattern, (m) {
        return '${m.group(1)!.toLowerCase()}${m.group(2)!.toLowerCase()}';
      });
    }

    // Generic pattern: word ending in lowercase + UPPERCASE continuation
    // Only merge if result looks like a valid word
    text = text.replaceAllMapped(RegExp(r'\b([a-z]{3,})\s+([A-Z]{3,})\b'), (m) {
      final part1 = m.group(1)!.toLowerCase();
      final part2 = m.group(2)!.toLowerCase();
      // Common word endings that indicate split
      if (part2 == 'tion' ||
          part2 == 'sion' ||
          part2 == 'ment' ||
          part2 == 'ness' ||
          part2 == 'able' ||
          part2 == 'ible') {
        return '$part1$part2';
      }
      return m.group(0)!; // Keep as-is if not confident
    });

    return text;
  }

  // Fix merged words like "followingchemical" -> "following chemical"
  static String _fixMergedWords(String text) {
    // 1. Structural Splitting (Subject-Agnostic)

    // Case Transitions: UPPERCASETitleCase (e.g., "GRAVITATIONThe" -> "GRAVITATION The")
    text = text.replaceAllMapped(RegExp(r'([A-Z]{2,})([A-Z][a-z]+)'), (m) {
      return '${m.group(1)} ${m.group(2)}';
    });

    // Case Transitions: lowercaseTitleCase (e.g., "earthThe" -> "earth The")
    text = text.replaceAllMapped(RegExp(r'([a-z]{2,})([A-Z][a-z]+)'), (m) {
      return '${m.group(1)} ${m.group(2)}';
    });

    // Case Transitions: lowercaseUppercase (e.g., "followingChemical" -> "following Chemical")
    text = text.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) {
      // Don't split if preceded by a digit (chemical formula)
      final before = m.start > 0 ? text[m.start - 1] : '';
      if (RegExp(r'\d').hasMatch(before)) {
        return m.group(0)!;
      }
      return '${m.group(1)} ${m.group(2)}';
    });

    // Number Boundaries: NumberLetter (e.g., "9.1.2IMPORTANCE" -> "9.1.2 IMPORTANCE")
    text = text.replaceAllMapped(RegExp(r'(\d+\.?\d*\.?\d*)([A-Z][A-Za-z]+)'), (
      m,
    ) {
      return '${m.group(1)} ${m.group(2)}';
    });

    // Number Boundaries: Letter.Number (e.g., "Eq.10.1" -> "Eq. 10.1")
    text = text.replaceAllMapped(RegExp(r'([A-Za-z]+)\.(\d+)'), (m) {
      return '${m.group(1)}. ${m.group(2)}';
    });

    // List Markers: (i)Text -> (i) Text
    text = text.replaceAllMapped(RegExp(r'(\([ivx]+\))([A-Za-z])'), (m) {
      return '${m.group(1)} ${m.group(2)}';
    });

    // 2. Heuristic Splitting using Glue Words (STRICTER)
    final words = text.split(' ');
    final resultWords = <String>[];

    for (var word in words) {
      // Clean word of punctuation for lookup
      final cleanWord = word.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();

      if (cleanWord.length < 4 || _doNotSplit.contains(cleanWord)) {
        resultWords.add(word);
        continue;
      }

      bool splitFound = false;
      final lowerWord = word.toLowerCase();

      // Check for glue words at the beginning
      for (final glue in _glueWords) {
        if (lowerWord.startsWith(glue) && lowerWord.length >= glue.length + 3) {
          final part1 = word.substring(0, glue.length);
          final part2 = word.substring(glue.length);
          final part2Lower = part2.toLowerCase();

          // Only split if part2 is a valid word or another glue word
          if ((_glueWords.contains(part2Lower) ||
                  part2.length >= 4 ||
                  _doNotSplit.contains(part2Lower)) &&
              !_doNotSplit.contains(lowerWord)) {
            resultWords.add(part1);
            resultWords.add(part2);
            splitFound = true;
            break;
          }
        }
      }

      if (!splitFound) {
        // Check for glue words at the end
        for (final glue in _glueWords) {
          if (lowerWord.endsWith(glue) && lowerWord.length >= glue.length + 3) {
            final splitIdx = word.length - glue.length;
            final part1 = word.substring(0, splitIdx);
            final part2 = word.substring(splitIdx);
            final part1Lower = part1.toLowerCase();

            if ((_glueWords.contains(part1Lower) ||
                    part1.length >= 4 ||
                    _doNotSplit.contains(part1Lower)) &&
                !_doNotSplit.contains(lowerWord)) {
              resultWords.add(part1);
              resultWords.add(part2);
              splitFound = true;
              break;
            }
          }
        }
      }

      if (!splitFound) {
        resultWords.add(word);
      }
    }

    return resultWords.join(' ');
  }

  // Classify line as content vs structural/junk
  static bool _isContentLine(String line) {
    // Remove if too short
    if (line.length < 15) return false;

    // Remove structural elements
    // Page numbers
    if (RegExp(r'^(Page\s*)?\d+\s*$', caseSensitive: false).hasMatch(line)) {
      return false;
    }

    // Reprint years
    if (RegExp(r'Reprint\s+\d{4}', caseSensitive: false).hasMatch(line)) {
      return false;
    }

    // Exercise/Activity headers - ENHANCED
    if (RegExp(
      r'^(Activity|Exercise|Experiment|Question|Problem|Example|Solution|Fig\.|Figure|Table)\s*\d+',
      caseSensitive: false,
    ).hasMatch(line)) {
      return false;
    }

    // EXERCISES section marker (appears in user screenshot)
    if (RegExp(r'\bEXERCISES\b', caseSensitive: false).hasMatch(line)) {
      return false;
    }

    // Extended Learning / Activities and Projects
    if (RegExp(
      r'Extended Learning|Activities and Projects',
      caseSensitive: false,
    ).hasMatch(line)) {
      return false;
    }

    // Fill-in-the-blank questions (e.g., "Select the correct word from the following list and fill in the blanks")
    if (RegExp(
      r'(fill in the blank|select the correct word|complete the following|choose the correct)',
      caseSensitive: false,
    ).hasMatch(line)) {
      return false;
    }

    // Lines with multiple underscores (fill-in-the-blank placeholders)
    // More aggressive: even 2 underscores or any line that is mostly underscores
    if (RegExp(r'_{2,}').hasMatch(line)) {
      return false;
    }

    // Quiz options (e.g., "A. force", "B. fluence", or just "A", "B" on a line)
    // Only filter if it's a short line (likely an actual option)
    if (RegExp(r'^[A-D](\.|\s|$)').hasMatch(line) && line.length < 40) {
      return false;
    }

    // Chapter markers
    if (RegExp(
      r'^\d+\s+(CHAPTER|Chapter)',
      caseSensitive: false,
    ).hasMatch(line)) {
      return false;
    }
    if (RegExp(
      r'^(CHAPTER|Chapter)\s+\d+',
      caseSensitive: false,
    ).hasMatch(line)) {
      return false;
    }

    // High digit ratio (likely page numbers or codes)
    final digitCount =
        line.split('').where((c) => RegExp(r'\d').hasMatch(c)).length;
    if (digitCount > line.length * 0.3) return false;

    // High uppercase ratio (likely headers or garbage)
    final upperCount =
        line
            .split('')
            .where((c) => c == c.toUpperCase() && c != c.toLowerCase())
            .length;
    if (upperCount > line.length * 0.6 && line.length < 50) return false;

    // Remove lines that are just references
    if (RegExp(
      r'^(See|Refer to|As shown in)',
      caseSensitive: false,
    ).hasMatch(line)) {
      return false;
    }

    // Keep everything else (inverted logic - permissive by default)
    return true;
  }

  // Extract top keywords
  static List<String> extractKeywords(
    String text, {
    int topK = 12,
    int minWordLen = 5,
  }) {
    final textLower = text.toLowerCase();
    final stopwords = {
      'the',
      'and',
      'for',
      'with',
      'from',
      'this',
      'that',
      'which',
      'are',
      'was',
      'were',
      'have',
      'has',
      'had',
      'their',
      'there',
      'they',
      'these',
      'those',
      'been',
      'also',
      'such',
      'but',
      'not',
      'can',
      'will',
      'may',
      'you',
      'your',
      'into',
      'about',
      'between',
      'during',
      'each',
      'per',
      'include',
      'including',
      'other',
      'use',
      'uses',
      'used',
      'using',
      'some',
      'many',
      'most',
      'more',
      'much',
      'one',
      'two',
      'three',
      'four',
      'five',
    };

    final words = RegExp(r'\b[a-z]{' + minWordLen.toString() + r',}\b')
        .allMatches(textLower)
        .map((m) => m.group(0)!)
        .where((w) => !stopwords.contains(w) && !RegExp(r'^\d+$').hasMatch(w));

    final freq = <String, int>{};
    for (final word in words) {
      freq[word] = (freq[word] ?? 0) + 1;
    }

    final sorted =
        freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(topK).map((e) => e.key).toList();
  }

  // Detect Subject (Weighted & Context-Aware)
  static String detectSubject(String text) {
    // For small texts, fallback to simple detection
    if (text.length < 500) {
      return _simpleDetectSubject(text);
    }

    final tracker = SubjectTracker();

    // Chunk the text with overlap to preserve context
    final chunks = _chunkTextWithOverlap(text, 1000, 200);

    for (final chunk in chunks) {
      tracker.processChunk(chunk);
    }

    final dominant = tracker.getDominantSubject();
    print('📚 Subject Analysis: $dominant (Scores: ${tracker.getScores()})');

    return dominant;
  }

  // Simple detection fallback
  static String _simpleDetectSubject(String text) {
    final textLower = text.toLowerCase();
    String bestSubject = 'General';
    int maxScore = 0;

    for (final entry in SubjectVocabulary.vocabulary.entries) {
      int score = 0;
      for (final term in entry.value.entries) {
        // Simple count * weight
        final count =
            RegExp(
              r'\b' + RegExp.escape(term.key) + r'\b',
            ).allMatches(textLower).length;
        score += count * term.value;
      }

      if (score > maxScore) {
        maxScore = score;
        bestSubject = entry.key;
      }
    }
    return bestSubject;
  }

  // Helper: Chunk text with overlap
  static List<String> _chunkTextWithOverlap(
    String text,
    int chunkSize,
    int overlap,
  ) {
    final List<String> chunks = [];
    int start = 0;

    while (start < text.length) {
      int end = start + chunkSize;
      if (end > text.length) {
        end = text.length;
      }

      // Try to break at a sentence boundary near the end
      if (end < text.length) {
        final lastPeriod = text.lastIndexOf('.', end);
        if (lastPeriod > start + (chunkSize * 0.5)) {
          end = lastPeriod + 1;
        }
      }

      chunks.add(text.substring(start, end));

      // Move forward by chunkSize - overlap
      start += (chunkSize - overlap);

      // Ensure we don't get stuck
      if (start >= end) start = end;
    }

    return chunks;
  }

  // Estimate Grade Level (Flesch-Kincaid)
  static double estimateGradeLevel(String text) {
    if (text.isEmpty) return 1.0;

    final sentences = text.split(RegExp(r'[.!?]\s+')).length;
    final words = text.split(RegExp(r'\s+')).length;
    final syllables = _countSyllablesInText(text);

    if (sentences == 0 || words == 0) return 1.0;

    // Flesch-Kincaid Grade Level Formula
    final grade =
        0.39 * (words / sentences) + 11.8 * (syllables / words) - 15.59;

    // Clamp between 1 and 12
    return grade.clamp(1.0, 12.0);
  }

  static int _countSyllablesInText(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    int count = 0;
    for (final word in words) {
      count += _countSyllables(word);
    }
    return count;
  }

  static int _countSyllables(String word) {
    word = word.replaceAll(RegExp(r'[^a-z]'), '');
    if (word.isEmpty) return 0;
    if (word.length <= 3) return 1;

    word = word.replaceAll(RegExp(r'e$'), ''); // silent e
    final vowelGroups = RegExp(r'[aeiouy]+').allMatches(word);
    return max(1, vowelGroups.length);
  }

  // Score sentence
  static int scoreSentence(String sentence, {String? subject}) {
    final cleaned =
        sentence.replaceAll(RegExp(r'[^A-Za-z0-9\s]'), '').toLowerCase();
    final words = cleaned.split(RegExp(r'\s+'));
    if (words.isEmpty) return 0;

    int score = words.length;

    // Penalize very short sentences
    if (words.length < 10) score -= 5;

    // Boost definitions
    if (cleaned.contains(' is a ') ||
        cleaned.contains(' refers to ') ||
        cleaned.contains(' defined as ')) {
      score += 10;
    }

    // Dynamic subject-based scoring
    if (subject != null && subject != 'General') {
      final vocab = SubjectVocabulary.vocabulary[subject];
      if (vocab != null) {
        for (final word in words) {
          if (vocab.containsKey(word)) {
            score += vocab[word]! * 2;
          }
        }
      }
    }

    // Fallback/General keywords
    final generalKeywords = [
      'important',
      'conclusion',
      'therefore',
      'however',
      'because',
      'result',
      'results',
      'study',
      'shows',
      'found',
      'evidence',
      'purpose',
      'objective',
      'method',
      'analysis',
      'significant',
      'key',
      'main',
    ];

    for (final keyword in generalKeywords) {
      if (cleaned.contains(keyword)) {
        score += 5;
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
    double? gradeLevel, // 1-10
    String? subject,
  }) async {
    // Extract activities BEFORE cleaning
    final activities = ContentStructureService.extractGroupActivities(text);

    // Detect subject if not provided
    final detectedSubject = subject ?? detectSubject(text);

    text = cleanText(text);
    if (text.isEmpty) {
      return 'No extractable text found in this PDF.';
    }

    // Adjust complexity based on grade level
    final minSentenceLength = (gradeLevel != null && gradeLevel < 5) ? 5 : 8;

    // Split into paragraphs
    final paras =
        text
            .split(RegExp(r'\n{2,}'))
            .map((p) => p.trim())
            .where((p) => p.split(RegExp(r'\s+')).length >= minSentenceLength)
            .toList();

    if (paras.isEmpty) {
      final sents =
          text
              .split(RegExp(r'(?<=[.!?])\s+'))
              .where((s) => s.split(RegExp(r'\s+')).length >= minSentenceLength)
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
          final count =
              RegExp(r'\b' + escapedKw + r'\b').allMatches(paraLower).length;
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
        final sents =
            para
                .split(RegExp(r'(?<=[.!?])\s+'))
                .where(
                  (s) => s.split(RegExp(r'\s+')).length >= minSentenceLength,
                )
                .toList();

        if (sents.isEmpty) continue;

        // Score sentences
        final scored =
            sents.map((s) {
                int score = scoreSentence(s, subject: detectedSubject);

                // Grade-level adjustments
                final wordCount = s.split(' ').length;
                if (gradeLevel != null) {
                  if (gradeLevel < 5) {
                    // Prefer shorter sentences for lower grades
                    if (wordCount > 25) score -= 5;
                    if (wordCount < 15) score += 3;
                  } else if (gradeLevel > 8) {
                    // Prefer richer sentences for higher grades
                    if (wordCount > 20) score += 2;
                  }
                }
                return MapEntry(score, s);
              }).toList()
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
      final matches = RegExp(r'([.!?])').allMatches(summary);
      if (matches.isNotEmpty) {
        final idx = matches.last.start;
        summary = summary.substring(0, idx + 1);
      }
    }

    final lines = summary
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((ln) => ln.split(RegExp(r'\s+')).length >= 4)
        .take(targetLines);

    final finalSummary = lines.join('\n').trim();

    // Structure content
    final subjectToUse = subject ?? detectSubject(text);
    final structured = ContentStructureService.structureContent(
      finalSummary,
      subjectToUse,
      activities: activities,
    );

    return jsonEncode(structured);
  }

  // Generate MCQ quiz (Concept-based)
  static Future<List<Map<String, dynamic>>> generateQuiz(
    String summary, {
    int numQuestions = 10,
    double? gradeLevel,
    String? subject,
  }) async {
    if (summary.isEmpty) return [];

    String textContent = summary;
    try {
      if (summary.trim().startsWith('{')) {
        final Map<String, dynamic> data = jsonDecode(summary);
        if (data.containsKey('sections')) {
          final sections = data['sections'] as List;
          textContent = sections.map((s) => s['content'] as String).join(' ');
        }
      }
    } catch (e) {
      // Not JSON, use raw text
    }

    // Split into sentences
    final sentences =
        textContent
            .split(RegExp(r'(?<=[.!?])\s+'))
            .where((s) => s.trim().split(RegExp(r'\s+')).length >= 6)
            .toList();

    // Find candidate answers (concepts)
    final candidates = _findCandidatePhrases(textContent, subject: subject);
    if (candidates.length < 4)
      return []; // Need at least 1 answer + 3 distractors

    final mcqs = <Map<String, dynamic>>[];
    final usedAnswers = <String>{};

    int attempts = 0;
    // Shuffle sentences to get random questions
    sentences.shuffle();

    for (final sent in sentences) {
      if (mcqs.length >= numQuestions) break;
      if (attempts > sentences.length * 2) break;
      attempts++;

      // Find a candidate present in this sentence
      String? chosenAnswer;
      for (final cand in candidates) {
        // Ensure exact word match to avoid partial replacements
        if (RegExp(
          r'\b' + RegExp.escape(cand) + r'\b',
          caseSensitive: false,
        ).hasMatch(sent)) {
          if (!usedAnswers.contains(cand.toLowerCase())) {
            chosenAnswer = cand;
            break;
          }
        }
      }

      if (chosenAnswer == null) continue;

      // Create Question
      String questionText;
      final lowerSent = sent.toLowerCase();

      // Template 1: Definition style
      if (lowerSent.contains(' is ') ||
          lowerSent.contains(' refers to ') ||
          lowerSent.contains(' defined as ')) {
        questionText = sent.replaceAll(
          RegExp(
            r'\b' + RegExp.escape(chosenAnswer) + r'\b',
            caseSensitive: false,
          ),
          '_______',
        );
        if (!questionText.contains('_______')) continue; // Safety check
        questionText = 'Which term fits this definition: "$questionText"?';
      }
      // Template 2: Context style
      else {
        questionText = sent.replaceAll(
          RegExp(
            r'\b' + RegExp.escape(chosenAnswer) + r'\b',
            caseSensitive: false,
          ),
          '_______',
        );
        if (!questionText.contains('_______')) continue;
        questionText = 'Complete the statement: "$questionText"';
      }

      // Get Distractors (Real words from text, not mutations)
      final distractors = _getDistractors(chosenAnswer, candidates, 3);
      if (distractors.length < 3) continue;

      final options = [...distractors, chosenAnswer];
      options.shuffle();

      final labeled =
          options
              .asMap()
              .entries
              .map(
                (e) => {
                  'label': String.fromCharCode(65 + e.key),
                  'text': e.value,
                },
              )
              .toList();

      final correctOption = labeled.firstWhere(
        (item) => item['text'] == chosenAnswer,
      );

      mcqs.add({
        'question': questionText,
        'options': labeled,
        'answer_label': correctOption['label'],
        'answer_text': chosenAnswer,
        'explanation': 'The correct answer is "$chosenAnswer".',
      });

      usedAnswers.add(chosenAnswer.toLowerCase());
    }

    return mcqs;
  }

  // Find potential answers (Named entities, subject terms, long words)
  static List<String> _findCandidatePhrases(
    String text, {
    String? subject,
    int minWordLen = 5,
  }) {
    try {
      final Set<String> candidates = {};

      // 1. Subject-specific vocabulary
      if (subject != null &&
          SubjectVocabulary.vocabulary.containsKey(subject)) {
        final vocab = SubjectVocabulary.vocabulary[subject]!;
        for (final term in vocab.keys) {
          if (text.toLowerCase().contains(term.toLowerCase())) {
            // Find the actual casing used in text if possible
            final match = RegExp(
              r'\b' + RegExp.escape(term) + r'\b',
              caseSensitive: false,
            ).firstMatch(text);
            if (match != null) {
              candidates.add(match.group(0)!);
            }
          }
        }
      }

      // 2. Capitalized Phrases (Proper Nouns / Titles)
      final named = RegExp(r'\b([A-Z][a-z]{2,}(?:\s+[A-Z][a-z]{2,}){0,2})\b')
          .allMatches(text)
          .map((m) => m.group(1)!)
          .where((n) => n.length >= minWordLen && n.split(' ').length <= 3);
      candidates.addAll(named);

      // 3. Long technical words
      final words = RegExp(r'\b[A-Za-z]{' + minWordLen.toString() + r',}\b')
          .allMatches(text)
          .map((m) => m.group(0)!)
          .where((w) => !candidates.contains(w)); // Avoid duplicates
      candidates.addAll(words);

      final stops = {
        'therefore',
        'however',
        'because',
        'throughout',
        'between',
        'including',
        'following',
        'according',
        'example',
        'another',
        'important',
        'significant',
      };

      return candidates.where((c) => !stops.contains(c.toLowerCase())).toList();
    } catch (e) {
      print('⚠️ Error finding candidate phrases: $e');
      return [];
    }
  }

  // Get random distractors from the candidate list
  static List<String> _getDistractors(
    String correct,
    List<String> allCandidates,
    int count,
  ) {
    final pool =
        allCandidates
            .where((c) => c.toLowerCase() != correct.toLowerCase())
            .toList();
    if (pool.length < count) return pool;

    pool.shuffle();
    return pool.take(count).toList();
  }

  // Generate printable HTML format
  static String generatePrintableFormat({
    required String title,
    required String summary,
    required List<Map<String, dynamic>> quiz,
    String? subject,
    double? gradeLevel,
  }) {
    final sb = StringBuffer();
    sb.writeln('''
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 20px; }
          h1 { color: #2c3e50; text-align: center; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
          .meta { color: #7f8c8d; font-style: italic; text-align: center; margin-bottom: 20px; }
          .summary-box { background: #f9f9f9; padding: 20px; border-left: 5px solid #2ecc71; margin-bottom: 30px; }
          .quiz-section { margin-top: 30px; }
          .question { margin-bottom: 15px; font-weight: bold; }
          .options { margin-left: 20px; }
          .option { margin-bottom: 5px; }
          .answer-key { margin-top: 50px; border-top: 1px dashed #ccc; padding-top: 20px; page-break-before: always; }
          
          /* Structured Content Styles */
          .educational-content { }
          .subject-header { display: none; }
          .objectives-box { background: #e3f2fd; padding: 15px; border-radius: 8px; margin-bottom: 20px; border: 1px solid #bbdefb; }
          .visual-aids-box { background: #f3e5f5; padding: 15px; border-radius: 8px; margin-top: 20px; border: 1px solid #e1bee7; }
          .activities-box { background: #fff3e0; padding: 15px; border-radius: 8px; margin-top: 20px; border: 1px solid #ffe0b2; }
          .activity-item { margin-bottom: 10px; border-bottom: 1px solid #ffe0b2; padding-bottom: 10px; }
          .activity-item:last-child { border-bottom: none; }
          h2 { color: #2980b9; border-bottom: 1px solid #eee; padding-bottom: 5px; margin-top: 20px; }
          h3 { color: #34495e; margin-top: 0; font-size: 1.1em; }
          ul { margin-top: 5px; padding-left: 20px; }
          li { margin-bottom: 5px; }
        </style>
      </head>
      <body>
        <h1>$title</h1>
        <div class="meta">
          ${subject != null ? 'Subject: $subject • ' : ''}
          ${gradeLevel != null ? 'Grade Level: ${gradeLevel.round()}' : ''}
        </div>
        
        <h2>Summary</h2>
        <div class="summary-box">
          ${_formatSummaryContent(summary)}
        </div>
        
        <div class="quiz-section">
          <h2>Quiz</h2>
    ''');

    for (int i = 0; i < quiz.length; i++) {
      final q = quiz[i];
      sb.writeln('<div class="question">${i + 1}. ${q['question']}</div>');
      sb.writeln('<div class="options">');
      for (final opt in q['options']) {
        sb.writeln('<div class="option">${opt['label']}) ${opt['text']}</div>');
      }
      sb.writeln('</div>');
    }

    sb.writeln('''
        </div>
        
        <div class="answer-key">
          <h3>Answer Key</h3>
          <ol>
    ''');

    for (final q in quiz) {
      sb.writeln('<li>${q['answer_label']} (${q['answer_text']})</li>');
    }

    sb.writeln('''
          </ol>
        </div>
      </body>
      </html>
    ''');

    return sb.toString();
  }

  static String _formatSummaryContent(String summary) {
    try {
      if (summary.trim().startsWith('{')) {
        final Map<String, dynamic> data = jsonDecode(summary);
        if (data.containsKey('sections')) {
          return ContentStructureService.formatAsHtml(data);
        }
      }
    } catch (e) {
      // ignore
    }
    return summary.replaceAll('\n', '<br>');
  }
}
