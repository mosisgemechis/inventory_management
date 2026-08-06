import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/import_service.dart';

class BulkImportLandingDialog extends StatefulWidget {
  final VoidCallback onSelectFile;

  const BulkImportLandingDialog({
    super.key,
    required this.onSelectFile,
  });

  @override
  State<BulkImportLandingDialog> createState() => _BulkImportLandingDialogState();
}

class _BulkImportLandingDialogState extends State<BulkImportLandingDialog> {
  final ImportService _importService = ImportService();
  bool _isDownloadingTemplate = false;

  Future<void> _handleDownloadTemplate() async {
    setState(() => _isDownloadingTemplate = true);
    try {
      final savedPath = await _importService.downloadTemplateFile();
      if (!mounted) return;
      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Template saved successfully to: $savedPath"),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Could not save template: $e"),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloadingTemplate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.grey.shade50;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 850,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.file_upload_outlined, color: AppColors.secondary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Bulk Product Import",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Import items from real-world Excel spreadsheets (.xlsx, .csv).",
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: "Close",
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column mapping & intelligent recognition instruction banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.info.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: AppColors.info, size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Intelligent Column Mapping: Headers like 'Price', 'Retail Price', 'Cost', 'Buy Price', 'Qty', 'Stock', 'Threshold', 'Min Stock' are automatically recognized regardless of column order, letter casing, or trailing spaces.",
                              style: TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Required vs Optional Fields Panel
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Required Panel
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                                    SizedBox(width: 8),
                                    Text("Required Fields", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _fieldBadge("Product Name", "Product, Item, Name, Item Name"),
                                _fieldBadge("Selling Price", "Price, Sell Price, Retail Price, SP"),
                                _fieldBadge("Buying Price", "Cost, Buy Price, Purchase Price, BP"),
                                _fieldBadge("Quantity", "Qty, Stock, Amount, Balance"),
                                _fieldBadge("Low Stock Warning Qty", "Threshold, Alert At, Min Stock, Safety Stock"),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Optional Panel
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.add_circle_outline_rounded, color: AppColors.textSecondary, size: 18),
                                    SizedBox(width: 8),
                                    Text("Optional Fields", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _fieldBadge("Barcode", "SKU, Code, UPC, ID (auto-generated if empty)", isOptional: true),
                                _fieldBadge("Expiry Date", "Exp, Expiry, Expdate, Valid Until", isOptional: true),
                                _fieldBadge("Branch", "Branch Name, Store, Location", isOptional: true),
                                _fieldBadge("Supplier / Description", "Vendor, Supplier Name, Brand", isOptional: true),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Visual Example Table
                    const Text(
                      "Visual Example Structure:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 24,
                          headingRowHeight: 36,
                          dataRowMinHeight: 32,
                          dataRowMaxHeight: 36,
                          headingRowColor: WidgetStateProperty.all(AppColors.secondary.withOpacity(0.08)),
                          columns: const [
                            DataColumn(label: Text("Product Name *", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Selling Price *", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Buying Price *", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Quantity *", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Low Stock Qty *", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Barcode", style: TextStyle(fontSize: 11))),
                            DataColumn(label: Text("Expiry Date", style: TextStyle(fontSize: 11))),
                          ],
                          rows: const [
                            DataRow(cells: [
                              DataCell(Text("Paracetamol 500mg", style: TextStyle(fontSize: 11))),
                              DataCell(Text("15.00", style: TextStyle(fontSize: 11))),
                              DataCell(Text("10.00", style: TextStyle(fontSize: 11))),
                              DataCell(Text("100", style: TextStyle(fontSize: 11))),
                              DataCell(Text("10", style: TextStyle(fontSize: 11))),
                              DataCell(Text("690123456789", style: TextStyle(fontSize: 11))),
                              DataCell(Text("2026-12-31", style: TextStyle(fontSize: 11))),
                            ]),
                            DataRow(cells: [
                              DataCell(Text("Coca Cola 500ml", style: TextStyle(fontSize: 11))),
                              DataCell(Text("35.00", style: TextStyle(fontSize: 11))),
                              DataCell(Text("25.00", style: TextStyle(fontSize: 11))),
                              DataCell(Text("50", style: TextStyle(fontSize: 11))),
                              DataCell(Text("5", style: TextStyle(fontSize: 11))),
                              DataCell(Text("5449000000996", style: TextStyle(fontSize: 11))),
                              DataCell(Text("-", style: TextStyle(fontSize: 11))),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Footer Actions
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isDownloadingTemplate ? null : _handleDownloadTemplate,
                  icon: _isDownloadingTemplate 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_rounded, size: 16),
                  label: const Text("Download Sample Template (.xlsx)"),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onSelectFile();
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text("Select Excel File"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldBadge(String label, String aliases, {bool isOptional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "• ",
            style: TextStyle(fontWeight: FontWeight.bold, color: isOptional ? AppColors.textSecondary : AppColors.secondary),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                children: [
                  TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (!isOptional) const TextSpan(text: " *", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                  TextSpan(text: " ($aliases)", style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
