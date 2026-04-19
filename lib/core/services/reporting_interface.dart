import 'dart:async';
import 'dart:typed_data';

abstract class ReportingInterface {
  Future<String> exportToCSV(String fileName, List<String> headers, List<List<dynamic>> rows);
  Future<String> exportToExcel(String fileName, String sheetName, List<String> headers, List<List<dynamic>> rows);
}
