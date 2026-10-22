import '../models/ai_message.dart';
import '../models/ai_provider_config.dart';
import '../models/ai_tool.dart';

/// Abstract interface for all AI model providers (Gemini, OpenAI, Claude, Ollama, Mock).
abstract class AiProvider {
  /// Provider identifier name (e.g., 'gemini', 'openai', 'claude', 'ollama', 'mock').
  String get name;

  /// Streams token-by-token response chunks from the model.
  Stream<String> streamMessage({
    required List<AiMessage> messages,
    List<AiTool>? tools,
    AiModelConfig? config,
  });

  /// Executes a full non-streaming request and returns the completed [AiResponse].
  Future<AiResponse> sendMessage({
    required List<AiMessage> messages,
    List<AiTool>? tools,
    AiModelConfig? config,
  });
}
