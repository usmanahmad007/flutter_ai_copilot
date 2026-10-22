import 'package:flutter/material.dart';
import '../controller/ai_chat_controller.dart';
import '../theme/ai_chat_theme.dart';
import 'ai_chat_view.dart';

/// Shows an interactive AI Copilot modal bottom sheet.
Future<T?> showAiCopilotSheet<T>({
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
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final effectiveTheme =
      theme ?? (isDark ? AiChatTheme.dark() : AiChatTheme.light());

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (ctx) => AiCopilotSheetWidget(
      controller: controller,
      theme: effectiveTheme,
      title: title,
      suggestedPrompts: suggestedPrompts,
      userAvatar: userAvatar,
      assistantAvatar: assistantAvatar,
      onVoicePressed: onVoicePressed,
    ),
  );
}

/// The Sheet Container widget containing handle bar, title, and [AiChatView].
class AiCopilotSheetWidget extends StatelessWidget {
  final AiChatController controller;
  final AiChatTheme theme;
  final String title;
  final List<String>? suggestedPrompts;
  final Widget? userAvatar;
  final Widget? assistantAvatar;
  final VoidCallback? onVoicePressed;

  const AiCopilotSheetWidget({
    super.key,
    required this.controller,
    required this.theme,
    required this.title,
    this.suggestedPrompts,
    this.userAvatar,
    this.assistantAvatar,
    this.onVoicePressed,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final targetHeight = mediaQuery.size.height * 0.82;

    return Container(
      height: targetHeight,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Drag Handle & Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.surfaceColor,
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: theme.inputHintColor.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.primaryColor,
                                theme.primaryColor.withAlpha(150)
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome_rounded,
                              size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.assistantTextColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: theme.assistantTextColor.withAlpha(160)),
                      splashRadius: 20,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Chat View
          Expanded(
            child: AiChatView(
              controller: controller,
              theme: theme,
              title: title,
              suggestedPrompts: suggestedPrompts,
              userAvatar: userAvatar,
              assistantAvatar: assistantAvatar,
              onVoicePressed: onVoicePressed,
            ),
          ),
        ],
      ),
    );
  }
}
