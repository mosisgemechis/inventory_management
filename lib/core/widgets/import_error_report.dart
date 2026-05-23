import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/bulk_import/import_models.dart';

class ImportErrorReport extends StatelessWidget {
  final List<ImportErrorRow> errors;
  final int successCount;

  const ImportErrorReport({
    super.key,
    required this.errors,
    required this.successCount,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.analytics_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          const Text("Import Results"),
        ],
      ),
      content: SizedBox(
        width: 800,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatCard(),
            const SizedBox(height: 16),
            if (errors.isNotEmpty) ...[
              const Text(
                "Execution Errors & Skipped Rows",
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 360,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.background),
                        columns: const [
                          DataColumn(label: Text("Row")),
                          DataColumn(label: Text("Reason")),
                          DataColumn(label: Text("Attempted Data")),
                        ],
                        rows: errors.map((e) {
                          return DataRow(cells: [
                            DataCell(Text("${e.rowNumber}")),
                            DataCell(Text(e.reason, style: TextStyle(color: AppColors.danger, fontSize: 12))),
                            DataCell(Text(e.originalData.toString(), style: TextStyle(fontSize: 10, color: AppColors.textSecondary))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ] else 
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.success, size: 48),
                      SizedBox(height: 16),
                      Text("Perfect Import! All rows processed successfully."),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }

  Widget _buildStatCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("Processed", "${successCount + errors.length}", AppColors.info),
          _statItem("Success", "$successCount", AppColors.success),
          _statItem("Failed", "${errors.length}", AppColors.danger),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
