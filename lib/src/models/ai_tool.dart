import 'dart:async';

/// Execution mode governing whether the AI tool executes autonomously or requires
/// explicit Human-in-the-Loop user approval.
enum AiToolExecutionMode {
  /// Tool executes immediately without prompting the user.
  automatic,

  /// Tool execution halts and requires explicit user confirmation via an Approval Card.
  requiresApproval,
}

/// Risk level classification for Human-in-the-Loop safety auditing.
enum AiToolRiskLevel {
  /// Read-only queries with zero side effects.
  low,

  /// Reversible mutations (e.g. adding item to cart, bookmarking, changing theme).
  medium,

  /// Irreversible or sensitive actions (e.g. monetary payments, deleting data, password resets).
  high,
}

/// Represents a callable function / tool available for the AI LLM to invoke.
class AiTool {
  /// Unique tool name (e.g., `check_weather`, `navigate_to_screen`, `transfer_funds`).
  final String name;

  /// Clear instructions telling the LLM when and why to invoke this tool.
  final String description;

  /// JSON Schema definition of parameters expected by the tool.
  final Map<String, dynamic> parameters;

  /// Dart handler executed when the LLM triggers this tool.
  final Future<dynamic> Function(Map<String, dynamic> arguments) handler;

  /// Whether this tool runs automatically or requires user confirmation.
  final AiToolExecutionMode executionMode;

  /// Risk assessment level of the tool.
  final AiToolRiskLevel riskLevel;

  /// Optional custom message displayed to the user during Human-in-the-Loop approval.
  final String Function(Map<String, dynamic> arguments)? confirmationMessage;

  const AiTool({
    required this.name,
    required this.description,
    this.parameters = const {
      'type': 'object',
      'properties': {},
    },
    required this.handler,
    this.executionMode = AiToolExecutionMode.automatic,
    this.riskLevel = AiToolRiskLevel.low,
    this.confirmationMessage,
  });

  /// True if this tool requires interactive user confirmation before running.
  bool get requiresApproval =>
      executionMode == AiToolExecutionMode.requiresApproval;

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
