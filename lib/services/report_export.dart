import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../models/report.dart';

enum ReportFormat {
  pdf('PDF', 'pdf', 'application/pdf', MimeType.pdf),
  excel(
    'Excel',
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    MimeType.microsoftExcel,
  );

  const ReportFormat(this.label, this.ext, this.mime, this.saverType);
  final String label;
  final String ext;
  final String mime;
  final MimeType saverType;
}

/// Builds PDF / Excel files from a [Report], saves them to the device, or
/// opens the share sheet (WhatsApp, Gmail, Drive...).
class ReportExport {
  static String period(Report r) =>
      r.fromDay == r.toDay ? r.fromDay : '${r.fromDay} to ${r.toDay}';

  /// File name without extension, e.g. hisaab_report_2026-11-01_2026-11-13
  static String fileBase(Report r) =>
      'hisaab_report_${r.fromDay}${r.fromDay == r.toDay ? '' : '_${r.toDay}'}';

  static Future<Uint8List> build(
    Report r,
    ReportFormat f, {
    required String cafeName,
  }) async => Uint8List.fromList(
    f == ReportFormat.pdf
        ? await buildPdf(r, cafeName: cafeName)
        : buildExcel(r, cafeName: cafeName),
  );

  /// Opens the system "Save to" picker so the user chooses where the file
  /// goes (e.g. Downloads). Returns the saved location, or null if cancelled.
  static Future<String?> download(Report r, ReportFormat f, Uint8List bytes) =>
      FileSaver.instance.saveAs(
        name: fileBase(r),
        bytes: bytes,
        fileExtension: f.ext,
        mimeType: f.saverType,
      );

  static Future<void> share(Report r, ReportFormat f, Uint8List bytes) =>
      _share(bytes, '${fileBase(r)}.${f.ext}', f.mime);

  static Future<List<int>> buildPdf(Report r, {required String cafeName}) {
    final doc = pw.Document();

    pw.Widget table(
      String title,
      List<String> headers,
      List<List<String>> rows,
    ) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 16),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        rows.isEmpty
            ? pw.Text('No data')
            : pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  for (var i = 1; i < headers.length; i++)
                    i: pw.Alignment.centerRight,
                },
              ),
      ],
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Text(
            cafeName,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Sales report  |  ${period(r)}  |  ${r.shopLabel}'),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              _pdfStat('Total sales', formatPrice(r.total)),
              _pdfStat('Orders', '${r.orders}'),
              _pdfStat('Items sold', '${r.itemsSold}'),
            ],
          ),
          table(
            'By shop',
            ['Shop', 'Orders', 'Amount'],
            [
              for (final l in r.byShop)
                [l.name, '${l.count}', formatPrice(l.amount)],
            ],
          ),
          table(
            'By item',
            ['Item', 'Qty', 'Amount'],
            [
              for (final l in r.byItem)
                [l.name, '${l.count}', formatPrice(l.amount)],
            ],
          ),
          table(
            'By waiter',
            ['Waiter', 'Shop', 'Orders', 'Amount'],
            [
              for (final l in r.byWaiter)
                [l.name, l.sub ?? '', '${l.count}', formatPrice(l.amount)],
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _pdfStat(String label, String value) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ),
  );

  // ---------------- Excel ----------------
  static List<int> buildExcel(Report r, {required String cafeName}) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Summary');

    CellValue num_(num n) =>
        n is int ? IntCellValue(n) : DoubleCellValue(n.toDouble());
    CellValue text(String s) => TextCellValue(s);

    final summary = excel['Summary'];
    summary.appendRow([text('Cafe'), text(cafeName)]);
    summary.appendRow([text('Period'), text(period(r))]);
    summary.appendRow([text('Shop'), text(r.shopLabel)]);
    summary.appendRow([text('Total sales'), num_(r.total)]);
    summary.appendRow([text('Orders'), IntCellValue(r.orders)]);
    summary.appendRow([text('Items sold'), IntCellValue(r.itemsSold)]);

    void sheet(
      String name,
      List<String> headers,
      List<ReportLine> lines, {
      bool withSub = false,
    }) {
      final s = excel[name];
      s.appendRow([for (final h in headers) text(h)]);
      for (final l in lines) {
        s.appendRow([
          text(l.name),
          if (withSub) text(l.sub ?? ''),
          IntCellValue(l.count),
          num_(l.amount),
        ]);
      }
    }

    sheet('By shop', ['Shop', 'Orders', 'Amount'], r.byShop);
    sheet('By item', ['Item', 'Qty', 'Amount'], r.byItem);
    sheet(
      'By waiter',
      ['Waiter', 'Shop', 'Orders', 'Amount'],
      r.byWaiter,
      withSub: true,
    );

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Could not build the Excel file');
    return bytes;
  }

  // ---------------- share ----------------
  static Future<void> _share(List<int> bytes, String name, String mime) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mime)],
        subject: name,
      ),
    );
  }
}
