import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'reporting_interface.dart';
import 'reporting_native.dart' if (dart.library.html) 'reporting_web.dart';

class ReportingService {
  final ReportingInterface _service = getReportingService();

  Future<String> exportFullExcel(List<Map<String, dynamic>> sales,
      List<Map<String, dynamic>> purchases, Map<String, dynamic> labels) async {
    
    // Convert snapshots to plain Maps and sanitize Timestamps for isolate compatibility
    final salesData = sales.map((d) {
      final m = Map<String, dynamic>.from(d);
      m.forEach((k, v) { if (v is Timestamp) m[k] = v.toDate().toIso8601String(); });
      return m;
    }).toList();
    final purchaseData = purchases.map((d) {
       final m = Map<String, dynamic>.from(d);
       m.forEach((k, v) { if (v is Timestamp) m[k] = v.toDate().toIso8601String(); });
       return m;
    }).toList();

    final result = await compute(_calculateExcelData, {
      'sales': salesData,
      'purchases': purchaseData,
      'labels': labels,
    });

    return _service.exportToExcel(
        'Business_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
        'Wealth Report',
        result['headers'] as List<String>,
        result['rows'] as List<List<dynamic>>);
  }

  Future<String> exportSalesExcel(List<Map<String, dynamic>> sales) async {
    return exportFullExcel(sales, [], {
       'metric': 'METRIC',
       'value': 'VALUE',
       'top_selling': 'TOP SELLING',
       'revenue': 'REVENUE',
       'total_revenue': 'Total Revenue',
       'total_profit': 'Total Profit',
       'total_purchases': 'Total Purchases',
       'net_performance': 'Net Performance',
       'profit_margin': 'Profit Margin',
       'transactions': 'Transactions',
       'date': 'DATE',
       'product': 'PRODUCT',
       'qty': 'QTY',
       'profit': 'PROFIT',
       'customer': 'CUSTOMER',
       'type': 'TYPE',
       'debt': 'Debt',
       'cash': 'Cash',
    });
  }

  Future<String> exportToPdf(String fileName, Map<String, dynamic> data) async {
    return _service.exportToPdf(fileName, data);
  }
}

// Top-level function for Isolate
Map<String, dynamic> _calculateExcelData(Map<String, dynamic> input) {
  final List<Map<String, dynamic>> sales = List.from(input['sales']);
  final List<Map<String, dynamic>> purchases = List.from(input['purchases']);
  final Map<String, dynamic> labels = Map.from(input['labels']);

  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final currencyFmt = NumberFormat('#,###.##');
  final getL = (String key, String def) => labels[key]?.toString() ?? def;

  double totalRev = 0;
  double totalProfit = 0;
  double totalPurch = 0;
  Map<String, double> itemSales = {};

  for (var m in purchases) {
    totalPurch += (m['totalPrice'] ?? 0).toDouble();
  }

  final detailRows = sales.map((m) {
    final tsRaw = m['timestamp'];
    DateTime? ts;
    if (tsRaw is Timestamp) ts = tsRaw.toDate();
    else if (tsRaw is String) ts = DateTime.tryParse(tsRaw);

    final rev = (m['totalPrice'] ?? 0).toDouble();
    final prof = (m['profit'] ?? 0).toDouble();
    final name = m['itemName'] ?? 'Unknown';

    totalRev += rev;
    totalProfit += prof;
    itemSales[name] = (itemSales[name] ?? 0) + rev;

    return [
      ts != null ? dateFmt.format(ts) : 'N/A',
      name,
      m['quantity'] ?? 0,
      currencyFmt.format(rev),
      currencyFmt.format(prof),
      m['customerName'] ?? 'Guest',
      m['isDebt'] == true ? getL('debt', 'Debt') : getL('cash', 'Cash'),
    ];
  }).toList();

  final summaryHeaders = [
    getL('metric', 'METRIC'),
    getL('value', 'VALUE'),
    '',
    getL('top_selling', 'TOP SELLING PRODUCTS'),
    getL('revenue', 'REVENUE')
  ];

  final summaryRows = [
    [getL('total_revenue', 'Total Period Revenue'), '${currencyFmt.format(totalRev)} Birr', '', '', ''],
    [getL('total_profit', 'Total Period Profit'), '${currencyFmt.format(totalProfit)} Birr', '', '', ''],
    [getL('total_purchases', 'Total Period Purchases'), '${currencyFmt.format(totalPurch)} Birr', '', '', ''],
    [getL('net_performance', 'Net Performance'), '${currencyFmt.format(totalRev - totalPurch)} Birr', '', '', ''],
    [getL('profit_margin', 'Profit Margin'), '${totalRev > 0 ? ((totalProfit / totalRev) * 100).toStringAsFixed(1) : 0}%', '', '', ''],
    [getL('transactions', 'Total Transactions'), sales.length.toString(), '', '', ''],
    ['', '', '', '', ''],
    [getL('date', 'DATE'), getL('product', 'PRODUCT'), getL('qty', 'QTY'), getL('revenue', 'REVENUE'), getL('profit', 'PROFIT'), getL('customer', 'CUSTOMER'), getL('type', 'TYPE')],
  ];

  final sortedItems = itemSales.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final top5 = sortedItems.take(5).toList();
  for (int i = 0; i < top5.length; i++) {
    if (i < summaryRows.length) {
      summaryRows[i][3] = top5[i].key;
      summaryRows[i][4] = '${currencyFmt.format(top5[i].value)} Birr';
    }
  }

  return {
    'headers': summaryHeaders,
    'rows': [...summaryRows, ...detailRows],
  };
}
