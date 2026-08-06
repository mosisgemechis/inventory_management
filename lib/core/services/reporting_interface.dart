import 'dart:async';

abstract class ReportingInterface {
  Future<String> exportToCSV(String fileName, List<String> headers, List<List<dynamic>> rows);
  Future<String> exportToExcel(String fileName, String sheetName, List<String> headers, List<List<dynamic>> rows);
  Future<String> exportReportToExcel(String fileName, Map<String, dynamic> data);
  Future<String> exportToPdf(String fileName, Map<String, dynamic> data);
}
