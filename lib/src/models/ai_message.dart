import 'dart:convert';
import 'dart:typed_data';

/// The role of a message participant in the AI conversation.
enum AiRole {
  user,
  assistant,
  system,
  tool,
}

/// A media attachment (image, document, audio) sent with a message.
class AiAttachment {
  final String name;
  final String mimeType;
  final Uint8List? bytes;
  final String? url;

  const AiAttachment({
    required this.name,
    required this.mimeType,
    this.bytes,
    this.url,
  });

  /// Base64 representation of the attachment if bytes are present.
  String? get base64Data => bytes != null ? base64Encode(bytes!) : null;

  Map<String, dynamic> toJson() => {
        'name': name,
        'mimeType': mimeType,
        if (url != null) 'url': url,
        if (bytes != null) 'bytesLength': bytes!.length,
      };

  factory AiAttachment.fromJson(Map<String, dynamic> json) => AiAttachment(
        name: json['name'] as String? ?? 'file',
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        url: json['url'] as String?,
      );
}

/// Lifecycle status of a tool call request.
enum AiToolCallStatus {
  pendingApproval,
  approved,
  rejected,
  executing,
  completed,
  failed,
}

/// Represents an LLM tool / function call invocation request.
class AiToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  AiToolCallStatus status;
  String? rejectionReason;
  String? riskLevel;

  AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.status = AiToolCallStatus.completed,
    this.rejectionReason,
    this.riskLevel,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'arguments': arguments,
        'status': status.name,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        if (riskLevel != null) 'riskLevel': riskLevel,
      };

  factory AiToolCall.fromJson(Map<String, dynamic> json) => AiToolCall(
        id: json['id'] as String? ??
            'tool_${DateTime.now().millisecondsSinceEpoch}',
        name: json['name'] as String,
        arguments: json['arguments'] is String
            ? jsonDecode(json['arguments'] as String) as Map<String, dynamic>
            : (json['arguments'] as Map<String, dynamic>? ?? {}),
        status: json['status'] != null
            ? AiToolCallStatus.values.firstWhere(
                (s) => s.name == json['status'],
                orElse: () => AiToolCallStatus.completed,
              )
            : AiToolCallStatus.completed,
        rejectionReason: json['rejectionReason'] as String?,
        riskLevel: json['riskLevel'] as String?,
      );
}

/// Represents the output of an executed tool call.
class AiToolResult {
  final String toolCallId;
  final String name;
  final dynamic result;
  final bool isError;

  const AiToolResult({
    required this.toolCallId,
    required this.name,
    required this.result,
    this.isError = false,
  });

  Map<String, dynamic> toJson() => {
        'toolCallId': toolCallId,
        'name': name,
        'result': result,
        'isError': isError,
      };
}

/// A single message in the AI Copilot conversation.
class AiMessage {
  final String id;
  final AiRole role;
  String content;
  final DateTime timestamp;
  final List<AiAttachment> attachments;
  final List<AiToolCall> toolCalls;
  final List<AiToolResult> toolResults;
  bool isStreaming;
  final Map<String, dynamic>? metadata;

  AiMessage({
    String? id,
    required this.role,
    this.content = '',
    DateTime? timestamp,
    List<AiAttachment>? attachments,
    List<AiToolCall>? toolCalls,
    List<AiToolResult>? toolResults,
    this.isStreaming = false,
    this.metadata,
  })  : id = id ?? 'msg_${DateTime.now().microsecondsSinceEpoch}',
        timestamp = timestamp ?? DateTime.now(),
        attachments = attachments ?? [],
        toolCalls = toolCalls ?? [],
        toolResults = toolResults ?? [];

  /// Helper factory for user messages.
  factory AiMessage.user(String content, {List<AiAttachment>? attachments}) =>
      AiMessage(
        role: AiRole.user,
        content: content,
        attachments: attachments,
      );

  /// Helper factory for assistant messages.
  factory AiMessage.assistant(String content, {bool isStreaming = false}) =>
      AiMessage(
        role: AiRole.assistant,
        content: content,
        isStreaming: isStreaming,
      );

  /// Helper factory for system messages.
  factory AiMessage.system(String content) => AiMessage(
        role: AiRole.system,
        content: content,
      );

  /// Helper factory for tool result messages.
  factory AiMessage.tool({
    required String toolCallId,
    required String name,
    required dynamic result,
    bool isError = false,
  }) =>
      AiMessage(
        role: AiRole.tool,
        toolResults: [
          AiToolResult(
            toolCallId: toolCallId,
            name: name,
            result: result,
            isError: isError,
          ),
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'toolCalls': toolCalls.map((t) => t.toJson()).toList(),
        'toolResults': toolResults.map((r) => r.toJson()).toList(),
      };

  factory AiMessage.fromJson(Map<String, dynamic> json) => AiMessage(
        id: json['id'] as String?,
        role: AiRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => AiRole.user,
        ),
        content: json['content'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        attachments: (json['attachments'] as List<dynamic>?)
            ?.map((a) => AiAttachment.fromJson(a as Map<String, dynamic>))
            .toList(),
        toolCalls: (json['toolCalls'] as List<dynamic>?)
            ?.map((t) => AiToolCall.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
