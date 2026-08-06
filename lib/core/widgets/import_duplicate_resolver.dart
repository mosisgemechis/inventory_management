import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/bulk_import/import_models.dart';

class ImportDuplicateResolver extends StatefulWidget {
  final List<ImportDuplicateRow> duplicates;

  const ImportDuplicateResolver({super.key, required this.duplicates});

  @override
  State<ImportDuplicateResolver> createState() => _ImportDuplicateResolverState();
}

class _ImportDuplicateResolverState extends State<ImportDuplicateResolver> {
  final Map<int, String> _actions = {}; // rowNumber -> action ('restock', 'replace', 'skip')

  @override
  void initState() {
    super.initState();
    for (var d in widget.duplicates) {
      _actions[d.rowNumber] = 'restock'; // Default action is safe restock
    }
  }

  void _applyAll(String action) {
    setState(() {
      for (var d in widget.duplicates) {
        _actions[d.rowNumber] = action;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.grey.shade50;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 820,
        height: 600,
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
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.copy_rounded, color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${widget.duplicates.length} Database Product Matches",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "These products already exist in your system. Select how to resolve each item:",
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Bulk Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Text("Apply to all: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(width: 8),
                  _BulkChip(
                    label: "Restock All",
                    icon: Icons.add_box_rounded,
                    color: AppColors.secondary,
                    onTap: () => _applyAll('restock'),
                  ),
                  const SizedBox(width: 8),
                  _BulkChip(
                    label: "Replace All",
                    icon: Icons.published_with_changes_rounded,
                    color: Colors.orange,
                    onTap: () => _applyAll('replace'),
                  ),
                  const SizedBox(width: 8),
                  _BulkChip(
                    label: "Skip All",
                    icon: Icons.block_rounded,
                    color: AppColors.textSecondary,
                    onTap: () => _applyAll('skip'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Item List
            Expanded(
              child: ListView.separated(
                itemCount: widget.duplicates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final d = widget.duplicates[i];
                  final currentAction = _actions[d.rowNumber] ?? 'restock';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "Row ${d.rowNumber}",
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${d.newData['name']}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (d.newData['barcode']?.toString().isNotEmpty == true) ...[
                              const SizedBox(width: 6),
                              Text(
                                "(${d.newData['barcode']})",
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Comparison row
                        Row(
                          children: [
                            Expanded(
                              child: _infoBox(
                                "Excel Data",
                                "Qty: ${d.newData['quantity']} | Sell: ${d.newData['sellingPrice']} | Buy: ${d.newData['buyingPrice']}",
                                AppColors.info,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _infoBox(
                                "System Product",
                                "Qty: ${d.existingData['quantity']} | Sell: ${d.existingData['sellingPrice']} | Buy: ${d.existingData['buyingPrice']}",
                                AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Segmented Button
                        SegmentedButton<String>(
                          style: ButtonStyle(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          segments: const [
                            ButtonSegment(
                              value: 'restock',
                              label: Text('Restock Stock', style: TextStyle(fontSize: 11)),
                              icon: Icon(Icons.add_box_rounded, size: 14),
                            ),
                            ButtonSegment(
                              value: 'replace',
                              label: Text('Replace Prices/Info', style: TextStyle(fontSize: 11)),
                              icon: Icon(Icons.published_with_changes_rounded, size: 14),
                            ),
                            ButtonSegment(
                              value: 'skip',
                              label: Text('Skip Item', style: TextStyle(fontSize: 11)),
                              icon: Icon(Icons.block_rounded, size: 14),
                            ),
                          ],
                          selected: {currentAction},
                          onSelectionChanged: (set) {
                            setState(() => _actions[d.rowNumber] = set.first);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final Map<String, ImportResolutionStrategy> resolutions = {};
                    for (var d in widget.duplicates) {
                      final actionStr = _actions[d.rowNumber];
                      final strategy = ImportResolutionStrategy.values.firstWhere(
                        (e) => e.name == actionStr,
                        orElse: () => ImportResolutionStrategy.skip,
                      );
                      
                      final existingId = d.existingData['id']?.toString();
                      if (existingId != null) {
                        resolutions[existingId] = strategy;
                      }
                    }
                    Navigator.pop(context, resolutions);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Apply Resolution Rules"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(String title, String detail, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(detail, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _BulkChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BulkChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
