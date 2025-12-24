import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'model_downloader.dart';

class LLMSummaryService {
  static LlamaController? _controller;
  static bool _isModelLoaded = false;

  // Check if model is available
  static Future<bool> isModelAvailable() async {
    return await ModelDownloader.isModelDownloaded();
  }

  // Initialize and load model
  static Future<bool> _loadModel() async {
    if (_isModelLoaded && _controller != null) {
      print('✅ [LLM] Model already loaded, reusing...');
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
          contextSize: 2048,
        );
        _isModelLoaded = true;
        print('✅ [LLM] Model loaded successfully!');
      }
      
      return true;
    } catch (e) {
      print('❌ [LLM] Failed to load model: $e');
      
      if (e.toString().contains('already loaded')) {
        print('✅ [LLM] Model was already loaded, continuing...');
        _isModelLoaded = true;
        return true;
      }
      
      _isModelLoaded = false;
      return false;
    }
  }

  // CRITICAL: Clear context before each generation
  static Future<void> _clearContext() async {
    try {
      if (_controller != null && _isModelLoaded) {
        print('🧹 [LLM] Clearing context...');
        await _controller!.clearContext();
        print('✅ [LLM] Context cleared');
      }
    } catch (e) {
      print('⚠️ [LLM] Context clear warning: $e');
      // Continue anyway - not critical
    }
  }

  // Generate text with context clearing
  static Future<String> _generateText({
    required String prompt,
    required int maxTokens,
    double temperature = 0.7,
  }) async {
    // Clear context before generation
    await _clearContext();
    
    final buffer = StringBuffer();
    
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
      }
    } catch (e) {
      print('⚠️ [LLM] Generation error: $e');
      // Return what we got so far
    }

    return buffer.toString().trim();
  }

  // Split text into chunks
  static List<String> _chunkText(String text, int chunkSize) {
    final chunks = <String>[];
    int i = 0;
    while (i < text.length) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      chunks.add(text.substring(i, end));
      i += chunkSize;
    }
    return chunks;
  }

  // Summarize a single chunk
  static Future<String> _summarizeChunk(String chunk, String language) async {
    final languageInstruction = _getLanguageInstruction(language);
    
    final prompt = '''Summarize this text into 2-3 bullet points:

$languageInstruction

Text:
$chunk

Summary:''';

    return await _generateText(
      prompt: prompt,
      maxTokens: 100,
      temperature: 0.3,
    );
  }

  // Merge summaries
  static Future<String> _mergeSummaries(
    List<String> summaries,
    String language,
  ) async {
    final combined = summaries.join('\n');
    final limited = combined.length > 1500 ? combined.substring(0, 1500) : combined;
    
    final languageInstruction = _getLanguageInstruction(language);
    
    final prompt = '''Combine these points into one clear summary.

$languageInstruction

Include:
- Short intro (2-3 sentences)
- 5-8 bullet points with key concepts

Points:
$limited

Summary:''';

    return await _generateText(
      prompt: prompt,
      maxTokens: 300,
      temperature: 0.5,
    );
  }

  // Main summary generation
  static Future<String> generateSummaryWithLLM({
    required String text,
    required String language,
  }) async {
    try {
      if (!_isModelLoaded) {
        final loaded = await _loadModel();
        if (!loaded) throw Exception('Failed to load model');
      }

      print('🤖 [LLM] Starting summary generation in $language...');
      print('📊 [LLM] Input: ${text.length} chars');

      // Limit to 15K chars for speed
      final limitedText = text.length > 15000 ? text.substring(0, 15000) : text;

      // Chunk into 800 char pieces (larger = fewer chunks = faster)
      final chunks = _chunkText(limitedText, 800);
      print('📦 [LLM] Processing ${chunks.length} chunks');

      final miniSummaries = <String>[];
      
      // Process chunks
      for (int i = 0; i < chunks.length; i++) {
        print('🔄 [LLM] Chunk ${i + 1}/${chunks.length}');
        final mini = await _summarizeChunk(chunks[i], language);
        
        if (mini.isNotEmpty) {
          miniSummaries.add(mini);
        }

        // Merge if too many
        if (miniSummaries.length >= 15) {
          print('🔄 [LLM] Merging ${miniSummaries.length} summaries...');
          final merged = await _mergeSummaries(miniSummaries, language);
          miniSummaries.clear();
          miniSummaries.add(merged);
        }
      }

      // Final merge
      print('✅ [LLM] Creating final summary...');
      final finalSummary = miniSummaries.length > 1
          ? await _mergeSummaries(miniSummaries, language)
          : miniSummaries.isNotEmpty ? miniSummaries[0] : 'No summary generated';
      
      print('✅ [LLM] Summary complete: ${finalSummary.length} chars');
      return finalSummary;

    } catch (e) {
      print('❌ [LLM] Summary failed: $e');
      rethrow;
    }
  }

  // Generate quiz
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

      // Limit summary to 800 chars
      final limitedSummary = summary.length > 800 
          ? summary.substring(0, 800) 
          : summary;

      final languageInstruction = _getLanguageInstruction(language);
      
      final prompt = '''Create EXACTLY $numQuestions multiple choice questions.

$languageInstruction

RULES:
- Create EXACTLY $numQuestions questions
- Each has 4 options: A, B, C, D
- Format like this:

Q1: [question]
A) [option]
B) [option]
C) [option]
D) [option]
ANSWER: A

Q2: [question]
A) [option]
B) [option]
C) [option]
D) [option]
ANSWER: B

Summary:
$limitedSummary

Questions:''';

      final quizText = await _generateText(
        prompt: prompt,
        maxTokens: 600,
        temperature: 0.7,
      );

      print('📝 [LLM] Quiz generated: ${quizText.length} chars');
      print('📝 [LLM] Preview: ${quizText.substring(0, quizText.length > 200 ? 200 : quizText.length)}...');

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
        return 'Write ONLY in Hindi (हिंदी).';
      case 'mr':
        return 'Write ONLY in Marathi (मराठी).';
      default:
        return 'Write ONLY in English.';
    }
  }

  // Parse quiz output
  static List<Map<String, dynamic>> _parseQuizOutput(String quizText, int expected) {
    final questions = <Map<String, dynamic>>[];
    
    try {
      // Split by Q1:, Q2:, etc.
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
          
          if (qMatch == null) {
            print('⚠️ [LLM] No question in block $i');
            continue;
          }
          
          final question = qMatch.group(1)?.trim() ?? '';
          if (question.isEmpty) continue;

          // Extract options
          final optA = _extractOption(block, 'A');
          final optB = _extractOption(block, 'B');
          final optC = _extractOption(block, 'C');
          final optD = _extractOption(block, 'D');

          // Check if we got real options
          if (optA == 'Option A' || optB == 'Option B') {
            print('⚠️ [LLM] Missing options in block $i');
          }

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

          print('✅ [LLM] Parsed question ${questions.length}');

        } catch (e) {
          print('⚠️ [LLM] Parse error block $i: $e');
        }
      }

      // Fill with fallbacks
      while (questions.length < expected) {
        print('⚠️ [LLM] Adding fallback ${questions.length + 1}');
        questions.add(_fallbackQuestion(questions.length + 1));
      }

      return questions;

    } catch (e) {
      print('❌ [LLM] Parse failed: $e');
      return List.generate(expected, (i) => _fallbackQuestion(i + 1));
    }
  }

  // Extract option
  static String _extractOption(String block, String label) {
    try {
      final pattern = RegExp(
        '$label\\)\\s*(.+?)(?=\\n[A-D]\\)|\\nANSWER:|\\n\\n|\\Z)',
        caseSensitive: false,
        multiLine: true,
        dotAll: true,
      );
      final match = pattern.firstMatch(block);
      final text = match?.group(1)?.trim() ?? 'Option $label';
      return text.isEmpty ? 'Option $label' : text;
    } catch (e) {
      return 'Option $label';
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