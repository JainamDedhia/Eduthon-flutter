// FILE: lib/services/rag_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/rag_models.dart';
import 'vector_store.dart';
import 'groq_service.dart';

class RAGService {
  static const int DEFAULT_TOP_K = 5;
  static const int MAX_CONTEXT_LENGTH = 3000;

  // Main RAG query method - Automatically uses online if available, offline otherwise
  static Future<String> query(
    String userQuery, {
    bool useOnline = true, // Default to true - will auto-detect
    int topK = DEFAULT_TOP_K,
    List<ChatMessage>? history,
  }) async {
    try {
      print('💬 [RAGService] Processing query: "$userQuery"');

      // Check connectivity and API availability
      final isOnline = await _checkConnectivity();
      final hasGroqKey = await GroqService.checkApiKey();
      
      // Auto-detect: use online if available (override useOnline parameter if online and has key)
      // This ensures Groq is used whenever possible
      final shouldUseOnline = (useOnline || (isOnline && hasGroqKey)) && isOnline && hasGroqKey;
      print('🌐 [RAGService] Connectivity: $isOnline, Groq Key: $hasGroqKey, useOnline param: $useOnline, Will Use Online: $shouldUseOnline');

      // Handle greetings, formalities, and conversational inputs
      final lowerQuery = userQuery.toLowerCase().trim();
      final response = await _handleConversationalInput(lowerQuery, shouldUseOnline);
      if (response != null) {
        return response;
      }

      // Step 1: Search knowledge base for relevant text from downloaded PDFs
      final totalChunks = await VectorStore.getTotalChunks();
      List<SearchResult> searchResults = [];
      String context = '';
      
      if (totalChunks > 0) {
        // Search for relevant chunks related to the question
        searchResults = await VectorStore.searchSimilar(userQuery, topK);
        if (searchResults.isNotEmpty) {
          // Format context from retrieved chunks - this is the relevant text from PDFs
          context = formatContext(searchResults);
          print('📚 [RAGService] Found ${searchResults.length} relevant chunks from knowledge base');
          print('📄 [RAGService] Context length: ${context.length} characters');
        } else {
          print('📚 [RAGService] No relevant chunks found in knowledge base for this question');
        }
      } else {
        print('📚 [RAGService] Knowledge base is empty (no indexed PDFs)');
      }

      // Step 2: Always use Groq API if online - send question + relevant text
      if (shouldUseOnline) {
        print('🌐 [RAGService] Using Groq API');
        print('   Question: "$userQuery"');
        print('   Context available: ${context.isNotEmpty} (${context.length} chars)');
        print('   Relevant chunks: ${searchResults.length}');
        
        try {
          final historyMessages = history?.map((m) => {
            'role': m.role,
            'content': m.content,
          }).toList() ?? [];

          // Always send to Groq:
          // - If context exists: question + relevant PDF text
          // - If no context: question only (Groq can still answer)
          final answer = await GroqService.refineAnswer(
            query: userQuery,
            context: context, // Will be empty if no chunks found, but Groq will still answer
            history: historyMessages,
          );
          print('✅ [RAGService] Groq API response received (${answer.length} chars)');
          return answer;
        } catch (e) {
          print('⚠️ [RAGService] Groq API failed: $e');
          print('   Falling back to offline mode...');
          // Fall through to offline answer generation
        }
      }

      // Offline mode: need context from knowledge base
      if (totalChunks == 0) {
        return 'I don\'t have any content indexed yet. Please download some PDFs first, and they will be automatically indexed. Once indexed, I can answer questions about your materials!';
      }

      if (searchResults.isEmpty) {
        return 'I couldn\'t find relevant information for "$userQuery" in your downloaded materials. Try:\n\n• Rephrasing your question\n• Using keywords from your PDFs\n• Asking about specific topics from your course materials\n\nMake sure the relevant PDFs are downloaded and indexed.';
      } else {
        print('📱 [RAGService] Skipping Groq API - Online: $isOnline, HasKey: $hasGroqKey, useOnline param: $useOnline');
      }

      // Generate offline answer
      print('📱 [RAGService] Using offline answer generation');
      return generateLocalAnswer(userQuery, context);
    } catch (e) {
      print('❌ [RAGService] Error processing query: $e');
      return 'Sorry, I encountered an error while processing your question. Please try again.';
    }
  }

  // Handle greetings, formalities, and conversational inputs
  static Future<String?> _handleConversationalInput(String lowerQuery, bool isOnline) async {
    // Greetings
    if (lowerQuery.contains('hi') || 
        lowerQuery.contains('hello') || 
        lowerQuery.contains('hey') ||
        lowerQuery.contains('hii') ||
        lowerQuery.contains('namaste') ||
        lowerQuery.contains('namaskar')) {
      final totalChunks = await VectorStore.getTotalChunks();
      final mode = isOnline ? 'online (Groq AI)' : 'offline';
      if (totalChunks == 0) {
        return 'Hello! 👋 I\'m your study assistant. I can help you find information from all your downloaded PDFs. Please download some PDFs first, and they will be automatically indexed. Then ask me questions about the content! Currently running in $mode mode.';
      } else {
        return 'Hello! 👋 I\'m your study assistant. I have access to ${totalChunks} indexed chunks from all your downloaded PDFs. Ask me anything about your course materials! Currently running in $mode mode.';
      }
    }

    // Name/Introduction
    if (lowerQuery.contains('my self') || 
        lowerQuery.contains('my name') ||
        lowerQuery.contains('i am') ||
        lowerQuery.contains('i\'m') ||
        lowerQuery.contains('this is')) {
      return 'Nice to meet you! 👋 I\'m your study assistant. I can help you find information from all your downloaded PDFs. What would you like to know about your course materials?';
    }

    // Thanks/Gratitude
    if (lowerQuery.contains('thank') || 
        lowerQuery.contains('thanks') ||
        lowerQuery.contains('dhanyavad')) {
      return 'You\'re welcome! 😊 Feel free to ask me anything about your downloaded PDFs. I\'m here to help!';
    }

    // Goodbye
    if (lowerQuery.contains('bye') || 
        lowerQuery.contains('goodbye') ||
        lowerQuery.contains('see you') ||
        lowerQuery.contains('tata')) {
      return 'Goodbye! 👋 Feel free to come back anytime if you have questions about your course materials!';
    }

    // How are you / Status
    if (lowerQuery.contains('how are you') || 
        lowerQuery.contains('how do you do') ||
        lowerQuery.contains('what\'s up')) {
      final totalChunks = await VectorStore.getTotalChunks();
      final mode = isOnline ? 'online with Groq AI' : 'offline';
      return 'I\'m doing great! 😊 I\'m ready to help you with your studies. I have ${totalChunks} chunks indexed from your PDFs and I\'m running in $mode mode. What would you like to know?';
    }

    // What can you do
    if (lowerQuery.contains('what can you') || 
        lowerQuery.contains('what do you') ||
        lowerQuery.contains('help me') ||
        lowerQuery.contains('capabilities')) {
      final totalChunks = await VectorStore.getTotalChunks();
      return 'I can help you:\n\n• Answer questions from your downloaded PDFs\n• Explain concepts from your course materials\n• Find specific information across all your files\n• Provide summaries and explanations\n\nI currently have ${totalChunks} chunks indexed from your PDFs. Ask me anything!';
    }

    return null; // Not a conversational input, proceed with RAG
  }

  // Format context from search results
  static String formatContext(List<SearchResult> results) {
    if (results.isEmpty) return '';

    final buffer = StringBuffer();
    
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      final chunk = result.chunk;
      
      buffer.writeln('--- Source ${i + 1}: ${chunk.fileName} (Class: ${chunk.classCode}) ---');
      buffer.writeln(chunk.text);
      buffer.writeln();
    }

    final context = buffer.toString();
    
    // Truncate if too long
    if (context.length > MAX_CONTEXT_LENGTH) {
      return context.substring(0, MAX_CONTEXT_LENGTH) + '...';
    }

    return context;
  }

  // Generate local answer using template-based approach
  static String generateLocalAnswer(String query, String context) {
    if (context.isEmpty) {
      return 'I couldn\'t find relevant information to answer your question.';
    }

    // Simple template-based answer generation
    // Extract key sentences from context that match query terms
    final queryTerms = query.toLowerCase().split(' ').where((t) => t.length > 2).toList();
    final contextSentences = context.split(RegExp(r'[.!?]\s+'));
    
    final relevantSentences = <String>[];
    for (final sentence in contextSentences) {
      final lowerSentence = sentence.toLowerCase();
      int matchCount = 0;
      for (final term in queryTerms) {
        if (lowerSentence.contains(term)) {
          matchCount++;
        }
      }
      if (matchCount > 0) {
        relevantSentences.add(sentence.trim());
      }
    }

    if (relevantSentences.isEmpty) {
      // Fallback: return first few sentences from context
      final fallbackSentences = contextSentences.take(3).toList();
      return 'Based on your materials:\n\n${fallbackSentences.join('. ')}.';
    }

    // Combine relevant sentences
    final answer = relevantSentences.take(5).join('. ');
    
    return 'Based on your downloaded materials:\n\n$answer.';
  }

  // Check connectivity
  static Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  // Check if knowledge base is ready
  static Future<bool> isKnowledgeBaseReady() async {
    final totalChunks = await VectorStore.getTotalChunks();
    return totalChunks > 0;
  }

  // Get statistics about the knowledge base
  static Future<Map<String, dynamic>> getKnowledgeBaseStats() async {
    try {
      final totalChunks = await VectorStore.getTotalChunks();
      final indexedFiles = await VectorStore.getTotalChunks(); // This is approximate
      
      return {
        'totalChunks': totalChunks,
        'indexedFiles': indexedFiles,
        'isReady': totalChunks > 0,
      };
    } catch (e) {
      return {
        'totalChunks': 0,
        'indexedFiles': 0,
        'isReady': false,
      };
    }
  }
}

