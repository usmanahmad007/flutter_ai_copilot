import '../context/screen_context.dart';
import '../models/ai_message.dart';

/// Represents a persistent conversational session.
class AiChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<AiMessage> messages;
  final AiScreenContext? screenContext;

  AiChatSession({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AiMessage>? messages,
    this.screenContext,
  })  : id = id ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
        title = title ?? 'New Conversation',
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
        if (screenContext != null) 'screenContext': screenContext!.toJson(),
      };

  factory AiChatSession.fromJson(Map<String, dynamic> json) => AiChatSession(
        id: json['id'] as String?,
        title: json['title'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
        messages: (json['messages'] as List<dynamic>?)
                ?.map((m) => AiMessage.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        screenContext: json['screenContext'] != null
            ? AiScreenContext.fromJson(
                json['screenContext'] as Map<String, dynamic>)
            : null,
      );
}

/// Abstract contract for conversational history persistence.
abstract class AiChatStorageEngine {
  /// Persists or updates a session.
  Future<void> saveSession(AiChatSession session);

  /// Loads a session by its unique ID.
  Future<AiChatSession?> loadSession(String sessionId);

  /// Lists all saved sessions ordered by most recently updated.
  Future<List<AiChatSession>> listSessions();

  /// Deletes a session by ID.
  Future<void> deleteSession(String sessionId);

  /// Clears all stored sessions.
  Future<void> clearAll();
}

/// Default volatile in-memory storage engine.
class InMemoryStorageEngine implements AiChatStorageEngine {
  final Map<String, AiChatSession> _sessions = {};

  @override
  Future<void> saveSession(AiChatSession session) async {
    session.updatedAt = DateTime.now();
    _sessions[session.id] = session;
  }

  @override
  Future<AiChatSession?> loadSession(String sessionId) async {
    return _sessions[sessionId];
  }

  @override
  Future<List<AiChatSession>> listSessions() async {
    final list = _sessions.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _sessions.remove(sessionId);
  }

  @override
  Future<void> clearAll() async {
    _sessions.clear();
  }
}
