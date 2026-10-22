import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/ai_message.dart';
import '../models/ai_tool.dart';
import '../theme/ai_chat_theme.dart';

/// Interactive Human-in-the-Loop security card for authorizing or denying
/// sensitive/destructive tool executions.
class ToolApprovalCard extends StatelessWidget {
  final AiToolCall toolCall;
  final AiTool? tool;
  final AiChatTheme theme;
  final VoidCallback onApprove;
  final ValueChanged<String?> onDeny;

  const ToolApprovalCard({
    super.key,
    required this.toolCall,
    this.tool,
    required this.theme,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final risk = tool?.riskLevel ?? AiToolRiskLevel.medium;

    Color riskColor;
    String riskText;
    switch (risk) {
      case AiToolRiskLevel.low:
        riskColor = Colors.green;
        riskText = 'LOW RISK';
        break;
      case AiToolRiskLevel.medium:
        riskColor = Colors.amber;
        riskText = 'MODERATE RISK';
        break;
      case AiToolRiskLevel.high:
        riskColor = Colors.redAccent;
        riskText = 'SENSITIVE / HIGH RISK';
        break;
    }

    final isPending = toolCall.status == AiToolCallStatus.pendingApproval;
    final isApproved = toolCall.status == AiToolCallStatus.approved ||
        toolCall.status == AiToolCallStatus.executing ||
        toolCall.status == AiToolCallStatus.completed;
    final isRejected = toolCall.status == AiToolCallStatus.rejected;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2030) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending
              ? riskColor
              : (isApproved
                  ? Colors.greenAccent
                  : Colors.redAccent.withAlpha(120)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Risk Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: riskColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Permission Request',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: riskColor.withAlpha(35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  riskText,
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Action Description
          Text(
            tool?.confirmationMessage != null
                ? tool!.confirmationMessage!(toolCall.arguments)
                : 'The AI assistant is requesting authorization to invoke "${toolCall.name}".',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),

          // Arguments Summary
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121622) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PARAMETERS:',
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
                      .convert(toolCall.arguments),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Status & Action Buttons
          if (isPending)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.block_rounded, size: 16),
                  label: const Text('Deny Action'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => onDeny('Denied by user'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Approve & Run'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onApprove,
                ),
              ],
            )
          else if (isApproved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.greenAccent, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Action authorized and executed.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else if (isRejected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_rounded,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Action rejected: ${toolCall.rejectionReason ?? 'Denied by user'}.',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
