import 'package:echo_me/features/echo_ai/echo_ai_advisor.dart';
import 'package:flutter/material.dart';

class EchoAiAdvisorIcon extends StatelessWidget {
  final EchoAiAdvisor advisor;
  final double size;
  final double iconSize;

  const EchoAiAdvisorIcon({
    super.key,
    required this.advisor,
    this.size = 58,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: advisor.colors,
        ),
        boxShadow: [
          BoxShadow(
            color: advisor.colors.first.withValues(alpha: .24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(advisor.icon, color: advisor.colors.first, size: iconSize),
      ),
    );
  }
}
