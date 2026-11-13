import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// A list's heading with a small live count beside it: "Menu  12 items".
class ListHeading extends StatelessWidget {
  const ListHeading({
    super.key,
    required this.title,
    required this.count,
    required this.one,
    required this.many,
  });

  final String title;
  final int count;
  final String one; // "item"
  final String many; // "items"

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(width: 10),
          Text(
            '$count ${count == 1 ? one : many}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.h.pencil,
              fontFeatures: tabular,
            ),
          ),
        ],
      ),
    );
  }
}
