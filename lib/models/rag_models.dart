// RAG Models for Chatbot
class KnowledgeChunk {
  final String id;
  final String classCode;
  final String fileName;
  final int chunkIndex;
  final String text;
  final String timestamp;
  final Map<String, double> tfidfVector; // Term -> TF-IDF score

  KnowledgeChunk({
    required this.id,
    required this.classCode,
    required this.fileName,
    required this.chunkIndex,
    required this.text,
    required this.timestamp,
    required this.tfidfVector,
  });

  factory KnowledgeChunk.fromJson(Map<String, dynamic> json) {
    return KnowledgeChunk(
      id: json['id'] ?? '',
      classCode: json['classCode'] ?? '',
      fileName: json['fileName'] ?? '',
      chunkIndex: json['chunkIndex'] ?? 0,
      text: json['text'] ?? '',
      timestamp: json['timestamp'] ?? '',
      tfidfVector: Map<String, double>.from(
        json['tfidfVector'] ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'classCode': classCode,
      'fileName': fileName,
      'chunkIndex': chunkIndex,
      'text': text,
      'timestamp': timestamp,
      'tfidfVector': tfidfVector,
    };
  }
}

class SearchResult {
  final KnowledgeChunk chunk;
  final double similarityScore;

  SearchResult({
    required this.chunk,
    required this.similarityScore,
  });
}

class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isLoading;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isLoading = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isLoading: json['isLoading'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isLoading': isLoading,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    bool? isLoading,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

