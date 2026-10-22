import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/ai_message.dart';
import '../models/ai_provider_config.dart';
import '../models/ai_tool.dart';
import 'base_provider.dart';

/// Alias for [OllamaProvider].
typedef OllamaAiProvider = OllamaProvider;

/// Provider for local, private, and offline Ollama LLMs (Llama 3, Mistral, Gemma 2, Phi).
class OllamaProvider implements AiProvider {
  final String host;
  final String defaultModel;
  final http.Client _client;

  OllamaProvider({
    this.host = 'http://localhost:11434',
    String? defaultModel,
    String? modelName,
    http.Client? client,
  })  : defaultModel = defaultModel ?? modelName ?? 'llama3',
        _client = client ?? http.Client();

  @override
  String get name => 'ollama';

  @override
  Stream<String> streamMessage({
    required List<AiMessage> messages,
    List<AiTool>? tools,
    AiModelConfig? config,
  }) async* {
    final url = Uri.parse('$host/api/chat');
    final formattedMessages = _formatMessages(messages, config);

    final requestBody = {
      'model': config?.modelName ?? defaultModel,
      'messages': formattedMessages,
      'stream': true,
      'options': {
        'temperature': config?.temperature ?? 0.7,
      },
    };

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(requestBody);

    final response = await _client.send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception('Ollama Error (${response.statusCode}): $errorBody');
    }

    final lines =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final data = jsonDecode(line) as Map<String, dynamic>;
        final msg = data['message'] as Map<String, dynamic>?;
        final content = msg?['content'] as String?;
        if (content != null && content.isNotEmpty) {
          yield content;
        }
      } catch (_) {}
    }
  }

  @override
  Future<AiResponse> sendMessage({
    required List<AiMessage> messages,
    List<AiTool>? tools,
    AiModelConfig? config,
  }) async {
    final url = Uri.parse('$host/api/chat');
    final formattedMessages = _formatMessages(messages, config);

    final requestBody = {
      'model': config?.modelName ?? defaultModel,
      'messages': formattedMessages,
      'stream': false,
      'options': {
        'temperature': config?.temperature ?? 0.7,
      },
    };

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Ollama Error (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final msg = data['message'] as Map<String, dynamic>?;
    final content = msg?['content'] as String? ?? '';

    return AiResponse(content: content);
  }

  List<Map<String, dynamic>> _formatMessages(
    List<AiMessage> messages,
    AiModelConfig? config,
  ) {
    final formatted = <Map<String, dynamic>>[];

    if (config?.systemPrompt != null && config!.systemPrompt!.isNotEmpty) {
      formatted.add({
        'role': 'system',
        'content': config.systemPrompt!,
      });
    }

    for (final m in messages) {
      final roleStr = m.role == AiRole.assistant ? 'assistant' : 'user';
      final map = <String, dynamic>{
        'role': roleStr,
        'content': m.content,
      };

      if (m.attachments.isNotEmpty) {
        final images = m.attachments
            .where((a) => a.base64Data != null)
            .map((a) => a.base64Data!)
            .toList();
        if (images.isNotEmpty) {
          map['images'] = images;
        }
      }

      formatted.add(map);
    }

    return formatted;
  }
}
