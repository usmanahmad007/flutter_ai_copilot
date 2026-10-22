import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/ai_message.dart';
import '../../models/ai_tool.dart';
import '../../security/tool_approval_card.dart';
import '../../theme/ai_chat_theme.dart';

/// Collapsible timeline accordion displaying autonomous tool execution steps,
/// inputs, outputs, embedded Generative UI widgets, and Human-in-the-Loop approvals.
class ToolCallTimelineWidget extends StatefulWidget {
  final List<AiToolCall> toolCalls;
  final List<AiToolResult> toolResults;
  final AiChatTheme theme;
  final Map<String, Widget Function(BuildContext context, dynamic data)>?
      generativeUiRegistry;
  final Map<String, AiTool>? tools;
  final void Function(String toolCallId)? onApproveTool;
  final void Function(String toolCallId, String? reason)? onRejectTool;

  const ToolCallTimelineWidget({
    super.key,
    required this.toolCalls,
    required this.toolResults,
    required this.theme,
    this.generativeUiRegistry,
    this.tools,
    this.onApproveTool,
    this.onRejectTool,
  });

  @override
  State<ToolCallTimelineWidget> createState() => _ToolCallTimelineWidgetState();
}

class _ToolCallTimelineWidgetState extends State<ToolCallTimelineWidget> {
  final Set<String> _expandedToolIds = {};

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedToolIds.contains(id)) {
        _expandedToolIds.remove(id);
      } else {
        _expandedToolIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.toolCalls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: widget.toolCalls.map((call) {
        // If the tool requires Human-in-the-Loop approval or was rejected, display the approval card
        if (call.status == AiToolCallStatus.pendingApproval ||
            call.status == AiToolCallStatus.rejected) {
          return ToolApprovalCard(
            toolCall: call,
            tool: widget.tools?[call.name],
            theme: widget.theme,
            onApprove: () => widget.onApproveTool?.call(call.id),
            onDeny: (reason) => widget.onRejectTool?.call(call.id, reason),
          );
        }

        final matchingResult =
            widget.toolResults.cast<AiToolResult?>().firstWhere(
                  (r) => r?.toolCallId == call.id || r?.name == call.name,
                  orElse: () => null,
                );

        final isDone = matchingResult != null;
        final isExpanded = _expandedToolIds.contains(call.id);
        final customUiBuilder = widget.generativeUiRegistry?[call.name];

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: widget.theme.toolBannerColor.withAlpha(80),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.theme.toolBannerColor,
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header item
              InkWell(
                onTap: () => _toggleExpand(call.id),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDone
                              ? Colors.green.withAlpha(40)
                              : Colors.amber.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : Icons.pending_rounded,
                          size: 16,
                          color:
                              isDone ? Colors.greenAccent : Colors.amberAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tool: ${call.name}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              isDone
                                  ? 'Finished execution'
                                  : 'Executing tool action...',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),

              // Embedded Generative UI (if registered)
              if (isDone && customUiBuilder != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: customUiBuilder(context, matchingResult.result),
                ),

              // Expanded JSON inspection
              if (isExpanded)
                Container(
                  color: Colors.black.withAlpha(40),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INPUT ARGUMENTS:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        const JsonEncoder.withIndent('  ')
                            .convert(call.arguments),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.cyanAccent,
                        ),
                      ),
                      if (matchingResult != null) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'OUTPUT RESULT:',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          matchingResult.result is Map ||
                                  matchingResult.result is List
                              ? const JsonEncoder.withIndent('  ')
                                  .convert(matchingResult.result)
                              : matchingResult.result.toString(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: matchingResult.isError
                                ? Colors.redAccent
                                : Colors.lightGreenAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
