import 'package:flutter/material.dart';
import '../controller/ai_chat_controller.dart';
import '../theme/ai_chat_theme.dart';
import 'ai_copilot_sheet.dart';

/// Floating Action Button with AI glowing gradient that opens the Copilot Sheet.
class AiCopilotFab extends StatefulWidget {
  final AiChatController controller;
  final AiChatTheme? theme;
  final String title;
  final List<String>? suggestedPrompts;
  final VoidCallback? customOnPressed;
  final Widget? icon;
  final String? tooltip;

  const AiCopilotFab({
    super.key,
    required this.controller,
    this.theme,
    this.title = 'AI Copilot Assistant',
    this.suggestedPrompts,
    this.customOnPressed,
    this.icon,
    this.tooltip = 'Ask AI Copilot',
  });

  @override
  State<AiCopilotFab> createState() => _AiCopilotFabState();
}

class _AiCopilotFabState extends State<AiCopilotFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.customOnPressed != null) {
      widget.customOnPressed!();
    } else {
      showAiCopilotSheet(
        context: context,
        controller: widget.controller,
        theme: widget.theme,
        title: widget.title,
        suggestedPrompts: widget.suggestedPrompts,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ??
        (Theme.of(context).brightness == Brightness.dark
            ? AiChatTheme.dark()
            : AiChatTheme.light());

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              theme.primaryColor,
              const Color(0xFF00E5FF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withAlpha(120),
              blurRadius: 14,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _handleTap,
            child: Tooltip(
              message: widget.tooltip ?? 'Ask AI Copilot',
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: widget.icon ??
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
