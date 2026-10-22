/// Production-ready AI Chatbot & Copilot Kit for Flutter with streaming tokens,
/// Markdown/code rendering, multimodal vision, tool calling, and multi-LLM engine.
library flutter_ai_copilot;

import 'package:flutter/widgets.dart';

import 'src/controller/ai_chat_controller.dart';
import 'src/theme/ai_chat_theme.dart';
import 'src/ui/ai_copilot_sheet.dart';

// Models
export 'src/models/ai_message.dart';
export 'src/models/ai_tool.dart';
export 'src/models/ai_provider_config.dart';

// Context & Screen-Aware Introspection
export 'src/context/screen_context.dart';

// Streaming Engine & Performance Metrics
export 'src/streaming/frame_synced_buffer.dart';
export 'src/streaming/stream_metrics.dart';

// Security & Human-in-the-Loop Approval
export 'src/security/tool_approval_card.dart';

// Persistent Storage & Session History
export 'src/storage/chat_storage.dart';

// Action Bus & Navigation Bridge
export 'src/actions/ai_action_bus.dart';

// Providers
export 'src/providers/base_provider.dart';
export 'src/providers/gemini_provider.dart';
export 'src/providers/openai_provider.dart';
export 'src/providers/ollama_provider.dart';
export 'src/providers/mock_provider.dart';

// Controller
export 'src/controller/ai_chat_controller.dart';

// Theme
export 'src/theme/ai_chat_theme.dart';

// UI
export 'src/ui/ai_chat_view.dart';
export 'src/ui/ai_copilot_sheet.dart';
export 'src/ui/ai_copilot_fab.dart';
export 'src/ui/widgets/ai_message_bubble.dart';
export 'src/ui/widgets/code_block_widget.dart';
export 'src/ui/widgets/tool_call_timeline_widget.dart';

/// Top-level convenience API for Flutter AI Copilot.
class AiCopilot {
  AiCopilot._();

  /// Opens the AI Copilot modal bottom sheet from anywhere in the app.
  static Future<T?> showSheet<T>({
    required BuildContext context,
    required AiChatController controller,
    AiChatTheme? theme,
    String title = 'AI Copilot Assistant',
    List<String>? suggestedPrompts,
    Widget? userAvatar,
    Widget? assistantAvatar,
    VoidCallback? onVoicePressed,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showAiCopilotSheet<T>(
      context: context,
      controller: controller,
      theme: theme,
      title: title,
      suggestedPrompts: suggestedPrompts,
      userAvatar: userAvatar,
      assistantAvatar: assistantAvatar,
      onVoicePressed: onVoicePressed,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
    );
  }
}
