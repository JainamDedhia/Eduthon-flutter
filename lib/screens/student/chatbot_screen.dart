// FILE: lib/screens/student/chatbot_screen.dart
// FIXED VERSION - Better error handling and history management
import 'package:flutter/material.dart';
import '../../services/server_api_service.dart';

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

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add(ChatMessage(
      text: widget.pdfContext != null && widget.pdfContext!.isNotEmpty
          ? "Hi! I've read ${widget.fileName ?? 'your document'}. Ask me anything about it!"
          : "Hi! I'm your AI tutor. How can I help you today?",
      isUser: false,
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
      _messages.add(ChatMessage(text: userMessage, isUser: true));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Build history for API - FIXED: Only include actual conversation
      final history = <Map<String, String>>[];
      
      // Add previous messages (skip welcome message at index 0)
      for (int i = 1; i < _messages.length - 1; i++) {
        final msg = _messages[i];
        history.add({
          "role": msg.isUser ? "user" : "assistant",
          "content": msg.text,
        });
      }

      print('💬 Sending chat with ${history.length} history messages');

      // Call chatbot API
      final response = await ServerAPIService.chat(
        message: userMessage,
        context: widget.pdfContext ?? "",
        history: history,
        model: _selectedModel,
      );

      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
        ));
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      print('❌ Chat error: $e');
      
      // Show user-friendly error message
      String errorMessage;
      if (e.toString().contains('Rate limit')) {
        errorMessage = "I'm getting too many requests right now. Please wait a moment and try again.";
      } else if (e.toString().contains('timed out')) {
        errorMessage = "The request took too long. Please check your connection and try again.";
      } else if (e.toString().contains('Server error')) {
        errorMessage = "The AI service is temporarily unavailable. Please try again in a few moments.";
      } else {
        errorMessage = "I'm having trouble responding right now. Please try again.\n\nError: ${e.toString().split(':').last.trim()}";
      }
      
      setState(() {
        _messages.add(ChatMessage(
          text: errorMessage,
          isUser: false,
          isError: true,
        ));
        _isLoading = false;
      });
      
      _scrollToBottom();
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
      // Add welcome message back
      _messages.add(ChatMessage(
        text: widget.pdfContext != null && widget.pdfContext!.isNotEmpty
            ? "Hi! I've read ${widget.fileName ?? 'your document'}. Ask me anything about it!"
            : "Hi! I'm your AI tutor. How can I help you today?",
        isUser: false,
      ));
    });
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
          // Clear chat button
          if (_messages.length > 1)
            IconButton(
              icon: Icon(Icons.clear_all),
              onPressed: _clearChat,
              tooltip: 'Clear chat',
            ),
          // Model selector
          PopupMenuButton<String>(
            icon: Icon(Icons.tune),
            onSelected: (value) => setState(() => _selectedModel = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'fast',
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
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'Start a conversation with AI',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
                      valueColor: AlwaysStoppedAnimation(Color(0xFF4A90E2)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'AI is thinking...',
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
                        hintText: 'Ask me anything...',
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
                        colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
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
                color: message.isError ? Colors.red : Color(0xFF4A90E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                message.isError ? Icons.error : Icons.smart_toy, 
                color: Colors.white, 
                size: 20
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
                    : null,
              ),
              child: Text(
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

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}