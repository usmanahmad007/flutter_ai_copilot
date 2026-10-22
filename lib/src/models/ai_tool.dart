import 'dart:async';

/// Represents a callable function / tool available for the AI LLM to invoke.
class AiTool {
  /// Unique tool name (e.g., `check_weather`, `navigate_to_screen`, `search_catalog`).
  final String name;

  /// Clear instructions telling the LLM when and why to invoke this tool.
  final String description;

  /// JSON Schema definition of parameters expected by the tool.
  final Map<String, dynamic> parameters;

  /// Dart handler executed when the LLM triggers this tool.
  final Future<dynamic> Function(Map<String, dynamic> arguments) handler;

  const AiTool({
    required this.name,
    required this.description,
    this.parameters = const {
      'type': 'object',
      'properties': {},
    },
    required this.handler,
  });

  /// Formats the tool schema for OpenAI / Gemini function calling declarations.
  Map<String, dynamic> toJsonSchema() => {
        'name': name,
        'description': description,
        'parameters': parameters,
      };

  /// Formats for Gemini function declarations.
  Map<String, dynamic> toGeminiDeclaration() => {
        'name': name,
        'description': description,
        'parameters': parameters,
      };

  /// Formats for OpenAI tools array.
  Map<String, dynamic> toOpenAiTool() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}
