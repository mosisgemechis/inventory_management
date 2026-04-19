import 'reporting_interface.dart';
import 'reporting_native.dart' if (dart.library.html) 'reporting_web.dart';

class ReportingService {
  final ReportingInterface _service = getReportingService();

  Future<String> exportToCSV(String fileName, List<String> headers, List<List<dynamic>> rows) {
    return _service.exportToCSV(fileName, headers, rows);
  }

  Future<String> exportToExcel(String fileName, String sheetName, List<String> headers, List<List<dynamic>> rows) {
    return _service.exportToExcel(fileName, sheetName, headers, rows);
  }
}
