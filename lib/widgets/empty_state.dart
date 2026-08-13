import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: const Alignment(0, -0.33),
      child: Icon(
        Icons.medical_services_outlined,
        size: 120,
        color: theme.colorScheme.primary.withValues(alpha: 0.2),
      ),
    );
  }
}