import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'reporting_interface.dart';
import 'reporting_native.dart' if (dart.library.html) 'reporting_web.dart';

class ReportingService {
  final ReportingInterface _service = getReportingService();

  Future<String> exportReportToExcel(String fileName, Map<String, dynamic> data) async {
    return _service.exportReportToExcel(fileName, data);
  }

  Future<String> exportSalesExcel(List<Map<String, dynamic>> sales) async {
    double totalRev = 0, totalProf = 0, totalUnpaid = 0;
    Map<String, double> productRevMap = {};
    Map<String, double> productQtyMap = {};

    for (var m in sales) {
      final rev = (m['totalPrice'] ?? 0.0).toDouble();
      final prof = (m['profit'] ?? 0.0).toDouble();
      totalRev += rev;
      totalProf += prof;
      if (m['isDebt'] == true) {
        totalUnpaid += (m['debtRemaining'] ?? m['totalPrice'] ?? 0.0).toDouble();
      }
      final name = m['itemName']?.toString() ?? 'Unknown';
      productRevMap[name] = (productRevMap[name] ?? 0.0) + rev;
      productQtyMap[name] = (productQtyMap[name] ?? 0.0) + (m['quantity'] ?? 0).toDouble();
    }

    final sortedByQty = productQtyMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topProducts = sortedByQty.take(10).map((e) {
      final name = e.key;
      final qty = e.value;
      final rev = productRevMap[name] ?? 0.0;
      double itemProf = 0;
      for (var s in sales) {
        if (s['itemName'] == name) {
          itemProf += (s['profit'] ?? 0.0).toDouble();
        }
      }
      return {
        'name': name,
        'qty': qty,
        'rev': rev,
        'profit': itemProf,
        'avgPrice': qty > 0 ? (rev / qty) : 0.0,
        'contrib': totalRev > 0 ? (rev / totalRev * 100) : 0.0,
      };
    }).toList();

    final reportData = {
      'revenue': totalRev,
      'profit': totalProf,
      'orders': sales.length,
      'debt': totalUnpaid,
      'purchases': 0.0,
      'lowStockCount': 0,
      'outStockCount': 0,
      'expiredCount': 0,
      'soonCount': 0,
      'topProducts': topProducts,
      'leastProducts': [],
      'dailySales': [],
      'sales': sales,
      'companyName': 'SmartInventory ERP',
      'branchName': 'All Branches',
      'period': 'All Transactions',
      'currency': 'ETB',
      'generatedBy': 'System Admin',
    };

    return exportReportToExcel('Business_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}', reportData);
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
    if (tsRaw is DateTime) ts = tsRaw;
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
