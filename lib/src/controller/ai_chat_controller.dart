import 'dart:async';
import 'package:flutter/widgets.dart';

import '../models/ai_message.dart';
import '../models/ai_provider_config.dart';
import '../models/ai_tool.dart';
import '../providers/base_provider.dart';
import '../providers/mock_provider.dart';

/// The central state manager and orchestrator for AI Chatbot and Copilot interactions.
class AiChatController extends ChangeNotifier {
  AiProvider _provider;
  AiModelConfig _config;

  final List<AiMessage> _messages = [];
  final Map<String, AiTool> _tools = {};
  final Map<String, Widget Function(BuildContext context, dynamic data)>
      _generativeUiRegistry = {};

  bool _isGenerating = false;
  bool _isListening = false;
  String? _error;
  StreamSubscription<String>? _currentStreamSubscription;

  AiChatController({
    AiProvider? provider,
    AiModelConfig? config,
    List<AiTool>? tools,
    List<AiMessage>? initialMessages,
  })  : _provider = provider ?? MockAiProvider(),
        _config = config ?? const AiModelConfig(modelName: 'default') {
    if (tools != null) {
      for (final t in tools) {
        _tools[t.name] = t;
      }
    }
    if (initialMessages != null) {
      _messages.addAll(initialMessages);
    }
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  List<AiMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  bool get isListening => _isListening;
  String? get error => _error;
  AiProvider get provider => _provider;
  AiModelConfig get config => _config;
  Map<String, AiTool> get tools => Map.unmodifiable(_tools);
  Map<String, Widget Function(BuildContext, dynamic)>
      get generativeUiRegistry => Map.unmodifiable(_generativeUiRegistry);

  // ---------------------------------------------------------------------------
  // Configuration & Tool Registration
  // ---------------------------------------------------------------------------

  /// Updates the active provider.
  void setProvider(AiProvider provider) {
    _provider = provider;
    notifyListeners();
  }

  /// Updates model configuration.
  void setConfig(AiModelConfig config) {
    _config = config;
    notifyListeners();
  }

  /// Registers a callable tool for function calling.
  void registerTool(AiTool tool) {
    _tools[tool.name] = tool;
    notifyListeners();
  }

  /// Registers a Generative UI builder callback for a specific tool or JSON tag.
  void registerGenerativeUi(
    String toolOrTag,
    Widget Function(BuildContext context, dynamic data) builder,
  ) {
    _generativeUiRegistry[toolOrTag] = builder;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Messaging & Execution Loop
  // ---------------------------------------------------------------------------

  /// Sends a message and streams the AI's response in real-time.
  Future<void> sendMessage(
    String text, {
    List<AiAttachment>? attachments,
    String? screenContext,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && (attachments == null || attachments.isEmpty)) return;

    _error = null;
    _isGenerating = true;

    // Optional screen context injection
    if (screenContext != null && screenContext.isNotEmpty) {
      _messages.add(
        AiMessage.system('Active App Screen Context: $screenContext'),
      );
    }

    // 1. Add user message
    final userMsg = AiMessage.user(trimmed, attachments: attachments);
    _messages.add(userMsg);
    notifyListeners();

    // 2. Prepare streaming assistant placeholder
    final assistantMsg = AiMessage.assistant('', isStreaming: true);
    _messages.add(assistantMsg);
    notifyListeners();

    final completer = Completer<void>();

    try {
      final activeTools = _tools.values.toList();

      // Check if provider supports direct streaming
      final stream = _provider.streamMessage(
        messages: _messages.where((m) => m != assistantMsg).toList(),
        tools: activeTools.isNotEmpty ? activeTools : null,
        config: _config,
      );

      _currentStreamSubscription = stream.listen(
        (chunk) {
          assistantMsg.content += chunk;
          notifyListeners();
        },
        onError: (err) {
          _error = err.toString();
          assistantMsg.isStreaming = false;
          _isGenerating = false;
          notifyListeners();
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () async {
          assistantMsg.isStreaming = false;
          _currentStreamSubscription = null;

          // If content is empty, check if tools were triggered via non-streaming fallback
          if (assistantMsg.content.trim().isEmpty) {
            await _executeNonStreamingWithTools(assistantMsg);
          }

          _isGenerating = false;
          notifyListeners();
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );
    } catch (e) {
      // Fallback to non-streaming execution
      await _executeNonStreamingWithTools(assistantMsg);
      _isGenerating = false;
      notifyListeners();
      if (!completer.isCompleted) completer.complete();
    }

    return completer.future;
  }

  Future<void> _executeNonStreamingWithTools(AiMessage assistantMsg) async {
    try {
      final activeTools = _tools.values.toList();
      final response = await _provider.sendMessage(
        messages: _messages.where((m) => m != assistantMsg).toList(),
        tools: activeTools.isNotEmpty ? activeTools : null,
        config: _config,
      );

      assistantMsg.content = response.content;
      assistantMsg.isStreaming = false;
      notifyListeners();

      // Autonomous Tool Calling Loop
      if (response.toolCalls.isNotEmpty) {
        for (final rawCall in response.toolCalls) {
          final AiToolCall call = rawCall is AiToolCall
              ? rawCall
              : AiToolCall.fromJson(rawCall as Map<String, dynamic>);

          assistantMsg.toolCalls.add(call);
          notifyListeners();

          // Execute tool handler if registered
          final tool = _tools[call.name];
          dynamic resultData;
          bool isError = false;

          if (tool != null) {
            try {
              resultData = await tool.handler(call.arguments);
            } catch (err) {
              resultData = 'Tool execution failed: $err';
              isError = true;
            }
          } else {
            resultData =
                'Error: Tool "${call.name}" is not registered on this client.';
            isError = true;
          }

          // Append tool result message
          final resultMsg = AiMessage.tool(
            toolCallId: call.id,
            name: call.name,
            result: resultData,
            isError: isError,
          );
          _messages.add(resultMsg);
          notifyListeners();
        }

        // Send tool results back to LLM for final synthesis
        final followUpAssistant = AiMessage.assistant('', isStreaming: true);
        _messages.add(followUpAssistant);
        notifyListeners();

        final finalResponse = await _provider.sendMessage(
          messages: _messages.where((m) => m != followUpAssistant).toList(),
          tools: activeTools.isNotEmpty ? activeTools : null,
          config: _config,
        );

        followUpAssistant.content = finalResponse.content;
        followUpAssistant.isStreaming = false;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      assistantMsg.isStreaming = false;
      assistantMsg.content = 'Sorry, I encountered an error: $e';
    }
  }

  /// Stops any ongoing text generation stream.
  void stop() => stopGeneration();

  /// Cancels any ongoing text generation stream.
  void stopGeneration() {
    _currentStreamSubscription?.cancel();
    _currentStreamSubscription = null;
    _isGenerating = false;
    for (final m in _messages) {
      m.isStreaming = false;
    }
    notifyListeners();
  }

  /// Retries the last user message in the conversation.
  Future<void> retryLast() async {
    if (_messages.isEmpty) return;
    final lastUserIndex =
        _messages.lastIndexWhere((m) => m.role == AiRole.user);
    if (lastUserIndex == -1) return;

    final userMsg = _messages[lastUserIndex];
    // Remove the user message and any messages after it
    _messages.removeRange(lastUserIndex, _messages.length);
    notifyListeners();

    await sendMessage(
      userMsg.content,
      attachments: userMsg.attachments.isNotEmpty ? userMsg.attachments : null,
    );
  }

  /// Clears the entire chat history.
  void clearHistory() {
    stopGeneration();
    _messages.clear();
    _error = null;
    notifyListeners();
  }

  /// Toggles simulated voice input microphone state.
  void toggleVoiceInput() {
    _isListening = !_isListening;
    notifyListeners();
  }

  @override
  void dispose() {
    _currentStreamSubscription?.cancel();
    super.dispose();
  }
}
