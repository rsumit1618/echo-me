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
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: state.messages.length + (state.sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == state.messages.length) {
                  return _TypingBubble(advisor: widget.advisor);
                }
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
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
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

class _TypingBubble extends StatelessWidget {
  final EchoAiAdvisor advisor;

  const _TypingBubble({required this.advisor});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: advisor.colors.first,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${advisor.name} is thinking...',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
        ? colorScheme.primaryContainer
        : colorScheme.surface;
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
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 7),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            border: Border.all(
              color: isUser
                  ? colorScheme.primary.withValues(alpha: .28)
                  : advisor.colors.first.withValues(alpha: .24),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: .08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(advisor.icon, size: 16, color: advisor.colors.first),
                      const SizedBox(width: 6),
                      Text(
                        advisor.name,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: advisor.colors.first,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
              _ReadableAiText(
                text: message.text,
                color: textColor,
                accentColor: advisor.colors.first,
                compact: isUser,
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

class _ReadableAiText extends StatelessWidget {
  final String text;
  final Color color;
  final Color accentColor;
  final bool compact;

  const _ReadableAiText({
    required this.text,
    required this.color,
    required this.accentColor,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .toList();

    if (compact || lines.length == 1) {
      return Text(_cleanInlineMarkdown(text), style: _baseStyle(context));
    }

    final children = <Widget>[];
    for (final rawLine in lines) {
      if (rawLine.isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }

      final line = _cleanInlineMarkdown(rawLine);
      final bulletMatch = RegExp(r'^[-*]\s+(.+)$').firstMatch(line);
      final numberMatch = RegExp(r'^(\d+)[.)]\s+(.+)$').firstMatch(line);
      final heading = _headingText(line);

      if (heading != null) {
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 10, bottom: 4),
            child: Text(
              heading,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                height: 1.22,
              ),
            ),
          ),
        );
      } else if (bulletMatch != null) {
        children.add(_BulletLine(text: bulletMatch.group(1)!, color: color));
      } else if (numberMatch != null) {
        children.add(
          _NumberLine(
            number: numberMatch.group(1)!,
            text: numberMatch.group(2)!,
            color: color,
            accentColor: accentColor,
          ),
        );
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(line, style: _baseStyle(context)),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  TextStyle _baseStyle(BuildContext context) {
    return TextStyle(
      color: color,
      fontSize: 16,
      height: 1.38,
      fontWeight: FontWeight.w500,
    );
  }

  String _cleanInlineMarkdown(String value) {
    return value
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
        .replaceAll(RegExp(r'__(.*?)__'), r'$1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .trim();
  }

  String? _headingText(String line) {
    final headingMatch = RegExp(r'^\s*#{1,4}\s+(.+)$').firstMatch(line);
    if (headingMatch != null) return headingMatch.group(1);
    if (line.endsWith(':') && line.length <= 42)
      return line.substring(0, line.length - 1);
    return null;
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  final Color color;

  const _BulletLine({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 16,
                height: 1.36,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberLine extends StatelessWidget {
  final String number;
  final String text;
  final Color color;
  final Color accentColor;

  const _NumberLine({
    required this.number,
    required this.text,
    required this.color,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              number,
              style: TextStyle(
                color: accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 16,
                height: 1.36,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
