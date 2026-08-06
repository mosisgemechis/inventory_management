import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/models/models.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/import_service.dart';
import '../../core/services/bulk_import/import_models.dart';
import '../../core/widgets/bulk_import_landing_dialog.dart';
import '../../core/widgets/import_validation_summary_dialog.dart';
import '../../core/widgets/import_progress_dialog.dart';
import '../../core/widgets/import_duplicate_resolver.dart';
import '../../core/widgets/import_error_report.dart';
import '../../core/widgets/loading_overlay.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DatabaseService _db = DatabaseService();
  final ImportService _importService = ImportService();
  final currencyFormat = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 2);

  int _selectedIndex = 0; // 0=inventory, 1=sales, 2=purchases, 3=settings

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final items = <_NavItem>[
      const _NavItem('Inventory', Icons.inventory_2_outlined),
      const _NavItem('Sales', Icons.point_of_sale_outlined),
      const _NavItem('Purchases', Icons.shopping_cart_outlined),
      const _NavItem('Settings', Icons.settings_outlined),
    ];

    return Scaffold(
      appBar: desktop
          ? null
          : AppBar(
              title: Text(items[_selectedIndex].label),
              actions: [
                IconButton(
                  tooltip: 'Bulk Import',
                  icon: const Icon(Icons.file_upload_outlined),
                  onPressed: () => _handleImport(user),
                ),
              ],
            ),
      body: Row(
        children: [
          if (desktop)
            SizedBox(
              width: 260,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Text('GM Inventory',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) => ListTile(
                        leading: Icon(items[i].icon),
                        title: Text(items[i].label),
                        selected: i == _selectedIndex,
                        onTap: () => setState(() => _selectedIndex = i),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded,
                        color: AppColors.danger),
                    title: const Text('Logout',
                        style: TextStyle(color: AppColors.danger)),
                    onTap: () => Provider.of<AuthService>(context, listen: false)
                        .signOut(),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (desktop)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            color: AppColors.border.withOpacity(0.6)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(items[_selectedIndex].label,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => _handleImport(user),
                          icon: const Icon(Icons.file_upload_outlined),
                          label: const Text('Bulk Import'),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: _buildTab(user)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
              destinations: [
                for (final it in items)
                  NavigationDestination(icon: Icon(it.icon), label: it.label),
              ],
            ),
    );
  }

  Widget _buildTab(AppUser user) {
    switch (_selectedIndex) {
      case 0:
        return _buildInventory(user);
      case 1:
        return const Center(child: Text('Sales (local-first) – coming next'));
      case 2:
        return const Center(child: Text('Purchases (local-first) – coming next'));
      case 3:
        return const Center(child: Text('Settings (local-first) – coming next'));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInventory(AppUser user) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.watchProducts(user.shopId, branchId: user.branchId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const Center(child: Text('No products yet'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final m = items[i];
            return Card(
              child: ListTile(
                title: Text(m['name']?.toString() ?? 'Unnamed'),
                subtitle: Text('Barcode: ${m['barcode'] ?? ''}'),
                trailing: Text(
                  currencyFormat.format((m['sellingPrice'] ?? 0) as num),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleImport(AppUser user) async {
    showDialog(
      context: context,
      builder: (ctx) => BulkImportLandingDialog(
        onSelectFile: () => _processFileSelection(user),
      ),
    );
  }

  Future<void> _processFileSelection(AppUser user) async {
    LoadingOverlay.show(context);
    try {
      final parseResult = await _importService.pickAndParse(user);
      if (!mounted) return;
      LoadingOverlay.hide(context);

      if (parseResult.totalRows == 0 && parseResult.errors.isNotEmpty) {
        _showImportErrorSummary(parseResult.errors);
        return;
      }

      _showValidationSummary(user, parseResult);
    } catch (e) {
      if (!mounted) return;
      LoadingOverlay.hide(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Import Processing Error: $e"),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _showValidationSummary(AppUser user, ImportResult parseResult) async {
    final summary = _importService.getValidationSummary(parseResult);
    Map<String, ImportResolutionStrategy> resolutions = {};

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ImportValidationSummaryDialog(
        parseResult: parseResult,
        summary: summary,
        onResolveDuplicates: () async {
          final res = await showDialog<Map<String, ImportResolutionStrategy>>(
            context: context,
            barrierDismissible: false,
            builder: (c) => ImportDuplicateResolver(duplicates: parseResult.duplicates),
          );
          if (res != null) {
            resolutions = res;
          }
        },
        onStartImport: () {
          _startImportExecution(user, parseResult, resolutions);
        },
      ),
    );
  }

  Future<void> _startImportExecution(
    AppUser user, 
    ImportResult parseResult, 
    Map<String, ImportResolutionStrategy> resolutions,
  ) async {
    if (!mounted) return;

    final token = ImportCancellationToken();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => ImportProgressDialog(
        cancellationToken: token,
        onStart: (onProgress) async {
          final finalResult = await _importService.finalizeImport(
            user, 
            parseResult, 
            resolutions,
            onProgress: onProgress,
            cancellationToken: token,
          );
          if (mounted) {
            Navigator.pop(c);
            _showImportSuccess(finalResult);
            setState(() {});
          }
        },
      ),
    );
  }

  void _showImportErrorSummary(List<ImportErrorRow> errors, {int successCount = 0}) {
    showDialog(
      context: context,
      builder: (c) => ImportErrorReport(errors: errors, successCount: successCount),
    );
  }

  void _showImportSuccess(ImportFinalizeResult report) {
    showDialog(
      context: context,
      builder: (ctx) => ImportErrorReport(
        errors: report.errorDetails,
        successCount: report.importedCount,
        updatedCount: report.updatedCount,
        skippedCount: report.skippedCount,
        totalRows: report.totalRows,
        cancelledCount: report.cancelledCount,
        wasCancelled: report.wasCancelled,
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}
