import 'package:flutter/material.dart';
import '../../main.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:badges/badges.dart' as badges;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:csv/csv.dart';
import 'dart:io' show Platform, File;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:inventory_manager/core/l10n/l10n.dart' as erp_l10n;
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory_manager/core/services/auth_service.dart';
import 'package:inventory_manager/core/services/database_service.dart';
import 'package:inventory_manager/core/services/validation_service.dart';
import 'package:inventory_manager/core/services/import_service.dart';
import 'package:inventory_manager/core/services/reporting_service.dart';
import 'package:inventory_manager/core/repositories/inventory_repository.dart';
import 'package:inventory_manager/core/constants/colors.dart';
import 'package:inventory_manager/core/widgets/erp_components.dart';
import 'package:inventory_manager/core/widgets/loading_overlay.dart';
import 'package:inventory_manager/core/utils/thread_safe_stream.dart';
import 'package:inventory_manager/core/models/models.dart';
import 'package:inventory_manager/core/services/theme_service.dart';
import 'package:inventory_manager/core/services/bulk_import/import_models.dart';
import 'package:inventory_manager/core/widgets/bulk_import_landing_dialog.dart';
import 'package:inventory_manager/core/widgets/import_validation_summary_dialog.dart';
import 'package:inventory_manager/core/widgets/import_progress_dialog.dart';
import 'package:inventory_manager/core/widgets/import_error_report.dart';
import 'package:inventory_manager/core/widgets/import_duplicate_resolver.dart';
import 'package:inventory_manager/core/widgets/account_dropdown.dart';
import 'package:inventory_manager/core/utils/perf_logger.dart';
import 'package:inventory_manager/core/widgets/custom_date_range_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DatabaseService _db = DatabaseService();
  final ValidationService _validator = ValidationService();
  final ImportService _importService = ImportService();
  final ReportingService _reporting = ReportingService();
  final InventoryRepository _repo = InventoryRepository();
  int _selectedIndex = 0;
  String _reportFilter = 'Daily';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 0));
  DateTime _endDate = DateTime.now();
  String _purchaseSupplierFilter = 'All Suppliers';

  void _showSnackBar(String message, {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final color = isError ? AppColors.danger : (isWarning ? AppColors.warning : AppColors.success);
    final icon = isError ? Icons.error_outline_rounded : (isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded);
    final ms = isError ? 2000 : (isWarning ? 1500 : 1000);
    rootScaffoldMessengerKey.currentState!.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.25, end: 0, curve: Curves.easeOutQuad),
        backgroundColor: color,
        duration: Duration(milliseconds: ms),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Streams cached to prevent infinite rebuild/semantics loops
  Stream<List<Map<String, dynamic>>>? _notificationStream;
  Stream<List<Map<String, dynamic>>>? _homeSalesStream;
  Stream<List<Map<String, dynamic>>>? _homeInventoryStream;

  @override
  void initState() {
    super.initState();
    final sw = Stopwatch()..start();
    _setFilter('Daily');
    // Cache common streams once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPurchases();
      final user = Provider.of<AuthService>(context, listen: false).user;
      if (user != null) {
        setState(() {
          // If staff, default to their branch
          if (user.roles.contains(UserRole.inventoryStaff) && !user.roles.contains(UserRole.admin)) {
            _selectedBranchId = user.branchId ?? 'main';
          }
          
          // Local-first notifications (no UI dependency on network).
          _notificationStream = _db.watchNotifications(user.shopId).toMainThread();
          
          _homeSalesStream = _db.watchSales(user.shopId).toMainThread();
          _homeInventoryStream = _db.watchProducts(user.shopId).toMainThread();
          _loadCurrency();
        });
        // Proactively generate expiry warnings and expired-product notifications
        _db.checkAndNotifyExpiry(user.shopId).catchError((_) {});
        PerfLogger.logPerformance('App Startup / Dashboard Init', sw.elapsedMilliseconds);
      }
    });
  }

  void _setFilter(String type) {
    setState(() {
      _reportFilter = type;
      final now = DateTime.now();
      if (type == 'Daily') {
        _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (type == 'Weekly') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        _startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day, 0, 0, 0);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (type == 'Monthly') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      }
    });
  }

  NumberFormat get _currencyFormat {
    final symbol = _appCurrencySymbol ?? 'ETB ';
    return NumberFormat.currency(symbol: symbol, decimalDigits: 2);
  }
  
  String? _appCurrencySymbol;

  String _formatLargeNumber(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toInt().toString();
  }

  Future<void> _loadCurrency() async {
    final sym = await _db.getSetting('app_currency_symbol');
    if (mounted) {
      setState(() {
        _appCurrencySymbol = sym;
      });
    }
  }

  Widget _buildTopSellingPie(List<Map<String, dynamic>> allSales) {
    Map<String, num> stats = {};
    for (var m in allSales) {
      final bId = m['branchId']?.toString() ?? 'main';
      if (_selectedBranchId != "all" && bId != _selectedBranchId) continue;
      final ts = DateTime.tryParse(m['timestamp'] ?? '');
      if (ts == null || ts.isBefore(_startDate) || ts.isAfter(_endDate)) continue;
      final name = m['itemName'] ?? 'Unknown';
      final qty = (m['quantity'] ?? 0.0);
      stats[name] = (stats[name] ?? 0) + qty;
    }
    
    var sorted = stats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    List<MapEntry<String, num>> displayedEntries = [];
    double otherSum = 0;
    
    if (sorted.length > 5) {
      displayedEntries = sorted.take(5).toList();
      otherSum = sorted.skip(5).fold(0.0, (prev, e) => prev + e.value);
      if (otherSum > 0) displayedEntries.add(MapEntry("Other", otherSum));
    } else {
      displayedEntries = sorted;
    }
    
    if (displayedEntries.isEmpty) return const Center(child: Text("No Sales Data", style: TextStyle(fontSize: 12)));

    final colors = [AppColors.secondary, AppColors.primary, AppColors.info, AppColors.warning, AppColors.danger, Colors.grey];
    final total = displayedEntries.fold<double>(0.0, (p, e) => p + e.value.toDouble());

    return DashboardCard(
      title: "Top Selling Products",
      height: 380,
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 40,
                    sections: List.generate(displayedEntries.length, (i) {
                      final val = displayedEntries[i].value.toDouble();
                      final pct = total > 0 ? (val / total * 100).toInt() : 0;
                      return PieChartSectionData(
                        value: val < (total * 0.05) ? (total * 0.05) : val, // Minimum slice size
                        title: '$pct%',
                        color: colors[i % colors.length],
                        radius: 25,
                        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      );
                    }),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(total.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                    const Text("Total Units", style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ...displayedEntries.map((e) {
            final idx = displayedEntries.indexOf(e);
            return _buildPieLegend(e.key, colors[idx % colors.length], e.value.toInt().toString());
          }),
        ],
      ),
    );
  }

  String _searchQuery = "";
  final TextEditingController _posBarcodeC = TextEditingController(); // For POS Barcode scanning
  String _selectedBranchId = "all";
  List<CartItem> _posCart = [];
  double _cartTotal = 0;

  // Scanner Logic
  final MobileScannerController _scannerController = MobileScannerController();

  // Search controllers
  final TextEditingController _searchInventoryC = TextEditingController();
  final TextEditingController _searchSalesC = TextEditingController();
  final TextEditingController _searchPurchasesC = TextEditingController();
  final TextEditingController _searchAuditC = TextEditingController();
  final TextEditingController _auditUserSearchC = TextEditingController();
  String _selectedAuditAction = 'All Actions';
  String _selectedAuditUserFilter = "";
  int _graphDays = 7;

  @override
  void dispose() {
    _scannerController.dispose();
    _searchInventoryC.dispose();
    _searchSalesC.dispose();
    _searchPurchasesC.dispose();
    _searchAuditC.dispose();
    _auditUserSearchC.dispose();
    super.dispose();
  }

  void _handleAddToCart(Map<String, dynamic> doc, {bool isQuickSell = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _QuickSellDialog(
        doc: doc,
        isQuickSell: isQuickSell,
        onAddToCart: (params) {
          Navigator.pop(ctx);
          if (isQuickSell) {
             _handlePOSCheckout(params, doc);
          } else {
             _handleCartAddition(params, doc);
          }
        },
      ),
    );
  }

  void _handlePOSCheckout(Map<String, dynamic> params, Map<String, dynamic> doc) async {
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) return;
    final d = doc;
    final val = params['qty'] as double;
    final isDebt = params['paymentType'] == 'Debt';
    final buyer = params['buyer'] as String;
    final advanced = params['advanced'] as double;
    
    final sp = (d['sellingPrice'] ?? 0).toDouble();
    final bp = (d['buyingPrice'] ?? 0).toDouble();
    final total = sp * val;

    try {
      LoadingOverlay.show(context);
      await _repo.recordSale(user, {
        'itemId': d['id'],
        'itemName': d['name'],
        'quantity': val.toInt(),
        'totalPrice': total,
        'profit': (sp - bp) * val,
        'userId': user.id,
        'username': user.username,
        'customerName': buyer.isEmpty ? 'Guest' : buyer,
        'isDebt': isDebt && (total - advanced) > 0,
        'debtRemaining': isDebt ? (total - advanced) : 0.0,
        'advancedPaid': isDebt ? advanced : total,
        'shopId': user.shopId,
        'branchId': d['branchId'] ?? user.branchId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      if (mounted) LoadingOverlay.hide(context);
      _showSnackBar("Quick Sale Success!");
    } catch (e) {
      if (mounted) LoadingOverlay.hide(context);
      _showSnackBar(e.toString(), isError: true);
    }
  }

  void _handleCartAddition(Map<String, dynamic> params, Map<String, dynamic> doc) {
    final val = params['qty'] as double;
    final d = doc;
    final branchId = d['branchId']?.toString();
    
    setState(() {
      final exIdx = _posCart.indexWhere((i) => i.id == d['id'] && i.branchId == branchId);
      if (exIdx != -1) {
        _posCart[exIdx].quantity = val.toInt();
      } else {
        _posCart.add(CartItem(
          id: d['id'],
          name: d['name'],
          price: (d['sellingPrice'] ?? 0).toDouble(),
          quantity: val.toInt(),
          batchNumber: d['batchNumber']?.toString(),
          cost: (d['buyingPrice'] ?? 0).toDouble(),
          branchId: branchId,
        ));
      }
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _cartTotal = _posCart.fold(0, (sum, i) => sum + i.total);
  }

  void _clearCart() {
    setState(() {
      _posCart.clear();
      _cartTotal = 0;
    });
  }

  List<Map<String, dynamic>>? _purchases;
  bool _isLoadingPurchases = true;


  void _fetchPurchases() {}
  // Refactored to unified StreamBuilder in Phase 4.4.1.1

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthService, AppUser?>((auth) => auth.user);
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool desktop = MediaQuery.sizeOf(context).width > 900;
    final sidebarItems = _getSidebarItems(user);

    return Scaffold(
      key: const ValueKey('admin_scaffold'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: desktop ? null : _buildMobileAppBar(user),
      drawer: desktop ? null : Drawer(
        width: 280,
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    Text("SmartInventory ERP", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: sidebarItems.length,
                itemBuilder: (context, i) {
                  final item = sidebarItems[i];
                  return ListTile(
                    leading: Icon(item.icon, color: _selectedIndex == i ? AppColors.secondary : null),
                    title: Text(item.label, style: TextStyle(
                      fontWeight: _selectedIndex == i ? FontWeight.bold : null,
                      color: _selectedIndex == i ? AppColors.secondary : null,
                    )),
                    selected: _selectedIndex == i,
                    onTap: () {
                      final sw = Stopwatch()..start();
                      setState(() => _selectedIndex = i);
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                         PerfLogger.logPerformance('Open ${item.label}', sw.elapsedMilliseconds);
                      });
                    },
                  );
                },
              ),
            ),
            const Divider(),
            _buildLogoutButton(),
          ],
        ),
      ),

      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (desktop)
            SizedBox(
              width: 260,
              child: Column(
                children: [
                  Expanded(
                    child: ERPSidebar(
                      key: const ValueKey('admin_sidebar'),
                      selectedIndex: _selectedIndex,
                      items: sidebarItems,
                      onItemSelected: (i) => setState(() => _selectedIndex = i),
                    ),
                  ),
                  _buildLogoutButton(),
                ],
              ),
            ),
          Expanded(
            child: Column(
              key: const ValueKey('admin_main_content'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (desktop) _buildDesktopHeader(user),
                Expanded(child: _buildBody(user)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: desktop ? null : _buildBottomNav(),
      floatingActionButton: _buildCorrectFAB(user, sidebarItems),
    );
  }

  Widget? _buildCorrectFAB(AppUser user, List<SidebarItem> items) {
    return null;
  }

  Widget _buildLogoutButton() {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.primary, // MATCH SIDEBAR
        border: Border(
          right: BorderSide(color: AppColors.border, width: 0.5),
          top: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: ElevatedButton.icon(
        onPressed: () async {
          await Provider.of<AuthService>(context, listen: false).signOut();
        },
        icon: const Icon(Icons.logout_rounded,
            size: 18, color: Color(0xFFEF4444)),
        label: const Text("Logout",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: const Color(0xFFEF4444),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: const Size(double.infinity, 44),
        ),
      ),
    );
  }

  List<SidebarItem> _getSidebarItems(AppUser user) {
    final isAdminOrManager = user.hasRole(UserRole.admin) ||
        user.hasRole(UserRole.manager);
    
    final List<SidebarItem> items = [
      SidebarItem(
          uid: 'overview', icon: Icons.grid_view_rounded, label: 'dashboard'.tr(context)),
    ];

    if (user.hasPermission(AppUser.pViewInventory) ||
        user.hasPermission(AppUser.pTransferStock)) {
      items.add(SidebarItem(
          uid: 'inventory',
          icon: Icons.inventory_2_outlined,
          label: 'inventory'.tr(context)));
    }

    if (user.hasPermission(AppUser.pCreateSales)) {
      items.add(SidebarItem(
          uid: 'sales',
          icon: Icons.point_of_sale_rounded,
          label: 'sales_pos'.tr(context)));
    }

    if (user.hasPermission(AppUser.pViewSalesHistory) || user.hasPermission(AppUser.pRefundSales)) {
      items.add(SidebarItem(
          uid: 'transactions',
          icon: Icons.receipt_long_rounded,
          label: 'Transactions'));
    }

    if (user.hasPermission(AppUser.pCreatePurchase)) {
      items.add(SidebarItem(
          uid: 'purchases',
          icon: Icons.receipt_long_outlined,
          label: 'purchases'.tr(context)));
    }

    // Debt (Customer management / Debt management) is gated on Manage Customers permission
    if (user.hasPermission(AppUser.pManageCustomers)) {
      items.add(SidebarItem(uid: 'debt', icon: Icons.payments_rounded, label: 'debt'.tr(context)));
    }

    if (user.hasPermission(AppUser.pViewReports)) {
      items.add(SidebarItem(
          uid: 'reports', icon: Icons.analytics_outlined, label: 'reports'.tr(context)));
    }

    if (isAdminOrManager) {
      if (user.hasPermission(AppUser.pManageUsers) || user.hasRole(UserRole.admin)) {
        items.add(SidebarItem(uid: 'users', icon: Icons.group_outlined, label: 'Manage Users'));
      }
      if (user.hasPermission(AppUser.pManageBranches) || user.hasRole(UserRole.admin)) {
        items.add(SidebarItem(uid: 'branches', icon: Icons.lan_outlined, label: 'Manage Branches'));
      }
    }

    if (user.hasPermission(AppUser.pViewAuditLogs)) {
      items.add(SidebarItem(
          uid: 'audit', icon: Icons.history_rounded, label: 'audit_history'.tr(context)));
    }

    items.add(SidebarItem(
        uid: 'settings', icon: Icons.settings_outlined, label: 'settings'.tr(context)));

    return items;
  }



  PreferredSizeWidget _buildMobileAppBar(AppUser user) {
    return AppBar(
      title: Text(_getTabTitle(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      centerTitle: false,
      actions: [
        _buildBranchSelector(user),
        const SizedBox(width: 4),
        _buildNotificationBadge(user),
        const SizedBox(width: 4),
        const AccountDropdown(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDesktopHeader(AppUser user) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_getTabTitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary)),
                const SizedBox(height: 4),
                Text("Welcome back, ${user.username}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(DateFormat('MMM d, yyyy').format(DateTime.now()),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // ── Branch Selector ──
                _buildBranchSelector(user),
                const SizedBox(width: 16),
                _buildNotificationBadge(user),
                const SizedBox(width: 8),
                const AccountDropdown(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchSelector(AppUser user) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.watchBranches(user.shopId).toMainThread(),
      builder: (ctx, branchSnap) {
        final branches = (branchSnap.data ?? []).where((b) => b['id'] != 'all').toList();
        final allBranchIds = branches.map((b) => b['id'].toString()).toList();
        final allowedBranchIds = user.getAssignedBranchIds(allBranchIds);

        // Filter branch details to only those allowed
        final allowedBranches = branches.where((b) => allowedBranchIds.contains(b['id'])).toList();

        // 1. Single Branch
        if (allowedBranchIds.length == 1 || (allowedBranchIds.length == 2 && !allowedBranchIds.contains('all') && allowedBranches.length == 1)) {
          final branch = allowedBranches.isNotEmpty ? allowedBranches.first : {'id': user.branchId, 'name': user.branchName ?? 'Main Branch'};
          final branchName = branch['name'] ?? 'Main Branch';
          
          // Auto select if not already
          if (_selectedBranchId != branch['id']) {
            _selectedBranchId = branch['id'];
            Future.microtask(() => setState(() {
              _homeSalesStream = _db.watchSales(user.shopId, branchId: _selectedBranchId).toMainThread();
              _homeInventoryStream = _db.watchProducts(user.shopId, branchId: _selectedBranchId).toMainThread();
            }));
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_rounded, size: 16, color: Theme.of(context).brightness == Brightness.light ? Colors.black87 : Colors.white),
                const SizedBox(width: 8),
                Text(
                  branchName,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.light ? Colors.black87 : Colors.white),
                ),
              ],
            ),
          );
        }

        // 2. Multiple or All Branches
        final options = <Map<String, dynamic>>[];
        if (allowedBranchIds.contains('all')) {
          options.add({'id': 'all', 'name': 'All Branches'});
          options.addAll(branches);
        } else {
          options.addAll(allowedBranches);
        }

        // Robust validation to prevent Dropdown crash and set default on first load
        String validId = options.isNotEmpty ? options.first['id'] : 'all';
        if (options.any((b) => b['id'] == _selectedBranchId)) {
          validId = _selectedBranchId;
        } else {
          _selectedBranchId = validId;
          Future.microtask(() => setState(() {
            _homeSalesStream = _db.watchSales(user.shopId, branchId: _selectedBranchId == 'all' ? null : _selectedBranchId).toMainThread();
            _homeInventoryStream = _db.watchProducts(user.shopId, branchId: _selectedBranchId == 'all' ? null : _selectedBranchId).toMainThread();
          }));
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: validId,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.textSecondary),
              items: options
                  .map((b) => DropdownMenuItem<String>(
                        value: b['id'] as String,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.store_rounded,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(b['name'] as String,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedBranchId = val;
                    final newItems = _getSidebarItems(user);
                    if (_selectedIndex >= newItems.length) {
                       _selectedIndex = 0;
                    }
                    _homeSalesStream = _db
                        .watchSales(user.shopId,
                            branchId: val == 'all' ? null : val)
                        .toMainThread();
                    _homeInventoryStream = _db
                        .watchProducts(user.shopId,
                            branchId: val == 'all' ? null : val)
                        .toMainThread();
                  });
                }
              },
            ),
          ),
        );
      },
    );
  }

  String _getTabTitle() {
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) return "ERP";
    final items = _getSidebarItems(user);
    if (_selectedIndex >= items.length) return "ERP";
    return items[_selectedIndex].label;
  }

  Widget _buildNotificationBadge(AppUser user) {
    if (!user.hasPermission(AppUser.pViewNotifications)) return const SizedBox();
    if (_notificationStream == null) return const SizedBox();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _notificationStream,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <Map<String, dynamic>>[];
        final unread = all.where((n) => (n['isRead'] ?? false) != true).toList();
        final delCount = unread.length;
        return badges.Badge(
          showBadge: delCount > 0,
          badgeContent: Text('$delCount',
              style: const TextStyle(color: Colors.white, fontSize: 10)),
          child: IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => _showNotificationsPanel(user, all),
          ),
        );
      },
    );
  }

  
  void _handleNotificationTap(AppUser user, Map<String, dynamic> req) {
    final payload = jsonDecode(req['payloadJson'] ?? '{}');
    final type = req['type'] ?? 'info';
    
    if (type == 'stock_transfer' && payload['recordId'] != null) {
       // Logic to jump to audit or specific item
       rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(content: Text("Transfer Details: ${req['message']}")));
    } else if (type == 'low_stock') {
       setState(() {
         _selectedIndex = _getSidebarItems(user).indexWhere((it) => it.uid == 'inventory');
         _searchInventoryC.text = payload['productId'] ?? '';
       });
    }
    
    // Auto mark as read on tap
    if ((req['isRead'] ?? false) == false) {
       _db.markNotificationAsRead(req['id']);
    }
    Navigator.pop(context); // Close panel
  }

  void _showNotificationsPanel(
      AppUser user, List<Map<String, dynamic>> notifications) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Central Notifications",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    if (notifications.isNotEmpty)
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _db.markAllNotificationsAsRead(user.shopId);
        _showSnackBar('All notifications marked as read.');
                        },
                        child: const Text("Mark All Read"),
                      ),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_rounded,
                            color: AppColors.textSecondary.withOpacity(0.3),
                            size: 48),
                        const SizedBox(height: 16),
                        const Text("No pending alerts for today."),
                      ],
                    ))
                  : ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (c, i) {
                        final req = notifications[i];
                        final id = req['id']?.toString() ?? '';
                        final isRead = (req['isRead'] ?? false) == true;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isRead
                                ? AppColors.border.withOpacity(0.4)
                                : AppColors.secondary.withOpacity(0.15),
                            child: Icon(
                              Icons.notifications_rounded,
                              color: isRead ? AppColors.textSecondary : AppColors.secondary,
                              size: 18,
                            ),
                          ),
                          title: Text(req['title']?.toString() ?? 'Notification', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                          subtitle: Text(req['message']?.toString() ?? ''),
                          onTap: () => _handleNotificationTap(user, req),
                          trailing: (!isRead && id.isNotEmpty)
                              ? IconButton(
                                  tooltip: 'Mark as read',
                                  icon: const Icon(Icons.done_rounded, color: AppColors.success),
                                  onPressed: () async {
                                    await _db.markNotificationAsRead(id);
                                  },
                                )
                              : null,
                        );
                      }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppUser user) {
    final items = _getSidebarItems(user);
    final safeIndex = _selectedIndex < items.length ? _selectedIndex : 0;

    return IndexedStack(
      index: safeIndex,
      children: items.map((it) {
        switch (it.uid) {
          case 'overview': return _buildHomeTab(user, items);
          case 'inventory': return _buildInventoryTab(user);
          case 'sales': return _buildSalesTab(user);
          case 'transactions': return _buildTransactionsTab(user);
          case 'purchases': return _buildSupplierTab(user);
          case 'debt': return _buildDebtTab(user);
          case 'reports': return _buildReportsTab(user, items);
          case 'users': return _buildManageUsersTab(user);
          case 'branches': return _buildManageBranchesTab(user);
          case 'audit': return _buildAuditLogTab(user);
          case 'settings': return _buildSettingsTab(user);
          default: return const Center(child: Text("Coming Soon"));
        }
      }).toList(),
    );
  }

  Widget _buildHomeTab(AppUser user, List<SidebarItem> sidebarItems) {
    if (_homeSalesStream == null || _homeInventoryStream == null) {
      return const DashboardSkeleton();
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _homeSalesStream,
      builder: (context, salesSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _homeInventoryStream,
          builder: (context, invSnap) {
            double rev = 0;
            double prof = 0;
            int count = 0;
            int lowStock = 0;
            List<Map<String, dynamic>> sales = [];

            if (salesSnap.hasData) {
              sales = (salesSnap.data ?? []).where((m) {
                final bId = m['branchId']?.toString() ?? 'main';
                if (_selectedBranchId != "all" && bId != _selectedBranchId) return false;
                final ts = parseDT(m['timestamp']);
                if (ts == null) return false;
                return ts.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
                       ts.isBefore(_endDate.add(const Duration(days: 1)));
              }).toList();

              for (var doc in sales) {
                final m = doc;
                final rev_total = (m['totalPrice'] ?? 0).toDouble();
                final prof_total = (m['profit'] ?? 0).toDouble();
                final originalQty = (m['quantity'] ?? 0.0).toDouble();
                final refundedQty = (m['refundedQuantity'] ?? 0.0).toDouble();
                
                double effectiveRev = rev_total;
                double effectiveProf = prof_total;
                if (refundedQty > 0 && originalQty > 0) {
                  final unitPrice = rev_total / originalQty;
                  final unitProf = prof_total / originalQty;
                  effectiveRev -= (unitPrice * refundedQty);
                  effectiveProf -= (unitProf * refundedQty);
                }
                
                rev += effectiveRev;
                prof += effectiveProf;
                count++;
              }
            }

            int expiredCount = 0;
            int soonCount = 0;
            if (invSnap.hasData) {
              final today = DateTime.now();
              for (var m in (invSnap.data ?? [])) {
                final bId = m['branchId']?.toString() ?? 'main';
                if (_selectedBranchId != "all" && bId != _selectedBranchId) continue;
                final qty = (m['quantity'] ?? 0).toDouble();
                final threshold = (m['lowStockThreshold'] ?? 5).toDouble();
                // We use qty > 0 check for warnings to avoid double counting out of stock if needed, 
                // but usually lowStock includes 0. 
                if (qty <= threshold) lowStock++;
                
                final ed = m['expiry'] ?? m['exp'];
                if (ed != null) {
                   final exp = parseDT(ed);
                   if (exp != null) {
                      if (exp.isBefore(today)) {
                         expiredCount++;
                      } else if (exp.difference(today).inDays <= 30) {
                         soonCount++;
                      }
                   }
                }
              }
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cardDecoration = BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: isDark
                  ? null
                  : Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
            );

            return LayoutBuilder(builder: (context, constraints) {
              final bool isMobile = constraints.maxWidth < 750;
              final Color profitColor =
                  prof < 0 ? AppColors.danger : AppColors.success;

              final statCards = <Widget>[
                      if (user.hasPermission(AppUser.pViewReports))
                        StatCard(
                          title: 'Total Revenue',
                          value: _currencyFormat.format(rev),
                          color: profitColor,
                          icon: Icons.attach_money_rounded,
                          change: "+8.5%",
                          cardDecoration: cardDecoration,
                          onTap: () {
                             final idx = sidebarItems.indexWhere((it) => it.uid == 'reports');
                             if (idx != -1) setState(() => _selectedIndex = idx);
                          }
                        ),
                      if (user.hasPermission(AppUser.pViewProfit))
                        StatCard(
                          title: 'Net Profit',
                          value: _currencyFormat.format(prof),
                          color: profitColor,
                          icon: prof < 0
                              ? Icons.trending_down_rounded
                              : Icons.trending_up_rounded,
                          change: prof < 0 ? "Loss" : "Profit",
                          isPositive: prof >= 0,
                          cardDecoration: cardDecoration,
                          onTap: () {
                             final idx = sidebarItems.indexWhere((it) => it.uid == 'reports');
                             if (idx != -1) setState(() => _selectedIndex = idx);
                          }
                        ),
                      if (user.hasPermission(AppUser.pAccessPOS))
                        StatCard(
                          title: 'Transactions',
                          value: count.toString(),
                          color: AppColors.secondary,
                          icon: Icons.receipt_long_rounded,
                          change: "+$count",
                          cardDecoration: cardDecoration,
                          onTap: () => setState(() => _selectedIndex =
                              sidebarItems.indexWhere((it) => it.uid == 'sales')),
                        ),
                      if (user.hasPermission(AppUser.pAddEditProducts))
                        StatCard(
                          title: 'Low Stock',
                          value: '$lowStock items',
                          color: AppColors.danger,
                          icon: Icons.warning_amber_rounded,
                          change: lowStock > 0 ? "⚠ Reorder" : "✓ All Good",
                          isPositive: lowStock == 0,
                          cardDecoration: cardDecoration,
                          onTap: () => setState(() => _selectedIndex =
                              sidebarItems.indexWhere((it) => it.uid == 'inventory')),
                        ),
                      if (soonCount > 0 || expiredCount > 0)
                        StatCard(
                          title: 'Expiry Alerts',
                          value: '${soonCount + expiredCount} items',
                          color: expiredCount > 0 ? AppColors.danger : AppColors.warning,
                          icon: Icons.event_busy_rounded,
                          change: expiredCount > 0 ? "EXPIRED Found" : "Expiring Soon",
                          isPositive: false,
                          cardDecoration: cardDecoration,
                          onTap: () => setState(() => _selectedIndex =
                              sidebarItems.indexWhere((it) => it.uid == 'inventory')),
                        ),
                  ];

              return ListView(
                padding: EdgeInsets.all(isMobile ? 16 : 32),
                children: [
                  GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 2 : 4,
                      mainAxisSpacing: isMobile ? 12 : 24,
                      crossAxisSpacing: isMobile ? 12 : 24,
                      childAspectRatio: isMobile ? 1.4 : 1.6,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: statCards.length,
                    itemBuilder: (context, index) => statCards[index],
                  ),
                  const SizedBox(height: 32),
                  // Responsive Charts and Lists
                   if (isMobile) ...[
                    if (user.hasPermission(AppUser.pViewFinancialData)) ...[
                      _buildProfitLossSection(context, cardDecoration, salesSnap.data ?? []),
                      const SizedBox(height: 24),
                    ],
                    _buildRecentSalesList(
                        user, sales, cardDecoration, sidebarItems),
                    const SizedBox(height: 24),
                    _buildTopSellingTable(
                        user, salesSnap.data ?? [] ?? [], cardDecoration),
                    const SizedBox(height: 24),
                    _buildAlertsCol(
                        invSnap.data ?? [] ?? [], cardDecoration),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user.hasPermission(AppUser.pViewFinancialData)) ...[
                          Expanded(
                              flex: 3,
                              child: _buildProfitLossSection(
                                  context, cardDecoration, salesSnap.data ?? [])),
                          const SizedBox(width: 32),
                        ],
                        Expanded(
                            flex: 2,
                            child: _buildRecentSalesList(
                                user, sales, cardDecoration, sidebarItems)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 3,
                            child: _buildTopSellingTable(user, sales, cardDecoration)),
                        const SizedBox(width: 32),
                        Expanded(
                                child: _buildAlertsCol(invSnap.data ?? [], cardDecoration)),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      );
  }

  Widget _buildProfitLossSection(
      BuildContext context, BoxDecoration cardDecoration, List<Map<String, dynamic>> allSales) {
    final now = DateTime.now();
    List<FlSpot> spots = [];
    double maxVal = 1000;
    double minVal = 0;

    double totalPeriodProf = 0;
    for (int i = 0; i < _graphDays; i++) {
        final date = now.subtract(Duration(days: (_graphDays - 1) - i));
        double dailyProf = 0;
        for (var doc in allSales) {
            final m = doc;
            final bId = m['branchId']?.toString() ?? 'main';
            if (_selectedBranchId != 'all' && bId != _selectedBranchId) continue;
            
            final ts = parseDT(m['timestamp']);
            if (ts != null &&
                ts.year == date.year &&
                ts.month == date.month &&
                ts.day == date.day) {
            dailyProf += (m['profit'] ?? 0).toDouble();
            }
        }
        spots.add(FlSpot(i.toDouble(), dailyProf));
        totalPeriodProf += dailyProf;
        if (dailyProf > maxVal) maxVal = dailyProf;
        if (dailyProf < minVal) minVal = dailyProf;
    }

    final periodColor =
        totalPeriodProf < 0 ? AppColors.danger : AppColors.secondary;

    // Ensure some padding for visuals
    // Dynamic scaling: If max is 0, default to 2000 for visibility
    if (maxVal == 0) maxVal = 2000;
    
    final double absoluteMax = maxVal;
    maxVal = maxVal * 1.3; // Add more headroom
    minVal = minVal < 0 ? minVal * 1.2 : 0;
    
    // Ensure small values don't look like a flat line
    if (maxVal - minVal < 100) maxVal = minVal + 100;

    return DashboardCard(
        title: "Profit/Loss Overview",
        height: 380,
        trailing: SegmentedButton<int>(
            segments: const [
            ButtonSegment(value: 7, label: Text("7D")),
            ButtonSegment(value: 30, label: Text("30D")),
            ],
            selected: {_graphDays},
            onSelectionChanged: (set) => setState(() => _graphDays = set.first),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            textStyle: const TextStyle(fontSize: 10),
            ),
        ),
        child: SizedBox(
                height: 250,
                child: LineChart(
                LineChartData(
                    gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                        color: AppColors.border.withOpacity(0.1),
                        strokeWidth: 1,
                    ),
                    ),
                    titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (v, meta) {
                            return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                                _formatLargeNumber(v),
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                            ),
                            );
                        },
                        ),
                    ),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: _graphDays == 30 ? 5 : 1,
                        getTitlesWidget: (v, meta) {
                            final date = now.subtract(Duration(days: (_graphDays - 1) - v.toInt()));
                            if (_graphDays == 7) {
                            return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(DateFormat('E').format(date),
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 8)),
                            );
                            }
                            return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(DateFormat('MMM d').format(date),
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 8)),
                            );
                        },
                        ),
                    ),
                    ),
                    minY: minVal,
                    maxY: maxVal,
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                    LineChartBarData(
                        spots: spots,
                        isCurved: false,
                        color: periodColor,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 4,
                            color: periodColor,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                        ),
                        ),
                        belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [periodColor.withOpacity(0.2), periodColor.withOpacity(0.0)],
                        ),
                        ),
                    ),
                    ],
                    lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                            final date = now.subtract(Duration(days: (_graphDays - 1) - spot.x.toInt()));
                            return LineTooltipItem(
                            "${DateFormat('MMM d').format(date)}\n${_currencyFormat.format(spot.y)}",
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            );
                        }).toList();
                        },
                    ),
                    ),
                ),
                ),
            ),
    );
  }

  Widget _buildRecentSalesList(AppUser user, List<Map<String, dynamic>> sales,
      BoxDecoration cardDecoration, List<SidebarItem> sidebarItems) {
    return DashboardCard(
      title: "Recent Activity",
      height: 380,
      trailing: TextButton(
          onPressed: () => setState(() => _selectedIndex =
              sidebarItems.indexWhere((it) => it.uid == 'audit')),
          child: const Text("View all",
              style: TextStyle(fontSize: 12, color: AppColors.secondary))),
      child: Column(
        children: [
          if (sales.isEmpty)
             const Padding(padding: EdgeInsets.all(24), child: Text("No recent sales.", style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          ...sales.take(10).map((s) {
            final d = s;
            final ts = parseDT(d['timestamp']) ?? DateTime.now();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.shopping_bag_outlined,
                    color: AppColors.secondary, size: 18),
              ),
              title: Text(d['itemName'] ?? 'Product',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(DateFormat('hh:mm a').format(ts),
                  style: const TextStyle(fontSize: 11)),
              trailing: Text(_currencyFormat.format(d['totalPrice'] ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success)),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildManageUsersTab(AppUser adminUser) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          floating: true,
          pinned: false,
          snap: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          expandedHeight: 80,
          toolbarHeight: 64,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              child: Row(
                children: [
                   const Spacer(),
                   ElevatedButton.icon(
                    onPressed: () => _showCreateUserDialog(adminUser),
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text("Add Account", style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _db.watchUsers(adminUser.shopId).toMainThread(),
          builder: (c, snap) {
            if (!snap.hasData) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
            final users = snap.data ?? [];
            if (users.isEmpty) return const SliverFillRemaining(child: Center(child: Text('No staff accounts found.')));
            
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (c, i) {
                    final d = users[i];
                    final role = ((d['roles'] as List?)?.first ?? 'inventoryStaff').toString();
                    final displayRole = role == 'admin' ? 'Admin' :
                                        role == 'manager' ? 'Manager' :
                                        role == 'cashier' ? 'Cashier' :
                                        role == 'inventoryStaff' ? 'Inventory Staff' : 'Inventory Staff';
                    final isAdmin = role == 'admin';
                    final username = (d['username'] ?? 'User').toString().toTitleCase();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                         color: Theme.of(context).colorScheme.surface,
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(color: AppColors.border.withOpacity(0.5)),
                      ),
                      child: ListTile(
                         leading: CircleAvatar(
                           backgroundColor: (isAdmin ? AppColors.warning : AppColors.secondary).withOpacity(0.1),
                           child: Icon(isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_outline_rounded,
                               color: isAdmin ? AppColors.warning : AppColors.secondary, size: 20),
                         ),
                         title: Row(
                           children: [
                             Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                             const SizedBox(width: 8),
                              const SizedBox.shrink(),
                           ],
                         ),
                         subtitle: Text(d['email'] ?? '', style: const TextStyle(fontSize: 11)),
                         trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             PastelBadge(label: displayRole.toUpperCase(), baseColor: isAdmin ? AppColors.warning : AppColors.secondary),
                            const SizedBox(width: 8),
                             if (!isAdmin) ...[
                               IconButton(
                                 icon: const Icon(Icons.lock_reset_rounded, size: 18, color: AppColors.warning),
                                 tooltip: 'Reset Password',
                                 onPressed: () {
                                   showDialog(
                                     context: context,
                                     builder: (ctx) => AdminResetPasswordDialog(
                                       targetUserId: d['uid']?.toString() ?? '',
                                       targetUsername: d['username']?.toString() ?? 'User',
                                     ),
                                   );
                                 },
                               ),
                               IconButton(
                                 icon: const Icon(Icons.edit_outlined, size: 18),
                                 onPressed: () => _showEditUserDialog(d['uid'], d),
                               ),
                               IconButton(
                                 icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                                 onPressed: () => _confirmDeleteUser(d['uid'], d['username'] ?? ''),
                               ),
                             ],
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: users.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showEditUserDialog(String uid, Map<String, dynamic> data) {
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) return;
    final nameC = TextEditingController(text: data['username']);
    String selectedRole = ((data['roles'] as List?)?.first ?? 'inventoryStaff').toString();
    if (selectedRole == 'staff') selectedRole = 'inventoryStaff';
    String? assignedBranchId = data['branchId']?.toString();
    
    // Initialize permissions/branch access from existing data
    Map<String, dynamic> rawPerms = data['permissions'] is Map ? data['permissions'] : (
      data['permissions'] is String ? jsonDecode(data['permissions'] as String) : {}
    );
    Map<String, bool> userPerms = {
      for (var p in AppUser.allPermissions) p: rawPerms[p] == true
    };

    String branchAccessType = 'single';
    if (rawPerms['branch_access_all'] == true) {
      branchAccessType = 'all';
    } else {
      int count = rawPerms.keys.where((k) => k.startsWith('branch_access_') && rawPerms[k] == true).length;
      if (count > 1) {
        branchAccessType = 'multiple';
      }
    }

    Map<String, bool> checkedBranches = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.surface,
                title: const Text("Edit Staff Account"),
                content: SizedBox(
                   width: 500,
                   child: SingleChildScrollView(
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         TextField(
                           controller: nameC,
                           decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person)),
                         ),
                         const SizedBox(height: 16),
                         
                         DropdownButtonFormField<String>(
                           value: ['admin', 'manager', 'cashier', 'inventoryStaff'].contains(selectedRole) ? selectedRole : 'inventoryStaff',
                           decoration: const InputDecoration(labelText: "Role"),
                           items: const [
                             DropdownMenuItem(value: 'admin', child: Text('Admin')),
                             DropdownMenuItem(value: 'manager', child: Text('Manager')),
                             DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                             DropdownMenuItem(value: 'inventoryStaff', child: Text('Inventory Staff')),
                           ],
                           onChanged: (v) {
                             if (v != null) setS(() => selectedRole = v);
                           },
                         ),
                         const SizedBox(height: 16),

                         StreamBuilder<List<Map<String, dynamic>>>(
                           stream: _db.watchBranches(user.shopId).toMainThread(),
                           builder: (c, snap) {
                             final branches = (snap.data ?? []).where((element) => element['id'] != 'all').toList();
                             if (branches.isEmpty) {
                               branches.add({'id': 'main', 'name': 'Main Branch'});
                             }
                             
                             for (var b in branches) {
                               final bId = b['id'].toString();
                               checkedBranches.putIfAbsent(bId, () => rawPerms['branch_access_$bId'] == true);
                             }

                             return Column(
                               crossAxisAlignment: CrossAxisAlignment.stretch,
                               children: [
                                 DropdownButtonFormField<String>(
                                   value: branchAccessType,
                                   decoration: const InputDecoration(labelText: "Branch Access Scope"),
                                   items: const [
                                     DropdownMenuItem(value: 'single', child: Text('Single Branch')),
                                     DropdownMenuItem(value: 'multiple', child: Text('Multiple Branches')),
                                     DropdownMenuItem(value: 'all', child: Text('All Branches')),
                                   ],
                                   onChanged: (v) {
                                     if (v != null) {
                                       setS(() {
                                         branchAccessType = v;
                                         if (v == 'all') {
                                           assignedBranchId = 'main';
                                         }
                                       });
                                     }
                                   },
                                 ),
                                 const SizedBox(height: 12),
                                 if (branchAccessType == 'single') ...[
                                   DropdownButtonFormField<String>(
                                     value: branches.any((b) => b['id'] == assignedBranchId) ? assignedBranchId : branches.first['id'].toString(),
                                     decoration: const InputDecoration(labelText: "Select Primary Branch"),
                                     items: branches.map((b) => DropdownMenuItem(
                                       value: b['id'].toString(),
                                       child: Text(b['name']),
                                     )).toList(),
                                     onChanged: (v) => setS(() => assignedBranchId = v),
                                   ),
                                 ] else if (branchAccessType == 'multiple') ...[
                                   const Align(
                                     alignment: Alignment.centerLeft,
                                     child: Text("Select Assigned Branches:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                                   ),
                                   const SizedBox(height: 6),
                                   Container(
                                     constraints: const BoxConstraints(maxHeight: 120),
                                     decoration: BoxDecoration(
                                       border: Border.all(color: AppColors.border),
                                       borderRadius: BorderRadius.circular(8),
                                     ),
                                     child: ListView(
                                       shrinkWrap: true,
                                       children: branches.map((b) {
                                         final bId = b['id'].toString();
                                         return CheckboxListTile(
                                           title: Text(b['name'], style: const TextStyle(fontSize: 12)),
                                           value: checkedBranches[bId] ?? false,
                                           dense: true,
                                           onChanged: (v) {
                                             setS(() {
                                               checkedBranches[bId] = v ?? false;
                                               if (v == true && (assignedBranchId == null || assignedBranchId == 'all')) {
                                                 assignedBranchId = bId;
                                               }
                                             });
                                           },
                                         );
                                       }).toList(),
                                     ),
                                   ),
                                 ] else ...[
                                   const Padding(
                                     padding: EdgeInsets.symmetric(vertical: 8),
                                     child: Text("User will have access to all branches.", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
                                   ),
                                 ],
                               ],
                             );
                           }
                         ),

                         const Divider(height: 32),
                         const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Permissions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary)),
                         ),
                         const SizedBox(height: 12),
                         Container(
                           decoration: BoxDecoration(
                             border: Border.all(color: AppColors.border),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Column(
                             children: AppUser.permissionGroups.entries.expand((entry) => [
                               Padding(
                                 padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                 child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary)),
                               ),
                               ...entry.value.map((p) => CheckboxListTile(
                                 title: Text(p, style: const TextStyle(fontSize: 12)),
                                 value: userPerms[p] ?? false,
                                 onChanged: (v) => setS(() => userPerms[p] = v ?? false),
                                 dense: true,
                                 controlAffinity: ListTileControlAffinity.leading,
                               )),
                               const Divider(height: 1),
                             ]).toList(),
                           ),
                         ),
                       ],
                     ),
                   ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                  ElevatedButton(
                    onPressed: () async {
                      final Map<String, bool> finalPerms = { ...userPerms };
                      if (branchAccessType == 'all') {
                        finalPerms['branch_access_all'] = true;
                      } else if (branchAccessType == 'multiple') {
                        finalPerms['branch_access_all'] = false;
                        checkedBranches.forEach((bId, value) {
                          finalPerms['branch_access_$bId'] = value;
                        });
                        if (assignedBranchId != null) {
                          finalPerms['branch_access_$assignedBranchId'] = true;
                        }
                      } else {
                        finalPerms['branch_access_all'] = false;
                        if (assignedBranchId != null) {
                          finalPerms['branch_access_$assignedBranchId'] = true;
                        }
                      }

                      // Validation: Manage Stock Transfers requires multi-branch access
                      final hasTransfer = finalPerms[AppUser.pManageStockTransfers] == true;
                      if (hasTransfer && branchAccessType == 'single') {
                        rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                          content: const Text('⚠️ "Manage Stock Transfers" requires access to multiple branches. Please change the branch scope or remove the transfer permission.'),
                          backgroundColor: AppColors.warning,
                          duration: const Duration(milliseconds: 2500),
                        ));
                        return;
                      }
                      
                      Navigator.pop(ctx);
                      LoadingOverlay.show(context);
                      try {
                        await _db.updateUser(uid, {
                          'username': nameC.text.trim().toLowerCase(),
                          'roles': [selectedRole],
                          'branchId': assignedBranchId,
                          'permissions': finalPerms,
                        });
                        if (mounted) LoadingOverlay.hide(context);
                        if (mounted) rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(content: Text('Account updated!'), backgroundColor: AppColors.success));
                      } catch (e) {
                        if (mounted) LoadingOverlay.hide(context);
                        if (mounted) rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
                      }
                    },
                    child: const Text("Save Changes"),
                  ),
                ],
              )),
    );
  }

  void _confirmDeleteUser(String uid, String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger),
          SizedBox(width: 8),
          Text("Confirm Delete")
        ]),
        content: Text(
            "Permanently delete account '$username'? This cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              LoadingOverlay.show(context);
              try {
                await _db.delete('users', uid);
                if (mounted)
                  rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                      content: Text("'$username' deleted."),
                      backgroundColor: AppColors.success));
              } catch (e) {
                if (mounted)
                  rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                      content: Text('Delete error: $e'),
                      backgroundColor: AppColors.danger));
              } finally {
                if (mounted) LoadingOverlay.hide(context);
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildManageBranchesTab(AppUser user) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          floating: true,
          pinned: false,
          snap: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          expandedHeight: 80,
          toolbarHeight: 64,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              child: Row(
                children: [
                   const Spacer(),
                   ElevatedButton.icon(
                    onPressed: () => _showAddBranchDialog(user.shopId),
                    icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                    label: const Text("New Branch", style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _db.watchBranches(user.shopId).toMainThread(),
          builder: (c, snap) {
            if (!snap.hasData) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
            final branches = snap.data!;
            if (branches.isEmpty) return const SliverFillRemaining(child: Center(child: Text("No branches configured.")));
            
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (c, i) {
                    final b = branches[i];
                    final name = (b['name'] ?? 'Untitled Branch').toString().toTitleCase();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                         color: Theme.of(context).colorScheme.surface,
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(color: AppColors.border.withOpacity(0.5)),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.secondary,
                          child: Icon(Icons.storefront_rounded, size: 20, color: Colors.white),
                        ),
                        title: Row(
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                             const SizedBox.shrink(),
                          ],
                        ),
                        subtitle: Text("Operations active", style: TextStyle(fontSize: 11, color: Colors.green.shade600, fontWeight: FontWeight.bold)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _showEditBranchDialog(b['id'], b),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                              onPressed: () => _confirmDeleteBranch(b['id'], b['name'] ?? ''),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: branches.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAddBranchDialog(String shopId) {
     final nameC = TextEditingController();
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text("Create New Branch"),
         content: TextField(
           controller: nameC,
           decoration: const InputDecoration(labelText: "Branch Name"),
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
           ElevatedButton(
             onPressed: () async {
               if (nameC.text.isEmpty) return;
               await _db.saveBranch({
                 'id': nameC.text.toLowerCase().replaceAll(' ', '_'),
                 'shopId': shopId,
                 'name': nameC.text.trim(),
               });
               if (ctx.mounted) Navigator.pop(ctx);
             },
             child: const Text("Create"),
           )
         ],
       ),
     );
  }

  void _confirmDeleteBranch(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Branch?"),
        content: Text("Proceed with deleting branch '$name'? Warning: Items assigned to this branch may become orphaned."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await _db.delete('branches', id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Delete"),
          )
        ],
      ),
    );
  }

  void _showEditBranchDialog(String id, Map<String, dynamic> b) {
    final nameC = TextEditingController(text: (b['name'] ?? '').toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Branch"),
        content: TextField(
          controller: nameC,
          decoration: const InputDecoration(labelText: "Branch Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.isEmpty) return;
              await _db.saveBranch({
                'id': id,
                'shopId': b['shopId'],
                'name': nameC.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  void _showCreateUserDialog(AppUser adminUser) {
    final nameC = TextEditingController();
    final emailC = TextEditingController();
    final passC = TextEditingController();
    String selectedRole = 'inventoryStaff';
    String? assignedBranchId = adminUser.branchId;
    String branchAccessType = 'single'; // 'single', 'multiple', 'all'
    Map<String, bool> userPerms = {};
    Map<String, bool> checkedBranches = {};

    void updatePermsForRole(String role, Map<String, bool> targetMap) {
      targetMap.clear();
      for (var p in AppUser.allPermissions) {
        targetMap[p] = false;
      }
      if (role == 'admin') {
        for (var p in AppUser.allPermissions) targetMap[p] = true;
      } else if (role == 'manager') {
        targetMap[AppUser.pManageInventory] = true;
        targetMap[AppUser.pManageSales] = true;
        targetMap[AppUser.pManagePurchases] = true;
        targetMap[AppUser.pManageCustomers] = true;
        targetMap[AppUser.pManageStockTransfers] = true;
        targetMap[AppUser.pViewReports] = true;
        targetMap[AppUser.pViewFinancialData] = true;
        targetMap[AppUser.pManageSettings] = true;
        targetMap[AppUser.pManageBranches] = true;
        targetMap[AppUser.pViewNotifications] = true;
      } else if (role == 'cashier') {
        targetMap[AppUser.pManageSales] = true;
        targetMap[AppUser.pManageCustomers] = true;
      } else if (role == 'inventoryStaff') {
        targetMap[AppUser.pManageInventory] = true;
        targetMap[AppUser.pManageStockTransfers] = true;
      }
    }

    updatePermsForRole(selectedRole, userPerms);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.surface,
                title: const Text("Add New Staff Account"),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                            controller: nameC,
                            decoration: const InputDecoration(
                                labelText: "Username*",
                                prefixIcon: Icon(Icons.person))),
                        const SizedBox(height: 12),
                        TextField(
                            controller: emailC,
                            decoration: const InputDecoration(
                                labelText: "Email Address*", prefixIcon: Icon(Icons.email))),
                        const SizedBox(height: 12),
                        TextField(
                            controller: passC,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: "Password*",
                                prefixIcon: Icon(Icons.lock))),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(labelText: "Primary Role"),
                          items: const [
                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
                            DropdownMenuItem(value: 'manager', child: Text('Manager')),
                            DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                            DropdownMenuItem(value: 'inventoryStaff', child: Text('Inventory Staff')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setS(() {
                                selectedRole = v;
                                updatePermsForRole(selectedRole, userPerms);
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _db.watchBranches(adminUser.shopId).toMainThread(),
                          builder: (c, snap) {
                            final branches = (snap.data ?? []).where((element) => element['id'] != 'all').toList();
                            if (branches.isEmpty) {
                              branches.add({'id': 'main', 'name': 'Main Branch'});
                            }
                            
                            // Initialize checked branches if not yet
                            for (var b in branches) {
                              checkedBranches.putIfAbsent(b['id'].toString(), () => false);
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  value: branchAccessType,
                                  decoration: const InputDecoration(labelText: "Branch Access Scope"),
                                  items: const [
                                    DropdownMenuItem(value: 'single', child: Text('Single Branch')),
                                    DropdownMenuItem(value: 'multiple', child: Text('Multiple Branches')),
                                    DropdownMenuItem(value: 'all', child: Text('All Branches')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setS(() {
                                        branchAccessType = v;
                                        if (v == 'all') {
                                          assignedBranchId = 'main';
                                        }
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                if (branchAccessType == 'single') ...[
                                  DropdownButtonFormField<String>(
                                    value: branches.any((b) => b['id'] == assignedBranchId) ? assignedBranchId : branches.first['id'].toString(),
                                    decoration: const InputDecoration(labelText: "Select Primary Branch"),
                                    items: branches.map((b) => DropdownMenuItem(
                                      value: b['id'].toString(),
                                      child: Text(b['name']),
                                    )).toList(),
                                    onChanged: (v) => setS(() => assignedBranchId = v),
                                  ),
                                ] else if (branchAccessType == 'multiple') ...[
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text("Select Assigned Branches:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 120),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: branches.map((b) {
                                        final bId = b['id'].toString();
                                        return CheckboxListTile(
                                          title: Text(b['name'], style: const TextStyle(fontSize: 12)),
                                          value: checkedBranches[bId] ?? false,
                                          dense: true,
                                          onChanged: (v) {
                                            setS(() {
                                              checkedBranches[bId] = v ?? false;
                                              if (v == true && (assignedBranchId == null || assignedBranchId == 'all')) {
                                                assignedBranchId = bId;
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ] else ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text("User will have access to all branches.", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
                                  ),
                                ],
                              ],
                            );
                          }
                        ),
                        
                        const Divider(height: 32),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Granular Permissions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary)),
                        ),
                        const SizedBox(height: 12),
                        Container(
                           decoration: BoxDecoration(
                             border: Border.all(color: AppColors.border),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Column(
                            children: AppUser.permissionGroups.entries.expand((entry) => [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary)),
                              ),
                              ...entry.value.map((p) => CheckboxListTile(
                                title: Text(p, style: const TextStyle(fontSize: 12)),
                                value: userPerms[p] ?? false,
                                onChanged: (v) => setS(() => userPerms[p] = v ?? false),
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                              )),
                              const Divider(height: 1),
                            ]).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel")),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameC.text.isEmpty ||
                          emailC.text.isEmpty ||
                          passC.text.isEmpty) {
                         rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
                         return;
                      }

                      // ── Duplicate username guard ─────────────────────────────
                      final usernameTaken = await _db.isUsernameTaken(nameC.text.trim());
                      if (usernameTaken) {
                        rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                          content: Text('Username "${nameC.text.trim()}" is already taken. Please choose a different username.'),
                          backgroundColor: AppColors.warning,
                          duration: const Duration(milliseconds: 2500),
                        ));
                        return;
                      }

                      final Map<String, bool> finalPerms = { ...userPerms };
                      if (branchAccessType == 'all') {
                        finalPerms['branch_access_all'] = true;
                      } else if (branchAccessType == 'multiple') {
                        finalPerms['branch_access_all'] = false;
                        checkedBranches.forEach((bId, value) {
                          finalPerms['branch_access_$bId'] = value;
                        });
                        if (assignedBranchId != null) {
                          finalPerms['branch_access_$assignedBranchId'] = true;
                        }
                      } else {
                        finalPerms['branch_access_all'] = false;
                        if (assignedBranchId != null) {
                          finalPerms['branch_access_$assignedBranchId'] = true;
                        }
                      }

                      // Validation: Manage Stock Transfers requires multi-branch access
                      final hasTransfer = finalPerms[AppUser.pManageStockTransfers] == true;
                      final isSingleBranch = branchAccessType == 'single';
                      if (hasTransfer && isSingleBranch) {
                        rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                          content: const Text('⚠️ "Manage Stock Transfers" requires access to multiple branches. Please change the branch scope or remove the transfer permission.'),
                          backgroundColor: AppColors.warning,
                          duration: const Duration(milliseconds: 2500),
                        ));
                        return;
                      }
                      
                      Navigator.pop(ctx);
                      LoadingOverlay.show(context);
                      try {
                        await Provider.of<AuthService>(context, listen: false).createStaffAccount(
                          email: emailC.text.trim(),
                          password: passC.text,
                          username: nameC.text.trim(),
                          fullName: nameC.text.trim(),
                          shopId: adminUser.shopId,
                          branchId: assignedBranchId ?? 'main',
                          branchName: 'Assigned Branch',
                          role: selectedRole,
                          permissions: finalPerms,
                        );
                        if (mounted)
                          rootScaffoldMessengerKey.currentState!.showSnackBar(
                              const SnackBar(
                                  content: Text('Staff account created successfully!'),
                                  backgroundColor: AppColors.success));
                      } catch (e) {
                        if (mounted)
                          rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                              content: Text('Failed to create account: $e'),
                              backgroundColor: AppColors.danger));
                      } finally {
                        if (mounted) LoadingOverlay.hide(context);
                      }
                    },
                    child: const Text("Create Account"),
                  ),
                ],
              )),
    );
  }

  Widget _buildInventoryTab(AppUser user) {
    return ExcludeSemantics(
      child: _InventoryTabView(
        user: user,
        db: _db,
        branchId: _selectedBranchId,
        onAddItem: (data, id) {
          if (data != null) _handleEditProduct(user, data);
        },
        onAddItemNew: () => _showAddItemDialog(user),
        onRestock: (prefill) => _showQuickRestockDialog(user, prefill),
        onDelete: (id, name) => _handleDeleteProduct(user, id, name),
        onImport: () => _handleImport(user),
        onRestockSearch: () => _showGlobalRestockSearchDialog(user, isForPurchase: false),
        onScanSearch: _launchScanner,
        onTransfer: () => _showTransferStockDialog(user),
        currencyFormat: _currencyFormat,
      ),
    );
  }







  Widget _buildInventoryFloatingButtons(AppUser user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
        border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddItemDialog(user),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text("New Product"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showGlobalRestockSearchDialog(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_to_photos_rounded, size: 20),
                  label: const Text("Restock"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleImport(user),
                  icon: const Icon(Icons.file_upload_outlined, size: 20),
                  label: const Text("Bulk Import"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTab(AppUser user) {
    if (_selectedBranchId == 'all') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline_rounded, size: 64, color: AppColors.info),
            const SizedBox(height: 16),
            const Text(
              "POS is disabled while All Branches is selected.\nPlease select a branch to continue.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _posBarcodeC,
                  onChanged: (v) => _handlePOSSearch(v, user),
                  decoration: InputDecoration(
                    hintText: 'Search product or scan barcode...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_posBarcodeC.text.isNotEmpty)
                          IconButton(
                              icon: const Icon(Icons.clear), 
                              onPressed: () { _posBarcodeC.clear(); _handlePOSSearch('', user); }),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.secondary),
                          onPressed: () => _launchScanner(_posBarcodeC),
                        ),
                      ],
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _db.watchProducts(user.shopId, branchId: _selectedBranchId == 'all' ? null : _selectedBranchId).toMainThread(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Stream Error: ${snapshot.error}"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final _posNow = DateTime.now();
              final items = snapshot.data!.where((d) {
                final m = d;
                final name = (m['name']?.toString().toLowerCase() ?? '');
                final barcode = (m['barcode']?.toString().toLowerCase() ?? '');
                final qty = (m['quantity'] ?? 0);
                // Block expired products — expired stock must not be sellable
                final ed = m['expiry'] ?? m['exp'] ?? m['expiryDate'];
                if (ed != null) {
                  final expDt = parseDT(ed);
                  if (expDt != null && expDt.isBefore(_posNow)) return false;
                }
                return (name.contains(_searchQuery) || barcode.contains(_searchQuery)) && qty > 0;
              }).toList();
              
              if (items.isEmpty) return const Center(child: Text('No products found.'));
              
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final d = items[i];
                  final qty = d['quantity'] ?? 0;
                  final isLow = qty <= (d['lowStockThreshold'] ?? 5);

                  Widget? expiryBadge;
                  final ed = d['expiry'] ?? d['exp'] ?? d['expiryDate'];
                  if (ed != null) {
                    final expiry = parseDT(ed);
                    if (expiry != null) {
                      final days = expiry.difference(DateTime.now()).inDays;
                      if (days < 0) {
                        expiryBadge = PastelBadge(label: 'EXP: ${days.abs()}d ago', baseColor: AppColors.danger);
                      } else if (days < 7) {
                        expiryBadge = PastelBadge(label: 'EXP: ${days}d left', baseColor: AppColors.danger);
                      } else if (days < 30) {
                        expiryBadge = PastelBadge(label: 'EXP: ${days}d left', baseColor: Colors.orange);
                      }
                    }
                  }

                  return Container(
                    padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((d['name'] ?? '').toString().toTitleCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(_currencyFormat.format(d['sellingPrice'] ?? 0),
                              style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 13)),
                          const Spacer(),
                          // Stock + expiry badges
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              PastelBadge(label: '$qty', baseColor: isLow ? AppColors.danger : AppColors.success),
                              if (expiryBadge != null) expiryBadge,
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Full-width button row — both buttons share the card width
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  label: const Text("Add", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                                  onPressed: (qty > 0) ? () => _handleAddToCart(d) : null,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    foregroundColor: AppColors.secondary,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: TextButton.icon(
                                  label: const Text("Sell", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  icon: const Icon(Icons.sell_outlined, size: 14),
                                  onPressed: (qty > 0) ? () => _handleAddToCart(d, isQuickSell: true) : null,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    foregroundColor: AppColors.success,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
              );
            },
          ),
        ),
        _buildCheckoutBar(),
      ],
    );
  }

  Widget _buildCheckoutBar() {
    if (_posCart.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border:
            const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _showCartOverlay,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            shadowColor: AppColors.secondary.withOpacity(0.4),
            elevation: 8,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_cart_checkout_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text("View Cart (${_posCart.length})",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white)),
                ],
              ),
              Text(_currencyFormat.format(_cartTotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCartOverlay() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          children: [
            Row(children: [
              const Text("Your Cart",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                  onPressed: () {
                    _clearCart();
                    Navigator.pop(ctx);
                  },
                  child: const Text("Clear All",
                      style: TextStyle(color: AppColors.danger))),
            ]),
            const Divider(height: 32),
            Expanded(
                child: ListView.builder(
              itemCount: _posCart.length,
              itemBuilder: (c, i) => ListTile(
                title: Text(_posCart[i].name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    "${_posCart[i].quantity} x ${_currencyFormat.format(_posCart[i].price)}"),
                trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.danger),
                    onPressed: () {
                      setState(() {
                        if (_posCart[i].quantity > 1) {
                          _posCart[i].quantity--;
                        } else {
                          _posCart.removeAt(i);
                        }
                        _calculateTotal();
                      });
                      if (_posCart.isEmpty) Navigator.pop(ctx);
                    }),
              ),
            )),
            const SizedBox(height: 24),
            SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleBulkCheckout();
                    },
                    child: Text(
                        "Checkout (${_currencyFormat.format(_cartTotal)})"))),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBulkCheckout() async {
    if (_posCart.isEmpty) return;
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) return;

    final customerC = TextEditingController();
    final advancedC = TextEditingController(text: '0');
    bool isDebt = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Process Transaction"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Total Amount: ${_currencyFormat.format(_cartTotal)}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.secondary)),
              const SizedBox(height: 16),
              TextField(
                  controller: customerC,
                  decoration: const InputDecoration(
                      labelText: "Customer Name (Optional)")),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setDialogState(() => isDebt = false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor:
                            !isDebt ? AppColors.secondary : Colors.transparent,
                        foregroundColor:
                            !isDebt ? Colors.white : AppColors.secondary,
                        side: const BorderSide(color: AppColors.secondary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Cash"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setDialogState(() => isDebt = true),
                      style: OutlinedButton.styleFrom(
                        backgroundColor:
                            isDebt ? AppColors.secondary : Colors.transparent,
                        foregroundColor:
                            isDebt ? Colors.white : AppColors.secondary,
                        side: const BorderSide(color: AppColors.secondary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Debt"),
                    ),
                  ),
                ],
              ),
              /* Advanced payment removed for simplification */
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel")),
            ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final groupId =
                      "TRX-${DateTime.now().millisecondsSinceEpoch}";

                  try {
                    for (var item in _posCart) {
                      final itemTotal = item.total;
                      double debtAmt = 0;
                      double paidAmt = itemTotal;

                      if (isDebt) {
                        paidAmt = 0.0;
                        debtAmt = itemTotal;
                      }

                      await _repo.recordSale(user, {
                        'shopId': user.shopId,
                        'branchId': item.branchId ?? user.branchId,
                        'userId': user.id,
                        'username': user.username,
                        'itemId': item.id,
                        'itemName': item.name,
                        'quantity': item.quantity,
                        'totalPrice': itemTotal,
                        'isDebt': isDebt,
                        'debtRemaining': debtAmt,
                        'amountPaid': paidAmt, // unified name
                        'customerName': customerC.text,
                        'profit':
                            (item.price - (item.cost ?? 0)) * item.quantity,
                        'saleGroupId': groupId,
                      });
                    }
                    _clearCart();
                    if (context.mounted) Navigator.pop(context);
                    rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('Sale processed successfully!')));
                  } catch (e) {
                    rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                        backgroundColor: AppColors.danger,
                        content: Text(e.toString())));
                  }
                },
                child: const Text("Confirm Sale")),
          ],
        ),
      ),
    );
  }

  void _showAdminSellDialog(Map<String, dynamic> doc, AppUser user) {
    final d = doc;
    final qtyC = TextEditingController(text: '1');
    final buyerC = TextEditingController();
    String paymentType = 'Cash';
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Checkout: ${d['name']}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyC,
                textAlign: TextAlign.start,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Enter Quantity",
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.add_shopping_cart_rounded, size: 20),
                ),
                onChanged: (v) => setS(() {}),
              ),
              Text("Available: ${d['quantity']}", style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                  controller: buyerC,
                  decoration: const InputDecoration(
                      labelText: 'Customer Name (optional)')),
              const SizedBox(height: 16),
              Row(
                  children: ['Cash', 'Debt']
                      .map((t) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: OutlinedButton(
                                onPressed: () => setS(() => paymentType = t),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: paymentType == t
                                      ? AppColors.secondary
                                      : Colors.transparent,
                                  foregroundColor:
                                      paymentType == t ? Colors.white : null,
                                ),
                                child: Text(t),
                              ),
                            ),
                          ))
                      .toList()),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                FocusScope.of(context).unfocus();
                if (!c.mounted) return;
                try {
                  final qtyRequested = double.tryParse(qtyC.text) ?? 1.0;
                  
                  // FETCH CORRECT BATCH-SPECIFIC PRICE (FEFO)
                  final batches = await _db.watchBatchesByItem(user.shopId, doc['id'], branchId: d['branchId']?.toString() ?? user.branchId).first;
                  final active = batches.where((b) {
                    final qty = (b['quantity'] ?? 0.0).toDouble();
                    final exp = parseDT(b['expiry'] ?? b['exp'] ?? b['expiryDate']);
                    final isExpired = exp != null && exp.isBefore(DateTime.now());
                    return qty > 0 && !isExpired;
                  }).toList();
                  
                  active.sort((a, b) {
                     final da = parseDT(a['expiry'] ?? a['exp'] ?? a['expiryDate']) ?? DateTime(2100);
                     final db = parseDT(b['expiry'] ?? b['exp'] ?? b['expiryDate']) ?? DateTime(2100);
                     return da.compareTo(db);
                  });

                  // We use the price from the earliest batch as the default charge
                  final firstBatch = active.isNotEmpty ? active.first : null;
                  final sell = (firstBatch?['sellingPrice'] as num?)?.toDouble() ?? (d['sellingPrice'] as num?)?.toDouble() ?? 0.0;
                  final buy = (firstBatch?['buyingPrice'] as num?)?.toDouble() ?? (d['buyingPrice'] as num?)?.toDouble() ?? 0.0;

                  // Optimistic/Instant local-first save via repo
                  _repo.recordSale(user, {
                    'shopId': user.shopId,
                    'branchId': d['branchId']?.toString() ?? user.branchId,
                    'userId': user.id,
                    'username': user.username,
                    'itemId': doc['id'],
                    'itemName': d['name'],
                    'quantity': qtyRequested,
                    'sellingPrice': sell,
                    'totalPrice': sell * qtyRequested,
                    'profit': (sell - buy) * qtyRequested,
                    'customerName': buyerC.text,
                    'isDebt': paymentType == 'Debt',
                    'debtRemaining': paymentType == 'Debt' ? (sell * qtyRequested) : 0.0,
                    'advancedPaid': 0.0,
                    'saleGroupId': "TRX-${DateTime.now().millisecondsSinceEpoch}",
                  }).catchError(
                      (e) => debugPrint('Sale sync (background): $e'));

                  if (c.mounted) {
                    Navigator.pop(c);
                    rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(
                        content: Text(
                            'Sale Recorded Instantly! Synching in background...'),
                        backgroundColor: AppColors.success));
                  }
                } catch (e) {
                  if (c.mounted)
                    rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.danger));
                }
              },
              child: const Text('Confirm Sale'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierTab(AppUser user) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          floating: true,
          pinned: false,
          snap: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          expandedHeight: 120,
          toolbarHeight: 64,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchPurchasesC,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: "Search items...",
                            prefixIcon: const Icon(Icons.search_rounded, size: 16),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            fillColor: Theme.of(context).colorScheme.surface,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showGlobalRestockSearchDialog(user, isForPurchase: true),
                            icon: const Icon(Icons.add_to_photos_rounded, size: 16),
                            label: const Text('Restock', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.info,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _showAdminPurchaseDialog(user),
                            icon: const Icon(Icons.receipt_rounded, size: 16),
                            label: const Text('Add Purchase', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _db.watchPurchases(user.shopId, branchId: _selectedBranchId).toMainThread(),
          builder: (context, snap) {
            if (!snap.hasData) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
            final allPurchases = snap.data!;
            var docs = allPurchases.where((m) {
              if (_searchPurchasesC.text.isNotEmpty) {
                final q = _searchPurchasesC.text.toLowerCase();
                return (m['itemName'] ?? '').toString().toLowerCase().contains(q) ||
                    (m['barcode'] ?? '').toString().toLowerCase().contains(q);
              }
              return true;
            }).toList();

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final d = docs[i];
                    final ts = parseDT(d['timestamp']);
                    final itemName = (d['itemName'] ?? 'Unknown').toString().toTitleCase();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border.withOpacity(0.5)),
                      ),
                      child: ListTile(
                        onTap: () => _showPurchaseDetailDialog(d),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: AppColors.info.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.inventory_2_rounded,
                              color: AppColors.info, size: 20),
                        ),
                        title: Row(
                          children: [
                            Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const Spacer(),
                             const SizedBox.shrink(),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text("${d['supplierName'] ?? 'No Supplier'} • ${ts != null ? DateFormat('MMM d, y • HH:mm').format(ts) : '-'}", style: const TextStyle(fontSize: 11)),
                            if (_selectedBranchId == 'all')
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text("Branch: ${d['branchId']?.toString().toUpperCase() ?? 'WAREHOUSE'}",
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_currencyFormat.format(d['totalCost'] ?? 0),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary)),
                            Text("${d['quantity']} units",
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: docs.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showEditPurchaseDialog(AppUser user, Map<String, dynamic> d) {
    final supplierC = TextEditingController(text: d['supplierName'] ?? '');
    final priceC = TextEditingController(text: (d['unitCost'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Purchase Log Entry"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Item: ${d['itemName']}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: supplierC,
              decoration: const InputDecoration(labelText: "Supplier Name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Unit Cost (ETB)"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newPrice = double.tryParse(priceC.text) ?? 0;
              final qty = (d['quantity'] ?? 0).toDouble();
              await _repo.updatePurchase(user, d['id'], {
                'supplierName': supplierC.text.trim(),
                'unitCost': newPrice,
                'totalCost': newPrice * qty,
              });
              if (ctx.mounted) {
                Navigator.pop(ctx);
                rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(
                    content: Text("Purchase log updated!"),
                    backgroundColor: AppColors.success));
              }
            },
            child: const Text("Save Changes"),
          ),
        ],
      ),
    );
  }

    void _showQuickRestockDialog(AppUser user, Map<String, dynamic> product) {
    final qtyC = TextEditingController();
    final costC = TextEditingController(text: (product['buyingPrice'] ?? '').toString());
    final sellC = TextEditingController(text: (product['sellingPrice'] ?? '').toString());
    final thresholdC = TextEditingController(text: (product['lowStockThreshold'] ?? 5).toString());
    final batchC = TextEditingController();
    DateTime? expiry = parseDT(product['expiry'] ?? product['exp']);
    // Branch is ALWAYS inherited from the product — never changeable during restock.
    final String productBranchId = product['branchId']?.toString() ?? user.branchId ?? 'main';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text("Restock: ${product['name']}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Current Stock: ${product['quantity'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: qtyC,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: "Quantity to Add*", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: costC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Buying Cost", border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: sellC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Selling Price", border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(expiry == null ? "Set Expiry" : "Expires: ${DateFormat('dd MMM yyyy').format(expiry!)}"),
                  leading: const Icon(Icons.event_note_rounded),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: expiry ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2040));
                    if (d != null) setS(() => expiry = d);
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: thresholdC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Low Stock Alert Threshold", border: OutlineInputBorder())),
                const SizedBox(height: 12),
                // Branch is locked to the product's branch — cannot be changed during restock.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 20, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(productBranchId.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600))),
                      const Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(qtyC.text) ?? 0;
                if (qty <= 0) {
                  rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(content: Text("Please enter a valid quantity")));
                  return;
                }
                try {
                  LoadingOverlay.show(context);
                  await _repo.recordRestock(user, {
                    'itemId': product['id'],
                    'itemName': product['name'],
                    'addedQuantity': qty,
                    'buyingPrice': double.tryParse(costC.text) ?? 0.0,
                    'sellingPrice': double.tryParse(sellC.text) ?? 0.0,
                    'lowStockThreshold': int.tryParse(thresholdC.text) ?? 5,
                    'expiry': expiry,
                    'batchNumber': batchC.text.trim(),
                    'branchId': productBranchId, // always use product's own branch
                  });
                  if (mounted) {
                     Navigator.pop(ctx);
                     rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(content: Text("Stock Updated Successfully!"), backgroundColor: AppColors.success));
                  }
                } catch (e) {
                  rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                } finally {
                  if (mounted) LoadingOverlay.hide(context);
                }
              },
              child: const Text("Update Stock"),
            ),
          ],
        ),
      ),
    );
  }

  void _showGlobalRestockSearchDialog(AppUser user, {bool isForPurchase = false}) {
    final searchC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: const Text("Restock: Search Inventory"),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchC,
                  autofocus: true,
                  onChanged: (_) => setS(() {}),
                  decoration: InputDecoration(
                    hintText: "Enter Name or Scan Barcode...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () => _launchScanner(searchC).then((_) => setS(() {}))),
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    // Filter to only branches accessible by this user
                    stream: _db.watchProducts(
                      user.shopId,
                      branchId: null, // Watch all branches, then filter in memory
                    ).toMainThread(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const LinearProgressIndicator();
                      final q = searchC.text.toLowerCase();
                      // Deduplicate by id+branchId so each branch-product appears once
                      final seen = <String>{};
                      final items = snap.data!.where((doc) {
                        final docBranchId = doc['branchId']?.toString() ?? 'main';
                        if (!user.hasBranchAccess(docBranchId)) return false;

                        final key = '${doc['id']}@$docBranchId';
                        if (!seen.add(key)) return false;
                        final name = (doc['name'] ?? '').toString().toLowerCase();
                        final bar = (doc['barcode'] ?? '').toString().toLowerCase();
                        return (name.contains(q) || bar.contains(q)) && q.isNotEmpty;
                      }).toList();

                      if (items.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(q.isEmpty ? "Type to search..." : "No matches found"),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (ctx, i) {
                          final doc = items[i];
                          final d = doc;
                          final branchLabel = (d['branchId'] ?? 'main').toString().toUpperCase();
                          return ListTile(
                            title: Text(d['name'] ?? ''),
                            subtitle: Text("Stock: ${d['quantity']} | Branch: $branchLabel | ${d['barcode'] ?? '-'}"),
                            trailing: const Icon(Icons.add_circle_outline, color: AppColors.info),
                            onTap: () {
                                Navigator.pop(ctx);
                                final prefill = Map<String, dynamic>.from(d);
                                prefill['id'] = doc['id'];
                                if (isForPurchase) {
                                  _showAdminPurchaseDialog(user, prefillProduct: prefill, forceShowSupplier: true);
                                } else {
                                  _showQuickRestockDialog(user, prefill);
                                }
                              },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ],
        ),
      ),
    );
  }

  void _showAdminPurchaseDialog(AppUser user,
      {Map<String, dynamic>? prefillProduct, bool forceShowSupplier = false}) {
    final bool isRestock = prefillProduct != null;
    final bool showSupplierField = !isRestock || forceShowSupplier;
    final nameC = TextEditingController(text: prefillProduct?['name'] ?? '');
    final bPrice = (prefillProduct?['buyingPrice'] ?? 0).toDouble();
    final costC = TextEditingController(text: bPrice > 0 ? bPrice.toString() : '');
    final qtyC = TextEditingController();
    final supplierC = TextEditingController();
    final barC = TextEditingController(text: prefillProduct?['barcode'] ?? '');
    final batchC = TextEditingController();
    final sPrice = (prefillProduct?['sellingPrice'] ?? 0).toDouble();
    final sellC = TextEditingController(text: sPrice > 0 ? sPrice.toString() : '');
    final thresholdC = TextEditingController(text: '5');
    DateTime? expiry = parseDT(prefillProduct?['expiryDate']);
    String selectedBranchId = prefillProduct?['branchId']?.toString() ?? 
        (_selectedBranchId != 'all' ? _selectedBranchId : user.branchId);
    bool createAsNew = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.surface,
                title: const Text('Inventory Intake / Purchase'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showSupplierField) ...[
                        TextField(
                            controller: supplierC,
                            decoration: const InputDecoration(
                                labelText: 'Supplier Name*',
                                prefixIcon: Icon(Icons.business_rounded))),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                          controller: nameC,
                          enabled: !isRestock, // Identity locked on direct restock
                          decoration: const InputDecoration(
                              labelText: 'Product Name*',
                              prefixIcon: Icon(Icons.inventory_2_outlined))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: barC,
                          enabled: !isRestock,
                          decoration: InputDecoration(
                            labelText: 'Barcode (Optional)',
                            prefixIcon: const Icon(Icons.barcode_reader),
                            suffixIcon: IconButton(
                                icon: const Icon(Icons.camera_alt_outlined),
                                onPressed: () => _launchScanner(barC)),
                          )),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: TextField(
                                  controller: qtyC,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Qty*'))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: TextField(
                                  controller: costC,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Buying Cost*'))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: TextField(
                                  controller: sellC,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Selling Price*'))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        title: Text(expiry == null
                            ? "Set Expiry (Optional)"
                            : "Expires: ${DateFormat('dd MMM yyyy').format(expiry!)}"),
                        leading: const Icon(Icons.event_note_rounded),
                        onTap: () async {
                          final d = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2040));
                          if (d != null) {
                            setS(() => expiry = d);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                          controller: thresholdC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Low Stock Alert Threshold',
                              hintText: 'e.g. 5',
                              prefixIcon: Icon(Icons.notifications_active_outlined))),
                      const SizedBox(height: 16),
                      // ── Branch Selector ─────────────────────────────────
                      if (isRestock)
                        // Branch is locked to the product's branch during restock.
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.storefront_rounded, size: 20, color: AppColors.secondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedBranchId.toUpperCase(),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                            ],
                          ),
                        )
                      else
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _db.watchBranches(user.shopId).toMainThread(),
                          builder: (c, snap) {
                            final branches = snap.data ?? [];
                            if (branches.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Assign to Branch*", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: branches.any((b) => b['id'] == selectedBranchId) ? selectedBranchId : branches.first['id'],
                                      isExpanded: true,
                                      items: branches.map((b) => DropdownMenuItem(
                                        value: b['id'] as String,
                                        child: Text(b['name'] as String),
                                      )).toList(),
                                      onChanged: (v) {
                                        if (v != null) setS(() => selectedBranchId = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameC.text.isEmpty ||
                          (showSupplierField && supplierC.text.isEmpty) ||
                          qtyC.text.isEmpty ||
                          costC.text.isEmpty) {
                        rootScaffoldMessengerKey.currentState!.showSnackBar(
                            const SnackBar(
                                content: Text("Fill all required fields (*)")));
                        return;
                      }

                      final purchaseMap = {
                        'shopId': user.shopId,
                        'branchId': selectedBranchId,
                        'userId': user.id,
                        'username': user.username,
                        'supplierName': supplierC.text.trim(),
                        'itemId': isRestock ? prefillProduct['id'] : null, 
                        'itemName': nameC.text.trim(),
                        'barcode': barC.text.trim(),
                        'quantity': double.tryParse(qtyC.text.trim()) ?? 0,
                        'unitCost': double.tryParse(costC.text.trim()) ?? 0,
                        'sellingPrice': double.tryParse(sellC.text.trim()) ?? 0,
                        'lowStockThreshold': int.tryParse(thresholdC.text.trim()) ?? 5,
                        'totalCost': (double.tryParse(qtyC.text) ?? 0) * (double.tryParse(costC.text) ?? 0),
                        'expiry': expiry,
                      };

                      // Duplicate Check Flow
                      if (!isRestock) {
                         final isDup = await _checkDuplicateBranchItem(user.shopId, selectedBranchId, nameC.text, barC.text);
                         if (isDup) {
                            final choice = await _showDuplicateChoiceDialog(nameC.text);
                            if (choice == null) return; // User cancelled
                            createAsNew = (choice == "new");
                         }
                      }

                      try {
                        LoadingOverlay.show(context);
                        await _repo.recordPurchase(user, purchaseMap, forceNew: createAsNew);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          setState(() {}); 
                          rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(content: Text('Purchase recorded successfully!'), backgroundColor: AppColors.success));
                        }
                      } catch (e) {
                        if (ctx.mounted) rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                      } finally {
                        if (ctx.mounted) LoadingOverlay.hide(context);
                      }
                    },
                    child: const Text('Commit purchase'),
                  ),
                ],
              )),
    );
  }

  Widget _buildReportsTab(AppUser user, List<SidebarItem> sidebarItems) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardDecor = BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border:
          isDark ? null : Border.all(color: const Color(0xFFE2E8F0), width: 1),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
    );
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.watchSales(user.shopId, branchId: _selectedBranchId == 'all' ? null : _selectedBranchId).toMainThread(),
      builder: (context, snap) {
        // Show skeleton until first sales data arrives
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _db.watchProducts(user.shopId, branchId: _selectedBranchId == 'all' ? null : _selectedBranchId).toMainThread(),
          builder: (context, invSnap) {
            // Show skeleton until first inventory data arrives
            if (!invSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allSales = snap.data ?? [];
            final allProducts = invSnap.data ?? [];

            int lowStock = 0;
            int expiringSoon = 0;
            final today = DateTime.now();
            for (var doc in allProducts) {
              final qty = (doc['quantity'] ?? 0.0) as num;
              final threshold = (doc['lowStockThreshold'] ?? 5) as num;
              if (qty <= threshold) lowStock++;

              final ed = doc['expiry'] ?? doc['exp'] ?? doc['expiryDate'];
              if (ed != null) {
                final exp = parseDT(ed);
                if (exp != null && exp.isAfter(today) && exp.difference(today).inDays <= 30) {
                  expiringSoon++;
                }
              }
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'Daily',
                            label: Text('Daily', style: TextStyle(fontSize: 11)),
                            icon: Icon(Icons.today_rounded, size: 16)),
                        ButtonSegment(
                            value: 'Weekly',
                            label: Text('Weekly', style: TextStyle(fontSize: 11)),
                            icon: Icon(Icons.date_range_rounded, size: 16)),
                        ButtonSegment(
                            value: 'Monthly',
                            label: Text('Monthly', style: TextStyle(fontSize: 11)),
                            icon: Icon(Icons.calendar_month_rounded, size: 16)),
                        ButtonSegment(
                            value: 'Custom',
                            label: Text('Custom'),
                            icon: Icon(Icons.calendar_month_rounded)),
                      ],
                      selected: {_reportFilter},
                      onSelectionChanged: (set) async {
                        if (set.first == 'Custom') {
                          final range = await showCustomDateRangePicker(
                              context: context,
                              initialStartDate: _startDate,
                              initialEndDate: _endDate,
                          );
                          if (range != null) {
                            setState(() {
                              _reportFilter = 'Custom';
                              _startDate = range.start;
                              _endDate = range.end;
                            });
                          }
                        } else {
                          _setFilter(set.first);
                        }
                      },
                    ),
                    PopupMenuButton<String>(
                      onSelected: (val) async {
                        LoadingOverlay.show(context);
                        try {
                          final allDocs = (snap.data ?? []);
                          final filtered = allDocs.where((d) {
                            final m = d;
                            final ts = parseDT(m['timestamp']);
                            if (ts == null) return false;
                            return ts.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
                                ts.isBefore(_endDate.add(const Duration(days: 1)));
                          }).toList();

                          if (filtered.isEmpty) {
                            if (mounted) {
                              rootScaffoldMessengerKey.currentState!.showSnackBar(
                                  const SnackBar(content: Text('No data for selected period.'), backgroundColor: AppColors.warning));
                            }
                            return;
                          }

                          String pathStr = "";
                          // ── Aggregate data for professional PDF & Excel Reports ──
                          double totalRev = 0, totalProf = 0, totalUnpaid = 0;
                          Map<String, double> productRevMap = {};
                          Map<String, double> productQtyMap = {};
                          Map<String, Map<String, dynamic>> dailyMap = {};

                          for (var d in filtered) {
                            final m = d;
                            final bId = m['branchId']?.toString() ?? 'main';
                            if (_selectedBranchId != 'all' && bId != _selectedBranchId) continue;
                            
                            final ts = parseDT(m['timestamp']);
                            final rev = (m['totalPrice'] ?? 0).toDouble();
                            final prof = (m['profit'] ?? 0).toDouble();
                            totalRev += rev;
                            totalProf += prof;
                            if (m['isDebt'] == true) {
                              totalUnpaid += (m['debtRemaining'] ?? m['totalPrice'] ?? 0).toDouble();
                            }
                            final name = m['itemName'] ?? 'Unknown';
                            productRevMap[name] = (productRevMap[name] ?? 0) + rev;
                            productQtyMap[name] = (productQtyMap[name] ?? 0) + (m['quantity'] ?? 0).toDouble();

                            if (ts != null) {
                              final key = DateFormat('yyyy-MM-dd').format(ts);
                              final label = DateFormat('dd MMM').format(ts);
                              dailyMap[key] ??= {'date': label, 'revenue': 0.0, 'profit': 0.0, 'orders': 0};
                              dailyMap[key]!['revenue'] = (dailyMap[key]!['revenue'] as double) + rev;
                              dailyMap[key]!['profit'] = (dailyMap[key]!['profit'] as double) + prof;
                              dailyMap[key]!['orders'] = (dailyMap[key]!['orders'] as int) + 1;
                            }
                          }

                          final sortedDays = dailyMap.entries.toList()
                            ..sort((a, b) => a.key.compareTo(b.key));

                          // Calculate total purchases inside date range
                          double totalPurch = 0;
                          try {
                            final purchRows = await _db.query('purchases', where: 'shopId = ?', whereArgs: [user.shopId]);
                            for (var r in purchRows) {
                              final bId = r['branchId']?.toString();
                              if (_selectedBranchId != 'all' && bId != _selectedBranchId) continue;
                              final ts = parseDT(r['timestamp']);
                              if (ts != null && ts.isAfter(_startDate.subtract(const Duration(seconds: 1))) && ts.isBefore(_endDate.add(const Duration(days: 1)))) {
                                totalPurch += (r['totalCost'] ?? ((r['quantity'] ?? 0) * (r['unitCost'] ?? 0)) ?? 0.0).toDouble();
                              }
                            }
                          } catch (e) {
                            debugPrint("Error fetching purchases: $e");
                          }

                          // Dynamic branch name lookup
                          String branchName = 'All Branches';
                          if (_selectedBranchId != 'all') {
                            try {
                              final branchRows = await _db.query('branches', where: 'id = ?', whereArgs: [_selectedBranchId]);
                              if (branchRows.isNotEmpty) {
                                branchName = branchRows.first['name']?.toString() ?? _selectedBranchId;
                              } else {
                                branchName = _selectedBranchId;
                              }
                            } catch (_) {
                              branchName = _selectedBranchId;
                            }
                          }

                          // Product performance with profit, unit, avgPrice, and contribution %
                          final sortedByQty = productQtyMap.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value));
                          
                          final topProducts = sortedByQty.take(10).map((e) {
                            final name = e.key;
                            final qty = e.value.toInt();
                            final rev = productRevMap[name] ?? 0.0;
                            double itemProf = 0;
                            String unitStr = '';
                            for (var sale in filtered) {
                              if (sale['itemName'] == name) {
                                itemProf += (sale['profit'] ?? 0.0).toDouble();
                                if (unitStr.isEmpty) {
                                  unitStr = sale['unit']?.toString() ?? sale['unitType']?.toString() ?? sale['packageUnit']?.toString() ?? '';
                                }
                              }
                            }
                            return {
                              'name': name,
                              'unit': unitStr,
                              'qty': qty,
                              'rev': rev,
                              'profit': itemProf,
                              'avgPrice': qty > 0 ? (rev / qty) : 0.0,
                              'contrib': totalRev > 0 ? (rev / totalRev * 100) : 0.0,
                            };
                          }).toList();

                          final leastProducts = sortedByQty.reversed.take(5).map((e) {
                            final name = e.key;
                            final qty = e.value.toInt();
                            final rev = productRevMap[name] ?? 0.0;
                            double itemProf = 0;
                            String unitStr = '';
                            for (var sale in filtered) {
                              if (sale['itemName'] == name) {
                                itemProf += (sale['profit'] ?? 0.0).toDouble();
                                if (unitStr.isEmpty) {
                                  unitStr = sale['unit']?.toString() ?? sale['unitType']?.toString() ?? sale['packageUnit']?.toString() ?? '';
                                }
                              }
                            }
                            return {
                              'name': name,
                              'unit': unitStr,
                              'qty': qty,
                              'rev': rev,
                              'profit': itemProf,
                              'avgPrice': qty > 0 ? (rev / qty) : 0.0,
                              'contrib': totalRev > 0 ? (rev / totalRev * 100) : 0.0,
                            };
                          }).toList();

                          // Itemized Inventory Alerts and counts
                          final lowStockItems = <Map<String, dynamic>>[];
                          final outOfStockItems = <Map<String, dynamic>>[];
                          final expiringSoonItems = <Map<String, dynamic>>[];
                          final expiredItems = <Map<String, dynamic>>[];

                          int lowCount = 0, outCount = 0, soonCount = 0, expiredCount = 0;
                          final now = DateTime.now();
                          for (var d in invSnap.data ?? []) {
                            final name = d['name']?.toString() ?? 'Unnamed';
                            final qty = (d['quantity'] ?? 0) as num;
                            final thresh = (d['lowStockThreshold'] ?? 5) as num;
                            final unit = d['unit']?.toString() ?? d['unitType']?.toString() ?? d['packageUnit']?.toString() ?? '';
                            final sku = d['sku']?.toString() ?? d['barcode']?.toString() ?? 'N/A';
                            final batch = d['batch']?.toString() ?? d['batchNumber']?.toString() ?? 'N/A';

                            if (qty <= 0) {
                              outCount++;
                              outOfStockItems.add({'name': name, 'unit': unit, 'sku': sku, 'batch': batch, 'qty': qty});
                            } else if (qty <= thresh) {
                              lowCount++;
                              lowStockItems.add({'name': name, 'unit': unit, 'sku': sku, 'batch': batch, 'qty': qty, 'threshold': thresh});
                            }

                            final expiry = d['expiryDate'] ?? d['expiry'] ?? d['exp'];
                            if (expiry != null) {
                              final date = (expiry is DateTime) ? expiry : DateTime.tryParse(expiry.toString());
                              if (date != null) {
                                final diff = date.difference(now).inDays;
                                if (date.isBefore(now)) {
                                  expiredCount++;
                                  expiredItems.add({
                                    'name': name,
                                    'unit': unit,
                                    'sku': sku,
                                    'batch': batch,
                                    'qty': qty,
                                    'expiryDate': DateFormat('dd MMM yyyy').format(date),
                                    'daysDiff': -diff,
                                  });
                                } else if (diff <= 30) {
                                  soonCount++;
                                  expiringSoonItems.add({
                                    'name': name,
                                    'unit': unit,
                                    'sku': sku,
                                    'batch': batch,
                                    'qty': qty,
                                    'expiryDate': DateFormat('dd MMM yyyy').format(date),
                                    'daysDiff': diff,
                                  });
                                }
                              }
                            }
                          }

                          final periodLabel = _reportFilter == 'Custom'
                              ? '${DateFormat('dd MMM yyyy').format(_startDate)} – ${DateFormat('dd MMM yyyy').format(_endDate)}'
                              : _reportFilter;
                          final shopName = await _db.getSetting('shopName') ?? 'SmartInventory ERP';
                          final shopPhone = await _db.getSetting('shopPhone') ?? '+251...';
                          final currSymbol = _appCurrencySymbol ?? user.currency ?? 'ETB';

                          final reportPayload = {
                            'revenue': totalRev,
                            'profit': totalProf,
                            'orders': filtered.length,
                            'debt': totalUnpaid,
                            'purchases': totalPurch,
                            'lowStockCount': lowCount,
                            'outStockCount': outCount,
                            'expiredCount': expiredCount,
                            'soonCount': soonCount,
                            'topProducts': topProducts,
                            'leastProducts': leastProducts,
                            'dailySales': sortedDays.map((e) => e.value).toList(),
                            'companyName': shopName,
                            'companyPhone': shopPhone,
                            'period': periodLabel,
                            'branchName': branchName,
                            'generatedBy': user.fullName.isNotEmpty ? user.fullName : user.username,
                            'currency': currSymbol,
                            'lowStockItems': lowStockItems,
                            'outOfStockItems': outOfStockItems,
                            'expiringSoonItems': expiringSoonItems,
                            'expiredItems': expiredItems,
                            'sales': filtered,
                          };

                          if (val == 'excel') {
                            pathStr = await _reporting.exportReportToExcel(
                              'Business_Report_${DateTime.now().millisecondsSinceEpoch}',
                              reportPayload,
                            );
                          } else if (val == 'pdf') {
                            pathStr = await _reporting.exportToPdf(
                              'Report_${DateTime.now().millisecondsSinceEpoch}',
                              reportPayload,
                            );
                          }

                          if (mounted) {
                            final msg = (pathStr == 'Cancelled')
                                ? 'Export cancelled.'
                                : '✅ Saved to: $pathStr';
                            rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                                content: Text(msg,
                                    style: const TextStyle(fontSize: 12)),
                                duration: const Duration(seconds: 6),
                                backgroundColor: pathStr == 'Cancelled'
                                    ? AppColors.warning
                                    : AppColors.success));
                          }
                        } catch (e) {
                          if (mounted) {
                            rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                                content: Text('Export failed: $e'),
                                backgroundColor: AppColors.danger));
                          }
                        } finally {
                          if (mounted) LoadingOverlay.hide(context);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'pdf', child: Text('Export as PDF (Snapshot)')),
                        const PopupMenuItem(value: 'excel', child: Text('Export as Excel (Data)')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download_rounded, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text("Export Report", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Summary stat cards
                Builder(builder: (context) {
                  double totalRev = 0;
                  double totalProfit = 0;
                  int txCount = 0;
                  double totalUnpaid = 0;
                    for (var doc in (snap.data ?? [])) {
                      final m = doc;
                      final bId = m['branchId']?.toString() ?? 'main';
                      if (_selectedBranchId != "all" && bId != _selectedBranchId) continue;
                      
                      final ts = parseDT(m['timestamp']);
                      if (ts != null &&
                          ts.isAfter(
                              _startDate.subtract(const Duration(seconds: 1))) &&
                          ts.isBefore(_endDate.add(const Duration(days: 1)))) {
                        
                        final rev_total = (m['totalPrice'] ?? 0).toDouble();
                        final prof_total = (m['profit'] ?? 0).toDouble();
                        final originalQty = (m['quantity'] ?? 0.0).toDouble();
                        final refundedQty = (m['refundedQuantity'] ?? 0.0).toDouble();
                        
                        double effectiveRev = rev_total;
                        double effectiveProf = prof_total;
                        
                        if (refundedQty > 0 && originalQty > 0) {
                          final unitPrice = rev_total / originalQty;
                          final unitProf = prof_total / originalQty;
                          effectiveRev -= (unitPrice * refundedQty);
                          effectiveProf -= (unitProf * refundedQty);
                        }

                        totalRev += effectiveRev;
                        totalProfit += effectiveProf;
                        
                        if (m['isDebt'] == true) {
                          final rem = (m['debtRemaining'] ?? (m['totalPrice'] ?? 0)).toDouble();
                          totalUnpaid += rem;
                        }
                        txCount++;
                      }
                    }
                    return LayoutBuilder(builder: (context, constraints) {
                    final bool isMobile = constraints.maxWidth < 650;
                    return GridView.count(
                      crossAxisCount: isMobile ? 2 : 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: isMobile ? 1.3 : 1.6,
                      children: [
                        StatCard(
                            title: 'Total Revenue',
                            value: _currencyFormat.format(totalRev),
                            color: AppColors.success,
                            icon: Icons.paid_outlined,
                            cardDecoration: cardDecor,
                            onTap: () => setState(() => _selectedIndex =
                                _getSidebarItems(user)
                                    .indexWhere((it) => it.uid == 'reports'))),
                        if (user.hasPermission(AppUser.pViewFinancialData))
                          StatCard(
                              title: 'Total Profit',
                              value: _currencyFormat.format(totalProfit),
                              color: AppColors.info,
                              icon: Icons.trending_up_rounded,
                              cardDecoration: cardDecor,
                              onTap: () => setState(() => _selectedIndex =
                                  _getSidebarItems(user)
                                      .indexWhere((it) => it.uid == 'reports'))),
                        StatCard(
                            title: 'Unpaid Customer Debt',
                            value: _currencyFormat.format(totalUnpaid),
                            color: AppColors.danger,
                            icon: Icons.money_off_rounded,
                            cardDecoration: cardDecor,
                            onTap: () => setState(() => _selectedIndex =
                                _getSidebarItems(user)
                                    .indexWhere((it) => it.uid == 'debt'))),
                        StatCard(
                            title: 'Expiring Soon',
                            value: expiringSoon.toString(),
                            color: AppColors.warning,
                            icon: Icons.event_note_rounded,
                            cardDecoration: cardDecor,
                            onTap: () => setState(() => _selectedIndex =
                                _getSidebarItems(user)
                                    .indexWhere((it) => it.uid == 'inventory'))),
                        StatCard(
                            title: 'Transactions',
                            value: txCount.toString(),
                            color: AppColors.secondary,
                            icon: Icons.receipt_long_rounded,
                            cardDecoration: cardDecor),
                        StatCard(
                            title: 'Low Stock',
                            value: '$lowStock',
                            color: AppColors.warning,
                            icon: Icons.warning_amber_rounded,
                            cardDecoration: cardDecor,
                            onTap: () => setState(() => _selectedIndex =
                                _getSidebarItems(user)
                                    .indexWhere((it) => it.uid == 'inventory'))),
                      ],
                    );
                  });
                }),
                // Charts row
                if (user.hasPermission(AppUser.pViewFinancialData)) ...[
                  RepaintBoundary(
                    child: LayoutBuilder(builder: (context, constraints) {
                      final bool isMobile = constraints.maxWidth < 750;
                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBarChartSection(context, cardDecor, allSales),
                            const SizedBox(height: 24),
                            _buildProfitLossSection(context, cardDecor, allSales),
                            const SizedBox(height: 24),
                            _buildTopSellingPie(allSales),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: _buildBarChartSection(
                                        context, cardDecor, allSales)),
                                const SizedBox(width: 24),
                                Expanded(
                                    child: _buildProfitLossSection(
                                        context, cardDecor, allSales)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildTopSellingPie(allSales)),
                                const Expanded(child: SizedBox()), // Placeholder to keep Pie Chart size consistent
                              ],
                            ),
                          ],
                        );
                      }
                    }),
                  ),
                  const SizedBox(height: 24),
                ],
                Row(
                  children: [
                    Expanded(
                        child: _reportCard(
                            "Sales Export (Excel)",
                            "Download full transaction history",
                            Icons.download_rounded, () async {
                      LoadingOverlay.show(context);
                      try {
                        final salesList = await _db.watchSales(user.shopId, branchId: _selectedBranchId == 'all' ? null : _selectedBranchId).first;
                        if (salesList.isEmpty) {
                          if (mounted)
                            rootScaffoldMessengerKey.currentState!.showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "No sales data available to export."),
                                    backgroundColor: AppColors.warning));
                          return;
                        }
                        final path =
                            await _reporting.exportSalesExcel(salesList);
                        if (mounted && path != "Cancelled")
                          rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                              content: Text("Export saved: $path"),
                              backgroundColor: AppColors.success));
                      } catch (e) {
                        if (mounted)
                          rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                              content: Text("Export failed: $e"),
                              backgroundColor: AppColors.danger));
                      } finally {
                        if (mounted) LoadingOverlay.hide(context);
                      }
                    })),
                    const SizedBox(width: 24),
                  ],
                ),

                // NEW ACTIONS SECTIONS
                const SizedBox(height: 32),
                Builder(builder: (ctx) {
                  final products = invSnap.data ?? [] ?? [];
                  final outOfStock = products
                      .where((d) => (d['quantity'] ?? 0.0) as num <= 0)
                      .toList();
                  final expired = products.where((d) {
                    final m = d;
                    final rawValue = m['expiry'] ?? m['exp'] ?? m['expiryDate'];
                    final date = parseDT(rawValue);
                    return date != null && date.isBefore(DateTime.now());
                  }).toList();
                  final expiringSoon = products.where((d) {
                    final m = d;
                    final rawValue = m['expiry'] ?? m['exp'] ?? m['expiryDate'];
                    final date = parseDT(rawValue);
                    if (date == null) return false;
                    final diff = date.difference(DateTime.now()).inDays;
                    return diff > 0 && diff <= 30;
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (expired.isNotEmpty) ...[
                        _buildReportSectionTitle(
                            "Expired Products (Action Required)",
                            AppColors.danger),
                        _buildHorizontalInventoryList(expired, cardDecor,
                            color: AppColors.danger),
                        const SizedBox(height: 24),
                      ],
                      if (expiringSoon.isNotEmpty) ...[
                        _buildReportSectionTitle(
                            "Expiring Soon (< 30 Days)", Colors.orange),
                        _buildHorizontalInventoryList(expiringSoon, cardDecor,
                            color: Colors.orange),
                        const SizedBox(height: 24),
                      ],
                      if (outOfStock.isNotEmpty) ...[
                        _buildReportSectionTitle(
                            "Out of Stock Products", AppColors.info),
                        _buildHorizontalInventoryList(outOfStock, cardDecor,
                            color: AppColors.info),
                        const SizedBox(height: 24),
                      ],

                      // NEW PERFORMANCE TIERS
                      Builder(builder: (c) {
                        final salesInPeriod = (snap.data ?? []);
                        final inventory = invSnap.data ?? [] ?? [];

                        if (inventory.isEmpty) return const SizedBox.shrink();

                        final Map<String, double> volumes = {};
                        for (var s in salesInPeriod) {
                          final name = s['itemName']?.toString() ?? 'Unknown';
                          volumes[name] = (volumes[name] ?? 0.0) + (s['quantity'] ?? 0).toDouble();
                        }

                        final moving = inventory.where((i) {
                          final name = i['name']?.toString() ?? '';
                          return name.isNotEmpty && volumes.containsKey(name);
                        }).toList();

                        moving.sort((a, b) {
                          final nameA = a['name']?.toString() ?? '';
                          final nameB = b['name']?.toString() ?? '';
                          final vA = volumes[nameA] ?? 0.0;
                          final vB = volumes[nameB] ?? 0.0;
                          return vB.compareTo(vA);
                        });

                        final dead = inventory.where((i) {
                          final name = i['name']?.toString() ?? '';
                          return name.isNotEmpty && !volumes.containsKey(name);
                        }).toList();

                        final fast = moving.take(5).toList();
                        final highValStock = List<Map<String, dynamic>>.from(inventory)
                          ..sort((a, b) => ((b)['sellingPrice'] ?? 0).compareTo((a)['sellingPrice'] ?? 0));
                        final highVal = highValStock.take(5).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (fast.isNotEmpty) ...[
                              _buildReportSectionTitle("Fast Moving Items (Top Sales)", Colors.green),
                              _buildHorizontalInventoryList(fast, cardDecor, color: Colors.green),
                              const SizedBox(height: 24),
                            ],
                            if (dead.isNotEmpty && _reportFilter != 'Daily') ...[
                              _buildReportSectionTitle("Dead Stock (Stable Inventory)", Colors.grey),
                              _buildHorizontalInventoryList(dead.take(10).toList(), cardDecor, color: Colors.grey),
                              const SizedBox(height: 24),
                            ],
                            if (highVal.isNotEmpty) ...[
                              _buildReportSectionTitle("High Value Inventory", Colors.purple),
                              _buildHorizontalInventoryList(highVal, cardDecor, color: Colors.purple),
                              const SizedBox(height: 24),
                            ],
                          ],
                        );
                      }),
                    ],
                  );
                }),
                const SizedBox(height: 32),
                _buildLowStockReportSection(user, cardDecor, invSnap.data ?? []),
                const SizedBox(height: 100),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionsTab(AppUser user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardDecor = BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: isDark ? null : Border.all(color: const Color(0xFFE2E8F0), width: 1),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
    );

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.watchSales(user.shopId, branchId: _selectedBranchId == 'all' ? null : _selectedBranchId).toMainThread(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allSales = snap.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Billing & Transactions",
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Review details and process customer refunds.",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.download_rounded, color: AppColors.secondary, size: 20),
                  ),
                  onSelected: (val) async {
                    LoadingOverlay.show(context);
                    try {
                      final filtered = allSales.where((d) {
                        final m = d;
                        final bId = m['branchId']?.toString() ?? 'main';
                        if (_selectedBranchId != "all" && bId != _selectedBranchId) return false;
                        final ts = parseDT(m['timestamp']);
                        if (ts == null) return false;
                        return ts.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
                               ts.isBefore(_endDate.add(const Duration(days: 1)));
                      }).toList();

                      if (filtered.isEmpty) {
                        rootScaffoldMessengerKey.currentState!.showSnackBar(
                          const SnackBar(content: Text('No data for selected period.'), backgroundColor: AppColors.warning));
                        return;
                      }

                      String pathStr = "";
                      if (val == 'excel') {
                        pathStr = await _reporting.exportSalesExcel(filtered);
                      } else if (val == 'pdf') {
                        // Aggregate data & trigger PDF Report
                        double totalRev = 0, totalProf = 0, totalUnpaid = 0;
                        Map<String, double> productRevMap = {};
                        Map<String, double> productQtyMap = {};
                        Map<String, Map<String, dynamic>> dailyMap = {};

                        for (var d in filtered) {
                          final m = d;
                          final bId = m['branchId']?.toString() ?? 'main';
                          if (_selectedBranchId != 'all' && bId != _selectedBranchId) continue;
                          
                          final ts = parseDT(m['timestamp']);
                          final rev = (m['totalPrice'] ?? 0).toDouble();
                          final prof = (m['profit'] ?? 0).toDouble();
                          totalRev += rev;
                          totalProf += prof;
                          if (m['isDebt'] == true) {
                            totalUnpaid += (m['debtRemaining'] ?? m['totalPrice'] ?? 0).toDouble();
                          }
                          final name = m['itemName'] ?? 'Unknown';
                          productRevMap[name] = (productRevMap[name] ?? 0) + rev;
                          productQtyMap[name] = (productQtyMap[name] ?? 0) + (m['quantity'] ?? 0).toDouble();

                          if (ts != null) {
                            final key = DateFormat('yyyy-MM-dd').format(ts);
                            final label = DateFormat('dd MMM').format(ts);
                            dailyMap[key] ??= {'date': label, 'revenue': 0.0, 'profit': 0.0, 'orders': 0};
                            dailyMap[key]!['revenue'] = (dailyMap[key]!['revenue'] as double) + rev;
                            dailyMap[key]!['profit'] = (dailyMap[key]!['profit'] as double) + prof;
                            dailyMap[key]!['orders'] = (dailyMap[key]!['orders'] as int) + 1;
                          }
                        }

                        final sortedDays = dailyMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
                        final sortedByQty = productQtyMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                        final topProducts = sortedByQty.take(5).map((e) => {
                          'name': e.key, 'qty': e.value.toInt(),
                          'rev': productRevMap[e.key] ?? 0,
                        }).toList();

                        final shopName = await _db.getSetting('shopName') ?? 'SmartInventory ERP';
                        final shopPhone = await _db.getSetting('shopPhone') ?? '+251...';

                        pathStr = await _reporting.exportToPdf(
                          'Transactions_Report_${DateTime.now().millisecondsSinceEpoch}',
                          {
                            'revenue': totalRev,
                            'profit': totalProf,
                            'orders': filtered.length,
                            'debt': totalUnpaid,
                            'purchases': 0.0,
                            'lowStockCount': 0,
                            'outStockCount': 0,
                            'expiredCount': 0,
                            'soonCount': 0,
                            'topProducts': topProducts,
                            'leastProducts': [],
                            'dailySales': sortedDays.map((e) => e.value).toList(),
                            'companyName': shopName,
                            'companyPhone': shopPhone,
                            'period': "${DateFormat('dd MMM yyyy').format(_startDate)} – ${DateFormat('dd MMM yyyy').format(_endDate)}",
                          },
                        );
                      }

                      if (mounted && pathStr != "Cancelled") {
                        rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(content: Text("Export saved: $pathStr"), backgroundColor: AppColors.success));
                      }
                    } catch (e) {
                      rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(content: Text("Export failed: $e"), backgroundColor: AppColors.danger));
                    } finally {
                      LoadingOverlay.hide(context);
                    }
                  },
                  itemBuilder: (c) => [
                    const PopupMenuItem(value: 'excel', child: Text("Export to Excel")),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters & Date Picker Segment
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Daily', label: Text('Daily', style: TextStyle(fontSize: 11)), icon: Icon(Icons.today_rounded, size: 16)),
                    ButtonSegment(value: 'Weekly', label: Text('Weekly', style: TextStyle(fontSize: 11)), icon: Icon(Icons.date_range_rounded, size: 16)),
                    ButtonSegment(value: 'Monthly', label: Text('Monthly', style: TextStyle(fontSize: 11)), icon: Icon(Icons.calendar_month_rounded, size: 16)),
                    ButtonSegment(value: 'Custom', label: Text('Custom', style: TextStyle(fontSize: 11)), icon: Icon(Icons.calendar_month_rounded, size: 16)),
                  ],
                  selected: {_reportFilter},
                  onSelectionChanged: (set) async {
                    if (set.first == 'Custom') {
                      final range = await showCustomDateRangePicker(
                          context: context,
                          initialStartDate: _startDate,
                          initialEndDate: _endDate,
                      );
                      if (range != null) {
                        setState(() {
                          _reportFilter = 'Custom';
                          _startDate = range.start;
                          _endDate = range.end;
                        });
                      }
                    } else {
                      _setFilter(set.first);
                    }
                  },
                ),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _searchSalesC,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Search by product or customer...",
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchSalesC.text.isNotEmpty)
                            IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchSalesC.clear();
                                  setState(() {});
                                }),
                          IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.secondary),
                              onPressed: () => _launchScanner(_searchSalesC)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSalesHistorySection(user, allSales),
          ],
        );
      },
    );
  }


  void _showSaleDetailDialog(Map<String, dynamic> s) {
    final ts = parseDT(s['timestamp']) ?? DateTime.now();
    final profit = (s['profit'] ?? 0).toDouble();
    final total = (s['totalPrice'] ?? 0).toDouble();
    final qty = (s['quantity'] ?? 0).toDouble();
    final refundedQty = (s['refundedQuantity'] ?? 0.0).toDouble();
    final isFullyRefunded = refundedQty >= qty;
    
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.secondary),
            const SizedBox(width: 12),
            const Text("Sale Details"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow("Product", s['itemName'] ?? 'Unknown'),
              _detailRow("Quantity", "$qty pieces"),
              if (refundedQty > 0) _detailRow("Refunded Qty", "$refundedQty pieces", color: Colors.red),
              _detailRow("Total Paid", _currencyFormat.format(total)),
              _detailRow("Unit Price", _currencyFormat.format(total / (qty > 0 ? qty : 1))),
              const Divider(height: 32),
              _detailRow("Sold By", s['username'] ?? 'Unknown'),
              _detailRow("Branch", s['branchId']?.toString() ?? 'Main Branch'),
              _detailRow("Customer", s['customerName']?.toString().isEmpty == false ? s['customerName'] : 'Walk-in Guest'),
              _detailRow("Date", DateFormat('MMM dd, yyyy').format(ts)),
              _detailRow("Time", DateFormat('hh:mm a').format(ts)),
              const Divider(height: 32),
              _detailRow("Net Profit", _currencyFormat.format(profit), 
                color: profit >= 0 ? Colors.green : Colors.red),
              const SizedBox(height: 16),
              Text("Transaction ID: ${s['id']}", style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close")),
          if (Provider.of<AuthService>(context, listen: false).user?.hasPermission(AppUser.pRefundSales) == true && !isFullyRefunded)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.pop(c);
                _showRefundConfirmDialog(s);
              },
              icon: const Icon(Icons.assignment_return_outlined, size: 18, color: Colors.white),
              label: const Text("Refund", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildSalesHistorySection(AppUser user, List<Map<String, dynamic>> allSales) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Transaction History", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () => _setFilter('Monthly'),
              icon: const Icon(Icons.history, size: 16),
              label: const Text("View Recent", style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Builder(builder: (context) {
          final searchQuery = _searchSalesC.text.trim().toLowerCase();

          final filtered = allSales.where((s) {
            final bId = s['branchId']?.toString() ?? 'main';
            if (_selectedBranchId != "all" && bId != _selectedBranchId) return false;

            if (searchQuery.isNotEmpty) {
               final name = s['itemName']?.toString().toLowerCase() ?? '';
               final cust = s['customerName']?.toString().toLowerCase() ?? '';
               if (!name.contains(searchQuery) && !cust.contains(searchQuery)) return false;
            }

            final ts = parseDT(s['timestamp']);
            if (ts == null) return false;
            return ts.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
                   ts.isBefore(_endDate.add(const Duration(days: 1)));
          }).toList();

          final displayList = filtered.take(50).toList();

          if (displayList.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(32),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Text("No records for this period.", style: TextStyle(color: AppColors.textSecondary))),
            );
          }

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withOpacity(0.5)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayList.length,
              separatorBuilder: (c, i) => const Divider(height: 1, indent: 64),
              itemBuilder: (c, i) {
                final s = displayList[i];
                final ts = parseDT(s['timestamp']) ?? DateTime.now();
                final profit = (s['profit'] ?? 0).toDouble();
                final refQty = (s['refundedQuantity'] ?? 0.0).toDouble();
                final qty = (s['quantity'] ?? 0.0).toDouble();

                return ListTile(
                  dense: true,
                  onTap: () => _showSaleDetailDialog(s),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.secondary.withOpacity(0.1),
                    child: const Icon(Icons.shopping_bag_outlined, color: AppColors.secondary, size: 16),
                  ),
                  title: Text(s['itemName'] ?? 'Product',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                      decoration: refQty >= qty ? TextDecoration.lineThrough : null)),
                  subtitle: Text("${DateFormat('MMM dd • hh:mm a').format(ts)} • ${s['username']}", style: const TextStyle(fontSize: 10)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_currencyFormat.format(s['totalPrice'] ?? 0),
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if (refQty > 0 && refQty < qty)
                        const Text("Partially Refunded", style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold))
                      else if (refQty >= qty && qty > 0)
                        const Text("Fully Refunded", style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold))
                      else
                        Text("${profit >= 0 ? '+' : ''}${_currencyFormat.format(profit)}",
                          style: TextStyle(fontSize: 10, color: profit >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

    
  void _showTransferStockDialog(AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _db.watchBranches(user.shopId).toMainThread(),
            builder: (c, branchSnap) {
              // Permission-filter branches to only what this user can access
              final rawBranches = branchSnap.data ?? [];
              final allIds = rawBranches
                  .where((b) => b['id'] != 'all')
                  .map((b) => b['id'].toString())
                  .toSet()
                  .toList();
              final allowedIds = user.getAssignedBranchIds(allIds);
              final branchMap = <String, Map<String, dynamic>>{};
              for (var b in rawBranches) {
                final bid = b['id'].toString();
                if (bid == 'all') continue;
                if (!allowedIds.contains('all') && !allowedIds.contains(bid)) continue;
                branchMap.putIfAbsent(bid, () => b);
              }
              final branches = branchMap.values.toList();

              // Guard: transfers require at least 2 branches
              if (branches.length < 2) {
                return AlertDialog(
                  title: const Text("Transfer Stock Between Branches"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        "You currently have access to only one branch. Contact your administrator to enable transfers between branches.",
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
                );
              }

              // Local state inside StreamBuilder (re-computed on each rebuild)
              String? sourceBranchId;
              String? destBranchId;
              String? selectedItemId;
              String? selectedBatchId;
              double transferQty = 0;
              final TextEditingController qtyC = TextEditingController();

              if (branches.isNotEmpty && sourceBranchId == null) {
                sourceBranchId = branches.first['id'].toString();
              }

              return StatefulBuilder(builder: (ctx2, setLocalState) {
                return AlertDialog(
                  title: const Text("Transfer Stock Between Branches"),
                  content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Source Branch", style: TextStyle(fontWeight: FontWeight.bold)),
                          DropdownButtonFormField<String>(
                            key: ValueKey('source_$sourceBranchId'),
                            value: sourceBranchId,
                            items: branches.map((b) => DropdownMenuItem(
                              value: b['id'].toString(),
                              child: Text(b['name']),
                            )).toList(),
                            onChanged: (v) => setLocalState(() {
                              sourceBranchId = v;
                              selectedItemId = null;
                            }),
                            decoration: const InputDecoration(hintText: "Select Source"),
                          ),
                          const SizedBox(height: 16),
                          const Text("Destination Branch", style: TextStyle(fontWeight: FontWeight.bold)),
                          DropdownButtonFormField<String>(
                            key: ValueKey('dest_$destBranchId'),
                            value: destBranchId,
                            items: branches
                                .where((b) => b['id'].toString() != sourceBranchId)
                                .map((b) => DropdownMenuItem(
                                  value: b['id'].toString(),
                                  child: Text(b['name']),
                                )).toList(),
                            onChanged: (v) => setLocalState(() => destBranchId = v),
                            decoration: const InputDecoration(hintText: "Select Destination"),
                          ),
                          const SizedBox(height: 16),
                          if (sourceBranchId != null) ...[
                            const Text("Select Product", style: TextStyle(fontWeight: FontWeight.bold)),
                            StreamBuilder<List<Map<String, dynamic>>>(
                              stream: _db.watchProducts(user.shopId, branchId: sourceBranchId).toMainThread(),
                              builder: (c, snap) {
                                final products = (snap.data ?? []).where((p) => (p['quantity'] ?? 0) > 0).toList();
                                return DropdownButtonFormField<String>(
                                  value: selectedItemId,
                                  items: products.map((p) => DropdownMenuItem(
                                    value: p['id'].toString(),
                                    child: Text("${p['name']} (${p['quantity']} avail)"),
                                  )).toList(),
                                  onChanged: (v) => setLocalState(() => selectedItemId = v),
                                  decoration: const InputDecoration(hintText: "Select Product"),
                                );
                              },
                            ),
                            if (selectedItemId != null) ...[
                              const SizedBox(height: 16),
                              const Text("Select Batch (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
                              StreamBuilder<List<Map<String, dynamic>>>(
                                stream: _db.watchBatchesByItem(user.shopId, selectedItemId!, branchId: sourceBranchId).toMainThread(),
                                builder: (c, snap) {
                                  final batches = (snap.data ?? []).where((b) => (b['quantity'] ?? 0.0) > 0).toList();
                                  batches.sort((a, b) {
                                    final da = parseDT(a['expiry'] ?? a['exp'] ?? a['expiryDate']);
                                    final db = parseDT(b['expiry'] ?? b['exp'] ?? b['expiryDate']);
                                    if (da == null && db == null) return 0;
                                    if (da == null) return 1;
                                    if (db == null) return -1;
                                    return da.compareTo(db);
                                  });
                                  return DropdownButtonFormField<String>(
                                    value: selectedBatchId,
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text("Auto (FEFO - recommended)")),
                                      ...batches.map((b) {
                                        final ed = b['expiry'] ?? b['exp'] ?? b['expiryDate'];
                                        DateTime? dVal = ed != null ? parseDT(ed) : null;
                                        final expStr = dVal != null ? DateFormat('dd MMM yy').format(dVal) : 'No Expiry';
                                        return DropdownMenuItem(
                                          value: b['id'].toString(),
                                          child: Text("Exp: $expStr | Qty: ${b['quantity']}"),
                                        );
                                      }),
                                    ],
                                    onChanged: (v) => setLocalState(() => selectedBatchId = v),
                                    decoration: const InputDecoration(hintText: "Optionally pick a specific batch"),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              const Text("Transfer Quantity", style: TextStyle(fontWeight: FontWeight.bold)),
                              TextField(
                                controller: qtyC,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: "Enter quantity to move"),
                                onChanged: (v) => setLocalState(() { transferQty = double.tryParse(v) ?? 0; }),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text("Cancel")),
                    ElevatedButton(
                      onPressed: (sourceBranchId != null && destBranchId != null && selectedItemId != null && transferQty > 0) ? () async {
                         Navigator.pop(ctx2);
                         LoadingOverlay.show(context);
                         try {
                           final products = await _db.query('products', where: 'id = ?', whereArgs: [selectedItemId!], limit: 1);
                           final itemName = products.isNotEmpty ? products.first['name'] : 'Item';
                           await _repo.transferStock(
                              admin: user,
                              itemId: selectedItemId!,
                              itemName: itemName,
                              fromBranchId: sourceBranchId!,
                              toBranchId: destBranchId!,
                              quantity: transferQty,
                              batchId: selectedBatchId,
                           );
                           if (mounted) rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(content: Text('Stock transferred successfully!'), backgroundColor: AppColors.success, duration: Duration(seconds: 1)));
                         } catch (e) {
                           if (mounted) rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(content: Text('Transfer Failed: $e'), backgroundColor: AppColors.danger, duration: Duration(seconds: 2)));
                         } finally {
                           if (mounted) LoadingOverlay.hide(context);
                         }
                      } : null,
                      child: const Text("Transfer Stock"),
                    ),
                  ],
                );
              });
            },
          );
        },
      ),
    );
  }

  void _showRefundConfirmDialog(Map<String, dynamic> s) {
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) return;
    final double maxRefundable = (s['quantity'] ?? 0.0).toDouble() - (s['refundedQuantity'] ?? 0.0).toDouble();
    double refundQty = maxRefundable;
    TextEditingController qtyC = TextEditingController(text: refundQty.toString());
    // Default: return to inventory. User may switch to "Dispose".
    bool returnToInventory = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text("Confirm Refund"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Item: ${s['itemName']}"),
                Text("Total Sold: ${s['quantity']} | Already Refunded: ${s['refundedQuantity'] ?? 0.0}"),
                Text("Available to Refund: $maxRefundable", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                const SizedBox(height: 16),
                const Text("Refund Quantity:"),
                TextField(
                  controller: qtyC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: "Enter amount"),
                  onChanged: (v) => setDialogState(() => refundQty = double.tryParse(v) ?? 0),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                const Text("What happens to the returned items?",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                // Return to Inventory tile
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setDialogState(() => returnToInventory = true),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: returnToInventory ? AppColors.secondary : Colors.grey.shade400,
                        width: returnToInventory ? 2 : 1,
                      ),
                      color: returnToInventory ? AppColors.secondary.withOpacity(0.07) : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            color: returnToInventory ? AppColors.secondary : Colors.grey, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Return to Inventory",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: returnToInventory ? AppColors.secondary : null)),
                              const Text("Product is sellable — restore to original batch (FEFO/FIFO order preserved)",
                                  style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        if (returnToInventory)
                          Icon(Icons.check_circle, color: AppColors.secondary, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Dispose tile
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setDialogState(() => returnToInventory = false),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !returnToInventory ? AppColors.danger : Colors.grey.shade400,
                        width: !returnToInventory ? 2 : 1,
                      ),
                      color: !returnToInventory ? AppColors.danger.withOpacity(0.07) : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            color: !returnToInventory ? AppColors.danger : Colors.grey, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Dispose Product",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: !returnToInventory ? AppColors.danger : null)),
                              const Text("Damaged / expired / unsellable — refund is financial only",
                                  style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        if (!returnToInventory)
                          Icon(Icons.check_circle, color: AppColors.danger, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: returnToInventory ? AppColors.secondary : AppColors.danger,
                ),
                onPressed: (refundQty > 0 && refundQty <= maxRefundable) ? () async {
                   Navigator.pop(dialogContext);
                   LoadingOverlay.show(context);
                   try {
                     await _repo.processRefund(user, s, refundQty, returnToInventory: returnToInventory);
                     if (mounted) rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                       content: Text(returnToInventory
                           ? 'Refund processed — stock restored to original batch.'
                           : 'Refund processed — product marked as disposed.'),
                       backgroundColor: AppColors.success,
                     ));
                   } catch (e) {
                     if (mounted) rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(content: Text('Refund Failed: $e'), backgroundColor: AppColors.danger));
                   } finally {
                     if (mounted) LoadingOverlay.hide(context);
                   }
                } : null,
                child: const Text("Confirm Refund"),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showPurchaseDetailDialog(Map<String, dynamic> d) {
    final ts = parseDT(d['timestamp']);
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Purchase Selection Details"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow("Item Name", d['itemName']),
                  _detailRow("Supplier", d['supplierName'] ?? 'N/A'),
                  _detailRow("Quantity", "${d['quantity']} Units"),
                  _detailRow(
                      "Unit Cost", _currencyFormat.format(d['unitCost'] ?? 0)),
                  _detailRow(
                      "Total Cost",
                      _currencyFormat
                          .format((d['unitCost'] ?? 0) * (d['quantity'] ?? 0))),
                  _detailRow(
                      "Date",
                      ts != null
                          ? DateFormat('MMM d, y – hh:mm a').format(ts)
                          : 'N/A'),
                  _detailRow("Barcode", d['barcode'] ?? 'N/A'),
                  _detailRow("Batch #", d['batchNumber'] ?? 'N/A'),
                  () {
                    final rawValue = d['expiry'] ?? d['exp'] ?? d['expiryDate'];
                    final parsed = parseDT(rawValue);
                    return _detailRow("Expiry Date", parsed != null 
                      ? DateFormat('MMM dd, yyyy').format(parsed) 
                      : "No Expiry");
                  }(),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Close")),
              ],
            ));
  }

  Widget _detailRow(String l, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text("$l: ",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(
              child: Text(v,
                  style: TextStyle(
                      color: color ?? AppColors.textSecondary, fontSize: 13))),
        ]),
      );

  Widget _buildLowStockReportSection(AppUser user, BoxDecoration decor, List<Map<String, dynamic>> products) {
    final items = products.where((d) {
      final qty = (d['quantity'] ?? 0.0) as num;
      final threshold = (d['lowStockThreshold'] ?? 5) as num;
      return qty > 0 && qty <= threshold;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: decor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Critical Low Stock Reorder List",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.danger)),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text("All items are well stocked.",
                style: TextStyle(color: AppColors.success))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (c, i) {
                final d = items[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber_rounded,
                      color: AppColors.danger),
                  title: Text(d['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      "Price: ${_currencyFormat.format(d['sellingPrice'] ?? 0)}"),
                  trailing: Text("${d['quantity']} Left",
                      style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _reportCard(
      String title, String sub, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: AppColors.glassDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.secondary),
            ),
            const SizedBox(height: 24),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(sub,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab(AppUser user) {
    final isAdmin = user.hasRole(UserRole.admin);
    final isAdminOrManager = isAdmin || user.hasRole(UserRole.manager);
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Text("Application Settings",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.storefront_rounded),
                title: const Text("Shop Profile"),
                subtitle: const Text("Update business details and logo"),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: !isAdmin
                    ? null
                    : () => showDialog(
                        context: context,
                        builder: (ctx) => StreamBuilder<Map<String, dynamic>>(
                          stream: Provider.of<AuthService>(context).shopStream,
                          builder: (context, snap) {
                            final shopData = snap.data;
                            final nameC = TextEditingController(text: shopData?['name'] ?? 'SmartInventory ERP');
                            final phoneC = TextEditingController(text: shopData?['phone'] ?? '+251...');

                            return AlertDialog(
                              title: const Text("Edit Shop Profile"),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    decoration: const InputDecoration(labelText: "Business Name"),
                                    controller: nameC,
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    decoration: const InputDecoration(labelText: "Public Phone Number"),
                                    controller: phoneC,
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                ElevatedButton(
                                  onPressed: () async {
                                    final auth = Provider.of<AuthService>(context, listen: false);
                                    await auth.updateShop(nameC.text, phoneC.text);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                                  child: const Text("Save Changes"),
                                ),
                              ],
                            );
                          }
                        )),
// ...
                enabled: isAdmin,
              ),
              const Divider(height: 1),
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                  title: const Text("Delete Shop", style: TextStyle(color: AppColors.danger)),
                  subtitle: const Text("Permanently delete business data", style: TextStyle(color: AppColors.danger)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.danger),
                  onTap: () async {
                    final passC = TextEditingController();
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text("Delete Shop", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("This will permanently remove all local business data associated with this shop. This action cannot be undone."),
                            const SizedBox(height: 16),
                            const Text("To confirm, enter your current password:"),
                            const SizedBox(height: 8),
                            TextField(
                              controller: passC,
                              obscureText: true,
                              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Password"),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                            onPressed: () async {
                              final pass = passC.text.trim();
                              if (pass.isEmpty) return;
                              final hash = sha256.convert(utf8.encode(pass)).toString();
                              final rows = await Provider.of<DatabaseService>(context, listen: false).query('users', where: 'uid = ?', whereArgs: [user.id]);
                              if (rows.isNotEmpty && rows.first['passwordHash'] == hash) {
                                Navigator.pop(c, true);
                              } else {
                                rootScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Incorrect password"), backgroundColor: AppColors.danger, duration: Duration(seconds: 2)));
                              }
                            },
                            child: const Text("Delete Shop"),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      LoadingOverlay.show(context);
                      await _repo.recordAuditLog(user.shopId, user.username, 'Shop Deleted', 'User ${user.username} permanently deleted shop at ${DateTime.now().toIso8601String()}', branchId: user.branchId ?? 'main');
                      await _db.deleteShopAndAccount(user.shopId);
                      if (mounted) {
                        LoadingOverlay.hide(context);
                        await Provider.of<AuthService>(context, listen: false).signOut();
                      }
                    }
                  },
                ),
              if (isAdmin) const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: const Text("Language Selection"),
                subtitle: const Text("Select preferred communication language"),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                            title: const Text("Choose Language"),
                            content: SizedBox(
                              width: double.maxFinite,
                              height: 400,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildLangItem(ctx, "English", "Global Business", erp_l10n.AppLanguage.en),
                                    _buildLangItem(ctx, "Amharic (አማርኛ)", "Ethiopia", erp_l10n.AppLanguage.am),
                                    _buildLangItem(ctx, "Arabic (العربية)", "Middle East / North Africa", erp_l10n.AppLanguage.ar),
                                    _buildLangItem(ctx, "French (Français)", "West Africa / Europe", erp_l10n.AppLanguage.fr),
                                    _buildLangItem(ctx, "Spanish (Español)", "Latin America / Spain", erp_l10n.AppLanguage.es),
                                    _buildLangItem(ctx, "Hindi (हिन्दी)", "India", erp_l10n.AppLanguage.hi),
                                    _buildLangItem(ctx, "Mandarin (中文)", "East Asia / Global Trade", erp_l10n.AppLanguage.zh),
                                    _buildLangItem(ctx, "Swahili (Kiswahili)", "East Africa", erp_l10n.AppLanguage.sw),
                                    _buildLangItem(ctx, "Portuguese (Português)", "Brazil, Angola & Mozambique", erp_l10n.AppLanguage.pt),
                                  ],
                                ),
                              ),
                            ),
                          ));
                },
              ),
               const Divider(height: 1),
               ListTile(
                 leading: const Icon(Icons.currency_exchange_rounded),
                 title: const Text("Currency Selection"),
                 subtitle: Text("Current: ${_appCurrencySymbol ?? 'ETB '}"),
                 trailing: const Icon(Icons.chevron_right_rounded),
                 onTap: () {
                     const currencyList = [
                       {'code': 'USD', 'name': 'US Dollar'},
                       {'code': 'EUR', 'name': 'Euro'},
                       {'code': 'GBP', 'name': 'British Pound'},
                       {'code': 'CAD', 'name': 'Canadian Dollar'},
                       {'code': 'AUD', 'name': 'Australian Dollar'},
                       {'code': 'NZD', 'name': 'New Zealand Dollar'},
                       {'code': 'JPY', 'name': 'Japanese Yen'},
                       {'code': 'CNY', 'name': 'Chinese Yuan'},
                       {'code': 'INR', 'name': 'Indian Rupee'},
                       {'code': 'SGD', 'name': 'Singapore Dollar'},
                       {'code': 'HKD', 'name': 'Hong Kong Dollar'},
                       {'code': 'AED', 'name': 'UAE Dirham'},
                       {'code': 'SAR', 'name': 'Saudi Riyal'},
                       {'code': 'ZAR', 'name': 'South African Rand'},
                       {'code': 'ETB', 'name': 'Ethiopian Birr'},
                       {'code': 'NGN', 'name': 'Nigerian Naira'},
                       {'code': 'KES', 'name': 'Kenyan Shilling'},
                       {'code': 'CHF', 'name': 'Swiss Franc'},
                       {'code': 'BRL', 'name': 'Brazilian Real'},
                       {'code': 'MXN', 'name': 'Mexican Peso'},
                     ];
                     showDialog(
                       context: context,
                       builder: (ctx) => AlertDialog(
                         title: const Text("Select Currency"),
                         content: SizedBox(
                           width: 320,
                           height: 400,
                           child: ListView(
                             children: currencyList.map((c) => ListTile(
                               dense: true,
                               title: Text(c['code']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                               subtitle: Text(c['name']!),
                               trailing: (_appCurrencySymbol?.trim() == c['code'])
                                   ? const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 18)
                                   : null,
                               onTap: () async {
                                  await _db.saveSetting('app_currency_symbol', '${c["code"]} ');
                                  await _loadCurrency();
                                  if (ctx.mounted) Navigator.pop(ctx);
                               },
                             )).toList(),
                           ),
                         ),
                       )
                     );
                  },
               ),
               const Divider(height: 1),
              Consumer<ThemeService>(
                builder: (context, theme, _) => ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text("Theme Mode"),
                  subtitle: Text(theme.themeMode == ThemeMode.dark ? "Dark Theme" : "Light Theme"),
                  trailing: Switch(
                    value: theme.themeMode == ThemeMode.dark,
                    onChanged: (val) {
                      final sw = Stopwatch()..start();
                      theme.toggleTheme(val);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        PerfLogger.logPerformance('Theme switched', sw.elapsedMilliseconds);
                      });
                    },
                    activeColor: AppColors.secondary,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded,
                    color: AppColors.danger),
                title: const Text("Factory Reset",
                    style: TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.bold)),
                subtitle: const Text("Clear all inventory, sales, and logs",
                    style: TextStyle(color: AppColors.danger)),
                onTap: !isAdmin
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text("DANGER ZONE",
                                style: TextStyle(color: AppColors.danger)),
                            content: const Text(
                                "This will permanently delete ALL data (inventory, sales, audits, etc). Type 'RESET' to confirm."),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text("Cancel")),
                              ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.danger),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text("Delete Everything")),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          LoadingOverlay.show(context);
                          await _repo.factoryReset(user.shopId);
                          if (mounted) {
                            LoadingOverlay.hide(context);
                            rootScaffoldMessengerKey.currentState!.showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("System reset successfully"),
                                    backgroundColor: AppColors.success));
                          }
                        }
                      },
              ),
              const Divider(height: 1),
              ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text("Logout",
                  style: TextStyle(color: AppColors.danger)),
              onTap: () => Provider.of<AuthService>(context, listen: false).signOut(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLangItem(BuildContext ctx, String name, String sub, erp_l10n.AppLanguage lang) {
    return ListTile(
      title: Text(name),
      subtitle: Text(sub),
      onTap: () => _updateLang(ctx, lang),
    );
  }

  Future<void> _updateLang(BuildContext ctx, erp_l10n.AppLanguage lang) async {
    final l10n = Provider.of<erp_l10n.LocalizationService>(context, listen: false);
    await l10n.setLanguage(lang);
    if (mounted) {
      Navigator.pop(ctx);
      String langName = "English";
      switch(lang) {
        case erp_l10n.AppLanguage.am: langName = "Amharic"; break;
        case erp_l10n.AppLanguage.ar: langName = "Arabic"; break;
        case erp_l10n.AppLanguage.fr: langName = "French"; break;
        case erp_l10n.AppLanguage.es: langName = "Spanish"; break;
        case erp_l10n.AppLanguage.hi: langName = "Hindi"; break;
        case erp_l10n.AppLanguage.zh: langName = "Mandarin"; break;
        case erp_l10n.AppLanguage.sw: langName = "Swahili"; break;
        case erp_l10n.AppLanguage.pt: langName = "Portuguese"; break;
        default: langName = "English";
      }
      rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
          content: Text('Language updated to $langName')));
      setState(() {});
    }
  }

  Widget _buildActiveTab(AppUser user) => Expanded(child: _buildBody(user));

  Widget _buildBottomNav() {
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) return const SizedBox();
    final items = _getSidebarItems(user);

    // Primary items always shown in bottom bar
    final primaryItems = items.take(4).toList();
    final bool hasMore = items.length > 4;
    final bool isMoreActive = _selectedIndex >= 4;

    return NavigationBar(
      selectedIndex: _selectedIndex < 4 ? _selectedIndex : 4,
      onDestinationSelected: (i) {
        if (i == 4 && hasMore) {
          _showMoreBottomSheet(context, items.skip(4).toList());
        } else {
          setState(() => _selectedIndex = i);
        }
      },
      destinations: [
        ...primaryItems.map((it) => NavigationDestination(
              icon: Icon(it.icon),
              label: it.label,
            )),
        if (hasMore)
          NavigationDestination(
            icon: Icon(isMoreActive ? Icons.more_horiz_rounded : Icons.more_horiz_outlined),
            label: "More",
          ),
      ],
    );
  }

  void _showMoreBottomSheet(BuildContext ctx, List<SidebarItem> items) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Theme.of(ctx).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text("More Options", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 20),
              ...items.map((item) {
                final allItems = _getSidebarItems(
                  Provider.of<AuthService>(context, listen: false).user!,
                );
                final itemIndex = allItems.indexWhere((i) => i.uid == item.uid);
                
                return ListTile(
                  leading: Icon(item.icon, color: AppColors.secondary),
                  title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(bCtx);
                    if (itemIndex != -1) {
                      setState(() => _selectedIndex = itemIndex);
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _checkDuplicateBranchItem(String shopId, String branchId, String name, String barcode, {String? excludeId}) async {
    // Build a query that is genuinely branch-scoped and correctly excludes
    // the current item when editing (excludeId is non-null).
    // IMPORTANT: never use `id != ''` as a guard — that matches ALL rows.
    final cleanName = name.trim();
    final cleanBarcode = barcode.trim();

    // Nothing to match if both name and barcode are empty.
    if (cleanName.isEmpty && cleanBarcode.isEmpty) return false;

    // Compose the name/barcode OR clause.
    final matchClause = cleanBarcode.isNotEmpty
        ? "(LOWER(name) = ? OR barcode = ?)"
        : "LOWER(name) = ?";
    final matchArgs = cleanBarcode.isNotEmpty
        ? [cleanName.toLowerCase(), cleanBarcode]
        : [cleanName.toLowerCase()];

    // Compose the exclusion clause only when an existing ID is provided.
    final excludeClause = (excludeId != null && excludeId.isNotEmpty) ? " AND id != ?" : "";
    final excludeArgs = (excludeId != null && excludeId.isNotEmpty) ? [excludeId] : <dynamic>[];

    final q = await _db.query(
      'products',
      where: 'shop_id = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = "main")) AND $matchClause$excludeClause AND sync_status <> ?',
      whereArgs: [shopId, branchId, branchId, ...matchArgs, ...excludeArgs, 'pendingDelete'],
    );
    return q.isNotEmpty;
  }

  Future<String?> _showDuplicateChoiceDialog(String itemName) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.secondary),
            SizedBox(width: 12),
            Text("Duplicate Found"),
          ],
        ),
        content: Text("A product named '$itemName' already exists in this branch. How would you like to proceed?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, "update"),
            child: const Text("Update Existing (Restock)"),
          ),
        ],
      ),
    );
  }

  void _handleEditProduct(AppUser u, Map<String, dynamic> item) async {
    LoadingOverlay.show(context);
    try {
      final allBatches = await _db.watchBatches(u.shopId).first;
      final productBatches = allBatches.where((b) {
        final matchItem = b['itemId'] == item['id'];
        final bId = b['branchId']?.toString() ?? 'main';
        if (_selectedBranchId != 'all' && bId != _selectedBranchId) return false;
        return matchItem;
      }).toList();
      
      if (mounted) LoadingOverlay.hide(context);

      if (productBatches.length > 1) {
        final selectedBatch = await _showBatchSelectionDialog(productBatches);
        if (selectedBatch != null) {
          _showAddItemDialog(u, {...selectedBatch, 'name': item['name']}, item['id'].toString(), true);
        }
      } else if (productBatches.length == 1) {
        _showAddItemDialog(u, {...productBatches.first, 'name': item['name']}, item['id'].toString(), true);
      } else {
        _showAddItemDialog(u, item, item['id'].toString());
      }
    } catch (e) {
      if (mounted) LoadingOverlay.hide(context);
      _showAddItemDialog(u, item, item['id'].toString());
    }
  }

  Future<Map<String, dynamic>?> _showBatchSelectionDialog(List<Map<String, dynamic>> batches) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select Batch to Edit"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("This product has multiple batches. Please select which one to modify:", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: batches.length,
                  itemBuilder: (c, i) {
                    final b = batches[i];
                    final exp = parseDT(b['expiry'] ?? b['exp'] ?? b['expiryDate']);
                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      title: Text("Batch: ${b['batchNumber'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Qty: ${b['quantity']} • Exp: ${exp != null ? DateFormat('MMM yyyy').format(exp) : 'N/A'}"),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => Navigator.pop(ctx, b),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddItemDialog(AppUser u, [Map<String, dynamic>? item, String? id, bool isBatchEdit = false]) {
    final isAdmin = u.roles.contains(UserRole.admin);
    final isManager = u.roles.contains(UserRole.manager);

    // Hard Locks: Manager cannot edit BuyingPrice after creation.
    // Selling price is allowed for anyone with Manage Inventory (they manage prices).
    final bool lockBuyingPrice = isManager && id != null;
    final bool lockSellingPrice = false; // Manage Inventory includes selling price management

    final nameC = TextEditingController(text: item?['name'] ?? '');
    final sellC =
        TextEditingController(text: item?['sellingPrice']?.toString() ?? '');
    final buyC =
        TextEditingController(text: item?['buyingPrice']?.toString() ?? '');
    final qtyC =
        TextEditingController(text: item?['quantity']?.toString() ?? '');
    final barC = TextEditingController(text: item?['barcode'] ?? '');
    final batchC = TextEditingController(text: item?['batchNumber'] ?? '');
    final thresholdC = TextEditingController(
        text: item?['lowStockThreshold']?.toString() ?? '5');
    DateTime? expiryDate = parseDT(item?['expiry'] ?? item?['exp'] ?? item?['expiryDate']);
    String selectedBranchId = item?['branchId']?.toString() ?? 
        (_selectedBranchId != 'all' ? _selectedBranchId : u.branchId);
    bool createAsNew = false;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (c, setS) => AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.surface,
                title: Text(id == null ? 'Add Product' : 'Edit Product'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                          controller: nameC,
                          enabled: !isBatchEdit,
                          decoration: const InputDecoration(
                              labelText: "Product Name*",
                              prefixIcon: Icon(Icons.shopping_bag_outlined))),
                      const SizedBox(height: 16),
                      TextField(
                          controller: barC,
                          decoration: InputDecoration(
                            labelText: "Barcode (Optional)",
                            prefixIcon:
                                const Icon(Icons.qr_code_scanner_rounded),
                            suffixIcon: IconButton(
                                icon: const Icon(Icons.camera_alt_outlined),
                                onPressed: () => _launchScanner(barC)),
                          )),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                              child: TextField(
                                  controller: buyC,
                                  enabled: !lockBuyingPrice,
                                  decoration: InputDecoration(
                                      labelText: "Buying Price*",
                                      hintText: "ETB",
                                      suffixIcon: lockBuyingPrice
                                          ? const Icon(Icons.lock_outline,
                                              size: 16)
                                          : null))),
                          const SizedBox(width: 16),
                          Expanded(
                              child: TextField(
                                  controller: sellC,
                                  enabled: !lockSellingPrice,
                                  decoration: InputDecoration(
                                      labelText: "Selling Price",
                                      hintText: "ETB",
                                      suffixIcon: lockSellingPrice
                                          ? const Icon(Icons.lock_outline,
                                              size: 16)
                                          : null))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: TextField(
                                  controller: qtyC,
                                  decoration: const InputDecoration(
                                      labelText: "Stock Qty*"))),
                          const SizedBox(width: 16),
                          Expanded(
                              child: TextField(
                                  controller: thresholdC,
                                  decoration: const InputDecoration(
                                      labelText: "Low Stock Alert",
                                      hintText: "e.g. 5"))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_note_rounded),
                        title: Text(expiryDate == null
                            ? "Set Expiry Date"
                            : "Expires: ${DateFormat('dd MMM yyyy').format(expiryDate!)}"),
                        onTap: () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: expiryDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2040));
                          if (picked != null) setS(() => expiryDate = picked);
                        },
                      ),
                      const SizedBox(height: 16),
                      // ── Branch Selector (respects user branch permissions) ─────
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _db.watchBranches(u.shopId).toMainThread(),
                        builder: (c, snap) {
                          final allBranches = (snap.data ?? []).where((b) => b['id'] != 'all').toList();
                          if (allBranches.isEmpty) return const SizedBox.shrink();

                          // Filter to only branches this user can access
                          final allIds = allBranches.map((b) => b['id'].toString()).toList();
                          final allowedIds = u.getAssignedBranchIds(allIds);
                          final branches = allowedIds.contains('all')
                              ? allBranches
                              : allBranches.where((b) => allowedIds.contains(b['id'].toString())).toList();

                          if (branches.isEmpty) return const SizedBox.shrink();

                          // If user only has access to one branch, auto-assign and hide dropdown
                          if (branches.length == 1) {
                            final singleBranch = branches.first;
                            if (selectedBranchId != singleBranch['id'].toString()) {
                              Future.microtask(() => setS(() => selectedBranchId = singleBranch['id'].toString()));
                            }
                            return Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                                color: Theme.of(context).colorScheme.surface,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.store_rounded, size: 16, color: AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(singleBranch['name'].toString(),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  const Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                                ],
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Product Branch*", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: branches.any((b) => b['id'] == selectedBranchId) ? selectedBranchId : branches.first['id'],
                                    isExpanded: true,
                                    items: branches.map((b) => DropdownMenuItem(
                                      value: b['id'] as String,
                                      child: Text(b['name'] as String),
                                    )).toList(),
                                    onChanged: (v) {
                                      if (v != null) setS(() => selectedBranchId = v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text("Cancel")),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameC.text.isEmpty ||
                          buyC.text.isEmpty ||
                          qtyC.text.isEmpty) {
                        rootScaffoldMessengerKey.currentState!.showSnackBar(
                            const SnackBar(
                                content:
                                    Text("Please fill mandatory fields (*)"),
                                duration: Duration(seconds: 2)));
                        return;
                      }
                      
                      

                      if (id == null) {
                        final isDup = await _checkDuplicateBranchItem(u.shopId, selectedBranchId, nameC.text, barC.text);
                        if (isDup) {
                          final choice = await _showDuplicateChoiceDialog(nameC.text);
                          if (choice == null) return;
                          createAsNew = choice == "new";
                        }
                      }

                      try {
                        LoadingOverlay.show(context);
                        final productMap = {
                          'name': nameC.text.trim(),
                          'barcode': barC.text.trim(),
                          'batchNumber': batchC.text.trim(),
                          'buyingPrice': double.tryParse(buyC.text) ?? 0.0,
                          'sellingPrice': double.tryParse(sellC.text) ?? 0.0,
                          'quantity': double.tryParse(qtyC.text.trim()) ?? 0,
                          'lowStockThreshold':
                              int.tryParse(thresholdC.text) ?? 5,
                          'expiryDate': expiryDate,
                          'shopId': u.shopId,
                          'branchId': selectedBranchId,
                          'lastUpdated': DateTime.now().toIso8601String(),
                        };

                        if (id == null) {
                          await _repo.registerItem(u, productMap, forceNew: createAsNew);
                          if (u.roles.contains(UserRole.inventoryStaff)) {
                            await _db.addNotification({
                              'shopId': u.shopId,
                              'title': 'New Medicine Added',
                              'message': "New medicine '${nameC.text}' added by Staff. Please set buying/selling price.",
                              'type': 'inventory_alert'
                            });
                          }
                        } else {
                          if (isBatchEdit && item != null && item.containsKey('id')) {
                            // Update specific batch record (persistence fix)
                            final batchId = item['id'].toString();
                            await _db.update('batches', batchId, {
                              'buyingPrice': double.tryParse(buyC.text) ?? 0.0,
                              'sellingPrice': double.tryParse(sellC.text) ?? 0.0,
                              'quantity': double.tryParse(qtyC.text.trim()) ?? 0.0,
                              'expiry': expiryDate?.toIso8601String(),
                              'batchNumber': batchC.text.trim(),
                              'lastUpdated': DateTime.now().toIso8601String(),
                            });
                            // Update product shared metadata or other fields if needed, 
                            // but forceRecalculate usually handles stock/price sync
                            await _db.update('products', id!, {
                              'name': nameC.text.trim(),
                              'barcode': barC.text.trim(),
                              'lowStockThreshold': int.tryParse(thresholdC.text) ?? 5,
                              'branchId': selectedBranchId, // Ensure correct branch context is set
                            });
                            // Trigger recalibration of main product stock/expiry from all batches
                            await _repo.forceRecalculate(u.shopId, id!);
                          } else {
                            await _db.update('products', id!, productMap);
                          }
                          await _repo.recordAuditLog(u.shopId, u.username, 'EDIT_PRODUCT', 'Updated product: ${nameC.text}');
                        }


                        if (c.mounted) {
                          LoadingOverlay.hide(context);
                          _showSnackBar('Product Added Instantly!');
                          Navigator.pop(c);
                        }
                      } catch (e) {
                        if (c.mounted) LoadingOverlay.hide(context);
                        _showSnackBar(e.toString(), isError: true);
                      }
                    },
                    child: Text(id == null ? "Add Product" : "Save Changes"),
                  ),
                ],
              )),
    );
  }



  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color)),
    );
  }

  // _handleCSVExport removed in favor of integrated _reporting.exportSalesExcel calls

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
      _showSnackBar("Import Processing Error: $e", isError: true);
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
          
          final event = finalResult.wasCancelled ? "Bulk Import Cancelled" : "Bulk Import";
          final details = "Total Rows: ${finalResult.totalRows} | "
                          "Imported: ${finalResult.importedCount} | "
                          "Updated: ${finalResult.updatedCount} | "
                          "Skipped: ${finalResult.skippedCount} | "
                          "Failed: ${finalResult.failedCount}";

          await _repo.recordAuditLog(
             user.shopId,
             user.username,
             event,
             details,
             branchId: user.branchId ?? 'main'
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

  Widget _reportRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPieLegend(String label, Color color, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildBarChartSection(BuildContext context, BoxDecoration cardDecoration, List<Map<String, dynamic>> allSales) {
    final now = DateTime.now();
    
    return DashboardCard(
      title: "Sales Over Time",
      height: 380,
      child: Column(
        children: [
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: null, // Let it scale automatically or calculate if needed
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (v, meta) => Text(
                        _formatLargeNumber(v),
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        final date = now.subtract(Duration(days: 6 - v.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(DateFormat('E').format(date),
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        _currencyFormat.format(rod.toY),
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final date = now.subtract(Duration(days: 6 - i));
                  double dailyRev = 0;
                  for (var m in allSales) {
                    final bId = m['branchId']?.toString() ?? 'main';
                    if (_selectedBranchId != "all" && bId != _selectedBranchId) continue;
                    final ts = parseDT(m['timestamp']);
                    if (ts != null && ts.year == date.year && ts.month == date.month && ts.day == date.day) {
                      final rev_total = (m['totalPrice'] ?? 0).toDouble();
                      final originalQty = (m['quantity'] ?? 0.0).toDouble();
                      final refundedQty = (m['refundedQuantity'] ?? 0.0).toDouble();
                      double effectiveRev = rev_total;
                      if (refundedQty > 0 && originalQty > 0) {
                        final unitPrice = rev_total / originalQty;
                        effectiveRev -= (unitPrice * refundedQty);
                      }
                      dailyRev += effectiveRev;
                    }
                  }
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: dailyRev,
                        color: AppColors.secondary,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingTable(AppUser user, List<Map<String, dynamic>> allSales,
      BoxDecoration cardDecoration) {
    // Aggregate sales by product name
    final Map<String, Map<String, dynamic>> aggregated = {};
    for (var doc in allSales) {
      final m = doc;
      final name = m['itemName']?.toString() ?? 'Unknown';
      final qty = (m['quantity'] ?? 0.0).toDouble();
      final rqty = (m['refundedQuantity'] ?? 0.0).toDouble();
      final profit = (m['profit'] ?? 0.0).toDouble();
      
      double netQty = qty - rqty;
      double netProf = profit;
      if (rqty > 0 && qty > 0) {
        netProf -= (profit / qty) * rqty;
      }

      if (aggregated.containsKey(name)) {
        aggregated[name]!['qty'] = (aggregated[name]!['qty'] as double) + netQty;
        aggregated[name]!['profit'] = (aggregated[name]!['profit'] as double) + netProf;
      } else {
        aggregated[name] = {'name': name, 'qty': netQty, 'profit': netProf};
      }
    }
    final top5 = (aggregated.values.toList()
          ..sort((a, b) => (b['qty'] as double).compareTo(a['qty'] as double)))
        .take(5)
        .toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);

    final showProfit = user.hasPermission(AppUser.pViewFinancialData);

    return DashboardCard(
      title: "Top Moving Inventory",
      height: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (top5.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text("No sales data yet.",
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4)))),
            )
          else
            Table(
              columnWidths: {
                0: const FlexColumnWidth(3),
                1: const FlexColumnWidth(1),
                if (showProfit) 2: const FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                      color: headerBg, borderRadius: BorderRadius.circular(8)),
                  children: [
                    const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text("Item",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12))),
                    const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text("Qty",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12))),
                    if (showProfit)
                      const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text("Profit",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
                ...top5.map((item) => TableRow(
                      children: [
                        Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(item['name'],
                                style: const TextStyle(fontSize: 12))),
                        Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(item['qty'].toInt().toString(),
                                style: const TextStyle(fontSize: 12))),
                        if (showProfit)
                          Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(_currencyFormat.format(item['profit'] ?? 0),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppColors.success))),
                      ],
                    )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAlertsCol(
      List<Map<String, dynamic>> inventory, BoxDecoration cardDecoration) {
    final now = DateTime.now();
    final alerts = inventory.where((m) {
      final qty = (m['quantity'] ?? 0.0).toDouble();
      final threshold = (m['lowStockThreshold'] ?? 5) as num;
      if (qty > 0 && qty <= threshold) return true;
      final expiry = parseDT(m['expiryDate']);
      if (expiry != null) {
        final days = expiry.difference(now).inDays;
        if (days >= 0 && days <= 30) return true;
      }
      return false;
    }).take(10).toList();
    return DashboardCard(
      title: "Action Required",
      height: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text("No urgent alerts ✓", style: TextStyle(color: AppColors.success))),
            )
          else
            ...alerts.map((m) {
              final qty = (m['quantity'] ?? 0.0).toDouble();
              final thresh = (m['lowStockThreshold'] ?? 5) as num;
              final expiry = parseDT(m['expiry'] ?? m['exp'] ?? m['expiryDate']);
              final days = expiry?.difference(now).inDays ?? 999;
              bool isExpiring = days >= 0 && days <= 30;
              bool isLow = qty > 0 && qty <= thresh;
              bool isCritical = (isLow && qty <= 2) || (isExpiring && days <= 7);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(width: 4, height: 24, decoration: BoxDecoration(color: isCritical ? AppColors.danger : AppColors.warning, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                          Text(isExpiring ? "Expires in $days days" : "Low Stock Alert ($qty left)", 
                               style: TextStyle(fontSize: 10, color: isCritical ? AppColors.danger : AppColors.secondary)),
                        ],
                      ),
                    ),
                    if (isExpiring)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text("EXPIRING", style: TextStyle(color: AppColors.danger, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDebtTab(AppUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Debt Collection (Unpaid Sales)",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Manage credit customers and track summaries", 
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _db.watchSales(user.shopId, branchId: _selectedBranchId == 'all' ? null : _selectedBranchId).toMainThread(),
            builder: (ctx, snap) {
              if (!snap.hasData)
                return const Center(child: CircularProgressIndicator());
              final allSales = snap.data!;
              Map<String, List<Map<String, dynamic>>> grouped = {};
              for (var doc in allSales) {
                final m = doc;
                final remaining = (m['debtRemaining'] ?? 0.0);
                if (m['isDebt'] == true && remaining > 0.1) {
                  // Fallback grouping: if groupId is missing, group by customer + day to avoid "divided" entries
                  String key = m['saleGroupId']?.toString() ?? "";
                  if (key.isEmpty) {
                     final ts = parseDT(m['timestamp']) ?? DateTime.now();
                     final dateKey = "${ts.year}${ts.month}${ts.day}";
                     key = "DEBT-${m['customerName']}-$dateKey";
                  }
                  if (!grouped.containsKey(key)) grouped[key] = [];
                  grouped[key]!.add(doc);
                }
              }
              final groupKeys = grouped.keys.toList();

              if (groupKeys.isEmpty)
                return const Center(
                    child: Text("No active debts found.",
                        style: TextStyle(color: AppColors.textSecondary)));

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                itemCount: groupKeys.length,
                separatorBuilder: (c, i) => const Divider(),
                itemBuilder: (c, i) {
                  final key = groupKeys[i];
                  final items = grouped[key]!;
                  final d = items.first;
                  final totalRemaining = items.fold(
                      0.0,
                      (sum, doc) =>
                          sum + (doc['debtRemaining'] ?? 0.0));
                  final ts = parseDT(d['timestamp']) ?? DateTime.now();

                  return ListTile(
                    onTap: () => _showDebtDetailDialog(items
                        .map((it) => it)
                        .toList()),
                    leading: const CircleAvatar(
                        backgroundColor: AppColors.danger,
                        child: Icon(Icons.money_off,
                            color: Colors.white, size: 18)),
                    title: Text(
                        "${d['customerName'] == null || d['customerName'].toString().isEmpty ? 'Unknown Customer' : d['customerName']} - ${items.length} Items",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${DateFormat('MMM d, y').format(ts)} • Sold by ${d['username']}"),
                        if (MediaQuery.of(context).size.width < 500)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              "Unpaid: ${_currencyFormat.format(totalRemaining)}",
                              style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (MediaQuery.of(context).size.width >= 500)
                           Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_currencyFormat.format(totalRemaining),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.danger,
                                        fontSize: 15)),
                                const Text("Unpaid",
                                    style: TextStyle(
                                        color: AppColors.danger, fontSize: 10)),
                              ],
                            ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.payments_outlined,
                              color: AppColors.info, size: 20),
                          onPressed: () => _showPartialPaymentDialog(items),
                          tooltip: "Record Partial Payment",
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 20),
                          onPressed: () async {
                            LoadingOverlay.show(context);
                            try {
                              final user = Provider.of<AuthService>(context, listen: false).user!;
                              final totalRem = items.fold(0.0, (sum, it) => sum + ((it['debtRemaining'] ?? 0.0) as num).toDouble());
                              await _repo.updateDebtPayments(user, items, totalRem);
                              if (mounted) rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(content: Text("All marked as paid!"), duration: Duration(seconds: 2)));
                            } catch(e) {
                              if (mounted) rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(content: Text("Error: $e"), duration: const Duration(seconds: 2)));
                            } finally {
                              if (mounted) LoadingOverlay.hide(context);
                            }
                          },
                          tooltip: "Mark ALL as Paid",
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }



  Widget _buildAuditLogTab(AppUser user) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.watchAuditLogs(user.shopId).toMainThread(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        
        var logs = snap.data!.where((d) {
          final m = d;
          if (!user.roles.contains(UserRole.admin) && !user.roles.contains(UserRole.manager)) {
            if ((m['username'] ?? '').toString() != user.username) return false;
          }
          if (_selectedAuditAction != 'All Actions' && m['action'] != _selectedAuditAction) return false;
          final userFilter = _selectedAuditUserFilter.toLowerCase();
          if (userFilter.isNotEmpty && (m['username'] ?? '').toString().toLowerCase() != userFilter) return false;
          
          // Branch filtering
          if (_selectedBranchId != 'all') {
            final bId = m['branchId']?.toString() ?? 'main';
            if (bId != _selectedBranchId) return false;
          }

          final q = _searchAuditC.text.toLowerCase();
          if (q.isNotEmpty) {
            return (m['details'] ?? '').toString().toLowerCase().contains(q) ||
                   (m['username'] ?? '').toString().toLowerCase().contains(q);
          }
          return true;
        }).toList();

        logs.sort((a, b) {
          final ta = parseDT((a)['timestamp']) ?? DateTime.now();
          final tb = parseDT((b)['timestamp']) ?? DateTime.now();
          return tb.compareTo(ta);
        });

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: false,
              elevation: 0,
              toolbarHeight: 64,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              automaticallyImplyLeading: false,
              flexibleSpace: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchAuditC,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: "Search logs...",
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          fillColor: Theme.of(context).colorScheme.surface,
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _db.watchUsers(user.shopId).toMainThread(),
                      builder: (ctx, userSnap) {
                        List<String> usernames = ['All Users'];
                        if (userSnap.hasData) {
                          for (var m in userSnap.data!) {
                            final un = m['username'] as String?;
                            if (un != null && !usernames.contains(un)) usernames.add(un);
                          }
                        }
                        return Container(
                          width: 120,
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border.withOpacity(0.5))),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedAuditUserFilter.isEmpty ? 'All Users' : _selectedAuditUserFilter,
                              isExpanded: true,
                              iconEnabledColor: Theme.of(context).brightness == Brightness.light ? Colors.black87 : Colors.white70,
                              style: TextStyle(
                                fontSize: 12, 
                                color: Theme.of(context).brightness == Brightness.light ? Colors.black87 : AppColors.textPrimary
                              ),
                              items: usernames.map((un) => DropdownMenuItem(value: un, child: Text(un, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _selectedAuditUserFilter = v == 'All Users' ? '' : v!),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 120,
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border.withOpacity(0.5))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedAuditAction,
                          isExpanded: true,
                          iconEnabledColor: Theme.of(context).brightness == Brightness.light ? Colors.black87 : Colors.white70,
                          style: TextStyle(
                            fontSize: 12, 
                            color: Theme.of(context).brightness == Brightness.light ? Colors.black87 : AppColors.textPrimary
                          ),
                          items: ['All Actions', 'SALE', 'REFUND', 'PURCHASE', 'RESTOCK', 'ADD_PRODUCT', 'EDIT_PRODUCT', 'LOGIN', 'BRANCH_TRANSFER', 'DEBT_PAYMENT', 'Bulk Import', 'Bulk Import Cancelled']
                              .map((e) {
                                String label = e.replaceAll('_', ' ');
                                if (e == 'BRANCH_TRANSFER') label = 'TRANSFER STOCK';
                                if (e == 'DEBT_PAYMENT') label = 'CUSTOMER DEBT';
                                return DropdownMenuItem(value: e, child: Text(label, overflow: TextOverflow.ellipsis));
                              }).toList(),
                          onChanged: (v) => setState(() => _selectedAuditAction = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (logs.isEmpty)
              const SliverFillRemaining(child: Center(child: Text("No audit records found.")))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final d = logs[i];
                      final ts = parseDT(d['timestamp']) ?? DateTime.now();
                      final action = d['action']?.toString() ?? 'INFO';
                      String displayAction = action.replaceAll('_', ' ');
                      if (action == 'BRANCH_TRANSFER') displayAction = 'TRANSFER STOCK';
                      if (action == 'DEBT_PAYMENT') displayAction = 'CUSTOMER DEBT';
                      
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        onTap: () => _showAuditDetailDialog(d),
                       leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: _getAuditColor(action).withOpacity(0.1),
                          child: Icon(_getAuditIcon(action), color: _getAuditColor(action), size: 14)),
                        title: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    () {
                                      // For debt entries: show a short summary, full detail is in the tap dialog
                                      if (action == 'DEBT_PAYMENT') {
                                        final raw = d['details']?.toString() ?? '';
                                        final custSale = RegExp(r'Debt Sale to (.+?):').firstMatch(raw);
                                        final custPay  = RegExp(r'Payment from (.+?) of').firstMatch(raw);
                                        if (custSale != null) return 'Debt Sale → ${custSale.group(1)}';
                                        if (custPay  != null) return 'Payment from ${custPay.group(1)}';
                                        return 'Customer Debt';
                                      }
                                      return d['details']?.toString().toTitleCase() ?? '';
                                    }(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  if (_selectedBranchId == 'all')
                                    Text("Branch: ${d['branchId'] ?? 'Main'}", 
                                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withOpacity(0.7))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          "${d['username'].toString().toTitleCase()} • ${DateFormat('MMM d, hh:mm a').format(ts)}",
                          style: const TextStyle(fontSize: 11)),
                        trailing: PastelBadge(label: displayAction.toUpperCase(), baseColor: _getAuditColor(action)),
                      );
                    },
                    childCount: logs.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
  void _showAuditDetailDialog(Map<String, dynamic> d) {
    final action = d['action']?.toString() ?? '';
    final details = d['details']?.toString() ?? 'No extra info';
    final ts = parseDT(d['timestamp']) ?? DateTime.now();
    final isDebtAction = action == 'DEBT_PAYMENT';

    // Parse structured debt details from the stored string
    String? customer, advance, remaining, total, units, item;
    if (isDebtAction) {
      // Pattern: "Debt Sale to CUSTOMER: QTY units of ITEM. Adv: X, Rem: Y. Total: Z"
      // OR: "Payment from CUSTOMER of AMOUNT. Remainder: REM"
      final custSaleMatch = RegExp(r'Debt Sale to (.+?): (\d+(?:\.\d+)?) units of (.+?)\. Adv: ([\d.]+), Rem: ([\d.]+)\. Total: ([\d.]+)').firstMatch(details);
      final custPayMatch = RegExp(r'Payment from (.+?) of ([\d.]+)\. Remainder: ([\d.]+)').firstMatch(details);
      if (custSaleMatch != null) {
        customer = custSaleMatch.group(1);
        units    = custSaleMatch.group(2);
        item     = custSaleMatch.group(3);
        advance  = custSaleMatch.group(4);
        remaining = custSaleMatch.group(5);
        total    = custSaleMatch.group(6);
      } else if (custPayMatch != null) {
        customer  = custPayMatch.group(1);
        advance   = custPayMatch.group(2); // amount paid now
        remaining = custPayMatch.group(3);
      }
    }

    final isBulkImport = action == 'Bulk Import' || action == 'BULK_IMPORT' || action == 'Bulk Import Cancelled' || action == 'BULK_IMPORT_CANCELLED';

    // Parse structured bulk import details if available
    // Format: "Total Rows: X | Imported: X | Updated: X | Skipped: X | Failed: X"
    String? imported, updated, skipped, failed, totalRows;
    if (isBulkImport) {
      final impM = RegExp(r'Imported:\s*(\d+)').firstMatch(details);
      final updM = RegExp(r'Updated:\s*(\d+)').firstMatch(details);
      final skpM = RegExp(r'Skipped:\s*(\d+)').firstMatch(details);
      final faiM = RegExp(r'Failed:\s*(\d+)').firstMatch(details);
      final totM = RegExp(r'Total Rows:\s*(\d+)').firstMatch(details);
      if (impM != null) imported = impM.group(1);
      if (updM != null) updated = updM.group(1);
      if (skpM != null) skipped = skpM.group(1);
      if (faiM != null) failed = faiM.group(1);
      if (totM != null) totalRows = totM.group(1);
    }

    String displayAction = action.replaceAll('_', ' ');
    if (action == 'BRANCH_TRANSFER') displayAction = 'TRANSFER STOCK';
    if (action == 'DEBT_PAYMENT') displayAction = 'CUSTOMER DEBT';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _getAuditColor(action).withOpacity(0.1),
              child: Icon(_getAuditIcon(action), color: _getAuditColor(action), size: 14),
            ),
            const SizedBox(width: 12),
            Text(displayAction, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow("User", d['username']?.toString() ?? 'System'),
              _detailRow("Branch", d['branchId']?.toString() ?? 'Main'),
              _detailRow("Timestamp", DateFormat('MMM d, yyyy  HH:mm').format(ts)),
              const Divider(height: 20),
              if (isDebtAction && customer != null) ...[
                const Text("Debt Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary)),
                const SizedBox(height: 8),
                _detailRow("Customer", customer),
                if (item != null) _detailRow("Item", item),
                if (units != null) _detailRow("Quantity", units),
                if (total != null) _detailRow("Total Price", total),
                _detailRow("Advance Paid", advance ?? '0.00'),
                _detailRow("Remaining Balance", remaining ?? '0.00'),
              ] else if (isBulkImport) ...[
                const Text("Imported inventory from Excel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                const SizedBox(height: 12),
                if (imported != null) _detailRow("Imported", imported),
                if (updated != null) _detailRow("Updated", updated),
                if (skipped != null) _detailRow("Skipped", skipped),
                if (failed != null) _detailRow("Failed", failed),
                if (totalRows != null) _detailRow("Total Rows", totalRows),
                if (imported == null && updated == null) ...[
                  const SizedBox(height: 4),
                  Text(details, style: const TextStyle(fontSize: 13)),
                ],
              ] else ...[
                const Text("Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Text(details, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }


  IconData _getAuditIcon(String? action) {
    switch (action) {
      case 'SALE':            return Icons.shopping_cart_outlined;
      case 'PURCHASE':        return Icons.receipt_long_outlined;
      case 'RESTOCK':         return Icons.inventory_outlined;
      case 'ADD_PRODUCT':     return Icons.add_box_outlined;
      case 'EDIT_PRODUCT':    return Icons.edit_outlined;
      case 'DELETE_REQUEST':  return Icons.delete_sweep_outlined;
      case 'DELETE_ITEM':     return Icons.delete_forever_outlined;
      case 'BRANCH_TRANSFER': return Icons.swap_horiz_rounded;
      case 'DEBT_PAYMENT':    return Icons.account_balance_wallet_outlined;
      case 'REFUND':          return Icons.undo_rounded;
      case 'LOGIN':           return Icons.login_rounded;
      default:                return Icons.history_rounded;
    }
  }

  Color _getAuditColor(String? action) {
    if (action == 'SALE')            return AppColors.success;
    if (action == 'DEBT_PAYMENT')    return AppColors.warning;
    if (action == 'PURCHASE')        return AppColors.info;
    if (action == 'RESTOCK')         return const Color(0xFF6C63FF);
    if (action == 'REFUND')          return Colors.orange;
    if (action == 'LOGIN')           return Colors.teal;
    if (action == 'BRANCH_TRANSFER') return Colors.blue;
    if (action == 'DELETE_REQUEST' ||
        action == 'DELETE_ITEM')     return AppColors.danger;
    if (action == 'ADD_PRODUCT' ||
        action == 'EDIT_PRODUCT')    return AppColors.secondary;
    return AppColors.secondary;
  }

  Future<void> _handleDeleteProduct(AppUser u, String id, String name) async {
    final bool isStaff = u.roles.contains(UserRole.inventoryStaff) || u.roles.contains(UserRole.cashier);

    if (isStaff) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Request Deletion?"),
          content: Text(
              "Staff members cannot delete items directly. Send a deletion request for '$name' to Admin?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel")),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Send Request")),
          ],
        ),
      );
      if (confirm == true) {
        LoadingOverlay.show(context);
        await _db.addNotification({
          'shopId': u.shopId,
          'title': 'Deletion Request',
          'message': "Staff '${u.username}' requested deletion of '$name'",
          'type': 'deletion_request',
          'targetRole': 'admin',
          'itemId': id,
        });
        await _db.recordAuditLog(u.shopId, u.username, 'DELETE_REQUEST',
            'Requested deletion for $name');
        if (mounted) {
          LoadingOverlay.hide(context);
          rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(
              content: Text('Request sent to Admin!'),
              duration: Duration(seconds: 2),
              backgroundColor: AppColors.info));
        }
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Delete Product?"),
          content: Text(
              "Are you sure you want to PERMANENTLY delete '$name'? This action cannot be undone."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel")),
            ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Delete")),
          ],
        ),
      );
      if (confirm == true) {
        LoadingOverlay.show(context);
        try {
          await _repo.deleteItem(u, id);
          if (mounted) {
            rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(
                content: Text('Product and local cache purged successfully.'),
                duration: Duration(seconds: 2),
                backgroundColor: AppColors.success));
          }
        } catch (e) {
          if (mounted)
            rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                content: Text('Delete failed: $e'),
                duration: const Duration(seconds: 2),
                backgroundColor: AppColors.danger));
        } finally {
          if (mounted) LoadingOverlay.hide(context);
        }
      }
    }
  }

  void _showPartialPaymentDialog(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return;
    final remaining = items.fold(
        0.0, (sum, i) => sum + ((i)['debtRemaining'] ?? 0.0));

    final payC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Record Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Remaining Debt: ${_currencyFormat.format(remaining)}"),
            const SizedBox(height: 16),
            TextField(
                controller: payC,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: "Payment Amount (ETB)")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(payC.text) ?? 0.0;
              if (amt <= 0) return;

              try {
                LoadingOverlay.show(context);
                final user = Provider.of<AuthService>(context, listen: false).user!;
                await _repo.updateDebtPayments(user, items, amt);
                if (mounted) {
                  Navigator.pop(ctx);
                  rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(
                      content: Text("Payment Successful!"),
                      backgroundColor: AppColors.success));
                }
              } catch (e) {
                if (mounted)
                  rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: AppColors.danger));
              } finally {
                if (mounted) LoadingOverlay.hide(context);
              }

            },
            child: const Text("Apply Payment"),
          ),
        ],
      ),
    );
  }

  Widget _buildAddItemFAB(AppUser u) => FloatingActionButton(
        backgroundColor: AppColors.secondary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
        onPressed: () => _showAddItemDialog(u),
      );

  Widget _buildAddPurchaseFAB(AppUser u) => FloatingActionButton(
        backgroundColor: AppColors.secondary,
        child: const Icon(Icons.add_to_photos_rounded, color: Colors.white),
        onPressed: () => _showAdminPurchaseDialog(u),
      );

  void _showDebtDetailDialog(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return;
    final totalRem =
        items.fold(0.0, (sum, i) => sum + (i['debtRemaining'] ?? 0));
    final first = items.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Debt Information"),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow("Customer", first['customerName'] ?? 'Unknown'),
              _detailRow("Sold By", first['username'] ?? '-'),
              const Divider(),
              const Text("Purchased Items:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              ...items.map((it) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${it['itemName']} (x${it['quantity']})",
                            style: const TextStyle(fontSize: 12)),
                        Text(_currencyFormat.format(it['totalPrice'] ?? 0),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
              const Divider(),
              _detailRow(
                  "Advanced Paid",
                  _currencyFormat.format(
                      items.fold(0.0, (s, i) => s + (i['advancedPaid'] ?? 0)))),
              _detailRow("Remaining Total", _currencyFormat.format(totalRem),
                  color: AppColors.danger),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Close"))
        ],
      ),
    );
  }

  Widget _buildReportSectionTitle(String title, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _buildHorizontalInventoryList(
      List<Map<String, dynamic>> items, BoxDecoration decor,
      {required Color color}) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (ctx, i) {
          final d = items[i];
          return Container(
            width: 250,
            padding: const EdgeInsets.all(16),
            decoration: decor.copyWith(
                border: Border.all(color: color.withOpacity(0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text("Stock: ${d['quantity']}",
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(d['barcode'] ?? '-',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary)),
                    Text(_currencyFormat.format(d['sellingPrice'] ?? 0),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _launchScanner(TextEditingController controller) async {
    if (!kIsWeb && Platform.isWindows) {
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Use Physical Scanner"),
          content: const Text("Camera-based scanning is unsupported on Windows. Please use a physical scanner or type manually."),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))],
        ),
      );
      return;
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final code = barcodes.first.rawValue;
              if (code != null) {
                controller.text = code;
                Navigator.pop(ctx);
                final user = Provider.of<AuthService>(context, listen: false).user;
                if (user != null) _handlePOSSearch(code, user);
              }
            }
          },
        ),
      ),
    );
  }

  void _handlePOSSearch(String query, AppUser user) async {
    setState(() {
      _searchQuery = query.toLowerCase();
    });

    if (query.isNotEmpty) {
      final snapshot = await _db.watchProducts(user.shopId, branchId: _selectedBranchId == 'all' ? null : _selectedBranchId).first;
      final matches = snapshot.where((d) {
        final m = d;
        return (m['barcode']?.toString() ?? '') == query.trim();
      }).toList();

      if (matches.length == 1) {
        _showQuickSellDialog(matches.first, user);
        _posBarcodeC.clear();
        setState(() => _searchQuery = '');
      }
    }
  }

  void _showQuickSellDialog(Map<String, dynamic> doc, AppUser user) {
    final d = doc;
    final qtyC = TextEditingController(text: '1');
    final stock = (d['quantity'] ?? 0).toInt();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Quick Sell: ${d['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Price: ${_currencyFormat.format(d['sellingPrice'] ?? 0)}"),
            Text(
              "Stock Available: $stock",
              style: TextStyle(
                  color: stock < 5 ? AppColors.danger : AppColors.success,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyC,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Quantity to Sell", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () async {
              final val = int.tryParse(qtyC.text) ?? 0;
              if (val <= 0 || val > stock) return;
              Navigator.pop(ctx);
              LoadingOverlay.show(context);
              try {
                await _repo.recordSale(user, {
                  'shopId': user.shopId,
                  'branchId': user.branchId ?? 'main',
                  'userId': user.id,
                  'username': user.username,
                  'itemId': doc['id'],
                  'itemName': d['name'],
                  'quantity': val,
                  'totalPrice': (d['sellingPrice'] ?? 0) * val,
                  'profit':
                      ((d['sellingPrice'] ?? 0) - (d['buyingPrice'] ?? 0)) * val,
                  'timestamp': DateTime.now().toIso8601String(),
                });
                if (mounted)
                  rootScaffoldMessengerKey.currentState!.showSnackBar(const SnackBar(
                      content: Text('Sale recorded successfully!'),
                      backgroundColor: AppColors.success));
              } catch (e) {
                if (mounted)
                  rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                      content: Text('Sale Failed: $e'),
                      backgroundColor: AppColors.danger));
              } finally {
                if (mounted) LoadingOverlay.hide(context);
              }
            },
            child: const Text("Sell Now"),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────
// _InventoryTabView — fully self-contained inventory tab widget.
// State mutation during build() is the root cause of the
// `!semantics.parentDataDirty` assertion crash. By extracting this
// into its own StatefulWidget we guarantee clean rebuild semantics.
// ─────────────────────────────────────────────────────────────────
class _InventoryTabView extends StatefulWidget {
  final AppUser user;
  final DatabaseService db;
  final String branchId;
  final void Function(Map<String, dynamic>? data, String? id) onAddItem;
  final VoidCallback onAddItemNew;
  final void Function(Map<String, dynamic> prefill) onRestock;
  final void Function(String id, String name) onDelete;
  final VoidCallback onImport;
  final VoidCallback onRestockSearch;
  final Future<void> Function(TextEditingController) onScanSearch;
  final VoidCallback onTransfer;
  final NumberFormat currencyFormat;

  const _InventoryTabView({
    required this.user,
    required this.db,
    required this.branchId,
    required this.onAddItem,
    required this.onAddItemNew,
    required this.onRestock,
    required this.onDelete,
    required this.onImport,
    required this.onRestockSearch,
    required this.onScanSearch,
    required this.onTransfer,
    required this.currencyFormat,
  });

  @override
  State<_InventoryTabView> createState() => _InventoryTabViewState();
}

class _InventoryTabViewState extends State<_InventoryTabView> {
  final Map<String, bool> _branchExpanded = {};
  final Set<String> _selectedIds = {};
  bool _isSelectMode = false;
  final TextEditingController _searchC = TextEditingController();
  String _searchQuery = "";

  void _showSnackBar(String message, {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final color = isError ? AppColors.danger : (isWarning ? AppColors.warning : AppColors.success);
    final icon = isError ? Icons.error_outline_rounded : (isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded);
    final ms = isError ? 2000 : (isWarning ? 1500 : 1000);
    rootScaffoldMessengerKey.currentState!.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.25, end: 0, curve: Curves.easeOutQuad),
        backgroundColor: color,
        duration: Duration(milliseconds: ms),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

   String _filter = 'All';
   late Stream<List<Map<String, dynamic>>> _inventoryStream;

  @override
  void initState() {
    super.initState();
    _inventoryStream = widget.db.watchProducts(
      widget.user.shopId,
      branchId: widget.branchId == 'all' ? null : widget.branchId,
    ).toMainThread();
  }

  @override
  void didUpdateWidget(_InventoryTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      setState(() {
        _inventoryStream = widget.db.watchProducts(
          widget.user.shopId,
          branchId: widget.branchId == 'all' ? null : widget.branchId,
        ).toMainThread();
      });
    }
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.db.watchProducts(widget.user.shopId, branchId: widget.branchId == 'all' ? null : widget.branchId).toMainThread(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Inventory Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final allDocs = snapshot.data!;
        final now = DateTime.now();

        // ── Compute available filters ─────────────────────────────────────
        final Set<String> availableFilters = {'All'};
        for (var doc in allDocs) {
          final qty = (doc['quantity'] ?? 0) as num;
          final lt = (doc['lowStockThreshold'] ?? 5) as num;
          final ed = doc['expiry'] ?? doc['exp'] ?? doc['expiryDate'];
          DateTime? expiry = ed != null ? parseDT(ed) : null;
          if (expiry != null && expiry.isBefore(now)) availableFilters.add('Expired');
          else if (expiry != null && expiry.difference(now).inDays <= 30) availableFilters.add('Expiring Soon');
          if (qty <= 0) availableFilters.add('Out of Stock');
          else if (qty <= lt) availableFilters.add('Low Stock');
          else availableFilters.add('Healthy');
        }
        final filtersList = availableFilters.toList()..sort();
        filtersList.remove('All');
        filtersList.insert(0, 'All');

        // ── Inventory Filter Logic ────────────────────────────────────────
        final items = allDocs.where((doc) {
          final m = doc;
          final name = (m['name']?.toString().toLowerCase() ?? '');
          final barcode = (m['barcode']?.toString().toLowerCase() ?? '');
          final qty = (m['quantity'] ?? 0) as num;
          final lt = (m['lowStockThreshold'] ?? 5) as num;
          final ed = m['expiry'] ?? m['exp'] ?? m['expiryDate'];
          DateTime? exp = ed != null ? parseDT(ed) : null;

          bool ok = true;
          switch (_filter) {
            case 'Healthy': ok = qty > lt; break;
            case 'Low Stock': ok = qty > 0 && qty <= lt; break;
            case 'Out of Stock': ok = qty <= 0; break;
            case 'Expiring Soon': ok = exp != null && exp.isAfter(now) && exp.difference(now).inDays <= 30; break;
            case 'Expired': ok = exp != null && exp.isBefore(now); break;
            default: ok = true;
          }
          return ok && (name.contains(_searchQuery) || barcode.contains(_searchQuery));
        }).toList();

        return Stack(
          children: [
            Column(
              children: [
                if (_isSelectMode) _buildSelectionBar(allDocs, isMobile),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                SliverAppBar(
                  floating: true,
                  pinned: false,
                  elevation: 0,
                  toolbarHeight: 64,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  automaticallyImplyLeading: false,
                  flexibleSpace: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        SizedBox(
                          width: isMobile ? double.infinity : 450,
                          child: TextField(
                            controller: _searchC,
                            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                            onSubmitted: (v) {
                              if (v.isNotEmpty) {
                                setState(() => _searchQuery = v.toLowerCase());
                              }
                            },
                            decoration: InputDecoration(
                              hintText: "Search items...",
                              prefixIcon: const Icon(Icons.search_rounded, size: 18),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                                onPressed: () {
                                    widget.onScanSearch(_searchC).then((v) {
                                      if (_searchC.text.isNotEmpty) {
                                        setState(() => _searchQuery = _searchC.text.toLowerCase());
                                      }
                                    });
                                },
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              fillColor: Theme.of(context).colorScheme.surface,
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border.withOpacity(0.5)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _filter,
                              items: filtersList.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) => setState(() => _filter = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState())
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, isMobile ? 120 : 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _buildItemCard(items[i], isMobile),
                        childCount: items.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
            if (!isMobile)
              Positioned(
                bottom: 16, right: 32,
                child: _buildDesktopBottomBar(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.user.hasPermission(AppUser.pAddInventory))
            _buildHeaderButton(onPressed: widget.onAddItemNew, icon: Icons.add_rounded, label: "Product"),
          const SizedBox(width: 8),
          if (widget.user.hasPermission(AppUser.pRestockInventory))
            _buildHeaderButton(onPressed: widget.onRestockSearch, icon: Icons.add_to_photos_rounded, label: "Restock", color: AppColors.info),
          const SizedBox(width: 8),
          if (widget.user.hasPermission(AppUser.pEditInventory))
            _buildHeaderButton(onPressed: widget.onImport, icon: Icons.upload_file_rounded, label: "Import", isOutlined: true),
          const SizedBox(width: 8),
          if (widget.user.hasPermission(AppUser.pTransferStock))
            _buildHeaderButton(onPressed: widget.onTransfer, icon: Icons.swap_horiz_rounded, label: "Transfer", color: AppColors.secondary),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64,
              color: AppColors.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No products found',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    Color? color,
    bool isOutlined = false,
  }) {
    final style = (isOutlined ? OutlinedButton.styleFrom : ElevatedButton.styleFrom)(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isOutlined ? null : color,
      foregroundColor: isOutlined ? null : (color != null ? Colors.white : null),
      minimumSize: const Size(0, 0), 
    );

    if (isOutlined) {
      return OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), style: style);
    }
    return ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), style: style);
  }

   void _showProductDetailDialog(Map<String, dynamic> product) async {
    // Isolated batch filtering: Only show batches for the CURRENT branch.
    // Batches are the single source of truth for prices and quantities.
    final streamBranchId = widget.branchId == 'all'
        ? product['branchId']?.toString()
        : widget.branchId;
    final allBatches = await widget.db
        .watchBatchesByItem(product['shopId'], product['id'],
            branchId: streamBranchId)
        .first;
    int batchIndex = 0;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setS) {
          // Use the batch row as single source of truth for prices/qty/expiry.
          // Fall back to the product doc only when there are no batch rows yet.
          final b = allBatches.isNotEmpty ? allBatches[batchIndex] : product;
          final exp = parseDT(b['expiry'] ?? b['exp'] ?? b['expiryDate']);

          final double batchBuyPrice = _toDouble(b['buyingPrice']);
          final double batchSellPrice = _toDouble(b['sellingPrice']);
          final double batchProfit = batchSellPrice - batchBuyPrice;
          final double batchQty = _toDouble(b['quantity']);
          final String branchDisplay =
              (b['branchId']?.toString() ?? streamBranchId ?? 'main')
                  .toUpperCase();

          return AlertDialog(
            title: Text(product['name'] ?? 'Product Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (allBatches.length > 1) ...[
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                     decoration: BoxDecoration(
                       color: AppColors.secondary.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(20),
                     ),
                     child: Text(
                       "Batch ${batchIndex + 1} of ${allBatches.length}",
                       style: const TextStyle(
                         fontSize: 10,
                         fontWeight: FontWeight.bold,
                         color: AppColors.secondary,
                       ),
                     ),
                   ),
                   const SizedBox(height: 12),
                ],
                _detailRow("Barcode", product['barcode']?.toString().isNotEmpty == true ? product['barcode'].toString() : '-'),
                _detailRow("Branch", branchDisplay),
                _detailRow("Selling Price", widget.currencyFormat.format(batchSellPrice)),
                _detailRow("Buying Cost", widget.currencyFormat.format(batchBuyPrice)),
                _detailRow(
                  "Batch Profit",
                  "${batchProfit >= 0 ? '+' : ''}${widget.currencyFormat.format(batchProfit)}",
                ),
                _detailRow("Stock (this batch)", "${batchQty.toStringAsFixed(batchQty.truncateToDouble() == batchQty ? 0 : 2)}"),
                _detailRow("Expiry", exp != null ? DateFormat('MMM dd, yyyy').format(exp) : "No Expiry"),
                if (allBatches.length > 1) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  _detailRow(
                    "Total Stock (all batches)",
                    "${allBatches.fold<double>(0, (s, b) => s + _toDouble(b['quantity'])).toStringAsFixed(0)}",
                  ),
                ],
              ],
            ),
            actions: [
              if (allBatches.length > 1)
                TextButton(
                  onPressed: () {
                    setS(() {
                      batchIndex = (batchIndex + 1) % allBatches.length;
                    });
                  },
                  child: const Text("Next Batch"),
                ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
            ],
          );
        }
      ),
    );
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> doc, bool isMobile) {
    final d = doc;
    final now = DateTime.now();
    final qty = (d['quantity'] ?? 0) as num;
    final isOut = qty <= 0;
    final lt = (d['lowStockThreshold'] ?? 5) as num;
    final isLow = !isOut && qty <= lt;

    final ed = d['expiry'] ?? d['exp'] ?? d['expiryDate'];
    Widget? expiryBadge;
    if (ed != null) {
      final exp = parseDT(ed);
      if (exp != null) {
        final days = exp.difference(now).inDays;
        if (days < 0) {
          expiryBadge = const PastelBadge(label: 'EXPIRED', baseColor: AppColors.danger);
        } else if (days < 7) {
          expiryBadge = PastelBadge(label: 'Expiring Soon ($days d left)', baseColor: AppColors.danger);
        } else if (days < 30) {
          expiryBadge = PastelBadge(label: 'Expiring Soon ($days d left)', baseColor: Colors.orange);
        }
      }
    }

    final branchId = d['branchId']?.toString() ?? 'main';
    final branchName = widget.branchId == 'all' ? branchId.toUpperCase() : null;

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.user.hasPermission(AppUser.pEditInventory))
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => widget.onAddItem(d, doc['id']),
          ),
        const SizedBox(width: 8),
        if (widget.user.hasPermission(AppUser.pRestockInventory))
          IconButton(
            icon: const Icon(Icons.add_to_photos_rounded, color: AppColors.info, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => widget.onRestock({
              'id': doc['id'], 'name': d['name'], 'barcode': d['barcode'],
              'buyingPrice': d['buyingPrice'], 'sellingPrice': d['sellingPrice'],
            }),
          ),
        const SizedBox(width: 8),
        if (widget.user.hasPermission(AppUser.pDeleteInventory))
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => widget.onDelete(doc['id'], d['name'] ?? ''),
          ),
      ],
    );

    final isSelected = _selectedIds.contains("${doc['id']}@${doc['branchId']}");
    
    return InkWell(
      onLongPress: isMobile ? () {
        final compositeId = "${doc['id']}@${doc['branchId']}";
        setState(() {
          _isSelectMode = true;
          _selectedIds.add(compositeId);
        });
      } : null,
      onTap: () {
        final compositeId = "${doc['id']}@${doc['branchId']}";
        if (_isSelectMode) {
          setState(() {
            if (_selectedIds.contains(compositeId)) {
              _selectedIds.remove(compositeId);
              if (_selectedIds.isEmpty) _isSelectMode = false;
            } else {
              _selectedIds.add(compositeId);
            }
          });
        } else {
          _showProductDetailDialog(d);
        }
      },
      child: StatefulBuilder(builder: (ctx, setHover) {
        bool isCardHovered = false;
        final cardColor = isSelected ? AppColors.secondary.withOpacity(0.1) : (isCardHovered ? const Color(0xFF1A1A1A) : null);
        final primaryTextColor = (isCardHovered && !isSelected) ? Colors.white : null;
        final secondaryTextColor = (isCardHovered && !isSelected) ? Colors.white70 : AppColors.textSecondary;

        return MouseRegion(
          onEnter: (_) => setHover(() => isCardHovered = true),
          onExit: (_) => setHover(() => isCardHovered = false),
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: cardColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                    color: isSelected ? AppColors.secondary : AppColors.border, 
                    width: isSelected ? 1.5 : 0.5)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!isMobile) ...[
                               GestureDetector(
                                 behavior: HitTestBehavior.opaque,
                                 onTap: () {
                                   final compositeId = "${doc['id']}@${doc['branchId']}";
                                   setState(() {
                                     if (isSelected) {
                                       _selectedIds.remove(compositeId);
                                       if (_selectedIds.isEmpty) _isSelectMode = false;
                                     } else {
                                       _selectedIds.add(compositeId);
                                       _isSelectMode = true;
                                     }
                                   });
                                 },
                                 child: IgnorePointer(
                                   child: SizedBox(
                                     width: 24,
                                     height: 24,
                                     child: Checkbox(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        side: BorderSide(color: isSelected ? AppColors.secondary : (isCardHovered ? Colors.white : AppColors.border), width: 1.5),
                                        activeColor: AppColors.secondary,
                                        checkColor: Colors.white,
                                        value: isSelected,
                                        onChanged: (_) {},
                                      ),
                                    ),
                                 ),
                               ),
                               const SizedBox(width: 8),
                            ] else if (_isSelectMode) ...[
                               const SizedBox(width: 32), // Padding for checkbox overlay on mobile
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d['name']?.toString().toTitleCase() ?? 'No Name',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor)),
                                  if (branchName != null)
                                    Text("Branch: $branchName",
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isSelected ? AppColors.secondary : secondaryTextColor)),
                                  if ((d['barcode']?.toString() ?? '').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.barcode_reader, size: 10, color: secondaryTextColor),
                                          const SizedBox(width: 3),
                                          Text(d['barcode'].toString(),
                                              style: TextStyle(fontSize: 10, color: secondaryTextColor, letterSpacing: 0.5)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!_isSelectMode) actions,
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isOut ? AppColors.danger : (isLow ? Colors.orange : AppColors.success)).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text("Qty: $qty", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOut ? AppColors.danger : (isLow ? Colors.orange : AppColors.success))),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Price", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                Text(widget.currencyFormat.format(d['sellingPrice'] ?? 0), 
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryTextColor ?? AppColors.secondary)),
                              ],
                            ),
                            const Spacer(),
                            if (expiryBadge != null) expiryBadge,
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isMobile && (_isSelectMode || isCardHovered))
                    Positioned(
                      top: 4, left: 4,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final compositeId = "${doc['id']}@${doc['branchId']}";
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(compositeId);
                              if (_selectedIds.isEmpty) _isSelectMode = false;
                            } else {
                              _selectedIds.add(compositeId);
                              _isSelectMode = true;
                            }
                          });
                        },
                        child: IgnorePointer(
                          child: Checkbox(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            side: BorderSide(color: (isCardHovered && !isSelected) ? Colors.white : AppColors.secondary, width: 1.5),
                            activeColor: AppColors.secondary,
                            checkColor: Colors.white,
                            value: isSelected,
                            onChanged: (_) {},
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSelectionBar(List<Map<String, dynamic>> allDocs, bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.secondary),
            onPressed: () => setState(() {
              _isSelectMode = false;
              _selectedIds.clear();
            }),
          ),
          const SizedBox(width: 8),
          Text("${_selectedIds.length} items selected",
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
          const SizedBox(width: 16),
          if (isMobile)
             TextButton.icon(
                onPressed: () => setState(() {
                  _selectedIds.addAll(allDocs.map((e) => "${e['id']}@${e['branchId']}"));
                }),
                icon: const Icon(Icons.select_all_rounded, color: AppColors.secondary, size: 20),
                label: const Text("Select All", style: TextStyle(color: AppColors.secondary)),
              ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _handleBulkDelete(),
            icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger, size: 20),
            label: const Text("Delete Selected", style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBulkDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bulk Delete?"),
        content: Text("Are you sure you want to delete ${_selectedIds.length} items permanently?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete All"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      LoadingOverlay.show(context);
      try {
        for (var compositeId in _selectedIds.toList()) {
          final parts = compositeId.split('@');
          final id = parts[0];
          final branchId = parts.length > 1 ? parts[1] : null;

          if (branchId != null) {
             await widget.db.deleteProductFromBranch(widget.user.shopId, id, branchId);
          } else {
             await widget.db.delete('products', id);
          }
        }
        setState(() {
          _selectedIds.clear();
          _isSelectMode = false;
        });
        if (mounted) _showSnackBar("Bulk deletion success!");
      } catch (e) {
        if (mounted) _showSnackBar("Error: $e", isError: true);
      } finally {
        if (mounted) LoadingOverlay.hide(context);
      }
    }
  }


  Widget _infoSegment(String label, String val, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return TextField(
      controller: _searchC,
      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
      decoration: InputDecoration(
        hintText: 'Search products by name or barcode...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searchC.text.isNotEmpty)
              IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() {
                    _searchC.clear();
                    _searchQuery = '';
                  })),
            IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded,
                    size: 18, color: AppColors.secondary),
                onPressed: () => widget.onScanSearch(_searchC).then((_) {
                  if (_searchC.text.isNotEmpty) setState(() => _searchQuery = _searchC.text.toLowerCase());
                })),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
        border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onAddItemNew,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Product", style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onRestockSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_to_photos_rounded, size: 18),
              label: const Text("Restock", style: TextStyle(fontSize: 11)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onImport,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text("Bulk Import", style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight status badge — avoids rebuilding Container on every frame.
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}


/// Polished stateful dialog for Quick Sell to prevent AXTree spam and handle FocusNodes/Controllers correctly.
class _QuickSellDialog extends StatefulWidget {
  final Map<String, dynamic> doc;
  final bool isQuickSell;
  final Function(Map<String, dynamic> params) onAddToCart;

  const _QuickSellDialog({
    required this.doc,
    required this.isQuickSell,
    required this.onAddToCart,
  });

  @override
  State<_QuickSellDialog> createState() => _QuickSellDialogState();
}

class _QuickSellDialogState extends State<_QuickSellDialog> {
  late double qty;
  late TextEditingController qtyC;
  late TextEditingController buyerC;
  late TextEditingController advancedC;
  String paymentType = 'Cash';

  @override
  void initState() {
    super.initState();
    qty = 1.0;
    qtyC = TextEditingController(text: '1');
    buyerC = TextEditingController();
    advancedC = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    qtyC.dispose();
    buyerC.dispose();
    advancedC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    final stock = (d['quantity'] ?? 0).toDouble();
    final price = (d['sellingPrice'] ?? 0).toDouble();
    final subtotal = price * qty;
    final _currencyFormat = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 2);

    return AlertDialog(
      title: Text(widget.isQuickSell ? 'Quick Sell: ${d['name']}' : 'Add to Cart: ${d['name']}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stock Available: $stock', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: qtyC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => qty = double.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Subtotal: ${_currencyFormat.format(subtotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            if (widget.isQuickSell) ...[
              const SizedBox(height: 20),
              TextField(controller: buyerC, decoration: const InputDecoration(labelText: 'Customer Name (Optional)', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text("Payment Method:", style: TextStyle(fontWeight: FontWeight.bold))),
              Row(
                children: [
                  ChoiceChip(label: const Text("Cash"), selected: paymentType == 'Cash', onSelected: (_) => setState(() => paymentType = 'Cash')),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text("Debt"), selected: paymentType == 'Debt', onSelected: (_) => setState(() => paymentType = 'Debt')),
                ],
              ),
              if (paymentType == 'Debt') ...[
                const SizedBox(height: 12),
                TextField(controller: advancedC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Advanced Payment (ETB)', border: OutlineInputBorder())),
              ]
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: (qty > 0 && qty <= stock) ? () {
             widget.onAddToCart({
               'qty': qty,
               'buyer': buyerC.text,
               'paymentType': paymentType,
               'advanced': double.tryParse(advancedC.text) ?? 0,
             });
             Navigator.pop(context);
          } : null,
          child: Text(widget.isQuickSell ? 'Confirm Sale' : 'Add to Cart'),
        ),
      ],
    );
  }
}

class _PermissionSelectorDialog extends StatefulWidget {
  final AppUser adminUser;
  const _PermissionSelectorDialog({required this.adminUser});
  @override
  State<_PermissionSelectorDialog> createState() => _PermissionManagerDialogState();
}

class _PermissionManagerDialogState extends State<_PermissionSelectorDialog> {
  final nameC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();
  String selectedRole = 'staff';
  Map<String, bool> perms = {for (var p in AppUser.allPermissions) p: false};

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    rootScaffoldMessengerKey.currentState!.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.25, end: 0, curve: Curves.easeOutQuad),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        duration: Duration(milliseconds: isError ? 2000 : 1000),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _updateDefaultPerms('staff');
  }

  void _updateDefaultPerms(String role) {
    setState(() {
      if (role == 'admin') {
         perms = {for (var p in AppUser.allPermissions) p: true};
      } else if (role == 'manager') {
         perms = {for (var p in AppUser.allPermissions) p: true};
         perms[AppUser.pManageSubscription] = false;
         perms[AppUser.pViewProfit] = false;
      } else {
         perms = {for (var p in AppUser.allPermissions) p: false};
         perms[AppUser.pViewInventory] = true;
         perms[AppUser.pSellProducts] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = {
      'INVENTORY': [AppUser.pViewInventory, AppUser.pAddEditProducts, AppUser.pSetSellingPrice, AppUser.pTransferStock],
      'SALES': [AppUser.pSellProducts, AppUser.pRefundSales],
      'PURCHASES': [AppUser.pManagePurchases, AppUser.pViewPurchases],
      'REPORTS': [AppUser.pViewReports, AppUser.pExportReports, AppUser.pViewProfit],
      'USERS & BRANCHES': [AppUser.pManageUsers, AppUser.pManageBranches],
      'SYSTEM': [AppUser.pManageSettings, AppUser.pManageSubscription, AppUser.pViewAuditLogs],
    };
    return AlertDialog(
      title: const Text("Add New Staff"),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 12),
              TextField(controller: emailC, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email))),
              const SizedBox(height: 12),
              TextField(controller: passC, obscureText: true, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock))),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: "Role Template"),
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => selectedRole = v);
                    _updateDefaultPerms(v);
                  }
                },
              ),
              const Divider(height: 32),
              const Align(alignment: Alignment.centerLeft, child: Text("Detailed Permissions", style: TextStyle(fontWeight: FontWeight.bold))),
              for (var cat in categories.entries) ...[
                Padding(padding: const EdgeInsets.only(top: 12), child: Text(cat.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.secondary))),
                ...cat.value.map((p) => CheckboxListTile(
                  title: Text(p.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12)),
                  value: perms[p] ?? false,
                  dense: true,
                  onChanged: (v) => setState(() => perms[p] = v ?? false),
                )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            if (nameC.text.isEmpty || emailC.text.isEmpty || passC.text.isEmpty) return;
            Navigator.pop(context);
            LoadingOverlay.show(context);
            try {
              await Provider.of<AuthService>(context, listen: false).createStaffAccount(
                email: emailC.text.trim(),
                password: passC.text,
                username: nameC.text.trim(),
                fullName: nameC.text.trim(),
                shopId: widget.adminUser.shopId,
                branchId: widget.adminUser.branchId,
                branchName: widget.adminUser.branchName ?? 'Main Branch',
                role: selectedRole,
                permissions: perms,
              );
              _showSnackBar('Staff account created!');
            } catch (e) {
              rootScaffoldMessengerKey.currentState!.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
            } finally {
              LoadingOverlay.hide(context);
            }
          },
          child: const Text("Create Account"),
        ),
      ],
    );
  }
}

class _ImportProgressDialog extends StatefulWidget {
  final int total;
  final Function(Function(double progress, String status) update)? onStart;
  const _ImportProgressDialog({required this.total, this.onStart});

  @override
  State<_ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<_ImportProgressDialog> {
  double _progress = 0;
  String _status = "Starting...";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStart?.call((p, s) {
        if (mounted) setState(() { _progress = p; _status = s; });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Importing Products"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: _progress, color: AppColors.secondary, backgroundColor: AppColors.secondary.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(_status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
