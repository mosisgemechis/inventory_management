import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/bulk_import/import_models.dart';

class ImportErrorReport extends StatelessWidget {
  final List<ImportErrorRow> errors;
  final int successCount;
  final int updatedCount;
  final int skippedCount;
  final int totalRows;
  final int cancelledCount;
  final bool wasCancelled;

  const ImportErrorReport({
    super.key,
    required this.errors,
    required this.successCount,
    this.updatedCount = 0,
    this.skippedCount = 0,
    this.totalRows = 0,
    this.cancelledCount = 0,
    this.wasCancelled = false,
  });

  @override
  Widget build(BuildContext context) {
    final failedCount = errors.length;
    final calcTotal = totalRows > 0
        ? totalRows
        : (successCount + updatedCount + skippedCount + failedCount + cancelledCount);
    final overallSuccess = failedCount == 0 && cancelledCount == 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: wasCancelled
                        ? Colors.orange.withOpacity(0.12)
                        : overallSuccess
                            ? AppColors.success.withOpacity(0.12)
                            : AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    wasCancelled
                        ? Icons.cancel_outlined
                        : overallSuccess
                            ? Icons.check_circle_rounded
                            : Icons.analytics_rounded,
                    color: wasCancelled
                        ? Colors.orange
                        : overallSuccess
                            ? AppColors.success
                            : AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wasCancelled ? "Import Cancelled" : "Bulk Import Results",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        wasCancelled
                            ? "Import was cancelled. $cancelledCount row(s) were not processed."
                            : "Execution summary for $calcTotal processed row(s).",
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
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Summary Stat Cards
            Row(
              children: [
                Expanded(child: _statItem("Processed", "$calcTotal", Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _statItem("Imported", "$successCount", AppColors.success)),
                const SizedBox(width: 8),
                Expanded(child: _statItem("Updated", "$updatedCount", AppColors.info)),
                const SizedBox(width: 8),
                Expanded(child: _statItem("Skipped", "$skippedCount", Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: _statItem("Failed", "$failedCount", AppColors.danger)),
                if (cancelledCount > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _statItem("Cancelled", "$cancelledCount", Colors.grey)),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Main Content Area
            Expanded(
              child: errors.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
                            const SizedBox(width: 6),
                            const Text(
                              "Failed Rows Breakdown:",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.danger),
                            ),
                            const Spacer(),
                            Text(
                              "${errors.length} failed item(s) skipped",
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.separated(
                              itemCount: errors.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final e = errors[i];
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.danger.withOpacity(0.12),
                                    child: Text(
                                      "${e.rowNumber}",
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.danger),
                                    ),
                                  ),
                                  title: Text(
                                    e.productName ?? "Row ${e.rowNumber}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  subtitle: Text(
                                    e.reason,
                                    style: const TextStyle(fontSize: 11, color: AppColors.danger),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, color: AppColors.success, size: 56),
                            SizedBox(height: 16),
                            Text(
                              "All valid records imported & updated successfully!",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Your inventory records are up to date.",
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Close Results"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
