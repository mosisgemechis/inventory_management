/// Lightweight cancellation token shared between the UI and [ImportService].
/// The UI calls [cancel()] on the button press; the service polls [isCancelled]
/// between rows and stops cleanly without rolling back already-committed data.
class ImportCancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class ImportResult {
  final List<dynamic> validCompanions; 
  final List<ImportErrorRow> errors;
  final List<ImportDuplicateRow> duplicates;
  final int totalRows;
  final int inFileDuplicatesMerged;
  final List<String> missingRequiredColumns;
  final Map<String, String> detectedHeaders;
  final Map<String, String> detectedColumnLetters;
  final int detectedHeaderRowNumber;
  final Map<String, List<String>> missingAcceptedNames;

  ImportResult(
    this.validCompanions, 
    this.errors, {
    this.duplicates = const [], 
    required this.totalRows,
    this.inFileDuplicatesMerged = 0,
    this.missingRequiredColumns = const [],
    this.detectedHeaders = const {},
    this.detectedColumnLetters = const {},
    this.detectedHeaderRowNumber = 0,
    this.missingAcceptedNames = const {},
  });
}

class ImportValidationSummary {
  final int totalRows;
  final int validRows;
  final int inFileDuplicatesMerged;
  final int databaseDuplicatesCount;
  final int warningCount;
  final int errorCount;
  final List<String> missingRequiredColumns;
  final Map<String, String> detectedHeaders;
  final Map<String, String> detectedColumnLetters;
  final int detectedHeaderRowNumber;
  final Map<String, List<String>> missingAcceptedNames;

  ImportValidationSummary({
    required this.totalRows,
    required this.validRows,
    required this.inFileDuplicatesMerged,
    required this.databaseDuplicatesCount,
    required this.warningCount,
    required this.errorCount,
    required this.missingRequiredColumns,
    required this.detectedHeaders,
    required this.detectedColumnLetters,
    required this.detectedHeaderRowNumber,
    required this.missingAcceptedNames,
  });
}

class ImportErrorRow {
  final int rowNumber;
  final String? productName;
  final String reason;
  final Map<String, dynamic> originalData;

  ImportErrorRow({
    required this.rowNumber,
    this.productName,
    required this.reason,
    required this.originalData,
  });
}

class ImportDuplicateRow {
  final Map<String, dynamic> newData;
  final Map<String, dynamic> existingData;
  final int rowNumber;

  ImportDuplicateRow({
    required this.newData,
    required this.existingData,
    required this.rowNumber,
  });
}

enum ImportResolutionStrategy {
  restock,
  replace,
  skip,
}

class ImportProgressState {
  final int current;
  final int total;
  final String currentProductName;
  final int importedCount;
  final int updatedCount;
  final int skippedCount;
  final int failedCount;
  final bool isCancelled;

  ImportProgressState({
    required this.current,
    required this.total,
    required this.currentProductName,
    required this.importedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.failedCount,
    this.isCancelled = false,
  });
}

class ImportFinalizeResult {
  final int totalRows;
  final int importedCount;
  final int updatedCount;
  final int skippedCount;
  final int failedCount;
  final int cancelledCount;
  final bool wasCancelled;
  final List<ImportErrorRow> errorDetails;

  ImportFinalizeResult({
    required this.totalRows,
    required this.importedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.failedCount,
    this.cancelledCount = 0,
    this.wasCancelled = false,
    required this.errorDetails,
  });
}
