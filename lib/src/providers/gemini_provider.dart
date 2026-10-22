import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/ai_message.dart';
import '../models/ai_provider_config.dart';
import '../models/ai_tool.dart';
import 'base_provider.dart';

/// Alias for [GeminiProvider].
typedef GeminiAiProvider = GeminiProvider;

/// Server-Sent Events (SSE) streaming, multimodal vision, and function calling.
class GeminiProvider implements AiProvider {
  final String apiKey;
  final String defaultModel;
  final http.Client _client;

  GeminiProvider({
    required this.apiKey,
    String? defaultModel,
    String? modelName,
    http.Client? client,
  })  : defaultModel = defaultModel ?? modelName ?? 'gemini-1.5-flash',
        _client = client ?? http.Client();

  @override
  String get name => 'gemini';

  @override
  Stream<String> streamMessage({
    required List<AiMessage> messages,
    List<AiTool>? tools,
    AiModelConfig? config,
  }) async* {
    final model = config?.modelName ?? defaultModel;
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse&key=$apiKey',
    );

    final requestBody = _buildRequestBody(messages, tools, config);

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(requestBody);

    final response = await _client.send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception('Gemini API Error (${response.statusCode}): $errorBody');
    }

    final lines =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      if (line.startsWith('data: ')) {
        final jsonStr = line.substring(6).trim();
        if (jsonStr.isEmpty) continue;
        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts != null) {
              for (final part in parts) {
                final text = part['text'] as String?;
                if (text != null && text.isNotEmpty) {
                  yield text;
                }
              }
            }
          }
        } catch (_) {}
      }
    }
  }

  @override
  Future<AiResponse> sendMessage({
    required List<AiMessage> messages,
    List<AiTool>? tools,
    AiModelConfig? config,
  }) async {
    final model = config?.modelName ?? defaultModel;
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final requestBody = _buildRequestBody(messages, tools, config);

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini API Error (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;

    String fullText = '';
    final toolCalls = <AiToolCall>[];

    if (candidates != null && candidates.isNotEmpty) {
      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts != null) {
        for (final part in parts) {
          if (part.containsKey('text')) {
            fullText += part['text'] as String;
          }
          if (part.containsKey('functionCall')) {
            final call = part['functionCall'] as Map<String, dynamic>;
            toolCalls.add(
              AiToolCall(
                id: 'gemini_call_${DateTime.now().millisecondsSinceEpoch}',
                name: call['name'] as String,
                arguments: (call['args'] as Map<String, dynamic>?) ?? {},
              ),
            );
          }
        }
      }
    }

    return AiResponse(
      content: fullText,
      toolCalls: toolCalls,
      usage: data['usageMetadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> _buildRequestBody(
    List<AiMessage> messages,
    List<AiTool>? tools,
    AiModelConfig? config,
  ) {
    final contents = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg.role == AiRole.system) continue; // Handled in systemInstruction

      final parts = <Map<String, dynamic>>[];

      // Multimodal image attachments
      for (final att in msg.attachments) {
        if (att.base64Data != null) {
          parts.add({
            'inlineData': {
              'mimeType': att.mimeType,
              'data': att.base64Data,
            },
          });
        }
      }

      if (msg.content.isNotEmpty) {
        parts.add({'text': msg.content});
      }

      // Tool result feedback
      for (final res in msg.toolResults) {
        parts.add({
          'functionResponse': {
            'name': res.name,
            'response': {'result': res.result},
          },
        });
      }

      // Tool call request
      for (final call in msg.toolCalls) {
        parts.add({
          'functionCall': {
            'name': call.name,
            'args': call.arguments,
          },
        });
      }

      final role = msg.role == AiRole.assistant ? 'model' : 'user';
      if (parts.isNotEmpty) {
        contents.add({
          'role': role,
          'parts': parts,
        });
      }
    }

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': config?.temperature ?? 0.7,
        if (config?.topP != null) 'topP': config!.topP,
        if (config?.maxTokens != null) 'maxOutputTokens': config!.maxTokens,
      },
    };

    // System prompt
    if (config?.systemPrompt != null && config!.systemPrompt!.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': config.systemPrompt!}
        ],
      };
    }

    // Tools / Function Declarations
    if (tools != null && tools.isNotEmpty) {
      body['tools'] = [
        {
          'functionDeclarations':
              tools.map((t) => t.toGeminiDeclaration()).toList(),
        }
      ];
    }

    return body;
  }
}
