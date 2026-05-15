import 'package:echo_me/core/widgets/app_card.dart';
import 'package:echo_me/features/echo_ai/echo_ai_advisor.dart';
import 'package:echo_me/features/echo_ai/echo_ai_advisor_icon.dart';
import 'package:echo_me/features/echo_ai/echo_ai_controller.dart';
import 'package:echo_me/features/echo_ai/echo_ai_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class EchoAiChatScreen extends ConsumerStatefulWidget {
  final EchoAiAdvisor advisor;

  const EchoAiChatScreen({super.key, required this.advisor});

  @override
  ConsumerState<EchoAiChatScreen> createState() => _EchoAiChatScreenState();
}

class _EchoAiChatScreenState extends ConsumerState<EchoAiChatScreen> {
  final _text = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(echoAiStateProvider(widget.advisor)).valueOrNull ??
        ref.watch(echoAiControllerProvider(widget.advisor)).state;
    final controller = ref.watch(echoAiControllerProvider(widget.advisor));

    ref.listen(echoAiStateProvider(widget.advisor), (_, next) {
      final error = next.valueOrNull?.error;
      if (error != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        controller.clearError();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            EchoAiAdvisorIcon(advisor: widget.advisor, size: 38, iconSize: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.advisor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.advisor.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New topic',
            onPressed: state.sending ? null : controller.reset,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _AdvisorScopeBanner(advisor: widget.advisor),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                return _EchoAiBubble(
                  message: state.messages[index],
                  advisor: widget.advisor,
                );
              },
            ),
          ),
          if (state.messages.length <= 1)
            _PromptChips(
              advisor: widget.advisor,
              onSelected: (prompt) => _sendPrompt(prompt, controller),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: AppCard(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'New topic',
                      onPressed: state.sending ? null : controller.reset,
                      icon: const Icon(Icons.add_comment_outlined),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !state.sending,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(controller),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          height: 1.25,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask ${widget.advisor.name}',
                          hintStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: state.sending
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            )
                          : IconButton(
                              key: const ValueKey('send'),
                              tooltip: 'Send',
                              onPressed: () => _send(controller),
                              icon: const Icon(Icons.send_rounded),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(EchoAiController controller) async {
    final message = _text.text;
    if (message.trim().isEmpty) return;
    _text.clear();
    await controller.sendText(message);
  }

  Future<void> _sendPrompt(String prompt, EchoAiController controller) async {
    _text.clear();
    await controller.sendText(prompt);
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }
}

class _AdvisorScopeBanner extends StatelessWidget {
  final EchoAiAdvisor advisor;

  const _AdvisorScopeBanner({required this.advisor});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: advisor.colors.first.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: advisor.colors.first.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Icon(advisor.icon, color: advisor.colors.first, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${advisor.role} only',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptChips extends StatelessWidget {
  final EchoAiAdvisor advisor;
  final ValueChanged<String> onSelected;

  const _PromptChips({required this.advisor, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: advisor.prompts
              .map(
                (prompt) => ActionChip(
                  avatar: Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: advisor.colors.first,
                  ),
                  label: Text(prompt),
                  onPressed: () => onSelected(prompt),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _EchoAiBubble extends StatelessWidget {
  final EchoAiMessage message;
  final EchoAiAdvisor advisor;

  const _EchoAiBubble({required this.message, required this.advisor});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? colorScheme.primary.withValues(alpha: .12)
        : colorScheme.surfaceContainerHighest.withValues(alpha: .55);
    final textColor = isUser
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .82,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isUser ? 14 : 5),
              bottomRight: Radius.circular(isUser ? 5 : 14),
            ),
            border: Border.all(
              color: isUser
                  ? colorScheme.primary.withValues(alpha: .16)
                  : colorScheme.outlineVariant.withValues(alpha: .55),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _cleanAiText(message.text),
                style: TextStyle(
                  color: textColor,
                  fontSize: 15.8,
                  height: 1.34,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  DateFormat.Hm().format(message.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isUser
                        ? colorScheme.onPrimaryContainer.withValues(alpha: .72)
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _cleanAiText(String value) {
  return sanitizeEchoAiText(value)
      .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
      .replaceAll(RegExp(r'__(.*?)__'), r'$1')
      .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
