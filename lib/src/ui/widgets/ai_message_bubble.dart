import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../models/ai_message.dart';
import '../../models/ai_tool.dart';
import '../../theme/ai_chat_theme.dart';
import 'code_block_widget.dart';
import 'tool_call_timeline_widget.dart';

/// Renders an individual chat bubble for User or Assistant messages.
class AiMessageBubble extends StatelessWidget {
  final AiMessage message;
  final AiChatTheme theme;
  final Widget? userAvatar;
  final Widget? assistantAvatar;
  final Map<String, Widget Function(BuildContext, dynamic)>?
      generativeUiRegistry;
  final Map<String, AiTool>? tools;
  final void Function(String toolCallId)? onApproveTool;
  final void Function(String toolCallId, String? reason)? onRejectTool;
  final VoidCallback? onRetry;

  const AiMessageBubble({
    super.key,
    required this.message,
    required this.theme,
    this.userAvatar,
    this.assistantAvatar,
    this.generativeUiRegistry,
    this.tools,
    this.onApproveTool,
    this.onRejectTool,
    this.onRetry,
  });

  bool get isUser => message.role == AiRole.user;

  @override
  Widget build(BuildContext context) {
    if (message.role == AiRole.system) {
      return _buildSystemNotice();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            assistantAvatar ?? _defaultAssistantAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Attachments preview
                if (message.attachments.isNotEmpty) _buildAttachmentsPreview(),

                // Tool Call Timeline
                if (message.toolCalls.isNotEmpty)
                  ToolCallTimelineWidget(
                    toolCalls: message.toolCalls,
                    toolResults: message.toolResults,
                    theme: theme,
                    generativeUiRegistry: generativeUiRegistry,
                    tools: tools,
                    onApproveTool: onApproveTool,
                    onRejectTool: onRejectTool,
                  ),

                // Main message bubble
                if (message.content.isNotEmpty || message.isStreaming)
                  Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    decoration: BoxDecoration(
                      color: isUser
                          ? theme.userBubbleColor
                          : theme.assistantBubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(theme.bubbleRadius),
                        topRight: Radius.circular(theme.bubbleRadius),
                        bottomLeft:
                            Radius.circular(isUser ? theme.bubbleRadius : 4),
                        bottomRight:
                            Radius.circular(isUser ? 4 : theme.bubbleRadius),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isUser)
                          SelectableText(
                            message.content,
                            style: TextStyle(
                              color: theme.userTextColor,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          )
                        else
                          _buildAssistantContent(context),
                      ],
                    ),
                  ),

                // Action Bar for Assistant Messages (Copy, etc.)
                if (!isUser &&
                    !message.isStreaming &&
                    message.content.isNotEmpty)
                  _buildActionBar(context),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            userAvatar ?? _defaultUserAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAssistantContent(BuildContext context) {
    if (message.content.isEmpty && message.isStreaming) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Thinking...',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: theme.assistantTextColor.withAlpha(180),
            ),
          ),
        ],
      );
    }

    final isDark = theme.assistantBubbleColor.computeLuminance() < 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: message.content,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: TextStyle(
              color: theme.assistantTextColor,
              fontSize: 15,
              height: 1.45,
            ),
            code: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              backgroundColor:
                  isDark ? const Color(0xFF262D3D) : const Color(0xFFE2E8F0),
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
            ),
          ),
          builders: {
            'pre': CodeBlockElementBuilder(theme: theme),
          },
        ),
        if (message.isStreaming) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'streaming...',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: theme.assistantTextColor.withAlpha(150),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAttachmentsPreview() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: message.attachments.map((att) {
          if (att.mimeType.startsWith('image/')) {
            if (att.bytes != null) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  att.bytes!,
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              );
            } else if (att.url != null) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  att.url!,
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              );
            }
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.attach_file, size: 16),
                const SizedBox(width: 4),
                Text(att.name, style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 14),
            splashRadius: 16,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            tooltip: 'Copy text',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message.content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Message copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 14),
              splashRadius: 16,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              tooltip: 'Retry response',
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemNotice() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.content,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _defaultAssistantAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColor.withAlpha(160)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child:
          const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
    );
  }

  Widget _defaultUserAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFF455A64),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, size: 18, color: Colors.white),
    );
  }
}
