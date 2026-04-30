import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'reporting_interface.dart';
import 'reporting_native.dart' if (dart.library.html) 'reporting_web.dart';

class ReportingService {
  final ReportingInterface _service = getReportingService();
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final _currencyFmt = NumberFormat('#,###.##');

  DateTime? _parseTimestamp(dynamic ts) {
    if (ts == null) return null;
    if (ts is Timestamp) return ts.toDate();
    if (ts is String) return DateTime.tryParse(ts);
    return null;
  }

  Future<String> exportToExcel(String fileName, String sheetName, List<String> headers, List<List<dynamic>> rows) {
    return _service.exportToExcel(fileName, sheetName, headers, rows);
  }

  Future<String> exportSalesExcel(List<DocumentSnapshot> docs) async {
    // 1. Calculate Summary (Weekly Report Style)
    double totalRev = 0;
    double totalProfit = 0;
    Map<String, double> itemSales = {};
    
    final detailRows = docs.map((d) {
      final m = d.data() as Map<String, dynamic>;
      final ts = _parseTimestamp(m['timestamp']);
      final rev = (m['totalPrice'] ?? 0).toDouble();
      final prof = (m['profit'] ?? 0).toDouble();
      final name = m['itemName'] ?? 'Unknown';
      
      totalRev += rev;
      totalProfit += prof;
      itemSales[name] = (itemSales[name] ?? 0) + rev;
      
      return [
        ts != null ? _dateFmt.format(ts) : 'N/A',
        name,
        m['quantity'] ?? 0,
        _currencyFmt.format(rev),
        _currencyFmt.format(prof),
        m['customerName'] ?? 'Guest',
        m['isDebt'] == true ? 'Debt' : 'Cash',
      ];
    }).toList();

    // 2. Prep Summary Section
    final summaryHeaders = ['METRIC', 'VALUE', '', 'TOP SELLING PRODUCTS', 'REVENUE'];
    final summaryRows = [
      ['Total Period Revenue', 'ETB ${_currencyFmt.format(totalRev)}', '', '', ''],
      ['Total Period Profit', 'ETB ${_currencyFmt.format(totalProfit)}', '', '', ''],
      ['Profit Margin', '${totalRev > 0 ? ((totalProfit / totalRev) * 100).toStringAsFixed(1) : 0}%', '', '', ''],
      ['Total Transactions', docs.length.toString(), '', '', ''],
      ['', '', '', '', ''],
      ['DATE', 'PRODUCT', 'QTY', 'REVENUE', 'PROFIT', 'CUSTOMER', 'TYPE'], // Header for details
    ];

    // Add top 5 items to summary
    final sortedItems = itemSales.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedItems.take(5).toList();
    for (int i = 0; i < top5.length; i++) {
        if (i < summaryRows.length) {
            summaryRows[i][3] = top5[i].key;
            summaryRows[i][4] = 'ETB ${_currencyFmt.format(top5[i].value)}';
        }
    }

    final allRows = [...summaryRows, ...detailRows];
    
    return _service.exportToExcel(
      'Business_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}', 
      'Wealth Report', 
      summaryHeaders, 
      allRows
    );
  }

  Future<String> exportToPdf(String fileName, Map<String, dynamic> data) async {
    return _service.exportToPdf(fileName, data);
  }
}
