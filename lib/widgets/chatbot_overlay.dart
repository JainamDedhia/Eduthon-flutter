// FILE: lib/widgets/chatbot_overlay.dart
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/rag_models.dart';
import '../services/rag_service.dart';
import '../services/groq_service.dart';
import '../services/knowledge_indexer.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ChatbotOverlay extends StatefulWidget {
  final bool isOnline;

  const ChatbotOverlay({
    super.key,
    required this.isOnline,
  });

  @override
  State<ChatbotOverlay> createState() => _ChatbotOverlayState();
}

class _ChatbotOverlayState extends State<ChatbotOverlay> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _useOnlineMode = true; // Default to true - will auto-detect in RAGService
  bool _hasGroqKey = false;

  @override
  void initState() {
    super.initState();
    _checkGroqKey();
    _checkKnowledgeBase();
    _addWelcomeMessage();
  }

  Future<void> _checkKnowledgeBase() async {
    // Check if knowledge base is ready
    final isReady = await RAGService.isKnowledgeBaseReady();
    if (!isReady) {
      // Show message about indexing
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: 'assistant',
            content: '📚 I\'m checking your downloaded PDFs. If you have PDFs downloaded, they should be automatically indexed. If indexing hasn\'t started, please go back to the dashboard and wait a moment, or download a PDF to trigger indexing.',
            timestamp: DateTime.now(),
          ));
        });
      }
    }
  }

  Future<void> _checkGroqKey() async {
    final hasKey = await GroqService.checkApiKey();
    setState(() {
      _hasGroqKey = hasKey;
      // Auto-enable online mode if online and has key
      // RAGService will handle actual connectivity check
      _useOnlineMode = widget.isOnline && hasKey;
    });
    print('🔑 [ChatbotOverlay] Groq Key: $hasKey, Online: ${widget.isOnline}, UseOnlineMode: $_useOnlineMode');
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'assistant',
      content: 'Hello! I\'m your study assistant. I can help you find information from your downloaded PDFs. Ask me anything!',
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final query = _messageController.text.trim();
    if (query.isEmpty || _isLoading) return;

    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: query,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    // Add loading message
    final loadingMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    final loadingMessage = ChatMessage(
      id: loadingMessageId,
      role: 'assistant',
      content: 'Thinking...',
      timestamp: DateTime.now(),
      isLoading: true,
    );
    setState(() {
      _messages.add(loadingMessage);
    });
    _scrollToBottom();

    try {
      // Get conversation history (exclude loading messages)
      final history = _messages
          .where((m) => !m.isLoading)
          .map((m) => {
                'role': m.role,
                'content': m.content,
              })
          .toList();

      // Query RAG service - automatically uses online if available
      final answer = await RAGService.query(
        query,
        useOnline: _useOnlineMode, // Will auto-detect and use online if available
        history: _messages.where((m) => !m.isLoading).toList(),
      );

      // Remove loading message and add answer
      setState(() {
        _messages.removeWhere((m) => m.id == loadingMessageId);
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: answer,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    } catch (e) {
      // Remove loading message and add error
      setState(() {
        _messages.removeWhere((m) => m.id == loadingMessageId);
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: 'Sorry, I encountered an error: $e',
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  Future<void> _showSettings() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SettingsSheet(
        hasGroqKey: _hasGroqKey,
        useOnlineMode: _useOnlineMode,
        isOnline: widget.isOnline,
      ),
    );

    if (result != null) {
      await _checkGroqKey();
      if (mounted) {
        setState(() {
          _useOnlineMode = result['useOnline'] ?? false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study Assistant',
                        style: AppTextStyles.title.copyWith(color: Colors.white),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: widget.isOnline ? AppColors.success : AppColors.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.isOnline ? 'Online' : 'Offline',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          if (_hasGroqKey && widget.isOnline) ...[
                            const SizedBox(width: 12),
                            const Text(
                              '• Groq Enabled',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: _showSettings,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _MessageBubble(message: message);
                    },
                  ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
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
                        hintText: 'Ask a question...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: AppColors.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: AppColors.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isLoading ? null : _sendMessage,
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
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surfaceMuted,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: message.isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isUser ? Colors.white : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isUser ? Colors.white : AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  final bool hasGroqKey;
  final bool useOnlineMode;
  final bool isOnline;

  const _SettingsSheet({
    required this.hasGroqKey,
    required this.useOnlineMode,
    required this.isOnline,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late bool _useOnlineMode;
  final TextEditingController _apiKeyController = TextEditingController();
  bool _testingKey = false;

  @override
  void initState() {
    super.initState();
    _useOnlineMode = widget.useOnlineMode;
    if (widget.hasGroqKey) {
      GroqService.getApiKey().then((key) {
        if (key != null) {
          _apiKeyController.text = key;
        }
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testAndSaveApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API key')),
      );
      return;
    }

    setState(() => _testingKey = true);

    try {
      final isValid = await GroqService.testApiKey(apiKey);
      if (isValid) {
        await GroqService.saveApiKey(apiKey);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('API key saved successfully!')),
          );
          Navigator.pop(context, {'useOnline': _useOnlineMode});
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid API key. Please check and try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _testingKey = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chatbot Settings',
            style: AppTextStyles.title,
          ),
          const SizedBox(height: 24),
          Text(
            'Groq API Key',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            decoration: InputDecoration(
              hintText: 'Enter your Groq API key',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _testingKey
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: _testAndSaveApiKey,
                    ),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Get your API key from https://console.groq.com',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 24),
          if (widget.isOnline && widget.hasGroqKey)
            SwitchListTile(
              title: const Text('Use Online Mode (Groq)'),
              subtitle: const Text('Enable AI-powered answer refinement'),
              value: _useOnlineMode,
              onChanged: (value) {
                setState(() => _useOnlineMode = value);
              },
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {'useOnline': _useOnlineMode});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

