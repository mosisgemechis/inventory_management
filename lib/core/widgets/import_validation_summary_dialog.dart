import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/bulk_import/import_models.dart';

class ImportValidationSummaryDialog extends StatelessWidget {
  final ImportResult parseResult;
  final ImportValidationSummary summary;
  final VoidCallback onStartImport;
  final VoidCallback onResolveDuplicates;

  const ImportValidationSummaryDialog({
    super.key,
    required this.parseResult,
    required this.summary,
    required this.onStartImport,
    required this.onResolveDuplicates,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.grey.shade50;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;

    final hasMissingColumns = summary.missingRequiredColumns.isNotEmpty;
    final hasErrors = parseResult.errors.isNotEmpty;
    final hasDuplicates = parseResult.duplicates.isNotEmpty;
    final hasHeaderInfo = summary.detectedHeaderRowNumber > 0;
    final hasColumnMapping = summary.detectedHeaders.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 780,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (hasMissingColumns || (summary.validRows == 0 && summary.totalRows > 0))
                        ? AppColors.danger.withOpacity(0.12)
                        : AppColors.info.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasMissingColumns ? Icons.warning_amber_rounded : Icons.fact_check_rounded,
                    color: hasMissingColumns ? AppColors.danger : AppColors.info,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Spreadsheet Validation Summary",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasHeaderInfo
                            ? "Header detected on Row ${summary.detectedHeaderRowNumber}. Scanned ${summary.totalRows} data row(s)."
                            : "Scanned ${summary.totalRows} data row(s) before database insertion.",
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── Scrollable Body ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Header Detection Preview ─────────────────────────
                    if (hasColumnMapping) ...[
                      _sectionLabel("Detected Column Mapping", Icons.table_chart_rounded, AppColors.info),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.info.withOpacity(0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasHeaderInfo)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.pin, size: 14, color: AppColors.info),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Header row found at Row ${summary.detectedHeaderRowNumber}",
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.info),
                                    ),
                                  ],
                                ),
                              ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: summary.detectedHeaders.entries.map((e) {
                                final fieldDisplay = _fieldDisplay(e.key);
                                final colLetter = summary.detectedColumnLetters[e.key] ?? '';
                                final isRequired = _isRequired(e.key);
                                return _mappingChip(
                                  field: fieldDisplay,
                                  header: e.value,
                                  location: colLetter,
                                  required: isRequired,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Missing Required Column Alert ────────────────────
                    if (hasMissingColumns) ...[
                      _sectionLabel("Required Columns Not Found", Icons.error_outline_rounded, AppColors.danger),
                      const SizedBox(height: 8),
                      ...summary.missingRequiredColumns.map((col) {
                        final accepted = summary.missingAcceptedNames[col];
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Required field \"$col\" could not be identified.",
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 12),
                                  ),
                                ],
                              ),
                              if (accepted != null && accepted.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                const Text("Accepted column header names:", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: accepted.map((name) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.danger.withOpacity(0.25)),
                                    ),
                                    child: Text(name, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                                  )).toList(),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],

                    // ── Stats Grid ───────────────────────────────────────
                    if (!hasMissingColumns) ...[
                      Row(
                        children: [
                          Expanded(child: _statCard("Total Rows", "${summary.totalRows}", Colors.blue, cardBg, borderColor)),
                          const SizedBox(width: 8),
                          Expanded(child: _statCard("Valid Items", "${summary.validRows}", AppColors.success, cardBg, borderColor)),
                          const SizedBox(width: 8),
                          Expanded(child: _statCard("In-File Merged", "${summary.inFileDuplicatesMerged}", Colors.purple, cardBg, borderColor)),
                          const SizedBox(width: 8),
                          Expanded(child: _statCard("DB Duplicates", "${summary.databaseDuplicatesCount}", Colors.orange, cardBg, borderColor)),
                          const SizedBox(width: 8),
                          Expanded(child: _statCard("Errors", "${summary.errorCount}", AppColors.danger, cardBg, borderColor)),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── In-File Merge Notice ─────────────────────────────
                    if (summary.inFileDuplicatesMerged > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.merge_type_rounded, color: Colors.purple, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "${summary.inFileDuplicatesMerged} duplicate row(s) inside the Excel file were automatically merged by barcode/name (quantities summed).",
                                style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── DB Duplicates Notice ─────────────────────────────
                    if (hasDuplicates) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.copy_rounded, color: Colors.orange, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "${summary.databaseDuplicatesCount} product(s) already exist in your system. Choose to Restock, Replace, or Skip each.",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: onResolveDuplicates,
                              icon: const Icon(Icons.tune_rounded, size: 14),
                              label: const Text("Configure Choices"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange.shade800,
                                side: BorderSide(color: Colors.orange.shade400),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Row Error Preview ────────────────────────────────
                    if (hasErrors && !hasMissingColumns) ...[
                      _sectionLabel("Row Validation Errors (skipped safely)", Icons.report_outlined, AppColors.danger),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: parseResult.errors.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final err = parseResult.errors[i];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.danger.withOpacity(0.12),
                                child: Text(
                                  "${err.rowNumber}",
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.danger),
                                ),
                              ),
                              title: Text(
                                err.productName ?? "Row ${err.rowNumber}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              subtitle: Text(
                                err.reason,
                                style: const TextStyle(fontSize: 11, color: AppColors.danger),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                const Spacer(),
                if (summary.validRows > 0 && !hasMissingColumns)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onStartImport();
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text("Start Import (${summary.validRows} Items)"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: null,
                    child: Text(hasMissingColumns ? "Fix Header Columns to Import" : "No Valid Items to Import"),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ],
    );
  }

  Widget _mappingChip({
    required String field,
    required String header,
    required String location,
    required bool required,
  }) {
    final color = required ? AppColors.secondary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            field,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
          const Text("  →  ", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(
            '"$header"',
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              "($location)",
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  bool _isRequired(String fieldKey) {
    const required = {'name', 'sellingPrice', 'buyingPrice', 'quantity', 'lowStockThreshold'};
    return required.contains(fieldKey);
  }

  String _fieldDisplay(String fieldKey) {
    const map = {
      'name': 'Product Name',
      'sellingPrice': 'Selling Price',
      'buyingPrice': 'Buying Price',
      'quantity': 'Quantity',
      'lowStockThreshold': 'Low Stock Qty',
      'barcode': 'Barcode',
      'expiryDate': 'Expiry Date',
      'branchName': 'Branch',
      'supplierName': 'Supplier',
    };
    return map[fieldKey] ?? fieldKey;
  }

  Widget _statCard(String label, String value, Color color, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
