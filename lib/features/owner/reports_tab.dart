import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/report.dart';
import '../../models/shop.dart';
import '../../providers/cafe_provider.dart';
import '../../providers/sales_provider.dart';
import '../../services/report_export.dart';

enum _Preset { today, yesterday, last7, thisMonth, custom }

const _presetLabels = {
  _Preset.today: 'Today',
  _Preset.yesterday: 'Yesterday',
  _Preset.last7: 'Last 7 days',
  _Preset.thisMonth: 'This month',
  _Preset.custom: 'Custom',
};

class ReportsTab extends ConsumerStatefulWidget {
  const ReportsTab({super.key, required this.cafeId});
  final String cafeId;

  @override
  ConsumerState<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<ReportsTab> {
  _Preset _preset = _Preset.today;
  late DateTime _from;
  late DateTime _to;
  String? _shopId; // null = all shops
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _applyPreset(_Preset.today);
  }

  void _applyPreset(_Preset p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (p) {
      case _Preset.today:
        _from = _to = today;
      case _Preset.yesterday:
        _from = _to = today.subtract(const Duration(days: 1));
      case _Preset.last7:
        _from = today.subtract(const Duration(days: 6));
        _to = today;
      case _Preset.thisMonth:
        _from = DateTime(today.year, today.month, 1);
        _to = today;
      case _Preset.custom:
        break; // set by the date picker
    }
    _preset = p;
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null) return;
    setState(() {
      _preset = _Preset.custom;
      _from = picked.start;
      _to = picked.end;
    });
  }

  Future<void> _export(Report r, bool pdf) async {
    setState(() => _exporting = true);
    try {
      final cafeName =
          ref.read(cafeNameProvider(widget.cafeId)).valueOrNull ?? 'Cafe';
      if (pdf) {
        await ReportExport.sharePdf(r, cafeName: cafeName);
      } else {
        await ReportExport.shareExcel(r, cafeName: cafeName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shops =
        ref.watch(shopsProvider(widget.cafeId)).valueOrNull ?? const <Shop>[];
    final shopNames = {for (final s in shops) s.id: s.name};
    final fromKey = dayKey(_from), toKey = dayKey(_to);
    final sales = ref.watch(rangeSalesProvider(
        (cafeId: widget.cafeId, from: fromKey, to: toKey)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in _Preset.values)
              ChoiceChip(
                label: Text(p == _Preset.custom && _preset == _Preset.custom
                    ? (fromKey == toKey ? fromKey : '$fromKey → $toKey')
                    : _presetLabels[p]!),
                selected: _preset == p,
                onSelected: (_) => p == _Preset.custom
                    ? _pickCustom()
                    : setState(() => _applyPreset(p)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: _shopId,
          decoration: const InputDecoration(
              labelText: 'Shop', isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('All shops')),
            for (final s in shops)
              DropdownMenuItem(value: s.id, child: Text(s.name)),
          ],
          onChanged: (v) => setState(() => _shopId = v),
        ),
        const SizedBox(height: 16),
        sales.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Could not load report: $e'),
          data: (all) {
            final filtered = _shopId == null
                ? all
                : all.where((s) => s.shopId == _shopId).toList();
            final report = Report.from(
              sales: filtered,
              shopNames: shopNames,
              fromDay: fromKey,
              toDay: toKey,
              shopLabel: _shopId == null
                  ? 'All shops'
                  : (shopNames[_shopId] ?? 'Shop'),
            );
            return _ReportView(
              report: report,
              showShops: _shopId == null,
              exporting: _exporting,
              onExport: (pdf) => _export(report, pdf),
            );
          },
        ),
      ],
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({
    required this.report,
    required this.showShops,
    required this.exporting,
    required this.onExport,
  });

  final Report report;
  final bool showShops;
  final bool exporting;
  final void Function(bool pdf) onExport;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final theme = Theme.of(context);

    final num_ = theme.textTheme.bodyLarge?.copyWith(fontFeatures: tabular);
    final head = theme.textTheme.labelMedium?.copyWith(color: HColors.pencil);

    // A ruled ledger table: name on the left, figures right-aligned in columns.
    Widget section(String title, String countLabel, List<ReportLine> lines) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 28),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Spacer(),
                SizedBox(width: 64, child: Text(countLabel, textAlign: TextAlign.right, style: head)),
                SizedBox(width: 110, child: Text('Amount', textAlign: TextAlign.right, style: head)),
              ]),
            ),
            const Divider(color: HColors.graphite),
            for (final l in lines)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: HColors.rule))),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.name, style: theme.textTheme.bodyLarge),
                        if (l.sub != null)
                          Text(l.sub!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: HColors.pencil)),
                      ],
                    ),
                  ),
                  SizedBox(
                      width: 64,
                      child: Text('${l.count}', textAlign: TextAlign.right, style: num_)),
                  SizedBox(
                      width: 110,
                      child: Text(formatMoney(l.amount),
                          textAlign: TextAlign.right, style: num_)),
                ]),
              ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The total, ruled off like the bottom of a ledger page.
        Text('Total sales', style: theme.textTheme.bodyLarge?.copyWith(color: HColors.pencil)),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.only(bottom: 3),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: HColors.ink, width: 1.5))),
            child: Container(
              padding: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: HColors.ink, width: 1.5))),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(formatMoney(r.total),
                    style: theme.textTheme.displaySmall?.copyWith(
                        color: HColors.ink,
                        fontWeight: FontWeight.w800,
                        fontFeatures: tabular)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${r.orders} ${r.orders == 1 ? 'order' : 'orders'}, '
          '${r.itemsSold} ${r.itemsSold == 1 ? 'item' : 'items'} sold',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: exporting || r.isEmpty ? null : () => onExport(true),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Share PDF'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    exporting || r.isEmpty ? null : () => onExport(false),
                icon: const Icon(Icons.grid_on),
                label: const Text('Share Excel'),
              ),
            ),
          ],
        ),
        if (r.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
                child: Text(
                    'No sales in this period. Pick another date range or shop.',
                    textAlign: TextAlign.center)),
          )
        else ...[
          if (showShops) section('By shop', 'Orders', r.byShop),
          section('By item', 'Qty', r.byItem),
          section('By waiter', 'Orders', r.byWaiter),
        ],
      ],
    );
  }
}
