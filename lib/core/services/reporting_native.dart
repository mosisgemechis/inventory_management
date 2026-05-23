import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'reporting_interface.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Platform helpers
// ─────────────────────────────────────────────────────────────────────────────
bool get _isMobile => Platform.isAndroid || Platform.isIOS;

/// Returns the best writable directory for user-visible exports.
///
/// Android: Tries `/storage/emulated/0/Download/CoreInventory/` first (visible
///          in Files app under "Downloads"), falls back to app-external dir.
/// iOS:     Returns `getApplicationDocumentsDirectory()` (visible in Files app
///          under the app name).
Future<Directory> _getExportDir() async {
  if (Platform.isAndroid) {
    // Option 1 — public Downloads (works on most devices including API 29+)
    final downloads = Directory('/storage/emulated/0/Download/CoreInventory');
    try {
      if (!await downloads.exists()) await downloads.create(recursive: true);
      // Quick write test
      final testFile = File('${downloads.path}/.tmp_test');
      await testFile.writeAsString('ok');
      await testFile.delete();
      return downloads;
    } catch (_) {
      // Option 2 — app-specific external dir (always works, always visible in Files)
      final extDir = await getExternalStorageDirectory();
      final dir = Directory('${extDir!.path}/CoreInventory');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
  } else {
    // iOS: Documents dir → visible in Files app → On My iPhone → [AppName]
    final dir = await getApplicationDocumentsDirectory();
    return dir;
  }
}

/// Save [bytes] to [dir]/[baseName], then open the native share sheet.
/// Returns the saved path.
Future<String> _saveAndShare(Directory dir, String baseName, Uint8List bytes) async {
  final file = File('${dir.path}/$baseName');
  await file.writeAsBytes(bytes, flush: true);
  // Offer share sheet so user can also open/send the file
  await Share.shareXFiles([XFile(file.path)], text: 'Core Inventory Export');
  return file.path;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service implementation
// ─────────────────────────────────────────────────────────────────────────────
class ReportingServiceImpl implements ReportingInterface {
  // ── CSV ──────────────────────────────────────────────────────────────────
  @override
  Future<String> exportToCSV(
      String fileName, List<String> headers, List<List<dynamic>> rows) async {
    final csvData = [headers, ...rows];
    final csv = const ListToCsvConverter().convert(csvData);
    final bytes = Uint8List.fromList(csv.codeUnits);
    final baseName = '$fileName.csv';

    if (_isMobile) {
      final dir = await _getExportDir();
      return _saveAndShare(dir, baseName, bytes);
    }

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV',
      fileName: baseName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (outputFile == null) return 'Cancelled';
    if (!outputFile.endsWith('.csv')) outputFile += '.csv';
    await File(outputFile).writeAsBytes(bytes, flush: true);
    return outputFile;
  }

  // ── Excel ─────────────────────────────────────────────────────────────────
  @override
  Future<String> exportToExcel(String fileName, String sheetName,
      List<String> headers, List<List<dynamic>> rows) async {
    final excel = Excel.createExcel();
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final row in rows) {
      sheet.appendRow(row.map((v) => TextCellValue(v.toString())).toList());
    }

    // Set reasonable column widths for readability
    for (var i = 0; i < headers.length; i++) {
       sheet.setColumnWidth(i, 20.0);
    }

    final savedBytes = excel.save();
    if (savedBytes == null || savedBytes.isEmpty) {
      throw Exception('Excel generation failed: no bytes produced.');
    }
    final bytes = Uint8List.fromList(savedBytes);
    final baseName = '$fileName.xlsx';

    if (_isMobile) {
      final dir = await _getExportDir();
      return _saveAndShare(dir, baseName, bytes);
    }

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Excel',
      fileName: baseName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (outputFile == null) return 'Cancelled';
    if (!outputFile.endsWith('.xlsx')) outputFile += '.xlsx';
    await File(outputFile).writeAsBytes(bytes, flush: true);
    return outputFile;
  }

  // ── PDF ───────────────────────────────────────────────────────────────────
  @override
  Future<String> exportToPdf(String fileName, Map<String, dynamic> data) async {
    // ── Fonts (graceful offline fallback) ──
    final labels = data['labels'] as Map<String, dynamic>? ?? {};
    final getL = (String key, String def) => labels[key]?.toString() ?? def;

    pw.Font baseFont;
    pw.Font boldFont;
    pw.Font italicFont;
    pw.Font? ethiopicFont;
    pw.Font? arabicFont;

    try {
      baseFont = await PdfGoogleFonts.notoSansRegular();
      boldFont = await PdfGoogleFonts.notoSansBold();
      italicFont = await PdfGoogleFonts.notoSansItalic();
      ethiopicFont = await PdfGoogleFonts.notoSansEthiopicRegular();
      arabicFont = await PdfGoogleFonts.notoSansArabicRegular();
    } catch (_) {
      baseFont = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
      italicFont = pw.Font.helveticaOblique();
      ethiopicFont = null;
      arabicFont = null;
    }

    final theme = pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
      italic: italicFont,
      fontFallback: [
        if (ethiopicFont != null) ethiopicFont,
        if (arabicFont != null) arabicFont,
      ],
    );

    final pdf = pw.Document(theme: theme);
    final now = DateTime.now();
    final fmt = DateFormat('MMMM d, yyyy  hh:mm a');
    final currencySymbol = data['currency']?.toString() ?? 'USD';
    final currency = NumberFormat.currency(symbol: '$currencySymbol ', decimalDigits: 2);

    // ── Colours ──
    const primaryColor = PdfColor.fromInt(0xFF1B8A5A);
    const accentColor = PdfColor.fromInt(0xFF5B50F9);
    const dangerColor = PdfColor.fromInt(0xFFDC3545);
    const warningColor = PdfColor.fromInt(0xFFFFA500);
    const lightBg = PdfColor.fromInt(0xFFF7F9FC);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0);
    const textSecondary = PdfColor.fromInt(0xFF6B7280);

    // ── Helpers ──
    pw.Widget _statCard(String label, String value,
        {PdfColor accent = primaryColor}) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: lightBg,
            border: pw.Border.all(color: borderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                  width: 20,
                  height: 3,
                  decoration: pw.BoxDecoration(
                      color: accent,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(2)))),
              pw.SizedBox(height: 6),
              pw.Text(value,
                  style: pw.TextStyle(
                      font: boldFont, fontSize: 14, color: accent)),
              pw.SizedBox(height: 3),
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 8, color: textSecondary)),
            ],
          ),
        ),
      );
    }

    pw.Widget _sectionHeader(String title, {PdfColor color = primaryColor}) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10, top: 18),
        child: pw.Row(children: [
          pw.Container(
              width: 4,
              height: 16,
              decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(2)))),
          pw.SizedBox(width: 8),
          pw.Text(title,
              style: pw.TextStyle(
                  font: boldFont, fontSize: 13, color: PdfColors.grey800)),
        ]),
      );
    }

    pw.Widget _tableSection(String title, List<String> headers,
        List<List<String>> rows,
        {PdfColor headerColor = primaryColor}) {
      return pw.Column(children: [
        _sectionHeader(title, color: headerColor),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle:
              pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: headerColor),
          cellStyle: const pw.TextStyle(fontSize: 9),
          rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: borderColor, width: 0.5))),
          cellHeight: 22,
          headerHeight: 24,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
          },
        ),
      ]);
    }

    pw.Widget _fRow(
        String label, String value, pw.Font bold, PdfColor valueColor) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
            pw.Text(value,
                style:
                    pw.TextStyle(font: bold, fontSize: 10, color: valueColor)),
          ],
        ),
      );
    }

    // ── Extract data ──
    final dailySales =
        (data['dailySales'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final topProducts = data['topProducts'] as List? ?? [];
    final leastProducts = data['leastProducts'] as List? ?? [];
    final totalRev = (data['revenue'] ?? 0).toDouble();
    final totalProfit = (data['profit'] ?? 0).toDouble();
    final totalDebt = (data['debt'] ?? 0).toDouble();
    final totalPurchases = (data['purchases'] ?? 0).toDouble();
    final totalOrders = data['orders'] ?? 0;
    final lowCount = data['lowStockCount'] ?? 0;
    final outCount = data['outStockCount'] ?? 0;
    final soonCount = data['soonCount'] ?? 0;
    final expiredCount = data['expiredCount'] ?? 0;
    final companyName = data['companyName']?.toString() ?? 'Core Inventory';
    final companyPhone = data['companyPhone']?.toString() ?? '+251 ...';
    final period = data['period']?.toString() ?? 'Selected Period';

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 30),
      theme: theme,
      header: (ctx) => pw.Column(children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(companyName,
                      style: pw.TextStyle(
                          font: boldFont, fontSize: 20, color: primaryColor)),
                  pw.SizedBox(height: 2),
                  pw.Text(getL('business_report', 'Business Performance Report'),
                      style: const pw.TextStyle(fontSize: 11, color: textSecondary)),
                  if (companyPhone != null) ...[
                    pw.SizedBox(height: 1),
                    pw.Text('Contact: $companyPhone',
                        style: const pw.TextStyle(
                            fontSize: 8, color: textSecondary)),
                  ],
                ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Generated: ${fmt.format(now)}',
                  style: const pw.TextStyle(fontSize: 8, color: textSecondary)),
              pw.SizedBox(height: 2),
              pw.Text('Period: $period',
                  style: const pw.TextStyle(fontSize: 8, color: textSecondary)),
              pw.SizedBox(height: 2),
              pw.Text('Ref: ${now.millisecondsSinceEpoch}',
                  style: const pw.TextStyle(fontSize: 7, color: textSecondary)),
            ]),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: primaryColor, thickness: 1.5),
        pw.SizedBox(height: 4),
      ]),
      build: (ctx) => [
        // 1 — Summary cards
        _sectionHeader('1. ' + getL('executive_summary', 'Executive Summary')),
        pw.Row(children: [
          _statCard(getL('total_revenue', 'Total Revenue'),
              currency.format(totalRev)),
          pw.SizedBox(width: 8),
          _statCard(getL('net_profit', 'Net Profit'),
              currency.format(totalProfit),
              accent: accentColor),
          pw.SizedBox(width: 8),
          _statCard(getL('total_orders', 'Total Orders'), '$totalOrders',
              accent: PdfColor.fromInt(0xFF0EA5E9)),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          _statCard(getL('outstanding_debt', 'Outstanding Debt'),
              currency.format(totalDebt),
              accent: dangerColor),
          pw.SizedBox(width: 8),
          _statCard(getL('total_purchases', 'Total Purchases'),
              currency.format(totalPurchases),
              accent: warningColor),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.SizedBox()),
        ]),

        // 2 — Daily trend
        if (dailySales.isNotEmpty) ...[
          _sectionHeader('2. ' + getL('sales_trend', 'Sales Trend')),
          pw.TableHelper.fromTextArray(
            headers: [
              getL('date', 'Date'),
              getL('revenue', 'Revenue'),
              getL('profit', 'Profit'),
              getL('orders', 'Orders')
            ],
            data: dailySales.map((d) => [
                  d['date']?.toString() ?? '',
                  currency.format((d['revenue'] ?? 0).toDouble()),
                  currency.format((d['profit'] ?? 0).toDouble()),
                  '${d['orders'] ?? 0}',
                ]).toList(),
            headerStyle: pw.TextStyle(
                font: boldFont, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 9),
            rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                    bottom: pw.BorderSide(color: borderColor, width: 0.5))),
            cellHeight: 22,
            headerHeight: 24,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.center,
            },
          ),
        ],

        // 3 — Inventory alerts
        _sectionHeader('3. Inventory Alerts', color: dangerColor),
        pw.Row(children: [
          _statCard('Low Stock', '$lowCount', accent: warningColor),
          pw.SizedBox(width: 8),
          _statCard('Out of Stock', '$outCount', accent: dangerColor),
          pw.SizedBox(width: 8),
          _statCard('Expiring Soon', '$soonCount',
              accent: PdfColor.fromInt(0xFFFF6B35)),
          pw.SizedBox(width: 8),
          _statCard('Expired', '$expiredCount', accent: dangerColor),
        ]),

        // 4 & 5 — Product tables
        if (topProducts.isNotEmpty)
          _tableSection(
              '4. ' + getL('top_selling', 'Top Selling Products'),
              [
                getL('product_name', 'Product Name'),
                getL('units_sold', 'Units Sold'),
                getL('revenue', 'Revenue')
              ],
              topProducts
                  .map<List<String>>((p) => [
                        p['name']?.toString() ?? '',
                        '${p['qty'] ?? 0}',
                        currency.format((p['rev'] ?? 0).toDouble()),
                      ])
                  .toList()),

        if (leastProducts.isNotEmpty)
          _tableSection(
              '5. ' + getL('least_selling', 'Least Selling Products'),
              [
                getL('product_name', 'Product Name'),
                getL('units_sold', 'Units Sold'),
                getL('revenue', 'Revenue')
              ],
              leastProducts
                  .map<List<String>>((p) => [
                        p['name']?.toString() ?? '',
                        '${p['qty'] ?? 0}',
                        currency.format((p['rev'] ?? 0).toDouble()),
                      ])
                  .toList(),
              headerColor: warningColor),

        // 6 — Financial summary
        _sectionHeader('6. ' + getL('financial_summary', 'Financial Summary'),
            color: accentColor),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: lightBg,
            border: pw.Border.all(color: borderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(children: [
            _fRow(getL('total_revenue', 'Total Revenue'),
                currency.format(totalRev), boldFont, primaryColor),
            pw.Divider(color: borderColor, thickness: 0.5),
            _fRow(getL('total_profit', 'Total Profit'),
                currency.format(totalProfit), boldFont, accentColor),
            pw.Divider(color: borderColor, thickness: 0.5),
            _fRow(
                getL('profit_margin', 'Profit Margin'),
                totalRev > 0
                    ? '${(totalProfit / totalRev * 100).toStringAsFixed(1)}%'
                    : '0%',
                boldFont,
                primaryColor),
            pw.Divider(color: borderColor, thickness: 0.5),
            _fRow(getL('outstanding_debt', 'Outstanding Debt'),
                currency.format(totalDebt), boldFont, dangerColor),
            pw.Divider(color: borderColor, thickness: 0.5),
            _fRow(getL('total_purchases', 'Total Purchases'),
                currency.format(totalPurchases), boldFont, warningColor),
          ]),
        ),

        pw.SizedBox(height: 20),
        pw.Text(
          'This report was automatically generated by Core Inventory. '
          'All figures reflect the selected reporting period only.',
          style: const pw.TextStyle(fontSize: 7, color: textSecondary),
          textAlign: pw.TextAlign.center,
        ),
      ],
    ));

    // ── Generate bytes ──
    final bytes = await pdf.save();
    if (bytes.isEmpty)
      throw Exception('PDF generation failed: no bytes produced.');
    final baseName = '$fileName.pdf';

    if (_isMobile) {
      // 1. Save to Downloads/SmartInventory folder
      final dir = await _getExportDir();
      final file = File('${dir.path}/$baseName');
      await file.writeAsBytes(bytes, flush: true);

      // 2. Open native share/print sheet so user can view immediately
      await Printing.sharePdf(bytes: bytes, filename: baseName);

      return file.path; // Return real path for snackbar
    }

    // Desktop: save via file picker dialog
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF Report',
      fileName: baseName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (outputFile == null) return 'Cancelled';
    if (!outputFile.endsWith('.pdf')) outputFile += '.pdf';
    await File(outputFile).writeAsBytes(bytes, flush: true);
    return outputFile;
  }

  pw.Widget _fRow(String label, String value, pw.Font bold, PdfColor valueColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value,
              style: pw.TextStyle(font: bold, fontSize: 10, color: valueColor)),
        ],
      ),
    );
  }
}

ReportingInterface getReportingService() => ReportingServiceImpl();
