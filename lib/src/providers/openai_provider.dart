import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/ai_message.dart';
import '../models/ai_provider_config.dart';
import '../models/ai_tool.dart';
import 'base_provider.dart';

/// OpenAI API provider compatible with GPT-4o, GPT-4o-mini, and any OpenAI-compatible
/// endpoint (Groq, OpenRouter, vLLM, LMStudio, LocalAI).
class OpenAiProvider implements AiProvider {
  final String apiKey;
  final String defaultModel;
  final String baseUrl;
  final http.Client _client;

  OpenAiProvider({
    required this.apiKey,
    String? defaultModel,
    String? modelName,
    this.baseUrl = 'https://api.openai.com/v1',
    http.Client? client,
  })  : defaultModel = defaultModel ?? modelName ?? 'gpt-4o',
        _client = client ?? http.Client();

  @override
  String get name => 'openai';

  @override
  Stream<String> streamMessage({
    required List<AiMessage> messages,
    List<AiTool>? tools,
    AiModelConfig? config,
  }) async* {
    final url = Uri.parse('$baseUrl/chat/completions');
    final requestBody =
        _buildRequestBody(messages, tools, config, stream: true);

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..body = jsonEncode(requestBody);

    final response = await _client.send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception('OpenAI API Error (${response.statusCode}): $errorBody');
    }

    final lines =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      if (line.startsWith('data: ')) {
        final jsonStr = line.substring(6).trim();
        if (jsonStr == '[DONE]') break;
        if (jsonStr.isEmpty) continue;
        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>?;
            final text = delta?['content'] as String?;
            if (text != null && text.isNotEmpty) {
              yield text;
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
    final url = Uri.parse('$baseUrl/chat/completions');
    final requestBody =
        _buildRequestBody(messages, tools, config, stream: false);

    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'OpenAI API Error (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;

    String content = '';
    final toolCalls = <AiToolCall>[];

    if (choices != null && choices.isNotEmpty) {
      final message = choices[0]['message'] as Map<String, dynamic>?;
      content = message?['content'] as String? ?? '';

      final rawCalls = message?['tool_calls'] as List<dynamic>?;
      if (rawCalls != null) {
        for (final call in rawCalls) {
          final fn = call['function'] as Map<String, dynamic>;
          final argsStr = fn['arguments'] as String? ?? '{}';
          Map<String, dynamic> args = {};
          try {
            args = jsonDecode(argsStr) as Map<String, dynamic>;
          } catch (_) {}

          toolCalls.add(
            AiToolCall(
              id: call['id'] as String? ??
                  'call_${DateTime.now().millisecondsSinceEpoch}',
              name: fn['name'] as String,
              arguments: args,
            ),
          );
        }
      }
    }

    return AiResponse(
      content: content,
      toolCalls: toolCalls,
      usage: data['usage'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> _buildRequestBody(
    List<AiMessage> messages,
    List<AiTool>? tools,
    AiModelConfig? config, {
    required bool stream,
  }) {
    final formattedMessages = <Map<String, dynamic>>[];

    // System prompt
    if (config?.systemPrompt != null && config!.systemPrompt!.isNotEmpty) {
      formattedMessages.add({
        'role': 'system',
        'content': config.systemPrompt!,
      });
    }

    for (final msg in messages) {
      if (msg.role == AiRole.system) {
        formattedMessages.add({'role': 'system', 'content': msg.content});
      } else if (msg.role == AiRole.user) {
        if (msg.attachments.isEmpty) {
          formattedMessages.add({'role': 'user', 'content': msg.content});
        } else {
          // Multimodal message structure
          final parts = <Map<String, dynamic>>[];
          if (msg.content.isNotEmpty) {
            parts.add({'type': 'text', 'text': msg.content});
          }
          for (final att in msg.attachments) {
            if (att.base64Data != null) {
              parts.add({
                'type': 'image_url',
                'image_url': {
                  'url': 'data:${att.mimeType};base64,${att.base64Data}',
                },
              });
            } else if (att.url != null) {
              parts.add({
                'type': 'image_url',
                'image_url': {'url': att.url},
              });
            }
          }
          formattedMessages.add({'role': 'user', 'content': parts});
        }
      } else if (msg.role == AiRole.assistant) {
        final assistantMap = <String, dynamic>{
          'role': 'assistant',
          'content': msg.content,
        };
        if (msg.toolCalls.isNotEmpty) {
          assistantMap['tool_calls'] = msg.toolCalls
              .map((c) => {
                    'id': c.id,
                    'type': 'function',
                    'function': {
                      'name': c.name,
                      'arguments': jsonEncode(c.arguments),
                    },
                  })
              .toList();
        }
        formattedMessages.add(assistantMap);
      } else if (msg.role == AiRole.tool) {
        for (final res in msg.toolResults) {
          formattedMessages.add({
            'role': 'tool',
            'tool_call_id': res.toolCallId,
            'name': res.name,
            'content': jsonEncode(res.result),
          });
        }
      }
    }

    final body = <String, dynamic>{
      'model': config?.modelName ?? defaultModel,
      'messages': formattedMessages,
      'stream': stream,
      'temperature': config?.temperature ?? 0.7,
      if (config?.maxTokens != null) 'max_tokens': config!.maxTokens,
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toOpenAiTool()).toList();
    }

    return body;
  }
}
