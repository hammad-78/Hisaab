import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/report.dart';
import '../../services/report_export.dart';

/// Shows a report inside the app, with Download (and Share) for the file.
/// PDF: the real rendered pages. Excel: the same sheets the .xlsx contains.
class ReportViewerScreen extends StatefulWidget {
  const ReportViewerScreen({
    super.key,
    required this.report,
    required this.format,
    required this.cafeName,
  });

  final Report report;
  final ReportFormat format;
  final String cafeName;

  @override
  State<ReportViewerScreen> createState() => _ReportViewerScreenState();
}

class _ReportViewerScreenState extends State<ReportViewerScreen> {
  late final Future<Uint8List> _file = ReportExport.build(
    widget.report,
    widget.format,
    cafeName: widget.cafeName,
  );
  bool _busy = false;

  String get _fileName =>
      '${ReportExport.fileBase(widget.report)}.${widget.format.ext}';

  Future<void> _download() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ReportExport.download(
        widget.report,
        widget.format,
        await _file,
      );
      if (!mounted) return;
      if (saved != null && saved.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.trf('Downloaded {0}', [_fileName])),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.trf('Download failed. Try again. ({0})', [e])),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    try {
      await ReportExport.share(widget.report, widget.format, await _file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.trf('Could not share the file. ({0})', [e]),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = widget.format;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.trf('Sales report ({0})', [f.label])),
            Text(
              '${ReportExport.period(widget.report)}, ${widget.report.shopLabel}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.h.pencil,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.tr('Share'),
            icon: const Icon(Icons.share_outlined),
            onPressed: _share,
          ),
        ],
      ),
      body: f == ReportFormat.pdf
          ? FutureBuilder<Uint8List>(
              future: _file,
              builder: (_, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      context.trf('The PDF could not be built. {0}', [
                        snap.error,
                      ]),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return PdfPreview(
                  build: (_) => snap.data!,
                  pdfFileName: _fileName,
                  useActions: false,
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  scrollViewDecoration: BoxDecoration(color: context.h.paper),
                );
              },
            )
          : _ExcelPreview(report: widget.report, cafeName: widget.cafeName),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: context.h.slip,
            border: Border(top: BorderSide(color: context.h.rule)),
          ),
          child: FilledButton.icon(
            onPressed: _busy ? null : _download,
            icon: _busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.h.onInk,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(context.trf('Download {0}', [f.label])),
          ),
        ),
      ),
    );
  }
}

/// The workbook's four sheets as tabs, laid out like a spreadsheet.
class _ExcelPreview extends StatelessWidget {
  const _ExcelPreview({required this.report, required this.cafeName});
  final Report report;
  final String cafeName;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final sheets = <String, List<List<String>>>{
      'Summary': [
        ['Cafe', cafeName],
        ['Period', ReportExport.period(r)],
        ['Shop', r.shopLabel],
        ['Total sales', formatPrice(r.total)],
        ['Orders', '${r.orders}'],
        ['Items sold', '${r.itemsSold}'],
      ],
      'By shop': [
        ['Shop', 'Orders', 'Amount'],
        for (final l in r.byShop) [l.name, '${l.count}', formatPrice(l.amount)],
      ],
      'By item': [
        ['Item', 'Qty', 'Amount'],
        for (final l in r.byItem) [l.name, '${l.count}', formatPrice(l.amount)],
      ],
      'By waiter': [
        ['Waiter', 'Shop', 'Orders', 'Amount'],
        for (final l in r.byWaiter)
          [l.name, l.sub ?? '', '${l.count}', formatPrice(l.amount)],
      ],
    };

    return DefaultTabController(
      length: sheets.length,
      child: Column(
        children: [
          Material(
            color: context.h.slip,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final name in sheets.keys) Tab(text: name)],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final e in sheets.entries)
                  _Sheet(rows: e.value, hasHeader: e.key != 'Summary'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A plain spreadsheet grid: bordered cells, header row shaded, numbers
/// right-aligned. Scrolls sideways if the columns don't fit.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.rows, required this.hasHeader});
  final List<List<String>> rows;
  final bool hasHeader;

  static final _number = RegExp(r'^-?[\d.]+$');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = context.h;

    if (hasHeader && rows.length == 1) {
      return Center(child: Text(context.tr('No rows in this sheet.')));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: h.rule),
          children: [
            for (var i = 0; i < rows.length; i++)
              TableRow(
                decoration: BoxDecoration(
                  color: hasHeader && i == 0 ? h.inkSoft : h.slip,
                ),
                children: [
                  for (final cell in rows[i])
                    Container(
                      constraints: const BoxConstraints(minWidth: 72),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      alignment: _number.hasMatch(cell)
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Text(
                        cell,
                        style:
                            (hasHeader && i == 0
                                    ? theme.textTheme.titleSmall
                                    : theme.textTheme.bodyMedium)
                                ?.copyWith(fontFeatures: tabular),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
