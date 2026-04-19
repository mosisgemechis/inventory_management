import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'reporting_interface.dart';

class ReportingServiceImpl implements ReportingInterface {
  @override
  Future<String> exportToCSV(String fileName, List<String> headers, List<List<dynamic>> rows) async {
    List<List<dynamic>> csvData = [headers, ...rows];
    String csvString = const ListToCsvConverter().convert(csvData);
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/$fileName.csv";
    final file = File(path);
    await file.writeAsString(csvString);
    return path;
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
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/$fileName.xlsx";
    final fileBytes = excel.encode();
    if (fileBytes != null) {
      final file = File(path);
      await file.writeAsBytes(fileBytes);
    }
    return path;
  }
}

ReportingInterface getReportingService() => ReportingServiceImpl();
