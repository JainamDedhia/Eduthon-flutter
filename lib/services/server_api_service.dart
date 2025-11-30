// FILE: lib/services/server_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ServerAPIService {
  // 🔥 IMPORTANT: Replace with your ngrok/localtunnel URL
  static const String BASE_URL = "https://proud-paws-melt.loca.lt";
  
  // Request timeout
  static const Duration TIMEOUT = Duration(seconds: 30);
  
  // Rate limit tracking
  static DateTime? _lastRequestTime;
  static int _requestCount = 0;
  static const int MAX_REQUESTS_PER_MINUTE = 30;
  
  // Check rate limit before making request
  static Future<bool> _checkRateLimit() async {
    final now = DateTime.now();
    
    if (_lastRequestTime == null || 
        now.difference(_lastRequestTime!) > Duration(minutes: 1)) {
      // Reset counter
      _requestCount = 0;
      _lastRequestTime = now;
    }
    
    if (_requestCount >= MAX_REQUESTS_PER_MINUTE) {
      print('⚠️ [ServerAPI] Rate limit reached, waiting...');
      await Future.delayed(Duration(seconds: 2));
      return false;
    }
    
    _requestCount++;
    return true;
  }
  
  // Health check
  static Future<bool> isServerHealthy() async {
    try {
      print('🏥 [ServerAPI] Checking server health...');
      
      final response = await http
          .get(Uri.parse('$BASE_URL/'))
          .timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ [ServerAPI] Server healthy: ${data['status']}');
        return true;
      }
      
      print('⚠️ [ServerAPI] Server returned ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ [ServerAPI] Health check failed: $e');
      return false;
    }
  }
  
  // Generate Summary
  static Future<String> generateSummary({
    required String text,
    required String model, // "fast", "balanced", "best"
    int maxLength = 500,
  }) async {
    try {
      print('📝 [ServerAPI] Generating summary with model: $model');
      
      // Check rate limit
      await _checkRateLimit();
      
      // Prepare request
      final response = await http.post(
        Uri.parse('$BASE_URL/api/summary'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text.substring(0, text.length > 20000 ? 20000 : text.length),
          'model': model,
          'max_length': maxLength,
        }),
      ).timeout(TIMEOUT);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = data['summary'] as String;
        
        print('✅ [ServerAPI] Summary generated: ${summary.length} chars');
        return summary;
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please wait a moment.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ServerAPI] Summary generation failed: $e');
      rethrow;
    }
  }
  
  // Generate Quiz
  static Future<List<Map<String, dynamic>>> generateQuiz({
    required String text,
    required String model,
    int numQuestions = 5,
  }) async {
    try {
      print('❓ [ServerAPI] Generating quiz with model: $model');
      
      // Check rate limit
      await _checkRateLimit();
      
      // Prepare request
      final response = await http.post(
        Uri.parse('$BASE_URL/api/quiz'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text.substring(0, text.length > 20000 ? 20000 : text.length),
          'model': model,
          'num_questions': numQuestions,
        }),
      ).timeout(TIMEOUT);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final questions = data['questions'] as List<dynamic>;
        
        print('✅ [ServerAPI] Quiz generated: ${questions.length} questions');
        
        // Convert to app format
        return questions.map((q) {
          final question = q as Map<String, dynamic>;
          final options = question['options'] as Map<String, dynamic>;
          final correctAnswer = question['correct'] as String;
          
          return {
            'question': question['question'] as String,
            'options': [
              {'label': 'A', 'text': options['A'] as String},
              {'label': 'B', 'text': options['B'] as String},
              {'label': 'C', 'text': options['C'] as String},
              {'label': 'D', 'text': options['D'] as String},
            ],
            'answer_label': correctAnswer,
            'answer_text': options[correctAnswer] as String,
          };
        }).toList();
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please wait a moment.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ServerAPI] Quiz generation failed: $e');
      rethrow;
    }
  }
  
  // Generate Mind Map
  static Future<Map<String, dynamic>> generateMindMap({
    required String text,
    required String model,
  }) async {
    try {
      print('🧠 [ServerAPI] Generating mind map with model: $model');
      
      // Check rate limit
      await _checkRateLimit();
      
      // Prepare request
      final response = await http.post(
        Uri.parse('$BASE_URL/api/mindmap'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text.substring(0, text.length > 20000 ? 20000 : text.length),
          'model': model,
        }),
      ).timeout(TIMEOUT);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ [ServerAPI] Mind map generated');
        return data['mindmap'] as Map<String, dynamic>;
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please wait a moment.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ServerAPI] Mind map generation failed: $e');
      rethrow;
    }
  }
  
  // Chat with context
  static Future<String> chat({
    required String message,
    required String context,
    required List<Map<String, String>> history,
    required String model,
  }) async {
    try {
      print('💬 [ServerAPI] Chatting with model: $model');
      
      // Check rate limit
      await _checkRateLimit();
      
      // Prepare request
      final response = await http.post(
        Uri.parse('$BASE_URL/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'context': context.substring(0, context.length > 10000 ? 10000 : context.length),
          'history': history,
          'model': model,
        }),
      ).timeout(TIMEOUT);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['response'] as String;
        
        print('✅ [ServerAPI] Chat response: ${reply.length} chars');
        return reply;
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please wait a moment.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ServerAPI] Chat failed: $e');
      rethrow;
    }
  }
  
  // Generate Image
  static Future<String> generateImage({
    required String prompt,
    String style = "realistic", // "realistic", "anime", "sketch", "diagram"
  }) async {
    try {
      print('🎨 [ServerAPI] Generating image with style: $style');
      
      // Check rate limit
      await _checkRateLimit();
      
      // Prepare request
      final response = await http.post(
        Uri.parse('$BASE_URL/api/generate-image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': prompt,
          'style': style,
        }),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['image_url'] as String;
        
        print('✅ [ServerAPI] Image generated: $imageUrl');
        return imageUrl;
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please wait a moment.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ServerAPI] Image generation failed: $e');
      rethrow;
    }
  }
  
  // Helper: Get model display name
  static String getModelDisplayName(String model) {
    switch (model) {
      case 'fast':
        return '⚡ Fast (Llama 3.1 8B)';
      case 'balanced':
        return '⚖️ Balanced (Llama 3.1 70B)';
      case 'best':
        return '🎯 Best (Mixtral 8x7B)';
      default:
        return model;
    }
  }
  
  // Helper: Get model description
  static String getModelDescription(String model) {
    switch (model) {
      case 'fast':
        return '2-3 seconds response time\nGood for quick summaries';
      case 'balanced':
        return '4-6 seconds response time\nBest balance of speed & quality';
      case 'best':
        return '7-10 seconds response time\nHighest quality output';
      default:
        return '';
    }
  }
  
  // Helper: Get model recommendation
  static String getModelRecommendation(String model) {
    switch (model) {
      case 'fast':
        return '💡 Recommended for: Quick reviews, short texts';
      case 'balanced':
        return '💡 Recommended for: Most use cases (default)';
      case 'best':
        return '💡 Recommended for: Complex topics, exams';
      default:
        return '';
    }
  }
}