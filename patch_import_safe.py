import sys
import os
import re

path = r'c:\projects\inventory_management\lib\features\admin\admin_dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Normalize
content_norm = content.replace('\r\n', '\n')

# Find the start and end of _handleImport
import_method_start = re.search(r'Future<void> _handleImport\(AppUser user\) async \{', content_norm)
if not import_method_start:
    print("FAILURE: _handleImport start not found")
    sys.exit(1)

# Find the matching closing brace (this is tricky but usually works for simple methods)
# Count braces
bracket_count = 0
found_end = -1
for i in range(import_method_start.start(), len(content_norm)):
    char = content_norm[i]
    if char == '{':
        bracket_count += 1
    elif char == '}':
        bracket_count -= 1
        if bracket_count == 0:
            found_end = i + 1
            break

if found_end == -1:
    print("FAILURE: _handleImport end not found")
    sys.exit(1)

new_methods = r'''  Future<void> _handleImport(AppUser user) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bulk Excel Import"),
        backgroundColor: Theme.of(context).colorScheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Upload an Excel/CSV file with these requirements:"),
            const SizedBox(height: 16),
            _reqItem("Name", true),
            _reqItem("Quantity / Stock", false, hint: "(Default: 0)"),
            _reqItem("Buying Cost", false, hint: "(Default: 0)"),
            _reqItem("Selling Price", false, hint: "(Default: 1.25x Cost)"),
            _reqItem("Barcode / SKU", false),
            _reqItem("Expiry Date", false, hint: "(e.g. 2025-12-31)"),
            _reqItem("Low Stock Alert", false),
            _reqItem("Supplier", false),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.info),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text("Duplicates will be flagged for resolution (Restock, Replace, or Skip).",
                      style: TextStyle(fontSize: 12, color: AppColors.info)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startImportFlow(user);
            },
            child: const Text("Pick File & Import"),
          ),
        ],
      ),
    );
  }

  Widget _reqItem(String label, bool required, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(required ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, 
            size: 14, color: required ? AppColors.success : AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: required ? FontWeight.bold : FontWeight.normal)),
          if (hint != null)
            Text(" $hint", style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          if (required)
            const Text(" *", style: TextStyle(color: AppColors.danger)),
        ],
      ),
    );
  }

  Future<void> _startImportFlow(AppUser user) async {
    try {
      final parseResult = await _importService.pickAndParse(user);
      
      if (parseResult.errors.isNotEmpty && parseResult.validCompanions.isEmpty && parseResult.duplicates.isEmpty) {
        if (mounted) _showImportErrorSummary(parseResult.errors);
        return;
      }

      if (parseResult.duplicates.isNotEmpty) {
        if (!mounted) return;
        final resolutions = await showDialog<Map<String, ImportResolutionStrategy>>(
          context: context,
          barrierDismissible: false,
          builder: (c) => ImportDuplicateResolver(duplicates: parseResult.duplicates),
        );

        if (resolutions == null) return; // Cancelled

        LoadingOverlay.show(context);
        final finalResult = await _importService.finalizeImport(user, parseResult, resolutions);
        LoadingOverlay.hide(context);
        
        if (mounted) {
          _showImportSuccess(finalResult.importedCount, parseResult.errors);
          setState(() {}); // Refresh UI
        }
      } else if (parseResult.validCompanions.isNotEmpty) {
        // No duplicates, just finalize
        LoadingOverlay.show(context);
        final finalResult = await _importService.finalizeImport(user, parseResult, {});
        LoadingOverlay.hide(context);
        
        if (mounted) {
          _showImportSuccess(finalResult.importedCount, parseResult.errors);
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint("Import Flow Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Import Failed: $e"),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  void _showImportErrorSummary(List<ImportErrorRow> errors) {
     showDialog(
      context: context,
      builder: (c) => ImportErrorReport(errors: errors),
    );
  }

  void _showImportSuccess(int count, List<ImportErrorRow> errors) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Import Complete"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Successfully processed $count items."),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text("${errors.length} rows had errors and were skipped.", 
                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          if (errors.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                _showImportErrorSummary(errors);
              }, 
              child: const Text("View Errors")
            ),
          ElevatedButton(onPressed: () => Navigator.pop(c), child: const Text("Close")),
        ],
      ),
    );
  }'''

updated = content_norm[:import_method_start.start()] + new_methods + content_norm[found_end:]

with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(updated)
print("SUCCESS: _handleImport and helpers updated")
