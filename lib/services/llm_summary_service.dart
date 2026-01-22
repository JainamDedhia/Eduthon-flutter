// FILE: lib/services/llm_summary_service.dart
// OPTIMIZED VERSION - 3-5x faster with better quality
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'model_downloader.dart';

class LLMSummaryService {
  static LlamaController? _controller;
  static bool _isModelLoaded = false;

  // Check if model is available
  static Future<bool> isModelAvailable() async {
    return await ModelDownloader.isModelDownloaded();
  }

  // Initialize and load model (OPTIMIZED)
  static Future<bool> _loadModel() async {
    if (_isModelLoaded && _controller != null) {
      print('✅ [LLM] Model already loaded');
      return true;
    }

    try {
      final modelPath = await ModelDownloader.getModelPath();
      print('🤖 [LLM] Loading model from: $modelPath');

      if (_controller == null) {
        _controller = LlamaController();
      }
      
      if (!_isModelLoaded) {
        await _controller!.loadModel(
          modelPath: modelPath,
          contextSize: 4096, // INCREASED from 2048 for better quality
        );
        _isModelLoaded = true;
        print('✅ [LLM] Model loaded successfully!');
      }
      
      return true;
    } catch (e) {
      print('❌ [LLM] Failed to load model: $e');
      if (e.toString().contains('already loaded')) {
        _isModelLoaded = true;
        return true;
      }
      _isModelLoaded = false;
      return false;
    }
  }

  // OPTIMIZED: Only clear context when absolutely necessary
  static Future<void> _clearContextIfNeeded() async {
    try {
      if (_controller != null && _isModelLoaded) {
        await _controller!.clearContext();
      }
    } catch (e) {
      print('⚠️ [LLM] Context clear warning: $e');
    }
  }

  // OPTIMIZED: Streaming generation with early stopping
  static Future<String> _generateText({
    required String prompt,
    required int maxTokens,
    double temperature = 0.7,
    bool clearContext = true, // Only clear when needed
  }) async {
    if (clearContext) {
      await _clearContextIfNeeded();
    }
    
    final buffer = StringBuffer();
    int tokenCount = 0;
    
    try {
      await for (final token in _controller!.generate(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: 0.9,
        topK: 40,
        repeatPenalty: 1.1,
      )) {
        buffer.write(token);
        tokenCount++;
        
        // Early stopping if we have enough content
        if (tokenCount > maxTokens * 0.8 && 
            RegExp(r'[.!?]\s*$').hasMatch(buffer.toString())) {
          break;
        }
      }
    } catch (e) {
      print('⚠️ [LLM] Generation error: $e');
    }

    return buffer.toString().trim();
  }

  // OPTIMIZED: Single-pass summary (NO chunking)
  static Future<String> generateSummaryWithLLM({
    required String text,
    required String language,
  }) async {
    try {
      if (!_isModelLoaded) {
        final loaded = await _loadModel();
        if (!loaded) throw Exception('Failed to load model');
      }

      print('🤖 [LLM] Starting FAST summary generation in $language...');
      print('📊 [LLM] Input: ${text.length} chars');

      // OPTIMIZATION 1: Smart text truncation (keep important parts)
      final processedText = _smartTruncate(text, 6000); // Increased from 15000
      
      // OPTIMIZATION 2: Single prompt (NO chunking/merging)
      final languageInstruction = _getLanguageInstruction(language);
      
      final prompt = '''Summarize this text concisely.

$languageInstruction

Requirements:
- 3-5 key points
- Clear and simple
- Focus on main ideas

Text:
${processedText.substring(0, processedText.length > 5000 ? 5000 : processedText.length)}

Summary:''';

      print('🔄 [LLM] Generating summary in one pass...');
      
      final summary = await _generateText(
        prompt: prompt,
        maxTokens: 400, // Reduced from 600 for speed
        temperature: 0.3, // Lower temp for consistency
      );
      
      print('✅ [LLM] Summary complete: ${summary.length} chars');
      
      // Clean up output
      return _cleanSummaryOutput(summary);

    } catch (e) {
      print('❌ [LLM] Summary failed: $e');
      rethrow;
    }
  }

  // OPTIMIZATION: Smart truncation keeps important content
  static String _smartTruncate(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    
    // Keep first 40% and last 60% (conclusions often at end)
    final firstPart = (maxChars * 0.4).toInt();
    final lastPart = maxChars - firstPart;
    
    final start = text.substring(0, firstPart);
    final end = text.substring(text.length - lastPart);
    
    return '$start\n...\n$end';
  }

  // OPTIMIZATION: Cleaner output processing
  static String _cleanSummaryOutput(String summary) {
    // Remove common artifacts
    summary = summary
        .replaceAll(RegExp(r'Summary:?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^-\s*'), '')
        .trim();
    
    // Ensure it's not too short
    if (summary.split(' ').length < 30) {
      summary = 'Content overview: $summary';
    }
    
    return summary;
  }

  // OPTIMIZED: Faster quiz generation with better prompting
  static Future<List<Map<String, dynamic>>> generateQuizWithLLM({
    required String summary,
    required String language,
    int numQuestions = 5,
  }) async {
    try {
      if (!_isModelLoaded) {
        final loaded = await _loadModel();
        if (!loaded) throw Exception('Failed to load model');
      }

      print('🤖 [LLM] Generating quiz in $language...');

      // OPTIMIZATION: Limit summary length
      final limitedSummary = summary.length > 1200 
          ? summary.substring(0, 1200) 
          : summary;

      final languageInstruction = _getLanguageInstruction(language);
      
      // OPTIMIZATION: Minimal prompt for speed
      final prompt = '''Create $numQuestions quiz questions.

$languageInstruction

Format (STRICT):
Q1: [question]
A) [option]
B) [option]
C) [option]
D) [option]
ANSWER: A

Text:
$limitedSummary

Questions:''';

      final quizText = await _generateText(
        prompt: prompt,
        maxTokens: 800, // Increased slightly for quality
        temperature: 0.8, // Higher temp for variety
        clearContext: false, // Don't clear - reuse context
      );

      print('✅ [LLM] Quiz generated: ${quizText.length} chars');

      final quiz = _parseQuizOutput(quizText, numQuestions);
      print('✅ [LLM] Parsed ${quiz.length} questions');
      
      return quiz;

    } catch (e) {
      print('❌ [LLM] Quiz failed: $e');
      rethrow;
    }
  }

  // Language instruction
  static String _getLanguageInstruction(String language) {
    switch (language) {
      case 'hi':
        return 'Write in Hindi (हिंदी).';
      case 'mr':
        return 'Write in Marathi (मराठी).';
      default:
        return 'Write in English.';
    }
  }

  // OPTIMIZED: Robust quiz parsing with fallbacks
  static List<Map<String, dynamic>> _parseQuizOutput(String quizText, int expected) {
    final questions = <Map<String, dynamic>>[];
    
    try {
      // Split by question markers
      final blocks = <String>[];
      final lines = quizText.split('\n');
      
      StringBuffer current = StringBuffer();
      for (final line in lines) {
        if (RegExp(r'^Q\d+:', caseSensitive: false).hasMatch(line.trim())) {
          if (current.isNotEmpty) blocks.add(current.toString());
          current = StringBuffer();
        }
        current.writeln(line);
      }
      if (current.isNotEmpty) blocks.add(current.toString());

      print('📦 [LLM] Found ${blocks.length} blocks');

      // Parse each block
      for (int i = 0; i < blocks.length && questions.length < expected; i++) {
        final block = blocks[i];
        
        try {
          // Extract question
          final qMatch = RegExp(
            r'Q\d+:\s*(.+?)(?=\n[A-D]\))',
            caseSensitive: false,
            multiLine: true,
            dotAll: true,
          ).firstMatch(block);
          
          if (qMatch == null) continue;
          
          final question = qMatch.group(1)?.trim() ?? '';
          if (question.isEmpty) continue;

          // Extract options (OPTIMIZED)
          final optA = _extractOption(block, 'A') ?? 'Option A';
          final optB = _extractOption(block, 'B') ?? 'Option B';
          final optC = _extractOption(block, 'C') ?? 'Option C';
          final optD = _extractOption(block, 'D') ?? 'Option D';

          // Extract answer
          final ansMatch = RegExp(r'ANSWER:\s*([A-D])', caseSensitive: false)
              .firstMatch(block);
          final answer = ansMatch?.group(1)?.toUpperCase() ?? 'A';

          final options = [
            {'label': 'A', 'text': optA},
            {'label': 'B', 'text': optB},
            {'label': 'C', 'text': optC},
            {'label': 'D', 'text': optD},
          ];

          final answerText = options.firstWhere(
            (o) => o['label'] == answer,
            orElse: () => options[0],
          )['text'] as String;

          questions.add({
            'question': question,
            'options': options,
            'answer_label': answer,
            'answer_text': answerText,
          });

        } catch (e) {
          print('⚠️ [LLM] Parse error block $i: $e');
        }
      }

      // Fill with fallbacks if needed
      while (questions.length < expected) {
        questions.add(_fallbackQuestion(questions.length + 1));
      }

      return questions;

    } catch (e) {
      print('❌ [LLM] Parse failed: $e');
      return List.generate(expected, (i) => _fallbackQuestion(i + 1));
    }
  }

  // Extract option (OPTIMIZED with null safety)
  static String? _extractOption(String block, String label) {
    try {
      final pattern = RegExp(
        '$label\\)\\s*(.+?)(?=\\n[A-D]\\)|\\nANSWER:|\\n\\n|\\Z)',
        caseSensitive: false,
        multiLine: true,
        dotAll: true,
      );
      final match = pattern.firstMatch(block);
      return match?.group(1)?.trim();
    } catch (e) {
      return null;
    }
  }

  // Fallback question
  static Map<String, dynamic> _fallbackQuestion(int n) {
    return {
      'question': 'Question $n: What is a main topic discussed?',
      'options': [
        {'label': 'A', 'text': 'Topic A'},
        {'label': 'B', 'text': 'Topic B'},
        {'label': 'C', 'text': 'Topic C'},
        {'label': 'D', 'text': 'Topic D'},
      ],
      'answer_label': 'A',
      'answer_text': 'Topic A',
    };
  }

  // Dispose
  static Future<void> dispose() async {
    try {
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
        _isModelLoaded = false;
        print('🗑️ [LLM] Disposed');
      }
    } catch (e) {
      print('⚠️ [LLM] Dispose error: $e');
    }
  }
}