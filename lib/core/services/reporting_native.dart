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

  // ── Single-Sheet Legacy/Raw Excel Export ──────────────────────────────────
  @override
  Future<String> exportToExcel(String fileName, String sheetName,
      List<String> headers, List<List<dynamic>> rows) async {
    final excel = Excel.createExcel();
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final row in rows) {
      sheet.appendRow(row.map((v) {
        if (v == null) return TextCellValue('');
        if (v is int) return IntCellValue(v);
        if (v is double) {
          if (v.isNaN || v.isInfinite) return IntCellValue(0);
          if (v.truncateToDouble() == v) return IntCellValue(v.toInt());
          return DoubleCellValue(v);
        }
        if (v is num) {
          final d = v.toDouble();
          if (d.isNaN || d.isInfinite) return IntCellValue(0);
          if (d.truncateToDouble() == d) return IntCellValue(d.toInt());
          return DoubleCellValue(d);
        }
        if (v is bool) return BoolCellValue(v);
        return TextCellValue(v.toString());
      }).toList());
    }

    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

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

  // ── Multi-Sheet Business Performance Excel Report ────────────────────────
  @override
  Future<String> exportReportToExcel(String fileName, Map<String, dynamic> data) async {
    final excel = Excel.createExcel();
    final now = DateTime.now();

    // Helper to output native Excel numeric/primitive CellValues
    CellValue toCell(dynamic val) {
      if (val == null) return TextCellValue('');
      if (val is int) return IntCellValue(val);
      if (val is double) {
        if (val.isNaN || val.isInfinite) return IntCellValue(0);
        if (val.truncateToDouble() == val) {
          return IntCellValue(val.toInt());
        }
        return DoubleCellValue(val);
      }
      if (val is num) {
        final d = val.toDouble();
        if (d.isNaN || d.isInfinite) return IntCellValue(0);
        if (d.truncateToDouble() == d) {
          return IntCellValue(d.toInt());
        }
        return DoubleCellValue(d);
      }
      if (val is bool) return BoolCellValue(val);
      return TextCellValue(val.toString());
    }

    // Extract exact dataset (identical to PDF report)
    final totalRev = (data['revenue'] ?? 0.0).toDouble();
    final totalProfit = (data['profit'] ?? 0.0).toDouble();
    final totalDebt = (data['debt'] ?? 0.0).toDouble();
    final totalPurchases = (data['purchases'] ?? 0.0).toDouble();
    final totalOrders = (data['orders'] ?? 0) as num;
    final grossMarginPct = totalRev > 0 ? (totalProfit / totalRev) * 100.0 : 0.0;

    final lowStockCount = (data['lowStockCount'] ?? 0) as num;
    final outStockCount = (data['outStockCount'] ?? 0) as num;
    final expiredCount = (data['expiredCount'] ?? 0) as num;
    final soonCount = (data['soonCount'] ?? 0) as num;

    final lowStockItems = (data['lowStockItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final outOfStockItems = (data['outOfStockItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final expiringSoonItems = (data['expiringSoonItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final expiredItems = (data['expiredItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final topProducts = (data['topProducts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final salesDetails = (data['sales'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final companyName = data['companyName']?.toString() ?? 'SmartInventory ERP';
    final branchName = data['branchName']?.toString() ?? 'All Branches';
    final period = data['period']?.toString() ?? 'Selected Period';
    final currencySymbol = data['currency']?.toString() ?? 'ETB';
    final generatedBy = data['generatedBy']?.toString() ?? 'System Admin';
    final refNo = 'REF-${DateFormat('yyyyMMdd-HHmmss').format(now)}';

    // ─────────────────────────────────────────────────────────────────────────
    // Sheet 1 — Business Performance Report
    // ─────────────────────────────────────────────────────────────────────────
    final sheet1 = excel['Business Performance Report'];
    excel.setDefaultSheet('Business Performance Report');

    sheet1.appendRow([TextCellValue('Business Performance Report')]);
    sheet1.appendRow([TextCellValue('')]);

    // Header Metadata Table
    sheet1.appendRow([TextCellValue('Field'), TextCellValue('Value')]);
    sheet1.appendRow([TextCellValue('Business'), TextCellValue(companyName)]);
    sheet1.appendRow([TextCellValue('Branch'), TextCellValue(branchName)]);
    sheet1.appendRow([TextCellValue('Reporting Period'), TextCellValue(period)]);
    sheet1.appendRow([TextCellValue('Date'), TextCellValue(DateFormat('yyyy-MM-dd').format(now))]);
    sheet1.appendRow([TextCellValue('Currency'), TextCellValue(currencySymbol)]);
    sheet1.appendRow([TextCellValue('Generated By'), TextCellValue(generatedBy)]);
    sheet1.appendRow([TextCellValue('Report Reference'), TextCellValue(refNo)]);
    sheet1.appendRow([TextCellValue('')]);

    // 💰 Money Overview
    sheet1.appendRow([TextCellValue('💰 Money Overview'), TextCellValue('Value'), TextCellValue('Unit')]);
    sheet1.appendRow([TextCellValue('Total Sales Revenue'), toCell(totalRev), TextCellValue(currencySymbol)]);
    sheet1.appendRow([TextCellValue('Total Profit Earned'), toCell(totalProfit), TextCellValue(currencySymbol)]);
    sheet1.appendRow([TextCellValue('Profit Percentage (Margin)'), toCell(grossMarginPct), TextCellValue('%')]);
    sheet1.appendRow([TextCellValue('Number of Sales Transactions'), toCell(totalOrders), TextCellValue('Transactions')]);
    sheet1.appendRow([TextCellValue('Total Purchases (Stock Cost)'), toCell(totalPurchases), TextCellValue(currencySymbol)]);
    sheet1.appendRow([TextCellValue('Money Owed by Customers'), toCell(totalDebt), TextCellValue(currencySymbol)]);
    sheet1.appendRow([TextCellValue('')]);

    // 📦 Inventory Health Overview
    sheet1.appendRow([TextCellValue('📦 Inventory Health Overview'), TextCellValue('Count'), TextCellValue('Status')]);
    sheet1.appendRow([TextCellValue('Low Stock Items'), toCell(lowStockCount), TextCellValue('Alerts')]);
    sheet1.appendRow([TextCellValue('Out of Stock Items'), toCell(outStockCount), TextCellValue('Critical')]);
    sheet1.appendRow([TextCellValue('Expired Items'), toCell(expiredCount), TextCellValue('Action Required')]);
    sheet1.appendRow([TextCellValue('Expiring Soon Items'), toCell(soonCount), TextCellValue('Warning')]);
    sheet1.appendRow([TextCellValue('')]);

    // Top Products Summary
    sheet1.appendRow([TextCellValue('Top Products Summary — By Quantity Sold')]);
    sheet1.appendRow([TextCellValue('Product'), TextCellValue('Unit'), TextCellValue('Qty Sold'), TextCellValue('Revenue'), TextCellValue('Profit')]);
    for (var p in topProducts.take(5)) {
      final name = p['name']?.toString() ?? 'Unknown';
      final unitStr = p['unit']?.toString() ?? '';
      final qtyNum = (p['qty'] ?? 0) as num;
      final rev = (p['rev'] ?? 0.0).toDouble();
      final prof = (p['profit'] ?? 0.0).toDouble();
      sheet1.appendRow([
        TextCellValue(name),
        TextCellValue(unitStr),
        toCell(qtyNum),
        toCell(rev),
        toCell(prof),
      ]);
    }

    sheet1.setColumnWidth(0, 32.0);
    sheet1.setColumnWidth(1, 20.0);
    sheet1.setColumnWidth(2, 20.0);
    sheet1.setColumnWidth(3, 20.0);
    sheet1.setColumnWidth(4, 20.0);

    // ─────────────────────────────────────────────────────────────────────────
    // Sheet 2 — Sales Details
    // ─────────────────────────────────────────────────────────────────────────
    final sheet2 = excel['Sales Details'];
    final salesHeaders = [
      'Date', 'Product', 'Barcode / SKU', 'Unit', 'Quantity', 'Unit Price',
      'Revenue', 'Cost', 'Profit', 'Customer', 'Payment Method', 'Branch', 'Cashier'
    ];
    sheet2.appendRow(salesHeaders.map((h) => TextCellValue(h)).toList());

    for (var s in salesDetails) {
      final tsRaw = s['timestamp'];
      DateTime? ts;
      if (tsRaw is DateTime) ts = tsRaw;
      else if (tsRaw is String) ts = DateTime.tryParse(tsRaw);
      final dateStr = ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts) : 'N/A';

      final name = s['itemName']?.toString() ?? 'Unknown';
      final sku = s['barcode']?.toString() ?? s['sku']?.toString() ?? 'N/A';
      final unitStr = s['unit']?.toString() ?? s['unitType']?.toString() ?? s['packageUnit']?.toString() ?? '';
      final qtyRaw = s['quantity'] ?? 0;
      final qtyNum = (qtyRaw is num) ? qtyRaw : (double.tryParse(qtyRaw.toString()) ?? 0);
      final rev = (s['totalPrice'] ?? 0.0).toDouble();
      final prof = (s['profit'] ?? 0.0).toDouble();
      final cost = (s['totalCost'] ?? (rev - prof)).toDouble();
      final unitPrice = qtyNum > 0 ? (rev / qtyNum) : rev;

      final cust = s['customerName']?.toString() ?? 'Guest';
      final pm = s['isDebt'] == true ? 'Debt' : 'Cash';
      final bId = s['branchId']?.toString() ?? branchName;
      final cashier = s['cashierName']?.toString() ?? s['username']?.toString() ?? generatedBy;

      sheet2.appendRow([
        TextCellValue(dateStr),
        TextCellValue(name),
        TextCellValue(sku),
        TextCellValue(unitStr),
        toCell(qtyNum),
        toCell(unitPrice),
        toCell(rev),
        toCell(cost),
        toCell(prof),
        TextCellValue(cust),
        TextCellValue(pm),
        TextCellValue(bId),
        TextCellValue(cashier),
      ]);
    }

    for (var i = 0; i < salesHeaders.length; i++) {
      sheet2.setColumnWidth(i, 20.0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Sheet 3 — Top Products — By Quantity Sold
    // ─────────────────────────────────────────────────────────────────────────
    final sheet3 = excel['Top Products — By Quantity Sold'];
    final topHeaders = [
      'Rank', 'Product', 'Unit', 'Units Sold', 'Total Revenue', 'Profit',
      'Profit Margin %', 'Avg Selling Price', 'Revenue Contribution %'
    ];
    sheet3.appendRow(topHeaders.map((h) => TextCellValue(h)).toList());

    for (int idx = 0; idx < topProducts.length; idx++) {
      final p = topProducts[idx];
      final name = p['name']?.toString() ?? 'Unknown';
      final unitStr = p['unit']?.toString() ?? '';
      final qtyNum = (p['qty'] ?? 0) as num;
      final rev = (p['rev'] ?? 0.0).toDouble();
      final prof = (p['profit'] ?? 0.0).toDouble();
      final margin = rev > 0 ? (prof / rev) * 100.0 : 0.0;
      final avgPrice = (p['avgPrice'] ?? (qtyNum > 0 ? rev / qtyNum : 0.0)).toDouble();
      final contrib = (p['contrib'] ?? (totalRev > 0 ? (rev / totalRev) * 100.0 : 0.0)).toDouble();

      sheet3.appendRow([
        IntCellValue(idx + 1),
        TextCellValue(name),
        TextCellValue(unitStr),
        toCell(qtyNum),
        toCell(rev),
        toCell(prof),
        toCell(margin),
        toCell(avgPrice),
        toCell(contrib),
      ]);
    }

    for (var i = 0; i < topHeaders.length; i++) {
      sheet3.setColumnWidth(i, 20.0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Sheet 4 — Inventory Alerts
    // ─────────────────────────────────────────────────────────────────────────
    final sheet4 = excel['Inventory Alerts'];
    final alertHeaders = [
      'Product', 'SKU / Identifier', 'Unit', 'Batch',
      'Expiry Date', 'Current Stock', 'Alert Type', 'Days Until/Since Expiry', 'Recommended Action'
    ];
    sheet4.appendRow(alertHeaders.map((h) => TextCellValue(h)).toList());

    for (var p in lowStockItems) {
      sheet4.appendRow([
        TextCellValue(p['name']?.toString() ?? 'Unknown'),
        TextCellValue(p['sku']?.toString() ?? 'N/A'),
        TextCellValue(p['unit']?.toString() ?? ''),
        TextCellValue(p['batch']?.toString() ?? 'N/A'),
        TextCellValue(p['expiryDate']?.toString() ?? 'N/A'),
        toCell(p['qty'] ?? 0),
        TextCellValue('Low Stock'),
        TextCellValue('N/A'),
        TextCellValue('Reorder Demand'),
      ]);
    }

    for (var p in outOfStockItems) {
      sheet4.appendRow([
        TextCellValue(p['name']?.toString() ?? 'Unknown'),
        TextCellValue(p['sku']?.toString() ?? 'N/A'),
        TextCellValue(p['unit']?.toString() ?? ''),
        TextCellValue(p['batch']?.toString() ?? 'N/A'),
        TextCellValue('N/A'),
        toCell(0),
        TextCellValue('Out of Stock'),
        TextCellValue('N/A'),
        TextCellValue('Critical Shutdown'),
      ]);
    }

    for (var p in expiredItems) {
      sheet4.appendRow([
        TextCellValue(p['name']?.toString() ?? 'Unknown'),
        TextCellValue(p['sku']?.toString() ?? 'N/A'),
        TextCellValue(p['unit']?.toString() ?? ''),
        TextCellValue(p['batch']?.toString() ?? 'N/A'),
        TextCellValue(p['expiryDate']?.toString() ?? 'N/A'),
        toCell(p['qty'] ?? 0),
        TextCellValue('Expired'),
        toCell(p['daysDiff'] ?? 0),
        TextCellValue('Immediate Removal'),
      ]);
    }

    for (var p in expiringSoonItems) {
      sheet4.appendRow([
        TextCellValue(p['name']?.toString() ?? 'Unknown'),
        TextCellValue(p['sku']?.toString() ?? 'N/A'),
        TextCellValue(p['unit']?.toString() ?? ''),
        TextCellValue(p['batch']?.toString() ?? 'N/A'),
        TextCellValue(p['expiryDate']?.toString() ?? 'N/A'),
        toCell(p['qty'] ?? 0),
        TextCellValue('Expiring Soon'),
        toCell(p['daysDiff'] ?? 0),
        TextCellValue('High Urgency Alert'),
      ]);
    }

    for (var i = 0; i < alertHeaders.length; i++) {
      sheet4.setColumnWidth(i, 20.0);
    }

    // ── Remove default empty Sheet1 if present ──
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
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
      dialogTitle: 'Save Business Performance Excel Report',
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
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final currencySymbol = data['currency']?.toString() ?? 'ETB';
    final currency = NumberFormat.currency(symbol: '$currencySymbol ', decimalDigits: 2);

    // ── Colours ──
    const primaryColor = PdfColor.fromInt(0xFF0F172A); // Slate Dark
    const secondaryColor = PdfColor.fromInt(0xFF10B981); // Emerald
    const accentColor = PdfColor.fromInt(0xFF6366F1); // Indigo
    const warningColor = PdfColor.fromInt(0xFFD97706); // Amber
    const dangerColor = PdfColor.fromInt(0xFFDC2626); // Red
    const lightBg = PdfColor.fromInt(0xFFF8FAFC);
    const borderTint = PdfColor.fromInt(0xFFE2E8F0);
    const textSecondary = PdfColor.fromInt(0xFF64748B);

    // ── Stat Card Helper ──
    pw.Widget statCard(String label, String value, {PdfColor? accent}) {
      final cardAccent = accent ?? primaryColor;
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: lightBg,
            border: pw.Border.all(color: borderTint),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 18,
                height: 3,
                decoration: pw.BoxDecoration(
                  color: cardAccent,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 13, color: primaryColor)),
              pw.SizedBox(height: 2),
              pw.Text(label, style: pw.TextStyle(fontSize: 7.5, color: textSecondary, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    // ── Section Header Helper ──
    pw.Widget sectionHeader(String title, {PdfColor? color}) {
      final headerColor = color ?? accentColor;
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8, top: 16),
        child: pw.Row(
          children: [
            pw.Container(
              width: 3.5,
              height: 14,
              decoration: pw.BoxDecoration(
                color: headerColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              title,
              style: pw.TextStyle(font: boldFont, fontSize: 11, color: primaryColor),
            ),
          ],
        ),
      );
    }

    // ── Table Helper (with alternating rows) ──
    pw.Widget tableSection(String title, List<String> headers, List<List<String>> rows, {PdfColor? headerColor}) {
      final tblHeaderColor = headerColor ?? primaryColor;
      const altRowBg = PdfColor.fromInt(0xFFF1F5F9); // Slate-100 for alternating
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          sectionHeader(title, color: tblHeaderColor),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: tblHeaderColor),
            cellStyle: const pw.TextStyle(fontSize: 8),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: borderTint, width: 0.5)),
            ),
            cellHeight: 20,
            headerHeight: 22,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
          ),
        ],
      );
    }

    // ── Data Extraction ──
    final dailySales = (data['dailySales'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final topProducts = (data['topProducts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final leastProducts = (data['leastProducts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final totalRev = (data['revenue'] ?? 0.0).toDouble();
    final totalProfit = (data['profit'] ?? 0.0).toDouble();
    final totalDebt = (data['debt'] ?? 0.0).toDouble();
    final totalPurchases = (data['purchases'] ?? 0.0).toDouble();
    final totalOrders = data['orders'] ?? 0;

    final lowStockCount = data['lowStockCount'] ?? 0;
    final outStockCount = data['outStockCount'] ?? 0;
    final expiredCount = data['expiredCount'] ?? 0;
    final soonCount = data['soonCount'] ?? 0;

    final lowStockItems = (data['lowStockItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final outOfStockItems = (data['outOfStockItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final expiringSoonItems = (data['expiringSoonItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final expiredItems = (data['expiredItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final companyName = data['companyName']?.toString() ?? 'SmartInventory ERP';
    final companyPhone = data['companyPhone']?.toString() ?? '+251 ...';
    final branchName = data['branchName']?.toString() ?? 'All Branches';
    final period = data['period']?.toString() ?? 'Selected Period';
    final generatedBy = data['generatedBy']?.toString() ?? 'System Admin';

    final refNo = 'REF-${DateFormat('yyyyMMdd-HHmmss').format(now)}';

    // ── HEADER ──
    pw.Widget buildPageHeader(pw.Context ctx) {
      return pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Company branding info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 32,
                    height: 32,
                    decoration: const pw.BoxDecoration(
                      color: primaryColor,
                      shape: pw.BoxShape.circle,
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      companyName.isNotEmpty ? companyName[0].toUpperCase() : 'G',
                      style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 16),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(companyName, style: pw.TextStyle(font: boldFont, fontSize: 15, color: primaryColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('Branch: $branchName', style: pw.TextStyle(font: boldFont, fontSize: 9, color: textSecondary)),
                      pw.Text('Contact: $companyPhone', style: const pw.TextStyle(fontSize: 8, color: textSecondary)),
                    ],
                  ),
                ],
              ),
              // Document metadata info
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Business Performance Report', style: pw.TextStyle(font: boldFont, fontSize: 10, color: accentColor)),
                  pw.SizedBox(height: 3),
                  pw.Text('Period: $period', style: const pw.TextStyle(fontSize: 8, color: textSecondary)),
                  pw.Text('Generated By: $generatedBy', style: const pw.TextStyle(fontSize: 8, color: textSecondary)),
                  pw.Text('Date: ${fmt.format(now)}', style: const pw.TextStyle(fontSize: 8, color: textSecondary)),
                  pw.Text('Ref: $refNo', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 7.5, color: textSecondary)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: accentColor, thickness: 1.5),
          pw.SizedBox(height: 8),
        ],
      );
    }

    // ── FOOTER ──
    pw.Widget buildPageFooter(pw.Context ctx) {
      return pw.Column(
        children: [
          pw.Divider(color: borderTint, thickness: 0.5),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated by GM Inventory • GM Softwares', style: const pw.TextStyle(fontSize: 7, color: textSecondary)),
              pw.Text('${fmt.format(now)}  |  Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(font: boldFont, fontSize: 7, color: textSecondary)),
            ],
          ),
        ],
      );
    }

    // ── Mini Visualization Chart for sales trend ──
    pw.Widget buildTrendChart() {
      if (dailySales.isEmpty) return pw.SizedBox();
      double maxVal = 100.0;
      for (var d in dailySales) {
        final r = (d['revenue'] ?? 0.0) as double;
        if (r > maxVal) maxVal = r;
      }

      return pw.Container(
        height: 82,
        margin: const pw.EdgeInsets.symmetric(vertical: 6),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: lightBg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: borderTint),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: dailySales.take(12).map((d) {
            final r = (d['revenue'] ?? 0.0) as double;
            final pct = maxVal > 0 ? (r / maxVal) : 0.0;
            final barHeight = pct * 45.0 + 3.0; // Dynamic scale height
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  r > 0 ? '$currencySymbol ${(r / 1000).toStringAsFixed(1)}k' : '$currencySymbol 0',
                  style: const pw.TextStyle(fontSize: 5.5, color: textSecondary),
                ),
                pw.SizedBox(height: 2),
                pw.Container(
                  width: 15,
                  height: barHeight,
                  decoration: const pw.BoxDecoration(
                    color: accentColor,
                    borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(2)),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  d['date']?.toString() ?? '',
                  style: pw.TextStyle(font: boldFont, fontSize: 5.5, color: primaryColor),
                ),
              ],
            );
          }).toList(),
        ),
      );
    }

    // ── Build Document Layout ──
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 30),
        theme: theme,
        header: (ctx) => buildPageHeader(ctx),
        footer: (ctx) => buildPageFooter(ctx),
        build: (ctx) => [
          // Section 1 — Executive summary cards
          sectionHeader('1. Executive Summary'),
          pw.Row(children: [
            statCard('Total Revenue', currency.format(totalRev), accent: secondaryColor),
            pw.SizedBox(width: 8),
            statCard('Net Profit', currency.format(totalProfit), accent: accentColor),
            pw.SizedBox(width: 8),
            statCard(
              'Gross Margin %',
              totalRev > 0 ? '${(totalProfit / totalRev * 100).toStringAsFixed(1)}%' : '0.0%',
              accent: secondaryColor,
            ),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            statCard('Total POS Sales', '$totalOrders sales', accent: primaryColor),
            pw.SizedBox(width: 8),
            statCard('Outstanding Customer Debt', currency.format(totalDebt), accent: dangerColor),
            pw.SizedBox(width: 8),
            statCard('Inventory Purchases', currency.format(totalPurchases), accent: warningColor),
          ]),

          // Section 2 — Daily Trend
          if (dailySales.isNotEmpty) ...[
            sectionHeader('2. Revenue Trend Visualization'),
            buildTrendChart(),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Revenue', 'Profit', 'Net Profit Margin %', 'Orders Count'],
              data: dailySales.map((d) {
                final r = (d['revenue'] ?? 0.0) as double;
                final p = (d['profit'] ?? 0.0) as double;
                final margin = r > 0 ? '${(p / r * 100).toStringAsFixed(1)}%' : '0.0%';
                return [
                  d['date']?.toString() ?? '',
                  currency.format(r),
                  currency.format(p),
                  margin,
                  '${d['orders'] ?? 0}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: primaryColor),
              cellStyle: const pw.TextStyle(fontSize: 8),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: borderTint, width: 0.5)),
              ),
              cellHeight: 20,
              headerHeight: 22,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
            ),
          ],

          // Section 3 — Inventory Alerts & Status
          sectionHeader('3. Operational & Health Alerts'),
          pw.Row(children: [
            statCard('Low Stock Products', '$lowStockCount items', accent: warningColor),
            pw.SizedBox(width: 8),
            statCard('Out of Stock Products', '$outStockCount items', accent: dangerColor),
            pw.SizedBox(width: 8),
            statCard('Expired Products', '$expiredCount items', accent: dangerColor),
            pw.SizedBox(width: 8),
            statCard('Expiring in 30 Days', '$soonCount items', accent: warningColor),
          ]),
          pw.SizedBox(height: 6),

          // Detailed alerts tables
          if (lowStockItems.isNotEmpty) ...[
            tableSection(
              'Low Stock Item Detail',
              ['Product Identifier / Name', 'Current Phys. Qty', 'Reorder Alert Threshold', 'Status Flag'],
              lowStockItems.map((p) => [
                p['name']?.toString() ?? 'Unknown',
                '${p['qty'] ?? 0}',
                '${p['threshold'] ?? 5}',
                'REORDER DEMAND',
              ]).toList(),
              headerColor: warningColor,
            ),
          ],
          if (outOfStockItems.isNotEmpty) ...[
            tableSection(
              'Out of Stock Item Detail',
              ['Product Identifier / Name', 'Physical Stock Level', 'Operational Status'],
              outOfStockItems.map((p) => [
                p['name']?.toString() ?? 'Unknown',
                '0.00',
                'CRITICAL SHUTDOWN',
              ]).toList(),
              headerColor: dangerColor,
            ),
          ],
          if (expiredItems.isNotEmpty) ...[
            tableSection(
              'Expired Product Batches Detail',
              ['Product Identifier / Name', 'Expiry Date Recorded', 'Days Since Expiration', 'Action Required'],
              expiredItems.map((p) => [
                p['name']?.toString() ?? 'Unknown',
                p['expiryDate']?.toString() ?? '',
                '${p['daysDiff'] ?? 0} days past',
                'IMMEDIATE REMOVAL',
              ]).toList(),
              headerColor: dangerColor,
            ),
          ],
          if (expiringSoonItems.isNotEmpty) ...[
            tableSection(
              'Expiring Soon Batches Detail',
              ['Product Identifier / Name', 'Scheduled Expiry', 'Days Remaining', 'Urgency Status'],
              expiringSoonItems.map((p) => [
                p['name']?.toString() ?? 'Unknown',
                p['expiryDate']?.toString() ?? '',
                '${p['daysDiff'] ?? 0} days left',
                'HIGH URGENCY ALERT',
              ]).toList(),
              headerColor: warningColor,
            ),
          ],

          // Section 4 — Product Performance Analytics
          if (topProducts.isNotEmpty) ...[
            tableSection(
              '4. Top Performing inventory items (By Qty Sold)',
              ['Rank', 'Item / Product', 'Units Sold', 'Total Revenue', 'Profit Contribution', 'Avg Selling Price', 'Rev % Contribution'],
              List.generate(topProducts.length, (idx) {
                final p = topProducts[idx];
                return [
                  '#${idx + 1}',
                  p['name']?.toString() ?? '',
                  '${p['qty'] ?? 0}',
                  currency.format((p['rev'] ?? 0.0).toDouble()),
                  currency.format((p['profit'] ?? 0.0).toDouble()),
                  currency.format((p['avgPrice'] ?? 0.0).toDouble()),
                  '${(p['contrib'] ?? 0.0).toStringAsFixed(1)}%',
                ];
              }),
              headerColor: primaryColor,
            ),
          ],

          if (leastProducts.isNotEmpty) ...[
            tableSection(
              '5. Least Performing inventory items (By Qty Sold)',
              ['Rank', 'Item / Product', 'Units Sold', 'Total Revenue', 'Profit Contribution', 'Avg Selling Price', 'Rev % Contribution'],
              List.generate(leastProducts.length, (idx) {
                final p = leastProducts[idx];
                return [
                  '#${idx + 1}',
                  p['name']?.toString() ?? '',
                  '${p['qty'] ?? 0}',
                  currency.format((p['rev'] ?? 0.0).toDouble()),
                  currency.format((p['profit'] ?? 0.0).toDouble()),
                  currency.format((p['avgPrice'] ?? 0.0).toDouble()),
                  '${(p['contrib'] ?? 0.0).toStringAsFixed(1)}%',
                ];
              }),
              headerColor: primaryColor,
            ),
          ],

          // Section 6 — Report Information
          sectionHeader('6. Report Information', color: primaryColor),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: lightBg,
              border: pw.Border.all(color: borderTint),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              children: [
                _fRow('Branch', branchName, boldFont, primaryColor),
                pw.Divider(color: borderTint, thickness: 0.5),
                _fRow('Date Range', period, boldFont, primaryColor),
                pw.Divider(color: borderTint, thickness: 0.5),
                _fRow('Applied Filters', data['filtersApplied']?.toString() ?? 'None', boldFont, primaryColor),
                pw.Divider(color: borderTint, thickness: 0.5),
                _fRow('Currency', '$currencySymbol', boldFont, secondaryColor),
                pw.Divider(color: borderTint, thickness: 0.5),
                _fRow('Generated By', generatedBy, boldFont, secondaryColor),
                pw.Divider(color: borderTint, thickness: 0.5),
                _fRow('Generated At', fmt.format(now), boldFont, primaryColor),
                pw.Divider(color: borderTint, thickness: 0.5),
                _fRow('Report Reference', refNo, boldFont, primaryColor),
              ],
            ),
          ),

          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              'This document represents a certified local ledger snapshot from GM Inventory ERP. '
              'Any modifications violate internal security guidelines.',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 6.5, color: textSecondary),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    // ── Generate bytes ──
    final bytes = await pdf.save();
    if (bytes.isEmpty) {
      throw Exception('PDF generation failed: no bytes produced.');
    }
    final baseName = '$fileName.pdf';

    if (_isMobile) {
      final dir = await _getExportDir();
      final file = File('${dir.path}/$baseName');
      await file.writeAsBytes(bytes, flush: true);
      await Printing.sharePdf(bytes: bytes, filename: baseName);
      return file.path;
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
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 8.5, color: valueColor)),
        ],
      ),
    );
  }
}

ReportingInterface getReportingService() => ReportingServiceImpl();

