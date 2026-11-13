import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../models/item.dart';

class SlipLine {
  const SlipLine(this.item, this.qty);
  final Item item;
  final int qty;
  num get amount => item.price * qty;
}

/// The current order, drawn as a counter "parchi": a torn-off slip with a red
/// ledger margin. Quantities sit in the margin, amounts on the right, and the
/// total is ruled off the way a khata page is (single rule above, double below).
class OrderSlip extends StatelessWidget {
  const OrderSlip({
    super.key,
    required this.lines,
    required this.waiterName,
    required this.busy,
    required this.onChange,
    required this.onClear,
    required this.onPlace,
  });

  final List<SlipLine> lines;
  final String? waiterName;
  final bool busy;
  final void Function(String itemId, int delta) onChange;
  final VoidCallback onClear;

  /// Null while no waiter is chosen.
  final void Function(num total)? onPlace;

  static const _margin = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = lines.fold<num>(0, (s, l) => s + l.amount);
    final count = lines.fold<int>(0, (s, l) => s + l.qty);

    return PhysicalShape(
      clipper: const _TornTop(),
      color: HColors.slip,
      elevation: 3,
      shadowColor: const Color(0x331C2230),
      child: SafeArea(
        top: false,
        child: lines.isEmpty
            ? _ruled(
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _empty(theme),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The written part of the slip, ruled by the red margin.
                  _ruled(
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(theme, count),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.sizeOf(context).height * 0.26,
                            ),
                            child: ListView(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              children: [
                                for (final l in lines) _line(theme, l),
                              ],
                            ),
                          ),
                          _total(theme, total),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: FilledButton.icon(
                      onPressed: onPlace == null || busy
                          ? null
                          : () => onPlace!(total),
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        onPlace == null
                            ? 'Choose a waiter to place this order'
                            : 'Place order',
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Draws the red ledger margin down the left of [child] only.
  Widget _ruled(Widget child) => Stack(
    children: [
      const Positioned(
        left: _margin,
        top: 0,
        bottom: 0,
        child: SizedBox(width: 1.5, child: ColoredBox(color: HColors.khataRed)),
      ),
      child,
    ],
  );

  Widget _empty(ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(_margin + 14, 6, 16, 18),
    child: Text(
      'Tap menu items to start an order.',
      style: theme.textTheme.bodyLarge?.copyWith(color: HColors.pencil),
    ),
  );

  Widget _header(ThemeData theme, int count) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 0, 8, 4),
    child: Row(
      children: [
        SizedBox(
          width: _margin,
          child: Text(
            'Qty',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(color: HColors.pencil),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            waiterName == null ? 'New order' : 'Order for $waiterName',
            style: theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: busy ? null : onClear,
          child: const Text('Clear'),
        ),
      ],
    ),
  );

  Widget _line(ThemeData theme, SlipLine l) => Container(
    height: 48,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: HColors.rule)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: _margin,
          child: Text(
            '${l.qty}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: HColors.ink,
              fontFeatures: tabular,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            l.item.name,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        _step(
          Icons.remove,
          'One less ${l.item.name}',
          () => onChange(l.item.id, -1),
        ),
        _step(
          Icons.add,
          'One more ${l.item.name}',
          () => onChange(l.item.id, 1),
        ),
        SizedBox(
          width: 92,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              formatMoney(l.amount),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge?.copyWith(fontFeatures: tabular),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _step(IconData icon, String tip, VoidCallback onTap) => IconButton(
    tooltip: tip,
    onPressed: busy ? null : onTap,
    icon: Icon(icon, size: 20),
    visualDensity: VisualDensity.compact,
    color: HColors.pencil,
  );

  Widget _total(ThemeData theme, num total) => Padding(
    padding: const EdgeInsets.fromLTRB(_margin + 14, 10, 16, 10),
    child: Row(
      children: [
        Text('Total', style: theme.textTheme.titleMedium),
        const Spacer(),
        // Ruled off like a ledger total: double line underneath.
        Container(
          padding: const EdgeInsets.only(bottom: 3),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: HColors.graphite, width: 1),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.only(bottom: 2),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: HColors.graphite, width: 1),
              ),
            ),
            child: Text(
              formatMoney(total),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: HColors.ink,
                fontFeatures: tabular,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A slip torn off a pad: small zigzag teeth along the top edge.
class _TornTop extends CustomClipper<Path> {
  const _TornTop();

  @override
  Path getClip(Size size) {
    const tooth = 10.0, depth = 5.0;
    final path = Path()..moveTo(0, depth);
    var x = 0.0;
    var up = true;
    while (x < size.width) {
      x = (x + tooth / 2).clamp(0, size.width);
      path.lineTo(x, up ? 0 : depth);
      up = !up;
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
