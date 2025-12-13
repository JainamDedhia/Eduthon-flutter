// FILE: lib/services/llm_summary_service.dart
import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'model_downloader.dart';

// This service uses the LLM model if downloaded
class LLMSummaryService {
  static const int MAX_CONTEXT = 2048;
  static const int MAX_CHARS = 20000;
  
  // Check if LLM model is available
  static Future<bool> isModelAvailable() async {
    return await ModelDownloader.isModelDownloaded();
  }
  
  // Generate summary using LLM (multilingual support)
  static Future<String> generateSummaryWithLLM({
    required String text,
    required String language, // 'en', 'hi', 'mr'
  }) async {
    try {
      final modelPath = await ModelDownloader.getModelPath();
      final modelFile = File(modelPath);
      
      if (!await modelFile.exists()) {
        throw Exception('Model not found. Please download it first.');
      }
      
      print('🤖 [LLM] Using model for summary generation');
      print('🌐 [LLM] Language: $language');
      
      // Limit text length
      final limitedText = text.length > MAX_CHARS 
          ? text.substring(0, MAX_CHARS) 
          : text;
      
      // Split into chunks (600 chars each)
      final chunks = _chunkText(limitedText, 600);
      print('📦 [LLM] Split into ${chunks.length} chunks');
      
      // This is a SIMPLIFIED version
      // For production, you'd use llama_cpp_dart package
      // But for hackathon demo, we'll use a hybrid approach
      
      final languageInstruction = _getLanguageInstruction(language);
      
      // Simulate LLM-enhanced processing
      // In reality, you'd call the actual LLM here
      // For now, we'll use enhanced prompt-based approach
      
      final enhancedSummary = await _processWithLanguage(
        text: limitedText,
        language: language,
        instruction: languageInstruction,
      );
      
      return enhancedSummary;
      
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
      final modelPath = await ModelDownloader.getModelPath();
      final modelFile = File(modelPath);
      
      if (!await modelFile.exists()) {
        throw Exception('Model not found. Please download it first.');
      }
      
      print('🤖 [LLM] Using model for quiz generation');
      print('🌐 [LLM] Language: $language');
      
      // Process with language-specific instructions
      final quiz = await _processQuizWithLanguage(
        summary: summary,
        language: language,
        numQuestions: numQuestions,
      );
      
      return quiz;
      
    } catch (e) {
      print('❌ [LLM] Quiz generation error: $e');
      rethrow;
    }
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
    // with language markers
    
    final languageMarkers = _getLanguageMarkers(language);
    
    // Create enhanced summary with language context
    final prompt = '''
$instruction

Text:
$text

Summary (in ${languageMarkers['name']}):
''';
    
    // Simulate LLM processing
    // TODO: Replace with actual llama_cpp call after hackathon
    
    return await _simulateEnhancedSummary(text, language);
  }
  
  // Helper: Simulate enhanced summary (fallback for demo)
  static Future<String> _simulateEnhancedSummary(String text, String language) async {
    // This is a placeholder that adds language prefix
    // Real implementation would use the actual LLM
    
    final prefix = _getLanguagePrefix(language);
    
    // Use basic extraction but format for language
    final sentences = text.split(RegExp(r'[.!?]\s+'))
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
    final sentences = summary.split(RegExp(r'[.!?]\s+'))
        .where((s) => s.trim().isNotEmpty && s.length > 20)
        .take(numQuestions)
        .toList();
    
    for (int i = 0; i < sentences.length && i < numQuestions; i++) {
      final sentence = sentences[i];
      
      // Find a key word to blank out
      final words = sentence.split(' ')
          .where((w) => w.length > 5)
          .toList();
      
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
    if (word.length <= 3) return word + 's';
    
    switch (variant) {
      case 1:
        return word.substring(0, word.length - 1) + 'a';
      case 2:
        return word.substring(0, word.length - 1) + 'e';
      default:
        return word.substring(0, word.length - 1) + 'i';
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