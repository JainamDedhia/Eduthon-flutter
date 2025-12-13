// FILE: lib/services/groq_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/groq_config.dart';

class GroqService {
  static const String BASE_URL = 'https://api.groq.com/openai/v1/chat/completions';
  static const String API_KEY_KEY = 'groq_api_key';
  static const String DEFAULT_MODEL = GroqConfig.DEFAULT_MODEL;
  static const String QUALITY_MODEL = GroqConfig.QUALITY_MODEL;
  static const Duration TIMEOUT = Duration(seconds: 30);
  static bool _initialized = false;

  // Check if API key exists
  static Future<bool> checkApiKey() async {
    try {
      final apiKey = await getApiKey();
      return apiKey != null && apiKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Initialize with default API key if not already set
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingKey = prefs.getString(API_KEY_KEY);
      
      // If no key exists, set the default one
      if (existingKey == null || existingKey.isEmpty) {
        await prefs.setString(API_KEY_KEY, GroqConfig.DEFAULT_API_KEY);
        print('✅ [GroqService] Initialized with default API key');
      }
      
      _initialized = true;
    } catch (e) {
      print('⚠️ [GroqService] Error initializing: $e');
    }
  }

  // Get API key from SharedPreferences (with fallback to default)
  static Future<String?> getApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(API_KEY_KEY);
      
      // If no key in preferences, return default
      if (key == null || key.isEmpty) {
        return GroqConfig.DEFAULT_API_KEY;
      }
      
      return key;
    } catch (e) {
      print('⚠️ [GroqService] Error getting API key: $e');
      return GroqConfig.DEFAULT_API_KEY;
    }
  }

  // Save API key to SharedPreferences
  static Future<void> saveApiKey(String apiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(API_KEY_KEY, apiKey);
      print('✅ [GroqService] API key saved');
    } catch (e) {
      print('❌ [GroqService] Error saving API key: $e');
      throw Exception('Failed to save API key: $e');
    }
  }

  // Refine answer using Groq API
  static Future<String> refineAnswer({
    required String query,
    required String context,
    List<Map<String, dynamic>>? history,
    String model = DEFAULT_MODEL,
    double temperature = 0.7,
    int maxTokens = 500,
  }) async {
    try {
      print('🤖 [GroqService] Refining answer with model: $model');

      final apiKey = await getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Groq API key not configured');
      }

      // Build messages
      final messages = <Map<String, String>>[];

      // System message with context (or without if no context available)
      if (context.isNotEmpty && context.trim().isNotEmpty) {
        // We have relevant text from PDFs - use it
        messages.add({
          'role': 'system',
          'content': '''You are a helpful educational assistant. Use the following context from student's downloaded course materials to answer questions accurately and concisely.

Context from downloaded PDFs:
$context

Instructions:
- Answer based on the provided context from the PDFs
- Be concise but complete
- Cite which source/file the information comes from when relevant
- If the context doesn't fully answer the question, you can supplement with your general knowledge but prioritize the PDF content''',
        });
        print('📄 [GroqService] Sending question with ${context.length} chars of PDF context');
      } else {
        // No context from PDFs - Groq can still answer general questions
        messages.add({
          'role': 'system',
          'content': '''You are a helpful educational assistant. Answer the student's question to the best of your ability. If the question is about course materials, note that no specific PDF content is available, but you can still provide helpful information based on general knowledge.''',
        });
        print('📄 [GroqService] Sending question without PDF context (general knowledge mode)');
      }

      // Add conversation history
      if (history != null && history.isNotEmpty) {
        for (final msg in history) {
          final role = msg['role'] as String?;
          final content = msg['content'] as String?;
          if (role != null && content != null) {
            messages.add({
              'role': role,
              'content': content,
            });
          }
        }
      }

      // Add user query
      messages.add({
        'role': 'user',
        'content': query,
      });

      // Prepare request
      final requestBody = {
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
      };

      print('📤 [GroqService] Sending request to Groq API...');
      print('   Model: $model');
      print('   Messages: ${messages.length}');
      print('   Context length: ${context.length} chars');

      // Make API request
      final response = await http.post(
        Uri.parse(BASE_URL),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(TIMEOUT);

      print('📥 [GroqService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = responseData['choices'] as List<dynamic>?;
        
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          
          if (content != null && content.isNotEmpty) {
            print('✅ [GroqService] Successfully refined answer');
            return content.trim();
          }
        }

        throw Exception('Empty response from Groq API');
      } else {
        final errorBody = response.body;
        print('❌ [GroqService] API error: ${response.statusCode} - $errorBody');
        
        if (response.statusCode == 401) {
          throw Exception('Invalid API key. Please check your Groq API key in settings.');
        } else if (response.statusCode == 429) {
          throw Exception('Rate limit exceeded. Please try again later.');
        } else {
          throw Exception('Groq API error: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('❌ [GroqService] Error refining answer: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to refine answer: $e');
    }
  }

  // Test API key validity
  static Future<bool> testApiKey(String apiKey) async {
    try {
      print('🧪 [GroqService] Testing API key...');

      final messages = [
        {
          'role': 'user',
          'content': 'Hello',
        }
      ];

      final requestBody = {
        'model': DEFAULT_MODEL,
        'messages': messages,
        'max_tokens': 10,
      };

      final response = await http.post(
        Uri.parse(BASE_URL),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ [GroqService] API key is valid');
        return true;
      } else {
        print('❌ [GroqService] API key test failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ [GroqService] Error testing API key: $e');
      return false;
    }
  }

  // Get available models
  static List<String> getAvailableModels() {
    return [
      DEFAULT_MODEL, // Fast
      QUALITY_MODEL, // Quality
    ];
  }
}

