import sys
import os

path = r'c:\projects\inventory_management\lib\features\admin\admin_dashboard_screen.dart'
# Use 'rb' and 'wb' to handle exactly what we want if needed, or just standard 'r' with encoding
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Normalize line endings to LF for processing
content = content.replace('\r\n', '\n')

# Check for import
new_import = "import 'package:inventory_manager/core/widgets/import_duplicate_resolver.dart';\n"
if "import 'package:inventory_manager/core/widgets/import_duplicate_resolver.dart';" not in content:
    # Insert after a known import to be safe
    insertion_point = content.find("import 'package:inventory_manager/core/widgets/import_error_report.dart';")
    if insertion_point != -1:
        end_of_line = content.find('\n', insertion_point) + 1
        content = content[:end_of_line] + new_import + content[end_of_line:]

old_handle = '''  Future<void> _handleImport(AppUser user) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bulk Spreadsheet Import"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Upload an Excel (.xlsx) or CSV file. The system will automatically detect your columns."),
            SizedBox(height: 16),
            Text("Requirements:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("• Product Name (Required)"),
            Text("• Selling Price (Required)"),
            Text("• Barcode (Optional)"),
            Text("• Quantity (Optional)"),
            SizedBox(height: 12),
            Text("Note: Large files (2000+ rows) are processed in the background without UI lag.", style: TextStyle(fontSize: 11, color: AppColors.info)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              LoadingOverlay.show(context);
              try {
                final result = await _importService.pickAndImport(user);
                
                if (mounted) {
                  LoadingOverlay.hide(context);
                  showDialog(
                    context: context,
                    builder: (_) => ImportErrorReport(
                      errors: result.errors,
                      successCount: result.validCompanions.length,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  LoadingOverlay.hide(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import Engine Error: $e'), backgroundColor: AppColors.danger));
                }
              }
            },
            child: const Text("Select File"),
          ),
        ],
      ),
    );
  }'''

new_handle = '''  Future<void> _handleImport(AppUser user) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bulk Spreadsheet Import"),
        backgroundColor: Theme.of(context).colorScheme.surface,
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Upload an Excel (.xlsx) or CSV file. The system will automatically detect your columns."),
            SizedBox(height: 16),
            Text("Requirements (Columns or Aliases):", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("• Product Name (Required)"),
            Text("• Selling Price (Required)"),
            Text("• Barcode / SKU (Optional)"),
            Text("• Stock Quantity (Optional)"),
            Text("• Buying Price / Cost (Optional)"),
            Text("• Expiry Date (Optional)"),
            Text("• Supplier Name (Optional)"),
            Text("• Low Stock Threshold (Optional)"),
            SizedBox(height: 12),
            Text("Duplicate Checker:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text("Identifies existing products by Barcode or Name and lets you choose between Restock, Replace, or Skip.", style: TextStyle(fontSize: 12)),
            SizedBox(height: 12),
            Text("Note: Large files are processed in the background without UI lag.", style: TextStyle(fontSize: 11, color: AppColors.info)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _startImportFlow(user);
            },
            child: const Text("Select File"),
          ),
        ],
      ),
    );
  }

  Future<void> _startImportFlow(AppUser user) async {
    LoadingOverlay.show(context);
    try {
      final result = await _importService.pickAndParse(user);
      if (!mounted) return;
      LoadingOverlay.hide(context);

      if (result.validCompanions.isEmpty && result.duplicates.isEmpty && result.errors.isEmpty) {
        return; // User cancelled
      }

      List<Map<String, dynamic>> itemsToProcess = List<Map<String, dynamic>>.from(result.validCompanions);

      if (result.duplicates.isNotEmpty) {
        final List<Map<String, dynamic>>? resolved = await showDialog<List<Map<String, dynamic>>>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => ImportDuplicateResolver(duplicates: result.duplicates),
        );
        
        if (resolved == null) return; // User cancelled the entire import during duplicate resolution
        itemsToProcess.addAll(resolved);
      }

      if (itemsToProcess.isNotEmpty) {
        LoadingOverlay.show(context);
        await _importService.finalizeImport(user, itemsToProcess);
        if (mounted) LoadingOverlay.hide(context);
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => ImportErrorReport(
            errors: result.errors,
            successCount: itemsToProcess.length,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        LoadingOverlay.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import Engine Error: $e'), backgroundColor: AppColors.danger));
      }
    }
  }'''

def normalize(s):
    return s.replace('\r\n', '\n').strip()

old_norm = normalize(old_handle)

if old_norm in content:
    new_content = content.replace(old_norm, normalize(new_handle))
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("SUCCESS")
else:
    print("FAILURE: Snippet not found")
