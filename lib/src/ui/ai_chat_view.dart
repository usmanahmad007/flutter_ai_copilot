import 'package:flutter/material.dart';
import '../controller/ai_chat_controller.dart';
import '../models/ai_message.dart';
import '../theme/ai_chat_theme.dart';
import 'widgets/ai_message_bubble.dart';

/// Full-screen or embedded AI Chatbot interface with streaming text,
/// suggested prompts, multimodal attachments, and autonomous tool calling.
class AiChatView extends StatefulWidget {
  final AiChatController controller;
  final AiChatTheme? theme;
  final String? title;
  final List<String>? suggestedPrompts;
  final Widget? header;
  final Widget? emptyState;
  final Widget? userAvatar;
  final Widget? assistantAvatar;
  final VoidCallback? onVoicePressed;

  const AiChatView({
    super.key,
    required this.controller,
    this.theme,
    this.title = 'AI Copilot',
    this.suggestedPrompts,
    this.header,
    this.emptyState,
    this.userAvatar,
    this.assistantAvatar,
    this.onVoicePressed,
  });

  @override
  State<AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends State<AiChatView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<AiAttachment> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    final attachments = List<AiAttachment>.from(_pendingAttachments);
    _textController.clear();
    setState(() => _pendingAttachments.clear());

    widget.controller.sendMessage(
      text,
      attachments: attachments.isNotEmpty ? attachments : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTheme =
        widget.theme ?? (isDark ? AiChatTheme.dark() : AiChatTheme.light());

    return Container(
      color: effectiveTheme.backgroundColor,
      child: Column(
        children: [
          // Optional Header
          if (widget.header != null) widget.header!,

          // Message List or Empty State
          Expanded(
            child: widget.controller.messages.isEmpty
                ? _buildEmptyState(effectiveTheme)
                : _buildMessageList(effectiveTheme),
          ),

          // Suggested Prompts (if any)
          if (widget.suggestedPrompts != null &&
              widget.suggestedPrompts!.isNotEmpty)
            _buildSuggestedPrompts(effectiveTheme),

          // Pending Attachments Bar
          if (_pendingAttachments.isNotEmpty)
            _buildPendingAttachments(effectiveTheme),

          // Input Bar
          _buildInputBar(effectiveTheme),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AiChatTheme theme) {
    if (widget.emptyState != null) return widget.emptyState!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withAlpha(160)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withAlpha(80),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title ?? 'AI Copilot',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.assistantTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'How can I help you today? Ask questions, generate code, or execute app tasks.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.assistantTextColor.withAlpha(160),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            if (widget.suggestedPrompts != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: widget.suggestedPrompts!.map((p) {
                  return ActionChip(
                    label: Text(p),
                    backgroundColor: theme.surfaceColor,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: theme.assistantTextColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: theme.toolBannerColor),
                    ),
                    onPressed: () {
                      _textController.text = p;
                      _handleSend();
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(AiChatTheme theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: widget.controller.messages.length,
      itemBuilder: (context, index) {
        final message = widget.controller.messages[index];
        return AiMessageBubble(
          key: ValueKey(message.id),
          message: message,
          theme: theme,
          userAvatar: widget.userAvatar,
          assistantAvatar: widget.assistantAvatar,
          generativeUiRegistry: widget.controller.generativeUiRegistry,
          onRetry: () => widget.controller.retryLast(),
        );
      },
    );
  }

  Widget _buildSuggestedPrompts(AiChatTheme theme) {
    if (widget.controller.messages.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: widget.suggestedPrompts!.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = widget.suggestedPrompts![index];
          return ActionChip(
            label: Text(prompt, style: const TextStyle(fontSize: 12)),
            backgroundColor: theme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.toolBannerColor),
            ),
            onPressed: () {
              _textController.text = prompt;
              _handleSend();
            },
          );
        },
      ),
    );
  }

  Widget _buildPendingAttachments(AiChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: _pendingAttachments.map((att) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.toolBannerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image, size: 16),
                const SizedBox(width: 4),
                Text(
                  att.name,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    setState(() => _pendingAttachments.remove(att));
                  },
                  child: const Icon(Icons.close, size: 14),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputBar(AiChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Voice Input Button (if callback provided)
            if (widget.onVoicePressed != null)
              IconButton(
                icon: Icon(
                  widget.controller.isListening ? Icons.mic : Icons.mic_none,
                  color: widget.controller.isListening
                      ? Colors.redAccent
                      : theme.inputTextColor.withAlpha(160),
                ),
                tooltip: 'Voice Input',
                onPressed: widget.onVoicePressed,
              ),

            // Text Input Field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.inputBackgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.toolBannerColor,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  style: TextStyle(color: theme.inputTextColor, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Ask AI Copilot...',
                    hintStyle: TextStyle(color: theme.inputHintColor),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send / Stop Button
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.controller.isGenerating
                  ? IconButton(
                      key: const ValueKey('stop_button'),
                      icon: const Icon(Icons.stop_circle_rounded,
                          color: Colors.redAccent, size: 30),
                      tooltip: 'Stop generation',
                      onPressed: () => widget.controller.stop(),
                    )
                  : IconButton(
                      key: const ValueKey('send_button'),
                      icon: Icon(Icons.send_rounded,
                          color: theme.primaryColor, size: 26),
                      tooltip: 'Send message',
                      onPressed: _handleSend,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
