import 'package:flutter/material.dart';

import '../l10n.dart';
import '../theme.dart';

/// Asks before deleting a menu item or waiter. Past sales keep their own copy
/// of names and prices, so deleting never changes old reports.
Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.trf('Delete {0}?', [what])),
      content: Text(ctx.tr('Past sales and reports are not affected.')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.tr('Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ctx.h.khataRed,
            minimumSize: const Size(0, 44),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.tr('Delete')),
        ),
      ],
    ),
  );
  return ok ?? false;
}
