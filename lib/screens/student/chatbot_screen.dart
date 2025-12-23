// FILE: lib/screens/student/chatbot_screen.dart
// HYBRID VERSION - Online Server + Offline RAG Fallback
import 'package:flutter/material.dart';
import '../../services/server_api_service.dart';
import '../../services/offline_rag_service.dart';

class ChatbotScreen extends StatefulWidget {
  final String? pdfContext;
  final String? fileName;

  const ChatbotScreen({
    super.key,
    this.pdfContext,
    this.fileName,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _selectedModel = 'fast';
  
  // Track mode for UI
  String _currentMode = 'online'; // 'online', 'offline_rag'
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add(ChatMessage(
      text: widget.pdfContext != null && widget.pdfContext!.isNotEmpty
          ? "Hi! I've read ${widget.fileName ?? 'your document'}. Ask me anything about it!"
          : "Hi! I'm your AI tutor. How can I help you today?",
      isUser: false,
      isFromDocument: false,
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final userMessage = message.trim();
    setState(() {
      _messages.add(ChatMessage(text: userMessage, isUser: true, isFromDocument: false));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Build history
      final history = <Map<String, String>>[];
      for (int i = 1; i < _messages.length - 1; i++) {
        final msg = _messages[i];
        history.add({
          "role": msg.isUser ? "user" : "assistant",
          "content": msg.text,
        });
      }

      print('💬 Sending chat with ${history.length} history messages');

      // Check if we have document context for RAG fallback
      final canUseRAG = widget.pdfContext != null && widget.pdfContext!.isNotEmpty;

      // TRY ONLINE FIRST (with shorter timeout)
      setState(() => _currentMode = 'online');
      try {
        final response = await ServerAPIService.chat(
          message: userMessage,
          context: widget.pdfContext ?? "",
          history: history,
          model: _selectedModel,
        ).timeout(
          Duration(seconds: 10), // 10 second timeout
          onTimeout: () {
            throw Exception('Request timed out');
          },
        );

        setState(() {
          _messages.add(ChatMessage(
            text: response,
            isUser: false,
            isFromDocument: false,
          ));
          _isLoading = false;
        });

      } catch (onlineError) {
        print('❌ Online chat failed: $onlineError');
        
        // ALWAYS TRY OFFLINE RAG IF WE HAVE A DOCUMENT
        if (canUseRAG) {
          print('🔄 Falling back to Offline RAG...');
          setState(() {
            _currentMode = 'offline_rag';
            _isOfflineMode = true;
          });
          
          try {
            final ragResponse = await OfflineRAGService.answerQuestion(
              question: userMessage,
              documentText: widget.pdfContext,
              conversationHistory: history,
            );
            
            if (ragResponse != null && ragResponse.isNotEmpty) {
              // RAG succeeded
              setState(() {
                _messages.add(ChatMessage(
                  text: "📄 (Offline Mode) $ragResponse",
                  isUser: false,
                  isFromDocument: true,
                ));
                _isLoading = false;
              });
            } else {
              // RAG returned nothing useful
              _addErrorMessage("I couldn't find relevant information in your document to answer that question. Try asking something related to the document content.");
            }
          } catch (ragError) {
            print('❌ RAG also failed: $ragError');
            _addErrorMessage("I'm having trouble processing your question. Please try rephrasing it or check if it's related to the document.");
          }
          
        } else {
          // No document available for RAG fallback
          _addErrorMessage("${_getUserFriendlyError(onlineError.toString())}\n\n💡 Tip: This chat works best with a PDF document loaded.");
        }
      }

      _scrollToBottom();
    } catch (e) {
      print('❌ Unexpected error: $e');
      _addErrorMessage("Something went wrong. Please try again.");
      _scrollToBottom();
    }
  }

  void _addErrorMessage(String errorMessage) {
    setState(() {
      _messages.add(ChatMessage(
        text: errorMessage,
        isUser: false,
        isError: true,
        isFromDocument: false,
      ));
      _isLoading = false;
    });
  }

  String _getUserFriendlyError(String error) {
    if (error.contains('Rate limit')) {
      return "I'm getting too many requests right now. Please wait a moment and try again.";
    } else if (error.contains('timed out')) {
      return "The request took too long. Switching to offline mode...";
    } else if (error.contains('Server error')) {
      return "The AI service is temporarily unavailable. Using offline document search instead.";
    } else if (error.contains('Failed host lookup')) {
      return "No internet connection. Searching your document offline...";
    } else {
      return "I'm having trouble responding right now. Please try again.";
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        text: widget.pdfContext != null && widget.pdfContext!.isNotEmpty
            ? "Hi! I've read ${widget.fileName ?? 'your document'}. Ask me anything about it!"
            : "Hi! I'm your AI tutor. How can I help you today?",
        isUser: false,
        isFromDocument: false,
      ));
      _currentMode = 'online';
      _isOfflineMode = false;
    });
  }

  String get _modeIndicatorText {
    if (_currentMode == 'offline_rag') {
      return '📚 Offline Document Search';
    }
    return '🌐 Online AI Mode';
  }

  String get _loadingText {
    if (_currentMode == 'offline_rag') {
      return 'Searching your document...';
    }
    return 'AI is thinking...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💬 AI Tutor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (widget.fileName != null)
              Text(
                widget.fileName!,
                style: TextStyle(fontSize: 12, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        backgroundColor: Color(0xFF4A90E2),
        actions: [
          if (_messages.length > 1)
            IconButton(
              icon: Icon(Icons.clear_all),
              onPressed: _clearChat,
              tooltip: 'Clear chat',
            ),
          // Model selector (disabled when offline)
          PopupMenuButton<String>(
            icon: Icon(Icons.tune),
            onSelected: _isOfflineMode 
                ? null 
                : (value) => setState(() => _selectedModel = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'fast',
                enabled: !_isOfflineMode,
                child: Row(
                  children: [
                    Icon(Icons.bolt, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text('Fast'),
                    if (_selectedModel == 'fast') ...[
                      Spacer(),
                      Icon(Icons.check, color: Colors.green, size: 16),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'balanced',
                enabled: !_isOfflineMode,
                child: Row(
                  children: [
                    Icon(Icons.balance, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('Balanced'),
                    if (_selectedModel == 'balanced') ...[
                      Spacer(),
                      Icon(Icons.check, color: Colors.green, size: 16),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'best',
                enabled: !_isOfflineMode,
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('Best'),
                    if (_selectedModel == 'best') ...[
                      Spacer(),
                      Icon(Icons.check, color: Colors.green, size: 16),
                    ],
                  ],
                ),
              ),
              if (_isOfflineMode)
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Online models unavailable offline',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Mode indicator (subtle)
          if (_isOfflineMode)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6),
              color: Colors.blue[50],
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 14, color: Colors.grey[700]),
                    SizedBox(width: 6),
                    Text(
                      _modeIndicatorText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.pdfContext != null ? Icons.description : Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          widget.pdfContext != null
                              ? 'Ask questions about your document'
                              : 'Start a conversation with AI',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 8),
                        if (widget.pdfContext != null)
                          Text(
                            'Will work online or offline',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        _isOfflineMode ? Colors.blue : Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    _loadingText,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // Input field
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: widget.pdfContext != null
                            ? 'Ask about your document...'
                            : 'Ask me anything...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _isLoading ? null : (value) => _sendMessage(value),
                      enabled: !_isLoading,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isOfflineMode
                            ? [Colors.blue[400]!, Colors.blue[600]!]
                            : [Color(0xFF4A90E2), Color(0xFF357ABD)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: _isLoading 
                          ? null 
                          : () => _sendMessage(_messageController.text.trim()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: message.isError 
                    ? Colors.red
                    : message.isFromDocument
                      ? Colors.blue
                      : Color(0xFF4A90E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                message.isError 
                    ? Icons.error 
                    : message.isFromDocument
                      ? Icons.search
                      : Icons.smart_toy,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Color(0xFF4A90E2)
                    : message.isError
                        ? Colors.red[50]
                        : message.isFromDocument
                          ? Colors.blue[50]
                          : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft:
                      message.isUser ? Radius.circular(16) : Radius.circular(4),
                  bottomRight:
                      message.isUser ? Radius.circular(4) : Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
                border: message.isError 
                    ? Border.all(color: Colors.red[300]!, width: 1)
                    : message.isFromDocument
                      ? Border.all(color: Colors.blue[100]!, width: 1)
                      : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isFromDocument && !message.isError)
                    Text(
                      '📄 From your document:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                  if (message.isFromDocument && !message.isError) SizedBox(height: 4),
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : message.isError
                              ? Colors.red[800]
                              : Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF66BB6A),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final bool isFromDocument;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.isFromDocument = false,
  });
}