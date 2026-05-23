import 'dart:io';

import 'package:inventory_manager/core/services/bulk_import/import_worker.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tools/import_debug.dart <path.xlsx|path.csv>');
    exitCode = 2;
    return;
  }
  final path = args.first;
  final file = File(path);
  if (!await file.exists()) {
    stderr.writeln('File not found: $path');
    exitCode = 2;
    return;
  }
  final bytes = await file.readAsBytes();
  final ext = path.split('.').last.toLowerCase();
  final res = ImportWorker.parseSpreadsheet(
    bytes: bytes,
    extension: ext,
    shopId: 'shop-main-001',
  );
  stdout.writeln('valid=${res.validCompanions.length} errors=${res.errors.length}');
  if (res.errors.isNotEmpty) {
    for (final e in res.errors.take(5)) {
      stdout.writeln('error row=${e.rowNumber} reason=${e.reason}');
    }
  }
}

