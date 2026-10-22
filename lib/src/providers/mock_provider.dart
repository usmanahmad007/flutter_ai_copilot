import 'dart:async';
import '../models/ai_message.dart';
import '../models/ai_provider_config.dart';
import '../models/ai_tool.dart';
import 'base_provider.dart';

/// Simulated AI Provider for zero-config prototyping, offline demos, and unit testing.
///
/// Emits realistic word-by-word streaming chunks, executes simulated tool calls,
/// and responds to text and image prompts without requiring an API key.
class MockAiProvider implements AiProvider {
  final Duration tokenDelay;

  MockAiProvider({
    this.tokenDelay = const Duration(milliseconds: 35),
  });

  @override
  String get name => 'mock';

  @override
  Stream<String> streamMessage({
    required List<AiMessage> messages,
    List<AiTool>? tools,
    AiModelConfig? config,
  }) async* {
    final lastMessage = messages.isNotEmpty ? messages.last : null;
    final query = lastMessage?.content.toLowerCase().trim() ?? '';

    // Check if the user is asking about weather and a weather tool is available
    if (query.contains('weather') &&
        tools != null &&
        tools.any((t) => t.name == 'check_weather')) {
      // Yield nothing so the controller executes the tool calling loop
      return;
    }

    // Check if flight tool is requested
    if (query.contains('flight') &&
        tools != null &&
        tools.any((t) => t.name == 'search_flights')) {
      // Yield nothing so the controller executes the tool calling loop
      return;
    }

    final response = _generateResponse(lastMessage);
    final words = response.split(' ');

    for (final word in words) {
      await Future.delayed(tokenDelay);
      yield '$word ';
    }
  }

  @override
  Future<AiResponse> sendMessage({
    required List<AiMessage> messages,
    List<AiTool>? tools,
    AiModelConfig? config,
  }) async {
    final lastMessage = messages.isNotEmpty ? messages.last : null;

    // Check if synthesizing tool execution results
    if (lastMessage != null && lastMessage.role == AiRole.tool) {
      final toolResult = lastMessage.toolResults.isNotEmpty
          ? lastMessage.toolResults.first
          : null;
      return AiResponse(
        content:
            'Here is the result for **${toolResult?.name ?? 'action'}**:\n\n`${toolResult?.result}`\n\nThe operation completed successfully!',
      );
    }

    final query = lastMessage?.content.toLowerCase().trim() ?? '';
    final hasToolAlreadyRun = messages.any((m) => m.role == AiRole.tool);

    // Check if tool should be called
    if (!hasToolAlreadyRun &&
        query.contains('weather') &&
        tools != null &&
        tools.any((t) => t.name == 'check_weather')) {
      return AiResponse(
        content: '',
        toolCalls: [
          AiToolCall(
            id: 'mock_tool_call_weather',
            name: 'check_weather',
            arguments: const {'city': 'San Francisco', 'units': 'celsius'},
          ),
        ],
      );
    }

    // Check if flight or travel tool should be called
    if (!hasToolAlreadyRun &&
        query.contains('flight') &&
        tools != null &&
        tools.any((t) => t.name == 'search_flights')) {
      return AiResponse(
        content: '',
        toolCalls: [
          AiToolCall(
            id: 'mock_tool_call_flight',
            name: 'search_flights',
            arguments: const {'destination': 'Tokyo', 'date': '2026-11-01'},
          ),
        ],
      );
    }

    // Check if secure transfer tool should be called
    if (!hasToolAlreadyRun &&
        query.contains('transfer') &&
        tools != null &&
        tools.any((t) => t.name == 'execute_secure_transfer')) {
      return AiResponse(
        content: '',
        toolCalls: [
          AiToolCall(
            id: 'mock_tool_call_transfer',
            name: 'execute_secure_transfer',
            arguments: const {'amount': 250, 'recipient': 'Alex Morgan'},
          ),
        ],
      );
    }

    final responseText = _generateResponse(lastMessage);
    return AiResponse(content: responseText);
  }

  String _generateResponse(AiMessage? message) {
    if (message == null) {
      return "Hello! I am your AI Copilot. How can I assist you today?";
    }

    // Multimodal image prompt check
    if (message.attachments.isNotEmpty) {
      final img = message.attachments.first;
      return "I've analyzed your image **${img.name}** (${img.mimeType}). It appears to be an application screenshot or document. What specific insight would you like extracted from it?";
    }

    final text = message.content.toLowerCase();

    if (text.contains('hi') || text.contains('hello') || text.contains('hey')) {
      return "Hello! 👋 I am your intelligent **Flutter AI Copilot**. I can answer questions, inspect app data, generate code, and trigger in-app tools. What would you like to build today?";
    }

    if (text.contains('code') ||
        text.contains('dart') ||
        text.contains('flutter')) {
      return "Here is an example of an animated AI Copilot button in Flutter:\n\n"
          "```dart\n"
          "ElevatedButton.icon(\n"
          "  icon: const Icon(Icons.auto_awesome),\n"
          "  label: const Text('Ask Copilot'),\n"
          "  onPressed: () => AiCopilot.showSheet(context),\n"
          ");\n"
          "```\n\n"
          "You can drop this button into any AppBar or FloatingActionButton!";
    }

    if (text.contains('help') || text.contains('feature')) {
      return "Here is what I can do for your application:\n\n"
          "- ⚡ **Real-Time Streaming**: Low-latency token generation with typewriter rendering\n"
          "- 🛠️ **Autonomous Tool Calling**: Execute app navigation and APIs autonomously\n"
          "- 🎨 **Generative UI**: Render native Flutter cards and charts directly in chat\n"
          "- 📷 **Multimodal Vision**: Attach and analyze images & documents\n"
          "- 🔄 **Multi-LLM Engine**: Switch between Gemini, OpenAI, Claude, and Ollama seamlessly";
    }

    return "That's a great question about **${message.content}**! As an intelligent copilot, I can process this request, interface with backend APIs via function calling, or guide you through the next workflow steps.";
  }
}
