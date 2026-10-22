import 'package:flutter/material.dart';

/// Customizable visual theme for AI Chat and Copilot components.
class AiChatTheme {
  final Color backgroundColor;
  final Color surfaceColor;
  final Color primaryColor;
  final Color userBubbleColor;
  final Color userTextColor;
  final Color assistantBubbleColor;
  final Color assistantTextColor;
  final Color inputBackgroundColor;
  final Color inputTextColor;
  final Color inputHintColor;
  final Color toolBannerColor;
  final double bubbleRadius;

  const AiChatTheme({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.primaryColor,
    required this.userBubbleColor,
    required this.userTextColor,
    required this.assistantBubbleColor,
    required this.assistantTextColor,
    required this.inputBackgroundColor,
    required this.inputTextColor,
    required this.inputHintColor,
    required this.toolBannerColor,
    this.bubbleRadius = 18.0,
  });

  /// Modern Dark Cyber/Copilot theme preset.
  factory AiChatTheme.dark() => const AiChatTheme(
        backgroundColor: Color(0xFF0F1117),
        surfaceColor: Color(0xFF181C28),
        primaryColor: Color(0xFF7C4DFF),
        userBubbleColor: Color(0xFF651FFF),
        userTextColor: Colors.white,
        assistantBubbleColor: Color(0xFF1E2436),
        assistantTextColor: Color(0xFFECEFF1),
        inputBackgroundColor: Color(0xFF181C28),
        inputTextColor: Colors.white,
        inputHintColor: Colors.white38,
        toolBannerColor: Color(0xFF262F47),
        bubbleRadius: 18.0,
      );

  /// Clean Modern Light theme preset.
  factory AiChatTheme.light() => const AiChatTheme(
        backgroundColor: Color(0xFFF7F8FA),
        surfaceColor: Colors.white,
        primaryColor: Color(0xFF6200EE),
        userBubbleColor: Color(0xFF6200EE),
        userTextColor: Colors.white,
        assistantBubbleColor: Color(0xFFE8EAF6),
        assistantTextColor: Color(0xFF212121),
        inputBackgroundColor: Colors.white,
        inputTextColor: Color(0xFF212121),
        inputHintColor: Colors.black38,
        toolBannerColor: Color(0xFFE0E7FF),
        bubbleRadius: 18.0,
      );
}
