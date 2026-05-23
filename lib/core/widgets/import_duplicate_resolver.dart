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
  final Map<int, String> _actions = {}; // rowNumber -> action ('skip', 'replace', 'restock')

  @override
  void initState() {
    super.initState();
    for (var d in widget.duplicates) {
      _actions[d.rowNumber] = 'restock'; // Default action
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
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.copy_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Text("${widget.duplicates.length} Duplicates Found"),
        ],
      ),
      content: SizedBox(
        width: 800,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                "The following products already exist. Choose how to handle each one:",
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            // ── Bulk action buttons ──
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  const Text("Apply to all:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  _BulkChip(
                    label: "Restock All",
                    icon: Icons.add_box_rounded,
                    color: AppColors.secondary,
                    onTap: () => _applyAll('restock'),
                  ),
                  _BulkChip(
                    label: "Replace All",
                    icon: Icons.published_with_changes_rounded,
                    color: AppColors.warning,
                    onTap: () => _applyAll('replace'),
                  ),
                  _BulkChip(
                    label: "Skip All",
                    icon: Icons.block_rounded,
                    color: AppColors.textSecondary,
                    onTap: () => _applyAll('skip'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: widget.duplicates.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, i) {
                  final d = widget.duplicates[i];
                  final currentAction = _actions[d.rowNumber];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text("Row ${d.rowNumber}: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("${d.newData['name']} ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                            if (d.newData['barcode']?.toString().isNotEmpty == true)
                               Text("(${d.newData['barcode']})", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildSmallDetail("New Qty", d.newData['quantity'].toString())),
                            Expanded(child: _buildSmallDetail("New Price", d.newData['sellingPrice'].toString())),
                            Expanded(child: _buildSmallDetail("Existing Qty", d.existingData['quantity'].toString())),
                             Expanded(child: _buildSmallDetail("Existing Price", d.existingData['sellingPrice'].toString())),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'restock', label: Text('Restock'), icon: Icon(Icons.add_box_rounded, size: 16)),
                            ButtonSegment(value: 'replace', label: Text('Replace'), icon: Icon(Icons.published_with_changes_rounded, size: 16)),
                            ButtonSegment(value: 'skip', label: Text('Skip'), icon: Icon(Icons.block_rounded, size: 16)),
                          ],
                          selected: {currentAction!},
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
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
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
          child: const Text("Apply Choices"),
        ),
      ],
    );
  }

  Widget _buildSmallDetail(String label, String value) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
         Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
       ],
     );
  }
}

class _BulkChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BulkChip({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
