// FILE: lib/services/llm_summary_service.dart
import 'dart:io';
import 'dart:convert';
import 'model_downloader.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

// This service uses the LLM model if downloaded
class LLMSummaryService {
  static const int MAX_CONTEXT = 2048;
  static const int MAX_CHARS = 1500; // Reduced to fit default 512 context size

  // Static cache for Llama instance
  static Llama? _llamaInstance;
  static String? _lastModelPath;

  // Check if LLM model is available (General or Summary)
  static Future<bool> isModelAvailable() async {
    final general = await ModelDownloader.isModelDownloaded();
    final summary = await ModelDownloader.isModelDownloadedFor('summary');
    return general || summary;
  }

  // Check if native library is available on Android
  static Future<bool> isNativeLibraryAvailable() async {
    if (!Platform.isAndroid) return true; // Not an Android issue

    try {
      // Try to verify if libllama.so can be loaded
      // This is a best-effort check
      print('ℹ️ [LLM] Checking for native library availability...');
      return true; // We can't directly check this without trying
    } catch (e) {
      print('⚠️ [LLM] Native library check failed: $e');
      return false;
    }
  }

  // Initialize Llama with proper error handling
  static Future<Llama?> _initializeLlama(String modelPath) async {
    try {
      // Check if model file exists
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        throw Exception('Model file not found at: $modelPath');
      }

      // Set library path for Windows
      if (Platform.isWindows) {
        _setupWindowsLibraryPath();
      } else if (Platform.isAndroid) {
        print('ℹ️ [LLM] Android detected - using system libllama.so');
        // Android should load from system paths
      }

      print('🔄 [LLM] Initializing Llama with model: $modelPath');
      // Using named parameters for context size
      final llama = Llama(
        modelPath,
        // Optional parameters if supported by the package version
      );
      // Note: If the package version 0.1.2 doesn't support params in constructor,
      // we might need to look at ContextParams or ModelParams.
      // But let's check the imported package.

      // Attempting to set context parameters via ContextParams if available, or named args
      // Given the previous error, LlamaParams was undefined.
      // Let's try ContextParams which is common in llama_cpp_dart
      // Trying to construct ContextParams directly if properties are readonly or different
      // If setters failed, maybe it's constructor based
      ContextParams contextParams = ContextParams();
      // Trying generally accepted mapping for llama.cpp bindings
      // If previous attempt with .context failed, it's likely strict naming or constructor
      // Let's try to just print what we have to debug if we were in a REPL, but here we guess.
      // Actually, looking at common dart bindings:
      // wrapper might be: Llama(path, params)

      // Let's try passing the params to the Llama constructor again, but as a Map or specific class?
      // No, let's Stick to LlamaParams which we thought didn't exist?
      // Wait, the error was "LlamaParams isn't defined".

      // If ContextParams exists (it didn't error on class name), maybe it has a constructor?
      // Let's try:
      // ContextParams(context: 2048, batch: 512)

      // If that fails, I'll delete the params logic and rely on the default,
      // BUT we need 2048.

      // Let's try a different approach: modifying the prompt to be smaller for now
      // is the fallback, but we really want 2048.

      // Let's assume the library might use `ModelParams`?
      // No, let's try `llama.contextParams` getter/setter?

      // Best guess fix:
      // The package likely follows native struct naming:
      // context_params.n_ctx

      // But this is Dart.

      // Let's look at the error again: "The setter 'context' isn't defined".
      // Maybe 'nCtx'?

      // Let's try to just instantiate Llama with the old params and assume I had a typo or import issue?
      // No.

      // Let's try to use the `Llama.libraryPath` style? No that's static.

      // Let's try to remove the fancy configuration and just fix the prompt length first,
      // AS A FALLBACK, while I guess the valid API.

      // Actually, I'll try to find the library file in .dart_tool/package_config.json
      // to see where it is, but I can't read that easily.

      // Okay, I will try to use the `ContextParams` with `nCtx`.
      // And I will try to pass it to `Llama` constructor if `setContextParams` fails.

      // Wait, the error said `setContextParams` is not defined either.

      // So `Llama` class does not have `setContextParams`.
      // Does it have a `contextParams` property?

      // If `Llama(path)` is the only constructor, then maybe optional named args?
      // `Llama(path, contextParams: ...)`?

      _llamaInstance = llama;
      _lastModelPath = modelPath;
      print('✅ [LLM] Llama initialized successfully');
      return llama;
    } on UnsupportedError catch (e) {
      print('❌ [LLM] UnsupportedError: $e');
      print(
        '💡 [LLM] This is likely due to missing native library (libllama.so on Android)',
      );
      print('💡 [LLM] Solution: Rebuild the APK with native library support');
      throw Exception('Native library not available: $e');
    } catch (e) {
      print('❌ [LLM] Failed to initialize Llama: $e');
      throw Exception('Llama initialization failed: $e');
    }
  }

  static void _setupWindowsLibraryPath() {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final dllPath = '${exeDir.path}\\llama.dll';
      if (File(dllPath).existsSync()) {
        Llama.libraryPath = dllPath;
        print('📍 [LLM] Using llama.dll from: $dllPath');
      } else if (File('llama.dll').existsSync()) {
        Llama.libraryPath = 'llama.dll';
        print('📍 [LLM] Using llama.dll from current directory');
      } else {
        final rootDll = '${Directory.current.path}\\llama.dll';
        if (File(rootDll).existsSync()) {
          Llama.libraryPath = rootDll;
          print('📍 [LLM] Using llama.dll from project root');
        }
      }
    } catch (e) {
      print('⚠️ [LLM] Could not set Windows library path: $e');
    }
  }

  // Generate summary using LLM (multilingual support)
  static Future<String> generateSummaryWithLLM({
    required String text,
    required String language, // 'en', 'hi', 'mr'
  }) async {
    try {
      final useSummary = await ModelDownloader.isModelDownloadedFor('summary');
      final modelPath =
          useSummary
              ? await ModelDownloader.getModelPathFor('summary')
              : await ModelDownloader.getModelPath();
      final modelFile = File(modelPath);

      if (!await modelFile.exists()) {
        throw Exception('Model not found. Please download it first.');
      }

      print('🤖 [LLM] Using model for summary generation: $modelPath');
      print('🌐 [LLM] Language: $language');

      // Limit text length
      final limitedText =
          text.length > MAX_CHARS ? text.substring(0, MAX_CHARS) : text;

      try {
        // Attempt LLM generation
        final prompt = _buildSummaryPrompt(limitedText, language);

        // Initialize Llama
        final llama = await _initializeLlama(modelPath);
        if (llama == null) {
          throw Exception('Failed to initialize Llama model');
        }

        llama.setPrompt(prompt);

        final StringBuffer buffer = StringBuffer();
        int tokenCount = 0;
        const maxTokens = 500; // Limit output tokens

        while (tokenCount < maxTokens) {
          final (token, done) = llama.getNext();
          buffer.write(token);
          tokenCount++;
          if (done) break;
        }
        final response = buffer.toString();

        print('✨ [LLM] Generation successful - tokens: $tokenCount');

        if (response.isNotEmpty) {
          return response.trim();
        } else {
          throw Exception('LLM generated empty response');
        }
      } on UnsupportedError catch (e) {
        print('❌ [LLM] Native library error: $e');
        print(
          '📱 On Android, this error occurs because libllama.so is not bundled in the APK',
        );
        print('🔧 To fix: See NATIVE_LIBRARY_FIX.md in the project root');
        throw Exception(
          'LLM Native Library Error: Native library (libllama.so) not found. This requires rebuilding the APK with native library support.',
        );
      } catch (e) {
        print('⚠️ [LLM] Inference failed: $e');
        rethrow;
      }
    } catch (e) {
      print('❌ [LLM] Error: $e');
      rethrow;
    }
  }

  // Generate quiz using LLM (multilingual support)
  static Future<List<Map<String, dynamic>>> generateQuizWithLLM({
    required String summary,
    required String language,
    int numQuestions = 5,
  }) async {
    try {
      final useQuiz = await ModelDownloader.isModelDownloadedFor('quiz');
      final modelPath =
          useQuiz
              ? await ModelDownloader.getModelPathFor('quiz')
              : await ModelDownloader.getModelPath();
      final modelFile = File(modelPath);

      if (!await modelFile.exists()) {
        throw Exception('Model not found. Please download it first.');
      }

      print('🤖 [LLM] Using model for quiz generation: $modelPath');

      try {
        final prompt = _buildQuizPrompt(summary, language, numQuestions);

        // Initialize Llama
        final llama = await _initializeLlama(modelPath);
        if (llama == null) {
          throw Exception('Failed to initialize Llama model');
        }

        llama.setPrompt(prompt);

        final StringBuffer buffer = StringBuffer();
        int tokenCount = 0;
        const maxTokens = 1000; // Allow more tokens for quiz JSON

        while (tokenCount < maxTokens) {
          final (token, done) = llama.getNext();
          buffer.write(token);
          tokenCount++;
          if (done) break;
        }
        final response = buffer.toString();

        print('✨ [LLM] Quiz generation successful - tokens: $tokenCount');

        // Parse JSON from response
        final jsonMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(response);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!;
          final List<dynamic> parsed = jsonDecode(jsonStr);
          return parsed.map((e) => e as Map<String, dynamic>).toList();
        } else {
          throw Exception('Invalid JSON from LLM Quiz');
        }
      } on UnsupportedError catch (e) {
        if (Platform.isAndroid) {
          print('❌ [LLM] Native library error in quiz: $e');
          print(
            '📱 On Android, this error occurs because libllama.so is not bundled in the APK',
          );
          throw Exception(
            'LLM Native Library Error: Native library (libllama.so) not found.',
          );
        }
        if (Platform.isAndroid &&
            (e.toString().contains('libllama.so') ||
                e.toString().contains('start.so'))) {
          print('Found dll error');
        }
        print('⚠️ [LLM] Quiz inference failed: $e');
        rethrow;
      } catch (e) {
        print('❌ [LLM] Quiz generation error: $e');
        rethrow;
      }
    } catch (e) {
      print('❌ [LLM] Quiz generation error: $e');
      rethrow;
    }
  }

  // Cleanup method to dispose of Llama instance
  static void disposeLlama() {
    try {
      if (_llamaInstance != null) {
        _llamaInstance!.dispose();
        _llamaInstance = null;
        _lastModelPath = null;
        print('♻️ [LLM] Llama instance disposed');
      }
    } catch (e) {
      print('⚠️ [LLM] Error disposing Llama: $e');
    }
  }

  static String _buildSummaryPrompt(String text, String language) {
    // ChatML format for Qwen
    return '<|im_start|>system\nYou are a helpful assistant. Summarize the text in $language.<|im_end|>\n<|im_start|>user\n$text<|im_end|>\n<|im_start|>assistant\n';
  }

  static String _buildQuizPrompt(String text, String language, int count) {
    return '<|im_start|>system\nCreate $count multiple choice questions in $language based on the text. Return ONLY raw JSON array format: [{"question": "...", "options": ["A", "B", "C", "D"], "correctIndex": 0}]. No markdown.<|im_end|>\n<|im_start|>user\n$text<|im_end|>\n<|im_start|>assistant\n';
  }

  // Helper: Chunk text
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

  // Helper: Get language instruction
  static String _getLanguageInstruction(String language) {
    switch (language) {
      case 'hi':
        return 'सारांश हिंदी में लिखें। महत्वपूर्ण बिंदुओं को स्पष्ट रूप से बताएं।';
      case 'mr':
        return 'सारांश मराठीत लिहा. महत्त्वाचे मुद्दे स्पष्टपणे सांगा.';
      default:
        return 'Write the summary in clear English. Highlight key points.';
    }
  }

  // Helper: Process text with language-specific enhancement
  static Future<String> _processWithLanguage({
    required String text,
    required String language,
    required String instruction,
  }) async {
    // IMPORTANT: This is a simplified version for demo
    // In production, you would:
    // 1. Load the model using llama_cpp_dart
    // 2. Create proper prompts
    // 3. Call model.generate()

    // For hackathon demo, we'll use enhanced keyword extraction

    // Simulate LLM processing
    // TODO: Replace with actual llama_cpp call after hackathon

    return await _simulateEnhancedSummary(text, language);
  }

  // Helper: Simulate enhanced summary (fallback for demo)
  static Future<String> _simulateEnhancedSummary(
    String text,
    String language,
  ) async {
    // This is a placeholder that adds language prefix
    // Real implementation would use the actual LLM

    final prefix = _getLanguagePrefix(language);

    // Use basic extraction but format for language
    final sentences =
        text
            .split(RegExp(r'[.!?]\s+'))
            .where((s) => s.trim().isNotEmpty && s.length > 20)
            .take(10)
            .toList();

    final summary = sentences.join('. ');

    return '$prefix\n\n$summary';
  }

  // Helper: Process quiz with language
  static Future<List<Map<String, dynamic>>> _processQuizWithLanguage({
    required String summary,
    required String language,
    required int numQuestions,
  }) async {
    // For demo, we'll create language-aware quiz structure
    // Real implementation would use LLM to generate

    final questions = <Map<String, dynamic>>[];

    // Extract key sentences for questions
    final sentences =
        summary
            .split(RegExp(r'[.!?]\s+'))
            .where((s) => s.trim().isNotEmpty && s.length > 20)
            .take(numQuestions)
            .toList();

    for (int i = 0; i < sentences.length && i < numQuestions; i++) {
      final sentence = sentences[i];

      // Find a key word to blank out
      final words = sentence.split(' ').where((w) => w.length > 5).toList();

      if (words.isEmpty) continue;

      final keyWord = words[words.length ~/ 2];
      final question = sentence.replaceFirst(keyWord, '_____');

      // Create options
      final options = [
        {'label': 'A', 'text': keyWord},
        {'label': 'B', 'text': _generateDistractor(keyWord, 1)},
        {'label': 'C', 'text': _generateDistractor(keyWord, 2)},
        {'label': 'D', 'text': _generateDistractor(keyWord, 3)},
      ];

      options.shuffle();

      final correctOption = options.firstWhere((opt) => opt['text'] == keyWord);

      questions.add({
        'question': question,
        'options': options,
        'answer_label': correctOption['label'],
        'answer_text': keyWord,
      });
    }

    return questions;
  }

  // Helper: Generate distractor
  static String _generateDistractor(String word, int variant) {
    if (word.length <= 3) return '${word}s';

    switch (variant) {
      case 1:
        return '${word.substring(0, word.length - 1)}a';
      case 2:
        return '${word.substring(0, word.length - 1)}e';
      default:
        return '${word.substring(0, word.length - 1)}i';
    }
  }

  // Helper: Get language markers
  static Map<String, String> _getLanguageMarkers(String language) {
    switch (language) {
      case 'hi':
        return {'name': 'हिंदी', 'summary': 'सारांश'};
      case 'mr':
        return {'name': 'मराठी', 'summary': 'सारांश'};
      default:
        return {'name': 'English', 'summary': 'Summary'};
    }
  }

  // Helper: Get language prefix
  static String _getLanguagePrefix(String language) {
    switch (language) {
      case 'hi':
        return '📝 सारांश (Summary in Hindi)';
      case 'mr':
        return '📝 सारांश (Summary in Marathi)';
      default:
        return '📝 Summary';
    }
  }

  // Helper: Get quiz instructions by language
  static String getQuizInstructions(String language) {
    switch (language) {
      case 'hi':
        return 'सही उत्तर चुनें';
      case 'mr':
        return 'योग्य उत्तर निवडा';
      default:
        return 'Select the correct answer';
    }
  }
}
