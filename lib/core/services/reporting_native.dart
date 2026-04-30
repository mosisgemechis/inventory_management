import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'reporting_interface.dart';

class ReportingServiceImpl implements ReportingInterface {
  @override
  Future<String> exportToCSV(String fileName, List<String> headers, List<List<dynamic>> rows) async {
    List<List<dynamic>> csvData = [headers, ...rows];
    String csv = const ListToCsvConverter().convert(csvData);
    
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV',
      fileName: '$fileName.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputFile == null) return "Cancelled";
    if (!outputFile.endsWith('.csv')) outputFile += '.csv';

    final file = File(outputFile);
    await file.writeAsString(csv);
    return outputFile;
  }

  @override
  Future<String> exportToExcel(String fileName, String sheetName, List<String> headers, List<List<dynamic>> rows) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (var row in rows) {
      sheetObject.appendRow(row.map((v) => TextCellValue(v.toString())).toList());
    }

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Excel',
      fileName: '$fileName.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (outputFile == null) return "Cancelled";
    if (!outputFile.endsWith('.xlsx')) outputFile += '.xlsx';

    final file = File(outputFile);
    await file.writeAsBytes(excel.save()!);
    return outputFile;
  }

  @override
  Future<String> exportToPdf(String fileName, Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final fmt = DateFormat('MMM d, yyyy HH:mm');
    final currency = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 2);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SmartInventory ERP',
                        style: pw.TextStyle(
                            fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Business Performance Report',
                        style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Generated: ${fmt.format(now)}'),
                    pw.Text('Reference: ${now.millisecondsSinceEpoch}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 32),

            // Summary Section
            pw.Text('1. Executive Summary',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 16),
            pw.Row(children: [
              _pdfStatCard('Total Revenue', currency.format(data['revenue'] ?? 0)),
              pw.SizedBox(width: 12),
              _pdfStatCard('Net Profit', currency.format(data['profit'] ?? 0)),
              pw.SizedBox(width: 12),
              _pdfStatCard('Orders', (data['orders'] ?? 0).toString()),
            ]),
            pw.SizedBox(height: 32),

            // Financial Insights
            pw.Text('2. Financial Insights',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 16),
            pw.Row(children: [
              _pdfStatCard('Debt (Owed)', currency.format(data['debt'] ?? 0)),
              pw.SizedBox(width: 12),
              _pdfStatCard('Purchases', currency.format(data['purchases'] ?? 0)),
            ]),
            pw.SizedBox(height: 32),

            // Inventory Status
            pw.Text('3. Inventory Insights',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headers: ['Category', 'Item Count', 'Status'],
              data: [
                ['Low Stock', data['lowStockCount']?.toString() ?? '0', 'Reorder'],
                ['Out of Stock', data['outStockCount']?.toString() ?? '0', 'Critical'],
                ['Expired', data['expiredCount']?.toString() ?? '0', 'Remove'],
                ['Expiring Soon', data['soonCount']?.toString() ?? '0', 'Watch'],
              ],
            ),
            pw.SizedBox(height: 32),

            // Top Products
            pw.Text('4. Top Products',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 16),
            if (data['topProducts'] != null)
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['Product Name', 'Quantity', 'Revenue'],
                data: (data['topProducts'] as List).map((p) => [
                  p['name'].toString(),
                  p['qty'].toString(),
                  currency.format(p['rev'] ?? 0),
                ]).toList(),
              ),
          ];
        },
      ),
    );

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF Report',
      fileName: '$fileName.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (outputFile == null) return "Cancelled";
    if (!outputFile.endsWith('.pdf')) outputFile += '.pdf';

    final file = File(outputFile);
    await file.writeAsBytes(await pdf.save());
    return outputFile;
  }

  pw.Widget _pdfStatCard(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          color: PdfColors.grey50,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

ReportingInterface getReportingService() => ReportingServiceImpl();
