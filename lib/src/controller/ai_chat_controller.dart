import 'dart:async';
import 'package:flutter/widgets.dart';

import '../context/screen_context.dart';
import '../models/ai_message.dart';
import '../models/ai_provider_config.dart';
import '../models/ai_tool.dart';
import '../providers/base_provider.dart';
import '../providers/mock_provider.dart';
import '../storage/chat_storage.dart';
import '../streaming/frame_synced_buffer.dart';
import '../streaming/stream_metrics.dart';

/// The central state manager and orchestrator for high-performance AI Copilot interactions,
/// supporting screen-aware context, 60/120fps frame-synced streaming, Human-in-the-Loop approvals,
/// and persistent session storage.
class AiChatController extends ChangeNotifier {
  AiProvider _provider;
  AiModelConfig _config;
  AiScreenContext? _screenContext;
  AiChatStorageEngine _storageEngine;
  String _currentSessionId;

  final List<AiMessage> _messages = [];
  final Map<String, AiTool> _tools = {};
  final Map<String, Widget Function(BuildContext context, dynamic data)>
      _generativeUiRegistry = {};

  bool _isGenerating = false;
  bool _isListening = false;
  String? _error;
  StreamSubscription<String>? _currentStreamSubscription;
  FrameSyncedStreamBuffer? _activeBuffer;
  AiStreamMetrics? _lastStreamMetrics;

  /// Display throttling interval for token batching (default: 16ms = ~60 FPS).
  final Duration frameThrottleInterval;

  AiChatController({
    AiProvider? provider,
    AiModelConfig? config,
    AiScreenContext? initialScreenContext,
    AiChatStorageEngine? storageEngine,
    String? sessionId,
    List<AiTool>? tools,
    List<AiMessage>? initialMessages,
    this.frameThrottleInterval = const Duration(milliseconds: 16),
  })  : _provider = provider ?? MockAiProvider(),
        _config = config ?? const AiModelConfig(modelName: 'default'),
        _screenContext = initialScreenContext,
        _storageEngine = storageEngine ?? InMemoryStorageEngine(),
        _currentSessionId =
            sessionId ?? 'session_${DateTime.now().millisecondsSinceEpoch}' {
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
  AiScreenContext? get screenContext => _screenContext;
  AiChatStorageEngine get storageEngine => _storageEngine;
  String get currentSessionId => _currentSessionId;
  AiStreamMetrics? get lastStreamMetrics => _lastStreamMetrics;
  Map<String, AiTool> get tools => Map.unmodifiable(_tools);
  Map<String, Widget Function(BuildContext, dynamic)>
      get generativeUiRegistry => Map.unmodifiable(_generativeUiRegistry);

  /// Returns true if there is any tool call awaiting Human-in-the-Loop user approval.
  bool get hasPendingApproval {
    for (final m in _messages) {
      if (m.toolCalls
          .any((c) => c.status == AiToolCallStatus.pendingApproval)) {
        return true;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Configuration & Tool Registration
  // ---------------------------------------------------------------------------

  /// Updates active screen context (route, form data, visible text) to inform the LLM.
  void setScreenContext(AiScreenContext? context) {
    _screenContext = context;
    notifyListeners();
  }

  /// Sets the storage engine for persisting session history.
  void setStorageEngine(AiChatStorageEngine engine) {
    _storageEngine = engine;
  }

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
  // Messaging & High-Performance Execution Loop
  // ---------------------------------------------------------------------------

  /// Sends a message and streams the AI's response in real-time using frame-synced batching.
  Future<void> sendMessage(
    String text, {
    List<AiAttachment>? attachments,
    String? screenContext,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && (attachments == null || attachments.isEmpty)) return;

    _error = null;
    _isGenerating = true;

    // 1. Screen Context Injection
    if (screenContext != null && screenContext.isNotEmpty) {
      _messages.add(
        AiMessage.system('Active App Screen Context: $screenContext'),
      );
    } else if (_screenContext != null) {
      _messages.add(
        AiMessage.system(_screenContext!.toPromptContext()),
      );
    }

    // 2. Add user message
    final userMsg = AiMessage.user(trimmed, attachments: attachments);
    _messages.add(userMsg);
    notifyListeners();

    // 3. Prepare streaming assistant placeholder
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

      // Initialize Zero-Jank Frame-Synced Token Buffer
      _activeBuffer = FrameSyncedStreamBuffer(
        frameInterval: frameThrottleInterval,
        onUpdate: (accumulated, delta, metrics) {
          assistantMsg.content = accumulated;
          _lastStreamMetrics = metrics;
          notifyListeners();
        },
        onDone: (metrics) {
          _lastStreamMetrics = metrics;
        },
      );

      _currentStreamSubscription = stream.listen(
        (chunk) {
          _activeBuffer?.add(chunk);
        },
        onError: (err) {
          _activeBuffer?.cancel();
          _error = err.toString();
          assistantMsg.isStreaming = false;
          _isGenerating = false;
          notifyListeners();
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () async {
          _activeBuffer?.close();
          assistantMsg.isStreaming = false;
          _currentStreamSubscription = null;

          // If content is empty, check if tools were triggered via non-streaming fallback
          if (assistantMsg.content.trim().isEmpty) {
            await _executeNonStreamingWithTools(assistantMsg);
          }

          _isGenerating = false;
          _autoSaveSession();
          notifyListeners();
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );
    } catch (e) {
      // Fallback to non-streaming execution
      await _executeNonStreamingWithTools(assistantMsg);
      _isGenerating = false;
      _autoSaveSession();
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

      // Autonomous Tool Calling & Human-in-the-Loop Loop
      if (response.toolCalls.isNotEmpty) {
        for (final rawCall in response.toolCalls) {
          final AiToolCall call = rawCall is AiToolCall
              ? rawCall
              : AiToolCall.fromJson(rawCall as Map<String, dynamic>);

          final tool = _tools[call.name];

          // Check if this tool requires Human-in-the-Loop approval
          if (tool != null && tool.requiresApproval) {
            call.status = AiToolCallStatus.pendingApproval;
            call.riskLevel = tool.riskLevel.name;
            assistantMsg.toolCalls.add(call);
            _isGenerating = false;
            notifyListeners();
            // Halt automated execution until user approves/denies via UI
            return;
          }

          // Automatic execution
          call.status = AiToolCallStatus.executing;
          assistantMsg.toolCalls.add(call);
          notifyListeners();

          await _executeSingleTool(call, tool);
        }

        // Send tool results back to LLM for final synthesis
        await _synthesizeToolResults(activeTools);
      }
    } catch (e) {
      _error = e.toString();
      assistantMsg.isStreaming = false;
      assistantMsg.content = 'Sorry, I encountered an error: $e';
    }
  }

  Future<void> _executeSingleTool(AiToolCall call, AiTool? tool) async {
    dynamic resultData;
    bool isError = false;

    if (tool != null) {
      try {
        resultData = await tool.handler(call.arguments);
        call.status = AiToolCallStatus.completed;
      } catch (err) {
        resultData = 'Tool execution failed: $err';
        isError = true;
        call.status = AiToolCallStatus.failed;
      }
    } else {
      resultData =
          'Error: Tool "${call.name}" is not registered on this client.';
      isError = true;
      call.status = AiToolCallStatus.failed;
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

  Future<void> _synthesizeToolResults(List<AiTool> activeTools) async {
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

  // ---------------------------------------------------------------------------
  // Human-in-the-Loop Approval API
  // ---------------------------------------------------------------------------

  /// Approves a pending tool call, executes the handler, and resumes LLM synthesis.
  Future<void> approveToolCall(String toolCallId) async {
    AiToolCall? targetCall;
    for (final m in _messages) {
      for (final c in m.toolCalls) {
        if (c.id == toolCallId &&
            c.status == AiToolCallStatus.pendingApproval) {
          targetCall = c;
          break;
        }
      }
      if (targetCall != null) break;
    }

    if (targetCall == null) return;

    final tool = _tools[targetCall.name];
    targetCall.status = AiToolCallStatus.approved;
    _isGenerating = true;
    notifyListeners();

    await _executeSingleTool(targetCall, tool);
    await _synthesizeToolResults(_tools.values.toList());

    _isGenerating = false;
    _autoSaveSession();
    notifyListeners();
  }

  /// Denies a pending tool call, records the reason, and prompts LLM to acknowledge rejection.
  Future<void> rejectToolCall(String toolCallId, {String? reason}) async {
    AiToolCall? targetCall;
    for (final m in _messages) {
      for (final c in m.toolCalls) {
        if (c.id == toolCallId &&
            c.status == AiToolCallStatus.pendingApproval) {
          targetCall = c;
          break;
        }
      }
      if (targetCall != null) break;
    }

    if (targetCall == null) return;

    targetCall.status = AiToolCallStatus.rejected;
    targetCall.rejectionReason = reason ?? 'Denied by user';
    notifyListeners();

    // Append tool rejection result
    final resultMsg = AiMessage.tool(
      toolCallId: targetCall.id,
      name: targetCall.name,
      result: 'Action declined by user: ${targetCall.rejectionReason}',
      isError: true,
    );
    _messages.add(resultMsg);
    notifyListeners();

    _isGenerating = true;
    await _synthesizeToolResults(_tools.values.toList());
    _isGenerating = false;
    _autoSaveSession();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Session Persistence API
  // ---------------------------------------------------------------------------

  void _autoSaveSession() {
    _storageEngine.saveSession(
      AiChatSession(
        id: _currentSessionId,
        messages: _messages,
        screenContext: _screenContext,
      ),
    );
  }

  /// Loads an existing conversation session from the storage engine.
  Future<void> loadSession(String sessionId) async {
    stopGeneration();
    final session = await _storageEngine.loadSession(sessionId);
    if (session != null) {
      _currentSessionId = session.id;
      _messages.clear();
      _messages.addAll(session.messages);
      _screenContext = session.screenContext;
      _error = null;
      notifyListeners();
    }
  }

  /// Starts a fresh session.
  void startNewSession({String? title}) {
    stopGeneration();
    _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _messages.clear();
    _error = null;
    notifyListeners();
  }

  /// Retrieves list of saved conversation sessions.
  Future<List<AiChatSession>> listSavedSessions() {
    return _storageEngine.listSessions();
  }

  // ---------------------------------------------------------------------------
  // Utilities & Lifecycle
  // ---------------------------------------------------------------------------

  /// Stops any ongoing text generation stream.
  void stop() => stopGeneration();

  /// Cancels any ongoing text generation stream.
  void stopGeneration() {
    _activeBuffer?.cancel();
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

  /// Appends an existing message directly to the conversation history.
  void addMessage(AiMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  /// Toggles simulated voice input microphone state.
  void toggleVoiceInput() {
    _isListening = !_isListening;
    notifyListeners();
  }

  @override
  void dispose() {
    _activeBuffer?.cancel();
    _currentStreamSubscription?.cancel();
    super.dispose();
  }
}
