import 'dart:html' as html;
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'reporting_interface.dart';

class ReportingServiceImpl implements ReportingInterface {
  @override
  Future<String> exportToCSV(String fileName, List<String> headers, List<List<dynamic>> rows) async {
    List<List<dynamic>> csvData = [headers, ...rows];
    String csvString = const ListToCsvConverter().convert(csvData);
    final bytes = utf8.encode(csvString);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "$fileName.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
    return "Browser Download Initiated";
  }

  @override
  Future<String> exportToExcel(String fileName, String sheetName, List<String> headers, List<List<dynamic>> rows) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel[sheetName];
    for (int i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
    }
    for (int i = 0; i < rows.length; i++) {
      for (int j = 0; j < rows[i].length; j++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
        cell.value = TextCellValue(rows[i][j].toString());
      }
    }
    final fileBytes = excel.encode();
    if (fileBytes != null) {
      final blob = html.Blob([fileBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "$fileName.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
    return "Browser Download Initiated";
  }
}

ReportingInterface getReportingService() => ReportingServiceImpl();
