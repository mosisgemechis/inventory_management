import 'package:drift/drift.dart';

class ImportResult {
  final List<dynamic> validCompanions; // ProductsCompanion or similar
  final List<ImportErrorRow> errors;
  final List<ImportDuplicateRow> duplicates;

  ImportResult(this.validCompanions, this.errors, {this.duplicates = const []});
}

class ImportErrorRow {
  final int rowNumber;
  final String reason;
  final Map<String, dynamic> originalData;

  ImportErrorRow({
    required this.rowNumber,
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

class ImportFinalizeResult {
  final int importedCount;
  ImportFinalizeResult(this.importedCount);
}
