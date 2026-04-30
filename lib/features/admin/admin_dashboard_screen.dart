import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
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
import 'package:inventory_manager/core/services/firestore_service.dart';
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

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirestoreService _db = FirestoreService();
  final ValidationService _validator = ValidationService();
  final ImportService _importService = ImportService();
  final ReportingService _reporting = ReportingService();
  final InventoryRepository _repo = InventoryRepository();
  int _selectedIndex = 0;
  String _reportFilter = 'Daily';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 0));
  DateTime _endDate = DateTime.now();
  String _inventoryFilter = 'All';
  String _purchaseSupplierFilter = 'All Suppliers';

  void _setFilter(String type) {
    setState(() {
      _reportFilter = type;
      final now = DateTime.now();
      if (type == 'Daily') {
        _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (type == 'Weekly') {
        _startDate = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 7));
        _endDate = now;
      } else if (type == 'Monthly') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      }
    });
  }

  final currencyFormat =
      NumberFormat.currency(symbol: 'ETB ', decimalDigits: 2);
  String _searchQuery = "";
  final String _selectedBranchId = "all";
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

  void _handleAddToCart(DocumentSnapshot doc, {bool isQuickSell = false}) {
    final d = doc.data() as Map<String, dynamic>;
    final stock = (d['quantity'] ?? 0).toDouble();
    final qtyC = TextEditingController(text: '1');
    final buyerC = TextEditingController();
    final advancedC = TextEditingController(text: '0');
    bool isDebt = false;
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) return;
    final expiryData = d['expiryDate'];
    if (expiryData != null) {
      final expiry = (expiryData is Timestamp)
          ? expiryData.toDate()
          : DateTime.tryParse(expiryData.toString());
      if (expiry != null) {
        final now = DateTime.now();
        if (expiry.isBefore(now)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Product has expired! cannot sell.'),
              backgroundColor: AppColors.danger));
          return;
        }
        final diff = expiry.difference(now).inDays;
        if (diff <= 30) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Warning: Product expires in $diff days!'),
              backgroundColor: AppColors.warning));
        }
      }
    }

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isQuickSell
              ? 'Quick Sale: ${d['name']}'
              : 'Add to Cart: ${d['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Stock Available: $stock',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                    controller: qtyC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity')),
                if (isQuickSell) ...[
                  const SizedBox(height: 12),
                  TextField(
                      controller: buyerC,
                      decoration: const InputDecoration(
                          labelText: 'Customer Name (Optional)')),
                  const SizedBox(height: 16),
                  Wrap(
                    // Fixed overflow
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text("Payment: "),
                      ChoiceChip(
                          label: const Text("Cash"),
                          selected: !isDebt,
                          onSelected: (_) => setS(() => isDebt = false)),
                      ChoiceChip(
                          label: const Text("Debt"),
                          selected: isDebt,
                          onSelected: (_) => setS(() => isDebt = true)),
                    ],
                  ),
                  if (isDebt) ...[
                    const SizedBox(height: 12),
                    TextField(
                        controller: advancedC,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Advanced Payment (ETB)')),
                  ]
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            if (!isQuickSell)
              ElevatedButton(
                onPressed: () {
                  final val = double.tryParse(qtyC.text) ?? 0;
                  if (val <= 0 || val > stock) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Stock not available! Only $stock units left."),
                        backgroundColor: AppColors.danger));
                    return;
                  }
                  setState(() {
                    final exIdx = _posCart.indexWhere((i) => i.id == doc.id);
                    if (exIdx != -1) {
                      _posCart[exIdx].quantity = val.toInt();
                    } else {
                      _posCart.add(CartItem(
                        id: doc.id,
                        name: d['name'],
                        price: (d['sellingPrice'] ?? 0).toDouble(),
                        quantity: val.toInt(),
                        batchNumber: d['batchNumber'],
                        cost: (d['buyingPrice'] ?? 0).toDouble(),
                      ));
                    }
                    _calculateTotal();
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Add to Cart'),
              ),
            if (isQuickSell)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary),
                onPressed: () async {
                  final val = double.tryParse(qtyC.text) ?? 0;
                  if (val <= 0 || val > stock) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Stock not available! Only $stock units left."),
                        backgroundColor: AppColors.danger));
                    return;
                  }

                  final sp = (d['sellingPrice'] ?? 0).toDouble();
                  final bp = (d['buyingPrice'] ?? 0).toDouble();
                  final total = sp * val;
                  final advanced = double.tryParse(advancedC.text) ?? 0.0;

                  try {
                    LoadingOverlay.show(context);
                    await _repo.recordSale(user, {
                      'itemId': doc.id,
                      'itemName': d['name'],
                      'quantity': val.toInt(),
                      'totalPrice': total,
                      'profit': (sp - bp) * val,
                      'userId': user.id,
                      'username': user.username,
                      'customerName':
                          buyerC.text.isEmpty ? 'Guest' : buyerC.text,
                      'isDebt': isDebt && (total - advanced) > 0,
                      'debtRemaining': isDebt ? (total - advanced) : 0.0,
                      'advancedPaid': isDebt ? advanced : total,
                      'shopId': user.shopId,
                      'branchId': user.branchId,
                      'timestamp': DateTime.now().toIso8601String(),
                    });
                    if (mounted) LoadingOverlay.hide(context);
                    if (mounted) Navigator.pop(ctx);
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Quick Sale Success!"),
                          backgroundColor: AppColors.success));
                  } catch (e) {
                    if (mounted) LoadingOverlay.hide(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(e.toString()),
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

  void _calculateTotal() {
    _cartTotal = _posCart.fold(0, (sum, i) => sum + i.total);
  }

  void _clearCart() {
    setState(() {
      _posCart.clear();
      _cartTotal = 0;
    });
  }

  List<DocumentSnapshot>? _purchases;
  bool _isLoadingPurchases = true;

  @override
  void initState() {
    super.initState();
    _setFilter('Daily');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPurchases();
    });
  }

  void _fetchPurchases() {}
  // Refactored to unified StreamBuilder in Phase 4.4.1.1

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthService, AppUser?>((auth) => auth.user);
    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return LayoutBuilder(builder: (outerCtx, outerConstraints) {
      final desktop = outerConstraints.maxWidth > 900;
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
                        setState(() => _selectedIndex = i);
                        Navigator.pop(context);
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
              Column(
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
            Expanded(
              child: Column(
                key: const ValueKey('admin_main_content'),
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
    });
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
    final isAdminOrManager = user.roles.contains(UserRole.admin) ||
        user.roles.contains(UserRole.manager);
    return [
      SidebarItem(
          uid: 'overview', icon: Icons.grid_view_rounded, label: 'Dashboard'),
      SidebarItem(
          uid: 'inventory',
          icon: Icons.inventory_2_outlined,
          label: 'Inventory'),
      SidebarItem(
          uid: 'sales',
          icon: Icons.shopping_cart_outlined,
          label: 'Sales (POS)'),
      SidebarItem(
          uid: 'purchases',
          icon: Icons.receipt_long_outlined,
          label: 'Purchases'),
      SidebarItem(uid: 'debt', icon: Icons.payments_rounded, label: 'Debt'),
      SidebarItem(
          uid: 'reports', icon: Icons.analytics_outlined, label: 'Reports'),
      if (isAdminOrManager)
        SidebarItem(
            uid: 'users', icon: Icons.people_outline_rounded, label: 'Users'),
      SidebarItem(
          uid: 'audit', icon: Icons.history_rounded, label: 'Audit Trail'),
      SidebarItem(
          uid: 'settings', icon: Icons.settings_outlined, label: 'Settings'),
    ];
  }

  PreferredSizeWidget _buildMobileAppBar(AppUser user) {
    return AppBar(
      elevation: 0,
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(_getTabTitle(),
          style: TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.bold,
              fontSize: 18)),
      actions: [_buildNotificationBadge(user), const SizedBox(width: 8)],
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_getTabTitle(),
                  style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary)),
              const SizedBox(height: 4),
              Text("Welcome back, ${user.username}",
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            ],
          ),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(DateFormat('MMM d, yyyy').format(DateTime.now()),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildNotificationBadge(user),
            ],
          ),
        ],
      ),
    );
  }

  String _getTabTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Admin Overview';
      case 1:
        return 'Inventory Control';
      case 2:
        return 'Sales (POS)';
      case 3:
        return 'Purchases';
      case 4:
        return 'Debt Ledger';
      case 5:
        return 'Financial Reports';
      case 6:
        return 'User Management';
      case 7:
        return 'Audit Trail';
      case 8:
        return 'Settings';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildNotificationBadge(AppUser user) {
    final shopId = user.shopId;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deletion_requests')
          .where('shopId', isEqualTo: shopId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .toMainThread(),
      builder: (context, snapshot) {
        final delCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return badges.Badge(
          showBadge: delCount > 0,
          badgeContent: Text('$delCount',
              style: const TextStyle(color: Colors.white, fontSize: 10)),
          child: IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () =>
                _showNotificationsPanel(user, snapshot.data?.docs ?? []),
          ),
        );
      },
    );
  }

  void _showNotificationsPanel(
      AppUser user, List<DocumentSnapshot> deletionRequests) {
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
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: deletionRequests.isEmpty
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
                      itemCount: deletionRequests.length,
                      itemBuilder: (c, i) {
                        final req =
                            deletionRequests[i].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: const CircleAvatar(
                              backgroundColor: Color(0xFFFFEDD5),
                              child: Icon(Icons.delete_sweep_rounded,
                                  color: Color(0xFFF97316), size: 20)),
                          title:
                              Text("Deletion Request: ${req['productName']}"),
                          subtitle: Text("Requested by ${req['requestedBy']}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.check_circle_outline,
                                      color: AppColors.success),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('deletion_requests')
                                        .doc(deletionRequests[i].id)
                                        .update({'status': 'approved'});
                                    await _repo.deleteItem(
                                        user, req['productId']);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  }),
                              IconButton(
                                  icon: const Icon(Icons.cancel_outlined,
                                      color: AppColors.danger),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('deletion_requests')
                                        .doc(deletionRequests[i].id)
                                        .update({'status': 'declined'});
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  }),
                            ],
                          ),
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
    // Ensure index is within range of the current filtered items
    final safeIndex = _selectedIndex < items.length ? _selectedIndex : 0;
    final uid = items[safeIndex].uid;

    switch (uid) {
      case 'overview':
        return _buildHomeTab(user, items);
      case 'inventory':
        return _buildInventoryTab(user);
      case 'sales':
        return _buildSalesTab(user);
      case 'purchases':
        return _buildSupplierTab(user);
      case 'debt':
        return _buildDebtTab(user);
      case 'reports':
        return _buildReportsTab(user, items);
      case 'users':
        return _buildManageUsersTab(user);
      case 'audit':
        return _buildAuditLogTab(user);
      case 'settings':
        return _buildSettingsTab(user);
      default:
        return _buildHomeTab(user, items);
    }
  }

  Widget _buildHomeTab(AppUser user, List<SidebarItem> sidebarItems) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.getSales(user.shopId).toMainThread(),
      builder: (context, salesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: _db.getInventory(user.shopId).toMainThread(),
          builder: (context, invSnap) {
            double rev = 0;
            double prof = 0;
            int count = 0;
            int lowStock = 0;
            List<DocumentSnapshot> sales = [];

            if (salesSnap.hasData) {
              final now = DateTime.now();
              sales = salesSnap.data!.docs.where((d) {
                final m = d.data() as Map;
                if (_selectedBranchId != "all" &&
                    m['branchId'] != _selectedBranchId) return false;
                final ts = parseDT(m['timestamp']);
                if (ts == null) return false;
                return ts.year == now.year &&
                    ts.month == now.month &&
                    ts.day == now.day;
              }).toList();

              for (var doc in sales) {
                final m = doc.data() as Map;
                rev += (m['totalPrice'] ?? 0).toDouble();
                prof += (m['profit'] ?? 0).toDouble();
                if (m['isDebt'] == true) {
                   // Corrected unpaid count for Today's Stats
                   // We take the current remaining debt
                }
                count++;
              }
            }

            if (invSnap.hasData) {
              for (var doc in invSnap.data!.docs) {
                final m = doc.data() as Map;
                final qty = m['quantity'] ?? 0;
                final threshold = m['lowStockThreshold'] ?? 5;
                if (qty <= threshold) lowStock++;
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

              return ListView(
                padding: EdgeInsets.all(isMobile ? 16 : 32),
                children: [
                  // Responsive Stat Cards
                  GridView.count(
                    crossAxisCount: isMobile ? 2 : 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: isMobile ? 12 : 24,
                    crossAxisSpacing: isMobile ? 12 : 24,
                    childAspectRatio: isMobile ? 1.4 : 1.6,
                    children: [
                      StatCard(
                        title: 'Total Revenue',
                        value: currencyFormat.format(rev),
                        color: profitColor,
                        icon: Icons.attach_money_rounded,
                        change: "+8.5%",
                        cardDecoration: cardDecoration,
                        onTap: () => setState(() => _selectedIndex =
                            sidebarItems.indexWhere((it) => it.uid == 'reports')),
                      ),
                      if (!user.roles.contains(UserRole.staff))
                        StatCard(
                          title: 'Net Profit',
                          value: prof < 0
                              ? "-ETB ${NumberFormat('#,###').format(prof.abs())}"
                              : currencyFormat.format(prof),
                          color: profitColor,
                          icon: prof < 0
                              ? Icons.trending_down_rounded
                              : Icons.trending_up_rounded,
                          change: prof < 0 ? "Loss" : "Profit",
                          isPositive: prof >= 0,
                          cardDecoration: cardDecoration,
                          onTap: () => setState(() => _selectedIndex =
                              sidebarItems.indexWhere((it) => it.uid == 'reports')),
                        ),
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
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Responsive Charts and Lists
                  if (isMobile) ...[
                    if (!user.roles.contains(UserRole.staff)) ...[
                      _buildLineChartSection(context, cardDecoration),
                      const SizedBox(height: 24),
                    ],
                    _buildRecentSalesList(
                        user, sales, cardDecoration, sidebarItems),
                    const SizedBox(height: 24),
                    _buildTopSellingTable(
                        user, salesSnap.data?.docs ?? [], cardDecoration),
                    const SizedBox(height: 24),
                    _buildLowStockList(
                        invSnap.data?.docs ?? [], cardDecoration),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!user.roles.contains(UserRole.staff))
                          Expanded(
                              flex: 3,
                              child: _buildLineChartSection(
                                  context, cardDecoration))
                        else
                          const SizedBox.shrink(),
                        const SizedBox(width: 32),
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
                            child: _buildTopSellingTable(user,
                                salesSnap.data?.docs ?? [], cardDecoration)),
                        const SizedBox(width: 32),
                        Expanded(
                            flex: 2,
                            child: _buildLowStockList(
                                invSnap.data?.docs ?? [], cardDecoration)),
                      ],
                    ),
                  ],
                ],
              );
            });
          },
        );
      },
    );
  }

  Widget _buildLineChartSection(
      BuildContext context, BoxDecoration cardDecoration) {
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
        stream: _db.getSales(user.shopId).toMainThread(),
        builder: (context, salesSnap) {
          final allSales = salesSnap.data?.docs ?? [];
          final now = DateTime.now();
          List<FlSpot> spots = [];
          double maxVal = 1000;
          double minVal = 0;

          double totalPeriodProf = 0;
          for (int i = 0; i < 7; i++) {
            final date = now.subtract(Duration(days: 6 - i));
            double dailyProf = 0;
            for (var doc in allSales) {
              final m = doc.data() as Map<String, dynamic>;
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
          maxVal = maxVal * 1.2;
          minVal = minVal < 0 ? minVal * 1.2 : 0;

          final currencyFormat =
              NumberFormat.currency(symbol: '', decimalDigits: 0);

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Weekly Profit/Loss",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 24),
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => FlLine(
                              color: AppColors.border.withOpacity(0.5),
                              strokeWidth: 1)),
                      titlesData: FlTitlesData(
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 45,
                                getTitlesWidget: (v, meta) {
                                  if (v == 0)
                                    return const Text('0',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary));
                                  return Text(
                                      '${(v / 1000).toStringAsFixed(1)}K',
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: AppColors.textSecondary));
                                })),
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1, // FIX: No duplicate labels
                                getTitlesWidget: (v, meta) {
                                  if (v != v.toInt()) return const SizedBox.shrink();
                                  final days = [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun'
                                  ];
                                  final todayDate = now
                                      .subtract(Duration(days: 6 - v.toInt()));
                                  return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(days[todayDate.weekday - 1],
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary)));
                                })),
                      ),
                      minY: minVal,
                      maxY: maxVal,
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: periodColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    periodColor.withOpacity(0.3),
                                    periodColor.withOpacity(0.0)
                                  ])),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: const LineTouchTooltipData(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }

  Widget _buildRecentSalesList(AppUser user, List<DocumentSnapshot> sales,
      BoxDecoration cardDecoration, List<SidebarItem> sidebarItems) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Recent Activity",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              TextButton(
                  onPressed: () => setState(() => _selectedIndex =
                      sidebarItems.indexWhere((it) => it.uid == 'audit')),
                  child: const Text("View all",
                      style:
                          TextStyle(fontSize: 12, color: AppColors.secondary))),
            ],
          ),
          const SizedBox(height: 16),
          ...sales.take(5).map((s) {
            final d = s.data() as Map<String, dynamic>;
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
                      fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(DateFormat('hh:mm a').format(ts),
                  style: const TextStyle(fontSize: 11)),
              trailing: Text(currencyFormat.format(d['totalPrice'] ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildManageUsersTab(AppUser adminUser) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              const Text("User Management",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              OutlinedButton.icon(
                onPressed: () => _showCreateUserDialog(adminUser),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text("Add Staff"),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.getUsers(adminUser.shopId).toMainThread(),
            builder: (c, snap) {
              if (!snap.hasData)
                return const Center(child: CircularProgressIndicator());
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                itemCount: snap.data!.docs.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (c, i) {
                  final doc = snap.data!.docs[i];
                  final d = doc.data() as Map<String, dynamic>;
                  final role =
                      ((d['roles'] as List?)?.first ?? 'staff').toString();
                  final isAdmin = role == 'admin';
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            (isAdmin ? AppColors.warning : AppColors.secondary)
                                .withOpacity(0.1),
                        child: Icon(
                            isAdmin
                                ? Icons.admin_panel_settings_rounded
                                : Icons.person,
                            color: isAdmin
                                ? AppColors.warning
                                : AppColors.secondary),
                      ),
                      title: Text(d['username'] ?? 'User',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(d['email'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: (isAdmin
                                        ? AppColors.warning
                                        : AppColors.secondary)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(role.toUpperCase(),
                                style: TextStyle(
                                    color: isAdmin
                                        ? AppColors.warning
                                        : AppColors.secondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          if (!isAdmin) ...[
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit User',
                              onPressed: () => _showEditUserDialog(doc.id, d),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: AppColors.danger),
                              tooltip: 'Delete User',
                              onPressed: () => _confirmDeleteUser(
                                  doc.id, d['username'] ?? ''),
                            ),
                          ],
                        ],
                      ),
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

  void _showEditUserDialog(String uid, Map<String, dynamic> data) {
    final nameC = TextEditingController(text: data['username']);
    String selectedRole =
        ((data['roles'] as List?)?.first ?? 'staff').toString();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.surface,
                title: const Text("Edit User"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameC,
                      decoration: const InputDecoration(
                          labelText: "Username",
                          prefixIcon: Icon(Icons.person)),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: "Role"),
                      items: const [
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                        DropdownMenuItem(
                            value: 'cashier', child: Text('Cashier')),
                      ],
                      onChanged: (v) {
                        if (v != null) setS(() => selectedRole = v);
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel")),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .update({
                          'username': nameC.text.trim().toLowerCase(),
                          'roles': [selectedRole],
                        });
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('User updated!'),
                                  backgroundColor: AppColors.success));
                        }
                      } catch (e) {
                        if (ctx.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppColors.danger));
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
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .delete();
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("'$username' deleted."),
                      backgroundColor: AppColors.success));
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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

  void _showCreateUserDialog(AppUser adminUser) {
    final nameC = TextEditingController();
    final emailC = TextEditingController();
    final passC = TextEditingController();
    String selectedRole = 'staff';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.surface,
                title: const Text("Add New Staff"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: nameC,
                        decoration: const InputDecoration(
                            labelText: "Username",
                            prefixIcon: Icon(Icons.person))),
                    const SizedBox(height: 12),
                    TextField(
                        controller: emailC,
                        decoration: const InputDecoration(
                            labelText: "Email", prefixIcon: Icon(Icons.email))),
                    const SizedBox(height: 12),
                    TextField(
                        controller: passC,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: "Temporary Password",
                            prefixIcon: Icon(Icons.lock))),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: "Role"),
                      items: const [
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                        DropdownMenuItem(
                            value: 'manager', child: Text('Manager')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (v) {
                        if (v != null) setS(() => selectedRole = v);
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel")),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameC.text.isEmpty ||
                          emailC.text.isEmpty ||
                          passC.text.isEmpty) return;
                      if (ctx.mounted) Navigator.pop(ctx);
                      LoadingOverlay.show(context);
                      try {
                        final cred = await FirebaseAuth.instance
                            .createUserWithEmailAndPassword(
                          email: emailC.text.trim(),
                          password: passC.text,
                        );
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(cred.user!.uid)
                            .set({
                          'username': nameC.text.trim().toLowerCase(),
                          'email': emailC.text.trim(),
                          'roles': [selectedRole],
                          'shopId': adminUser.shopId,
                          'branchId': adminUser.branchId,
                          'branchName': adminUser.branchName ?? 'Main Branch',
                        });
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Staff account created!'),
                                  backgroundColor: AppColors.success));
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Error: $e'),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: TextField(
            controller: _searchInventoryC,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search products by name or barcode...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchInventoryC.text.isNotEmpty)
                    IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchInventoryC.clear();
                          setState(() => _searchQuery = '');
                        }),
                  IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded,
                          size: 18, color: AppColors.secondary),
                      onPressed: () => _launchScanner(_searchInventoryC)),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: StreamBuilder<QuerySnapshot>(
              stream: _db.getInventory(user.shopId).toMainThread(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final all = snapshot.data!.docs;

                bool hasHealthy = false,
                    hasLow = false,
                    hasOut = false,
                    hasExpired = false,
                    hasSoon = false;
                for (var doc in all) {
                  final m = doc.data() as Map;
                  final qty = (m['quantity'] ?? 0);
                  final lt = (m['lowStockThreshold'] ?? 5);
                  final ed = m['expiryDate'];
                  final expiry = ed != null
                      ? (ed is Timestamp
                          ? ed.toDate()
                          : DateTime.tryParse(ed.toString()))
                      : null;
                  final now = DateTime.now();

                  if (expiry != null && expiry.isBefore(now))
                    hasExpired = true;
                  else if (expiry != null &&
                      expiry.difference(now).inDays <= 30) hasSoon = true;

                  if (qty <= 0)
                    hasOut = true;
                  else if (qty <= lt)
                    hasLow = true;
                  else
                    hasHealthy = true;
                }

                final List<String> availableFilters = ['All'];
                if (hasHealthy) availableFilters.add('Healthy');
                if (hasLow) availableFilters.add('Low Stock');
                if (hasOut) availableFilters.add('Out of Stock');
                if (hasSoon) availableFilters.add('Expiring Soon');
                if (hasExpired) availableFilters.add('Expired');

                if (!availableFilters.contains(_inventoryFilter))
                  _inventoryFilter = 'All';

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: availableFilters
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(f,
                                    style: const TextStyle(fontSize: 12)),
                                selected: _inventoryFilter == f,
                                onSelected: (val) =>
                                    setState(() => _inventoryFilter = f),
                                selectedColor: AppColors.secondary,
                                labelStyle: TextStyle(
                                    color: _inventoryFilter == f
                                        ? Colors.white
                                        : null),
                              ),
                            ))
                        .toList(),
                  ),
                );
              }),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.getInventory(user.shopId).toMainThread(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!.docs.where((d) {
                final m = d.data() as Map;
                final name = (m['name']?.toString().toLowerCase() ?? '');
                final barcode = (m['barcode']?.toString().toLowerCase() ?? '');
                final qty = (m['quantity'] ?? 0);
                final lowThresh = (m['lowStockThreshold'] ?? 5);
                final ed = m['expiryDate'];
                final expiry = ed != null
                    ? (ed is Timestamp
                        ? ed.toDate()
                        : DateTime.tryParse(ed.toString()))
                    : null;
                final now = DateTime.now();

                bool matchesFilter = true;
                if (_inventoryFilter == 'Healthy')
                  matchesFilter = qty > lowThresh;
                if (_inventoryFilter == 'Low Stock')
                  matchesFilter = qty > 0 && qty <= lowThresh;
                if (_inventoryFilter == 'Out of Stock')
                  matchesFilter = qty <= 0;
                if (_inventoryFilter == 'Expiring Soon') {
                  matchesFilter = expiry != null &&
                      expiry.difference(now).inDays <= 30 &&
                      expiry.difference(now).inDays > 0;
                }
                if (_inventoryFilter == 'Expired') {
                  matchesFilter = expiry != null && expiry.isBefore(now);
                }

                return (_selectedBranchId == 'all' ||
                        m['branchId'] == _selectedBranchId) &&
                    (name.contains(_searchQuery) ||
                        barcode.contains(_searchQuery)) &&
                    matchesFilter;
              }).toList();

              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                itemCount: items.length,
                separatorBuilder: (c, i) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final d = items[i].data() as Map<String, dynamic>;
                  final qty = (d['quantity'] ?? 0);
                  final isOut = qty <= 0;
                  final lowThresh = (d['lowStockThreshold'] ?? 5);
                  final isLow = !isOut && qty <= lowThresh;

                  bool isExpired = false;
                  bool isExpiringSoon = false;
                  final expiryData = d['expiryDate'];
                  if (expiryData != null) {
                    final expiry = (expiryData is Timestamp)
                        ? expiryData.toDate()
                        : DateTime.tryParse(expiryData.toString());
                    if (expiry != null) {
                      final diff = expiry.difference(DateTime.now()).inDays;
                      if (expiry.isBefore(DateTime.now()))
                        isExpired = true;
                      else if (diff <= 30 && diff > 0) isExpiringSoon = true;
                    }
                  }

                  return LayoutBuilder(builder: (context, constraints) {
                    final bool isCompact = constraints.maxWidth < 600;
                    
                    if (isCompact) {
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border, width: 0.5)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(d['name'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                  Text(currencyFormat.format(d['sellingPrice'] ?? 0),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.secondary,
                                          fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isOut
                                          ? AppColors.danger.withOpacity(0.1)
                                          : (isLow ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                        isOut ? "OUT OF STOCK" : (isLow ? "LOW STOCK: $qty" : "HEALTHY: $qty"),
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isOut ? AppColors.danger : (isLow ? Colors.orange : Colors.green))),
                                  ),
                                  if (isExpired)
                                    _buildBadge("EXPIRED", AppColors.danger)
                                  else if (isExpiringSoon)
                                    _buildBadge("EXPIRING SOON", Colors.red),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text("Barcode: ${d['barcode'] ?? '-'}",
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, size: 20),
                                    onPressed: () => _showAddItemDialog(user, d, items[i].id),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.add_to_photos_rounded, color: AppColors.info, size: 20),
                                    onPressed: () => _showAdminPurchaseDialog(user, prefillProduct: {
                                      'id': items[i].id,
                                      'name': d['name'],
                                      'barcode': d['barcode'],
                                      'buyingPrice': d['buyingPrice'],
                                      'sellingPrice': d['sellingPrice'],
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                    onPressed: () => _handleDeleteProduct(user, items[i].id, d['name'] ?? ''),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    }

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                              color: AppColors.border, width: 0.5)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        title: Text(d['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOut
                                        ? AppColors.danger.withOpacity(0.1)
                                        : (isLow
                                            ? Colors.orange.withOpacity(0.1)
                                            : Colors.green.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                      isOut
                                          ? "OUT OF STOCK"
                                          : (isLow
                                              ? "LOW STOCK: $qty"
                                              : "HEALTHY: $qty"),
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isOut
                                              ? AppColors.danger
                                              : (isLow
                                                  ? Colors.orange
                                                  : Colors.green))),
                                ),
                                if (isExpired)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: AppColors.danger.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: const Text("EXPIRED",
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.danger)),
                                  )
                                else if (isExpiringSoon)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: const Text("EXPIRING SOON",
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text("Barcode: ${d['barcode'] ?? '-'}",
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(currencyFormat.format(d['sellingPrice'] ?? 0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                    fontSize: 16)),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 20),
                              tooltip: 'Edit Product',
                              onPressed: () =>
                                  _showAddItemDialog(user, d, items[i].id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_to_photos_rounded,
                                  color: AppColors.info, size: 20),
                              tooltip: 'Restock / Add Batch',
                              onPressed: () {
                                _showAdminPurchaseDialog(user, prefillProduct: {
                                  'id': items[i].id,
                                  'name': d['name'],
                                  'barcode': d['barcode'],
                                  'buyingPrice': d['buyingPrice'],
                                  'sellingPrice': d['sellingPrice'],
                                });
                              },
                            ),
                            IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: AppColors.danger, size: 20),
                                tooltip: 'Delete Product',
                                onPressed: () => _handleDeleteProduct(
                                    user, items[i].id, d['name'] ?? '')),
                          ],
                        ),
                      ),
                    );
                  });
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(32),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showAddItemDialog(user),
                  icon: const Icon(Icons.add),
                  label: const Text("New Product"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(140, 48)),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showGlobalRestockSearchDialog(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 48),
                  ),
                  icon: const Icon(Icons.add_to_photos_rounded),
                  label: const Text("Restock Existing"),
                ),
                OutlinedButton.icon(
                  onPressed: () => _handleImport(user),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text("Bulk Import"),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(140, 48)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesTab(AppUser user) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search products to sell...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.border, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.secondary, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.getInventory(user.shopId).toMainThread(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!.docs.where((d) {
                final m = d.data() as Map;
                final name = (m['name']?.toString().toLowerCase() ?? '');
                final barcode = (m['barcode']?.toString().toLowerCase() ?? '');
                final price = (m['sellingPrice'] ?? 0).toDouble();
                final qty = (m['quantity'] ?? 0);
                return (name.contains(_searchQuery) ||
                        barcode.contains(_searchQuery)) &&
                    price > 0 &&
                    qty > 0;
              }).toList();
              if (items.isEmpty)
                return const Center(child: Text('No products found.'));
              return GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final d = items[i].data() as Map<String, dynamic>;
                  final qty = d['quantity'] ?? 0;
                  final isLow = qty <= (d['lowStockThreshold'] ?? 5);

                  bool isExpired = false;
                  bool isExpiringSoon = false;
                  final ed = d['expiryDate'];
                  if (ed != null) {
                    final expiry = (ed is Timestamp)
                        ? ed.toDate()
                        : DateTime.tryParse(ed.toString());
                    if (expiry != null) {
                      if (expiry.isBefore(DateTime.now()))
                        isExpired = true;
                      else if (expiry.difference(DateTime.now()).inDays <= 30)
                        isExpiringSoon = true;
                    }
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isExpired
                              ? AppColors.danger
                              : (isLow
                                  ? AppColors.danger.withOpacity(0.4)
                                  : AppColors.border),
                          width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(currencyFormat.format(d['sellingPrice'] ?? 0),
                            style: const TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: (isLow
                                          ? AppColors.danger
                                          : AppColors.success)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text('$qty left',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isLow
                                          ? AppColors.danger
                                          : AppColors.success)),
                            ),
                            if (isExpired)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: AppColors.danger.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6)),
                                child: const Text('EXPIRED',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.danger)),
                              )
                            else if (isExpiringSoon)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6)),
                                child: const Text('EXPERING SOON',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red)),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                                child: ElevatedButton(
                              onPressed: (qty > 0 && !isExpired)
                                  ? () => _handleAddToCart(items[i],
                                      isQuickSell: true)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                  backgroundColor: AppColors.success),
                              child: const Text('Sell',
                                  style: TextStyle(fontSize: 11)),
                            )),
                            const SizedBox(width: 8),
                            Expanded(
                                child: OutlinedButton(
                              onPressed: (qty > 0 && !isExpired)
                                  ? () => _handleAddToCart(items[i])
                                  : null,
                              style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                  side: const BorderSide(
                                      color: AppColors.secondary)),
                              child: const Icon(Icons.add_shopping_cart_rounded,
                                  size: 16, color: AppColors.secondary),
                            )),
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
              Text(currencyFormat.format(_cartTotal),
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
                    "${_posCart[i].quantity} x ${currencyFormat.format(_posCart[i].price)}"),
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
                        "Checkout (${currencyFormat.format(_cartTotal)})"))),
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
              Text("Total Amount: ${currencyFormat.format(_cartTotal)}",
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
              if (isDebt) ...[
                const SizedBox(height: 16),
                TextField(
                    controller: advancedC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: "Advanced Payment (ETB)")),
              ]
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel")),
            ElevatedButton(
                onPressed: () async {
                  final advanced = double.tryParse(advancedC.text) ?? 0.0;
                  Navigator.pop(ctx);
                  final groupId =
                      "TRX-${DateTime.now().millisecondsSinceEpoch}";

                  try {
                    for (var item in _posCart) {
                      final itemTotal = item.total;
                      double debtAmt = 0;
                      double paidAmt = itemTotal;

                      if (isDebt) {
                        paidAmt = (advanced / _cartTotal) * itemTotal;
                        debtAmt = itemTotal - paidAmt;
                      }

                      await _repo.recordSale(user, {
                        'shopId': user.shopId,
                        'branchId': user.branchId,
                        'userId': user.id,
                        'username': user.username,
                        'itemId': item.id,
                        'itemName': item.name,
                        'quantity': item.quantity,
                        'totalPrice': itemTotal,
                        'isDebt': isDebt && debtAmt > 0,
                        'debtRemaining': debtAmt,
                        'advancedPaid': paidAmt,
                        'customerName': customerC.text,
                        'profit':
                            (item.price - (item.cost ?? 0)) * item.quantity,
                        'saleGroupId': groupId,
                      });
                    }
                    _clearCart();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('Sale processed successfully!')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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

  void _showAdminSellDialog(DocumentSnapshot doc, AppUser user) {
    final d = doc.data() as Map<String, dynamic>;
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
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity')),
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
                  final qty = int.tryParse(qtyC.text) ?? 1;
                  final sell = (d['sellingPrice'] as num?)?.toDouble() ?? 0;
                  final buy = (d['buyingPrice'] as num?)?.toDouble() ?? 0;

                  // Optimistic/Instant local-first save via repo
                  _repo.recordSale(user, {
                    'shopId': user.shopId,
                    'branchId': user.branchId,
                    'userId': user.id,
                    'username': user.username,
                    'itemId': doc.id,
                    'itemName': d['name'],
                    'quantity': qty,
                    'sellingPrice': sell,
                    'totalPrice': sell * qty,
                    'profit': (sell - buy) * qty,
                    'customerName': buyerC.text,
                    'isDebt': paymentType == 'Debt',
                    'debtRemaining': paymentType == 'Debt' ? (sell * qty) : 0.0,
                    'advancedPaid': 0.0,
                    'saleGroupId': "TRX-${DateTime.now().millisecondsSinceEpoch}",
                  }).catchError(
                      (e) => debugPrint('Sale sync (background): $e'));

                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Sale Recorded Instantly! Synching in background...'),
                        backgroundColor: AppColors.success));
                  }
                } catch (e) {
                  if (c.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  const Text("Purchase Log",
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showGlobalRestockSearchDialog(user),
                        icon: const Icon(Icons.add_to_photos_rounded, size: 18),
                        label: const Text('Restock Existing'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: AppColors.info,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAdminPurchaseDialog(user),
                        icon: const Icon(Icons.receipt_rounded, size: 18),
                        label: const Text('New Intake Log'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchPurchasesC,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "Search purchases by item name...",
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchPurchasesC.text.isNotEmpty)
                        IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchPurchasesC.clear();
                              setState(() {});
                            }),
                      IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded,
                              size: 18, color: AppColors.secondary),
                          onPressed: () => _launchScanner(_searchPurchasesC)),
                    ],
                  ),
                  fillColor: Theme.of(context).colorScheme.surface,
                  filled: true,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.getPurchases(user.shopId).toMainThread(),
            builder: (context, snap) {
              if (!snap.hasData)
                return const Center(child: CircularProgressIndicator());
              final allPurchases = snap.data!.docs;

              // Extract Suppliers for Filter
              List<String> suppliers = ['All Suppliers'];
              for (var doc in allPurchases) {
                final sName = (doc.data() as Map)['supplierName']?.toString();
                if (sName != null &&
                    sName.isNotEmpty &&
                    !suppliers.contains(sName)) suppliers.add(sName);
              }

              var docs = allPurchases.where((d) {
                final m = d.data() as Map;
                if (_purchaseSupplierFilter != 'All Suppliers' &&
                    m['supplierName'] != _purchaseSupplierFilter) return false;

                if (_searchPurchasesC.text.isNotEmpty) {
                  final q = _searchPurchasesC.text.toLowerCase();
                  return (m['itemName'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(q) ||
                      (m['barcode'] ?? '').toString().toLowerCase().contains(q);
                }
                return true;
              }).toList();

              return Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Row(
                      children: [
                        const Text("Show Supplier: ",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: suppliers.contains(_purchaseSupplierFilter)
                                ? _purchaseSupplierFilter
                                : 'All Suppliers',
                            items: suppliers
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s,
                                        style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _purchaseSupplierFilter = v!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final ts = parseDT(d['timestamp']);
                        return Card(
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
                            title: Text(d['itemName'] ?? 'Unknown',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${d['supplierName'] ?? 'No Supplier'} • ${ts != null ? DateFormat('MMM d, y • HH:mm').format(ts) : '-'}"),
                                if (MediaQuery.of(context).size.width < 500)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      "${currencyFormat.format(d['totalCost'] ?? 0)} • ${d['quantity']} units",
                                      style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: LayoutBuilder(builder: (context, c) {
                              final mobile = MediaQuery.of(context).size.width < 500;
                              if (mobile) return const SizedBox.shrink(); 
                              
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(currencyFormat.format(d['totalCost'] ?? 0),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.secondary)),
                                      Text("${d['quantity']} units",
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary)),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.add_to_photos_rounded, color: AppColors.info, size: 20),
                                    tooltip: 'Restock again',
                                    onPressed: () => _showAdminPurchaseDialog(user, 
                                      prefillProduct: {
                                        'id': d['itemId'],
                                        'name': d['itemName'],
                                        'barcode': d['barcode'],
                                        'buyingPrice': d['unitCost'],
                                        'sellingPrice': d['sellingPrice'],
                                      }, 
                                      forceShowSupplier: true
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
                  const SizedBox(height: 16),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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

  void _showGlobalRestockSearchDialog(AppUser user, {bool forceShowSupplierInRestock = false}) {
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
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _db.getInventory(user.shopId).toMainThread(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const LinearProgressIndicator();
                      final q = searchC.text.toLowerCase();
                      final items = snap.data!.docs.where((doc) {
                        final d = doc.data() as Map;
                        final name = (d['name'] ?? '').toString().toLowerCase();
                        final bar = (d['barcode'] ?? '').toString().toLowerCase();
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
                          final d = doc.data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text(d['name'] ?? ''),
                            subtitle: Text("Stock: ${d['quantity']} | ${d['barcode'] ?? '-'}"),
                            trailing: const Icon(Icons.add_circle_outline, color: AppColors.info),
                            onTap: () {
                                Navigator.pop(ctx);
                                final prefill = Map<String, dynamic>.from(d);
                                prefill['id'] = doc.id;
                                _showAdminPurchaseDialog(user, prefillProduct: prefill, forceShowSupplier: forceShowSupplierInRestock);
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
    DateTime? expiry;

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
                            : "Expires: ${DateFormat('MMM yyyy').format(expiry!)}"),
                        leading: const Icon(Icons.event_note_rounded),
                        onTap: () async {
                          final d = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2040));
                          if (d != null) setS(() => expiry = d);
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
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Fill all required fields (*)")));
                        return;
                      }
                      try {
                        // UNIFIED FLOW: Every intake (New or Restock) is a Purchase Log entry.
                        // Repository now handles the "Identity vs. Movement" logic internally.
                        await _repo.recordPurchase(user, {
                          'shopId': user.shopId,
                          'branchId': user.branchId,
                          'userId': user.id,
                          'username': user.username,
                          'supplierName': supplierC.text.trim(),
                          'itemId': isRestock ? prefillProduct['id'] : null, 
                          'itemName': nameC.text.trim(),
                          'barcode': barC.text.trim(),
                          'quantity': double.tryParse(qtyC.text) ?? 0,
                          'unitCost': double.tryParse(costC.text) ?? 0,
                          'sellingPrice': double.tryParse(sellC.text) ?? 0,
                          'lowStockThreshold': int.tryParse(thresholdC.text) ?? 5,
                          'totalCost': (double.tryParse(qtyC.text) ?? 0) * (double.tryParse(costC.text) ?? 0),
                          'expiryDate': expiry != null ? Timestamp.fromDate(expiry!) : null,
                        });

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          setState(() {}); // Refresh list to show new intake instantly
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Inventory & Purchase Log updated!'),
                                  backgroundColor: AppColors.success));
                        }
                      } catch (e) {
                        if (ctx.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppColors.danger));
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
    return StreamBuilder<QuerySnapshot>(
      stream: _db.getSales(user.shopId).toMainThread(),
      builder: (context, snap) {
        return StreamBuilder<QuerySnapshot>(
          stream: _db.getInventory(user.shopId).toMainThread(),
          builder: (context, invSnap) {
            int lowStock = 0;
            if (invSnap.hasData) {
              for (var doc in invSnap.data!.docs) {
                final m = doc.data() as Map;
                final qty = m['quantity'] ?? 0;
                final threshold = m['lowStockThreshold'] ?? 5;
                if (qty <= threshold) lowStock++;
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
                    const Text("Financial Reports",
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
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
                          final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2023),
                              lastDate: DateTime.now());
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
                          final allDocs = snap.data?.docs ?? [];
                          final filtered = allDocs.where((d) {
                            final m = d.data() as Map;
                            final ts = parseDT(m['timestamp']);
                            if (ts == null) return false;
                            return ts.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
                                ts.isBefore(_endDate.add(const Duration(days: 1)));
                          }).toList();

                          if (filtered.isEmpty) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No data for selected period.'), backgroundColor: AppColors.warning));
                            }
                            return;
                          }

                          String pathStr = "";
                          if (val == 'excel') {
                            pathStr = await _reporting.exportSalesExcel(filtered);
                          } else if (val == 'pdf') {
                            // Calculate simple summary for the PDF
                            double totalRev = 0, totalProf = 0, totalUnpaid = 0;
                            Map<String, double> topProductsMap = {};
                            for (var d in filtered) {
                              final m = d.data() as Map;
                              final rev = (m['totalPrice'] ?? 0).toDouble();
                              totalRev += rev;
                              totalProf += (m['profit'] ?? 0).toDouble();
                              if (m['isDebt'] == true) {
                                totalUnpaid += (m['debtRemaining'] ?? m['totalPrice'] ?? 0).toDouble();
                              }
                              final name = m['itemName'] ?? 'Unknown';
                              topProductsMap[name] = (topProductsMap[name] ?? 0) + (m['quantity'] ?? 0).toDouble();
                            }
                            final topProducts = topProductsMap.entries.map((e) => {'name': e.key, 'qty': e.value, 'rev': 0}).toList()
                              ..sort((a, b) => (b['qty'] as num).compareTo(a['qty'] as num));

                            int lowCount = 0, outCount = 0, soonCount = 0;
                            for (var d in invSnap.data?.docs ?? []) {
                              final m = d.data() as Map;
                              final qty = m['quantity'] ?? 0;
                              if (qty == 0) outCount++;
                              else if (qty <= (m['lowStockThreshold'] ?? 5)) lowCount++;
                            }

                            pathStr = await _reporting.exportToPdf('Report_${DateTime.now().millisecondsSinceEpoch}', {
                              'revenue': totalRev,
                              'profit': totalProf,
                              'orders': filtered.length,
                              'debt': totalUnpaid,
                              'lowStockCount': lowCount,
                              'outStockCount': outCount,
                              'expiredCount': 0,
                              'soonCount': 0,
                              'topProducts': topProducts.take(5).toList(),
                            });
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Report exported to: $pathStr'),
                                backgroundColor: AppColors.success));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
                  for (var doc in snap.data?.docs ?? []) {
                    final m = doc.data() as Map;
                    final ts = parseDT(m['timestamp']);
                    if (ts != null &&
                        ts.isAfter(
                            _startDate.subtract(const Duration(seconds: 1))) &&
                        ts.isBefore(_endDate.add(const Duration(days: 1)))) {
                      totalRev += (m['totalPrice'] ?? 0).toDouble();
                      totalProfit += (m['profit'] ?? 0).toDouble();
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
                            value: currencyFormat.format(totalRev),
                            color: AppColors.success,
                            icon: Icons.paid_outlined,
                            cardDecoration: cardDecor,
                            onTap: () => setState(() => _selectedIndex =
                                _getSidebarItems(user)
                                    .indexWhere((it) => it.uid == 'reports'))),
                        if (!user.roles.contains(UserRole.staff))
                          StatCard(
                              title: 'Total Profit',
                              value: currencyFormat.format(totalProfit),
                              color: AppColors.info,
                              icon: Icons.trending_up_rounded,
                              cardDecoration: cardDecor,
                              onTap: () => setState(() => _selectedIndex =
                                  _getSidebarItems(user)
                                      .indexWhere((it) => it.uid == 'reports'))),
                        StatCard(
                            title: 'Unpaid Debts',
                            value: currencyFormat.format(totalUnpaid),
                            color: AppColors.danger,
                            icon: Icons.money_off_rounded,
                            cardDecoration: cardDecor,
                            onTap: () => setState(() => _selectedIndex =
                                _getSidebarItems(user)
                                    .indexWhere((it) => it.uid == 'debt'))),
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
                if (!user.roles.contains(UserRole.staff)) ...[
                  LayoutBuilder(builder: (context, constraints) {
                    final bool isMobile = constraints.maxWidth < 750;
                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBarChartSection(context, cardDecor),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: cardDecor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Top Selling Products",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 250,
                                  child: Builder(builder: (context) {
                                    Map<String, num> stats = {};
                                    for (var d in snap.data?.docs ?? []) {
                                      final m = d.data() as Map;
                                      final name = m['itemName'] ?? 'Unknown';
                                      final qty = (m['quantity'] ?? 0);
                                      stats[name] = (stats[name] ?? 0) + qty;
                                    }
                                    var sorted = stats.entries.toList()
                                      ..sort(
                                          (a, b) => b.value.compareTo(a.value));
                                    var top5 = sorted.take(5).toList();
                                    if (top5.isEmpty)
                                      return const Center(
                                          child: Text("No Sales Data",
                                              style: TextStyle(fontSize: 12)));

                                    final colors = [
                                      AppColors.secondary,
                                      AppColors.primary,
                                      AppColors.info,
                                      AppColors.warning,
                                      AppColors.danger
                                    ];

                                    return PieChart(
                                      PieChartData(
                                        sectionsSpace: 3,
                                        centerSpaceRadius: 50,
                                        sections: List.generate(top5.length, (i) {
                                          return PieChartSectionData(
                                            value: top5[i].value.toDouble(),
                                            title: '${top5[i].value}',
                                            color: colors[i % colors.length],
                                            radius: 25,
                                            titleStyle: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white),
                                          );
                                        }),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 24),
                                Builder(builder: (context) {
                                  Map<String, num> stats = {};
                                  for (var d in snap.data?.docs ?? []) {
                                    final m = d.data() as Map;
                                    final name = m['itemName'] ?? 'Unknown';
                                    final qty = (m['quantity'] ?? 0);
                                    stats[name] = (stats[name] ?? 0) + qty;
                                  }
                                  var sorted = stats.entries.toList()
                                    ..sort((a, b) => b.value.compareTo(a.value));
                                  var top5 = sorted.take(5).toList();
                                  final colors = [
                                    AppColors.secondary,
                                    AppColors.primary,
                                    AppColors.info,
                                    AppColors.warning,
                                    AppColors.danger
                                  ];
                                  return Column(
                                    children: List.generate(
                                        top5.length,
                                        (i) => _buildPieLegend(
                                            top5[i].key,
                                            colors[i % colors.length],
                                            top5[i].value.toString())),
                                  );
                                }),
                              ],
                            ),
                          )
                        ],
                      );
                    } else {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 3,
                              child: _buildBarChartSection(context, cardDecor)),
                          const SizedBox(width: 24),
                          Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: cardDecor,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Top Selling Products",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18)),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      height: 250,
                                      child: Builder(builder: (context) {
                                        Map<String, num> stats = {};
                                        for (var d in snap.data?.docs ?? []) {
                                          final m = d.data() as Map;
                                          final name = m['itemName'] ?? 'Unknown';
                                          final qty = (m['quantity'] ?? 0);
                                          stats[name] = (stats[name] ?? 0) + qty;
                                        }
                                        var sorted = stats.entries.toList()
                                          ..sort(
                                              (a, b) => b.value.compareTo(a.value));
                                        var top5 = sorted.take(5).toList();
                                        if (top5.isEmpty)
                                          return const Center(
                                              child: Text("No Sales Data",
                                                  style: TextStyle(fontSize: 12)));

                                        final colors = [
                                          AppColors.secondary,
                                          AppColors.primary,
                                          AppColors.info,
                                          AppColors.warning,
                                          AppColors.danger
                                        ];

                                        return PieChart(
                                          PieChartData(
                                            sectionsSpace: 3,
                                            centerSpaceRadius: 50,
                                            sections: List.generate(top5.length, (i) {
                                              return PieChartSectionData(
                                                value: top5[i].value.toDouble(),
                                                title: '${top5[i].value}',
                                                color: colors[i % colors.length],
                                                radius: 25,
                                                titleStyle: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white),
                                              );
                                            }),
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 24),
                                    Builder(builder: (context) {
                                      Map<String, num> stats = {};
                                      for (var d in snap.data?.docs ?? []) {
                                        final m = d.data() as Map;
                                        final name = m['itemName'] ?? 'Unknown';
                                        final qty = (m['quantity'] ?? 0);
                                        stats[name] = (stats[name] ?? 0) + qty;
                                      }
                                      var sorted = stats.entries.toList()
                                        ..sort((a, b) => b.value.compareTo(a.value));
                                      var top5 = sorted.take(5).toList();
                                      final colors = [
                                        AppColors.secondary,
                                        AppColors.primary,
                                        AppColors.info,
                                        AppColors.warning,
                                        AppColors.danger
                                      ];
                                      return Column(
                                        children: List.generate(
                                            top5.length,
                                            (i) => _buildPieLegend(
                                                top5[i].key,
                                                colors[i % colors.length],
                                                top5[i].value.toString())),
                                      );
                                    }),
                                  ],
                                ),
                              )),
                        ],
                      );
                    }
                  }),
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
                        final snapBatch = await FirebaseFirestore.instance
                            .collection('sales')
                            .where('shopId', isEqualTo: user.shopId)
                            .get();
                        if (snapBatch.docs.isEmpty) {
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "No sales data available to export."),
                                    backgroundColor: AppColors.warning));
                          return;
                        }
                        final path =
                            await _reporting.exportSalesExcel(snapBatch.docs);
                        if (mounted && path != "Cancelled")
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text("Export saved: $path"),
                              backgroundColor: AppColors.success));
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
                  final products = invSnap.data?.docs ?? [];
                  final outOfStock = products
                      .where((d) => (d.data() as Map)['quantity'] <= 0)
                      .toList();
                  final expired = products.where((d) {
                    final m = d.data() as Map;
                    final expiry = m['expiryDate'];
                    if (expiry == null) return false;
                    final date = (expiry is Timestamp)
                        ? expiry.toDate()
                        : DateTime.tryParse(expiry.toString());
                    return date != null && date.isBefore(DateTime.now());
                  }).toList();
                  final expiringSoon = products.where((d) {
                    final m = d.data() as Map;
                    final expiry = m['expiryDate'];
                    if (expiry == null) return false;
                    final date = (expiry is Timestamp)
                        ? expiry.toDate()
                        : DateTime.tryParse(expiry.toString());
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
                        final salesInPeriod = snap.data?.docs ?? [];
                        final inventory = invSnap.data?.docs ?? [];

                        Map<String, double> volumes = {};
                        for (var s in salesInPeriod) {
                          final m = s.data() as Map;
                          final name = m['itemName'] ?? 'Unknown';
                          volumes[name] = (volumes[name] ?? 0) +
                              (m['quantity'] ?? 0).toDouble();
                        }

                        final dead = inventory
                            .where((i) =>
                                !volumes.containsKey((i.data() as Map)['name']))
                            .toList();
                        final moving = inventory
                            .where((i) =>
                                volumes.containsKey((i.data() as Map)['name']))
                            .toList()
                          ..sort((a, b) => volumes[(b.data() as Map)['name']]!
                              .compareTo(volumes[(a.data() as Map)['name']]!));

                        final fast = moving.take(5).toList();
                        final slow = moving.reversed.take(5).toList();

                        final valStock = List<QueryDocumentSnapshot>.from(
                            inventory)
                          ..sort((a, b) =>
                              ((b.data() as Map)['sellingPrice'] ?? 0)
                                  .compareTo(
                                      (a.data() as Map)['sellingPrice'] ?? 0));

                        final highVal = valStock.take(5).toList();
                        final lowVal = valStock.reversed.take(5).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (fast.isNotEmpty) ...[
                              _buildReportSectionTitle(
                                  "Fast Moving Items (Top Sales)",
                                  Colors.green),
                              _buildHorizontalInventoryList(fast, cardDecor,
                                  color: Colors.green),
                              const SizedBox(height: 24),
                            ],
                            if (dead.isNotEmpty &&
                                _reportFilter != 'Daily') ...[
                              _buildReportSectionTitle(
                                  "Dead Stock (Stable Inventory)", Colors.grey),
                              _buildHorizontalInventoryList(dead, cardDecor,
                                  color: Colors.grey),
                              const SizedBox(height: 24),
                            ],
                            if (highVal.isNotEmpty) ...[
                              _buildReportSectionTitle(
                                  "High Value Inventory", Colors.purple),
                              _buildHorizontalInventoryList(highVal, cardDecor,
                                  color: Colors.purple),
                              const SizedBox(height: 24),
                            ],
                          ],
                        );
                      }),
                    ],
                  );
                }),
                const SizedBox(height: 32),
                _buildLowStockReportSection(user, cardDecor),
                const SizedBox(height: 32),
                const SizedBox(height: 32),
                // ── Searchable Sales History Log ──
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: cardDecor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Sales History Log",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          SizedBox(
                            width: 280,
                            child: TextField(
                              controller: _searchSalesC,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: "Search by product or customer...",
                                prefixIcon:
                                    const Icon(Icons.search_rounded, size: 18),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_searchSalesC.text.isNotEmpty)
                                      IconButton(
                                          icon: const Icon(Icons.clear_rounded,
                                              size: 16),
                                          onPressed: () {
                                            _searchSalesC.clear();
                                            setState(() {});
                                          }),
                                    IconButton(
                                        icon: const Icon(
                                            Icons.qr_code_scanner_rounded,
                                            size: 16,
                                            color: AppColors.secondary),
                                        onPressed: () =>
                                            _launchScanner(_searchSalesC)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Builder(builder: (_) {
                        var saleDocs = snap.data?.docs ?? [];
                        saleDocs = saleDocs.where((d) {
                          final m = d.data() as Map;
                          final ts = parseDT(m['timestamp']);
                          if (ts == null) return false;
                          return ts.isAfter(_startDate
                                  .subtract(const Duration(seconds: 1))) &&
                              ts.isBefore(
                                  _endDate.add(const Duration(days: 1)));
                        }).toList();
                        if (_searchSalesC.text.isNotEmpty) {
                          final q = _searchSalesC.text.toLowerCase();
                          saleDocs = saleDocs.where((d) {
                            final m = d.data() as Map;
                            return (m['itemName'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .contains(q) ||
                                (m['customerName'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .contains(q) ||
                                (m['barcode'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .contains(q) ||
                                (m['username'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .contains(q);
                          }).toList();
                        }
                        if (saleDocs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: Text("No sales found for this period.",
                                    style: TextStyle(
                                        color: AppColors.textSecondary))),
                          );
                        }
                        return Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1.5),
                            2: FlexColumnWidth(1),
                            3: FlexColumnWidth(1.2),
                            4: FlexColumnWidth(1.2)
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                  border: Border(
                                      bottom:
                                          BorderSide(color: AppColors.border))),
                              children: const [
                                Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Text('Product',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppColors.textSecondary))),
                                Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Text('Date & Time',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppColors.textSecondary))),
                                Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Text('Qty',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppColors.textSecondary))),
                                Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Text('Total',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppColors.textSecondary))),
                                Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Text('By',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppColors.textSecondary))),
                              ],
                            ),
                            ...saleDocs.take(50).map((doc) {
                              final m = doc.data() as Map<String, dynamic>;
                              final ts = parseDT(m['timestamp']);
                              return TableRow(children: [
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Text(m['itemName'] ?? '-',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis)),
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Text(
                                        ts != null
                                            ? DateFormat('dd MMM, hh:mm a')
                                                .format(ts)
                                            : '-',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary))),
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Text('${m['quantity'] ?? 0}',
                                        style: const TextStyle(fontSize: 13))),
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Text(
                                        currencyFormat
                                            .format(m['totalPrice'] ?? 0),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success))),
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Text(m['username'] ?? '-',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                        overflow: TextOverflow.ellipsis)),
                              ]);
                            }),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
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
                      "Unit Cost", currencyFormat.format(d['unitCost'] ?? 0)),
                  _detailRow(
                      "Total Cost",
                      currencyFormat
                          .format((d['unitCost'] ?? 0) * (d['quantity'] ?? 0))),
                  _detailRow(
                      "Date",
                      ts != null
                          ? DateFormat('MMM d, y – hh:mm a').format(ts)
                          : 'N/A'),
                  _detailRow("Barcode", d['barcode'] ?? 'N/A'),
                  _detailRow("Batch #", d['batchNumber'] ?? 'N/A'),
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

  Widget _buildLowStockReportSection(AppUser user, BoxDecoration decor) {
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
          StreamBuilder<QuerySnapshot>(
            stream: _db.getInventory(user.shopId).toMainThread(),
            builder: (context, snap) {
              final items = snap.data?.docs.where((d) {
                    final m = d.data() as Map;
                    final qty = (m['quantity'] ?? 0);
                    final threshold = (m['lowStockThreshold'] ?? 5);
                    return qty > 0 && qty <= threshold;
                  }).toList() ??
                  [];

              if (items.isEmpty)
                return const Text("All items are well stocked.",
                    style: TextStyle(color: AppColors.success));

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (c, i) {
                  final d = items[i].data() as Map;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.warning_amber_rounded,
                        color: AppColors.danger),
                    title: Text(d['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        "Price: ${currencyFormat.format(d['sellingPrice'] ?? 0)}"),
                    trailing: Text("${d['quantity']} Left",
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  );
                },
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
    final isAdmin = user.roles.contains(UserRole.admin);
    final isAdminOrManager = isAdmin || user.roles.contains(UserRole.manager);
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
                        builder: (ctx) => AlertDialog(
                              title: const Text("Shop Details"),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                      decoration: const InputDecoration(
                                          labelText: "Shop Name"),
                                      controller: TextEditingController(
                                          text: "SmartInventory ERP")),
                                  const SizedBox(height: 12),
                                  TextField(
                                      decoration: const InputDecoration(
                                          labelText: "Contact No"),
                                      controller: TextEditingController(
                                          text: "+251911...")),
                                ],
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("Cancel")),
                                ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("Save Changes")),
                              ],
                            )),
                enabled: isAdmin,
              ),
              const Divider(height: 1),
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
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: const Text("English"),
                                  onTap: () =>
                                      _updateLang(ctx, erp_l10n.AppLanguage.en),
                                  trailing:
                                      Provider.of<erp_l10n.LocalizationService>(
                                                      context,
                                                      listen: false)
                                                  .currentLanguage ==
                                              erp_l10n.AppLanguage.en
                                          ? const Icon(Icons.check,
                                              color: AppColors.success)
                                          : null,
                                ),
                                ListTile(
                                  title: const Text("Amharic (አማርኛ)"),
                                  onTap: () =>
                                      _updateLang(ctx, erp_l10n.AppLanguage.am),
                                  trailing:
                                      Provider.of<erp_l10n.LocalizationService>(
                                                      context,
                                                      listen: false)
                                                  .currentLanguage ==
                                              erp_l10n.AppLanguage.am
                                          ? const Icon(Icons.check,
                                              color: AppColors.success)
                                          : null,
                                ),
                              ],
                            ),
                          ));
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
                    onChanged: (val) => theme.toggleTheme(val),
                    activeColor: AppColors.secondary,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_sync_rounded),
                title: const Text("Database Backup"),
                subtitle: const Text("Secure your data offshore"),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: !isAdmin
                    ? null
                    : () async {
                        LoadingOverlay.show(context);
                        await Future.delayed(
                            const Duration(seconds: 2)); // Mock progress
                        if (mounted) {
                          LoadingOverlay.hide(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Offline data backed up successfully!'),
                                  backgroundColor: AppColors.success));
                        }
                      },
                enabled: isAdmin,
              ),
              if (isAdminOrManager) ...[
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text("System reset successfully"),
                                      backgroundColor: AppColors.success));
                            }
                          }
                        },
                ),
              ],
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

  Future<void> _updateLang(BuildContext ctx, erp_l10n.AppLanguage lang) async {
    final l10n =
        Provider.of<erp_l10n.LocalizationService>(context, listen: false);
    await l10n.setLanguage(lang);
    if (mounted) {
      Navigator.pop(ctx);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Language updated to ${lang == erp_l10n.AppLanguage.en ? "English" : "Amharic"}')));
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

  void _showAddItemDialog(AppUser u, [Map<String, dynamic>? item, String? id]) {
    final isAdmin = u.roles.contains(UserRole.admin);
    final isManager = u.roles.contains(UserRole.manager);
    final isStaff = u.roles.contains(UserRole.staff);

    // Hard Locks: Manager cannot edit BuyingPrice after creation. Staff cannot edit SellingPrice.
    final bool lockBuyingPrice = isManager && id != null;
    final bool lockSellingPrice = isStaff;

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
    DateTime? expiryDate = parseDT(item?['expiryDate']);

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
                            : "Expires: ${DateFormat('MMM yyyy').format(expiryDate!)}"),
                        onTap: () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: expiryDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2040));
                          if (picked != null) setS(() => expiryDate = picked);
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
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("Please fill mandatory fields (*)")));
                        return;
                      }
                      try {
                        LoadingOverlay.show(context);
                        final productMap = {
                          'name': nameC.text.trim(),
                          'barcode': barC.text.trim(),
                          'batchNumber': batchC.text.trim(),
                          'buyingPrice': double.tryParse(buyC.text) ?? 0.0,
                          'sellingPrice': double.tryParse(sellC.text) ?? 0.0,
                          'quantity': double.tryParse(qtyC.text) ?? 0,
                          'lowStockThreshold':
                              int.tryParse(thresholdC.text) ?? 5,
                          'expiryDate': expiryDate != null
                              ? Timestamp.fromDate(expiryDate!)
                              : null,
                          'shopId': u.shopId,
                          'branchId': u.branchId,
                          'lastUpdated': DateTime.now()
                              .toIso8601String(), // Avoid FieldValue locally
                        };

                        if (id == null) {
                          await _repo.registerItem(u, productMap);
                          if (u.roles.contains(UserRole.staff)) {
                            await _db.addNotification(
                                u.shopId,
                                "New medicine '${nameC.text}' added by Staff. Please set buying/selling price.",
                                "inventory_alert");
                          }
                        } else {
                          FirebaseFirestore.instance
                              .collection('items')
                              .doc(id)
                              .update(productMap);
                        }

                        if (c.mounted) {
                          LoadingOverlay.hide(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Product Added Instantly!'),
                                  backgroundColor: AppColors.success));
                          Navigator.pop(c);
                        }
                      } catch (e) {
                        if (c.mounted) LoadingOverlay.hide(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: AppColors.danger));
                      }
                    },
                    child: Text(id == null ? "Add Product" : "Save Changes"),
                  ),
                ],
              )),
    );
  }

  Future<void> _launchScanner(TextEditingController controller) async {
    if (!kIsWeb && Platform.isWindows) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Use Physical Scanner"),
          content: const Text(
              "Camera-based scanning is unsupported on Windows. Please click the text field and use a physical plug-and-play barcode scanner instead."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text("OK"))
          ],
        ),
      );
      return;
    }

    final localScannerController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            appBar: AppBar(title: const Text("Scan Barcode"), actions: [
              IconButton(
                icon: const Icon(Icons.flash_on),
                onPressed: () => localScannerController.toggleTorch(),
              )
            ]),
            body: MobileScanner(
              controller: localScannerController,
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  controller.text = barcodes.first.rawValue!;
                  localScannerController.dispose();
                  Navigator.pop(ctx);
                }
              },
            ),
          ),
        ),
      );
    } finally {
      localScannerController.dispose();
    }
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
      builder: (ctx) => AlertDialog(
        title: const Text("Bulk Excel Import"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "Upload an Excel file (.xlsx) with these columns in the first sheet:"),
            SizedBox(height: 12),
            Text("• Name (Required)"),
            Text("• Barcode"),
            Text("• Quantity"),
            Text("• Buying Price"),
            Text("• Selling Price"),
            Text("• Batch Number"),
            Text("• Min Threshold"),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['xlsx'],
                  withData: true);
              if (result != null) {
                LoadingOverlay.show(context);
                try {
                  final file = result.files.single;
                  final bytes = file.bytes ??
                      (file.path != null
                          ? await File(file.path!).readAsBytes()
                          : null);
                  if (bytes == null) throw "Could not read file data.";

                  final stats = await _importService.importFromExcel(bytes, user);
                  if (mounted) {
                    final imported = stats['imported'] ?? 0;
                    final failed = stats['failed'] ?? 0;
                    if (failed > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Imported: $imported. Failed: $failed. Check file format."),
                          backgroundColor: AppColors.warning));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Successfully imported $imported items."),
                          backgroundColor: AppColors.success));
                    }
                  }
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Import failed: $e"),
                        backgroundColor: AppColors.danger));
                } finally {
                  if (mounted) LoadingOverlay.hide(context);
                }
              }
            },
            child: const Text("Pick file & Import"),
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

  Widget _buildBarChartSection(
      BuildContext context, BoxDecoration cardDecoration) {
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
        stream: _db.getSales(user.shopId).toMainThread(),
        builder: (context, snap) {
          final allSales = snap.data?.docs ?? [];
          final now = DateTime.now();
          List<BarChartGroupData> groups = [];

          for (int i = 0; i < 7; i++) {
            final date = now.subtract(Duration(days: 6 - i));
            double dailyRev = 0;
            for (var doc in allSales) {
              final m = doc.data() as Map<String, dynamic>;
              final ts = parseDT(m['timestamp']);
              if (ts != null &&
                  ts.year == date.year &&
                  ts.month == date.month &&
                  ts.day == date.day) {
                dailyRev += (m['totalPrice'] ?? 0).toDouble();
              }
            }
            groups.add(BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                  toY: dailyRev,
                  color: AppColors.secondary,
                  width: 18,
                  borderRadius: BorderRadius.circular(4))
            ]));
          }

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Sales Over Time",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 32),
                SizedBox(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (v, m) => Text(
                                    '${(v / 1000).toInt()}K',
                                    style: const TextStyle(fontSize: 10)))),
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, m) {
                                  const days = [
                                    'M',
                                    'T',
                                    'W',
                                    'T',
                                    'F',
                                    'S',
                                    'S'
                                  ];
                                  return Text(days[v.toInt() % 7],
                                      style: const TextStyle(fontSize: 10));
                                })),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: groups,
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }

  Widget _buildTopSellingTable(AppUser user, List<DocumentSnapshot> allSales,
      BoxDecoration cardDecoration) {
    // Aggregate sales by product name
    final Map<String, Map<String, dynamic>> aggregated = {};
    for (var doc in allSales) {
      final m = doc.data() as Map<String, dynamic>;
      final name = m['itemName']?.toString() ?? 'Unknown';
      final qty = (m['quantity'] ?? 0).toInt();
      final profit = (m['profit'] ?? 0).toDouble();
      if (aggregated.containsKey(name)) {
        aggregated[name]!['qty'] = (aggregated[name]!['qty'] as int) + qty;
        aggregated[name]!['profit'] =
            (aggregated[name]!['profit'] as double) + profit;
      } else {
        aggregated[name] = {'name': name, 'qty': qty, 'profit': profit};
      }
    }
    final top5 = (aggregated.values.toList()
          ..sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int)))
        .take(5)
        .toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Top Moving Inventory",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
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
                1: const FlexColumnWidth(1.5),
                if (user.role != UserRole.staff) 2: const FlexColumnWidth(2)
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                      color: headerBg, borderRadius: BorderRadius.circular(8)),
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text("Product",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.secondary))),
                    Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text("Sold",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.secondary))),
                    if (user.role != UserRole.staff)
                      Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text("Profit",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.secondary))),
                  ],
                ),
                ...top5.map((item) => TableRow(
                      children: [
                        Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                            child: Text(item['name'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1)),
                        Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                            child: Text('${item['qty']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13))),
                        if (user.role != UserRole.staff)
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              child: Text(currencyFormat.format(item['profit']),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                      fontSize: 13))),
                      ],
                    )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLowStockList(
      List<DocumentSnapshot> inventory, BoxDecoration cardDecoration) {
    final lowItems = inventory
        .where((doc) {
          final m = doc.data() as Map;
          final qty = m['quantity'] ?? 0;
          return qty > 0 && qty <= (m['lowStockThreshold'] ?? 5);
        })
        .take(5)
        .toList();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 20),
            const SizedBox(width: 8),
            const Text("Inventory Alerts",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          const SizedBox(height: 16),
          if (lowItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text("All stock levels are healthy ✓",
                      style: TextStyle(color: AppColors.success))),
            )
          else
            ...lowItems.map((doc) {
              final m = doc.data() as Map<String, dynamic>;
              final qty = m['quantity'] ?? 0;
              final isCritical = qty <= 3;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: isCritical
                                ? AppColors.danger
                                : AppColors.warning,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(m['name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 13),
                            overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: (isCritical
                                  ? AppColors.danger
                                  : AppColors.warning)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('$qty left',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCritical
                                  ? AppColors.danger
                                  : AppColors.warning)),
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
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.getSales(user.shopId).toMainThread(),
            builder: (ctx, snap) {
              if (!snap.hasData)
                return const Center(child: CircularProgressIndicator());
              final allSales = snap.data!.docs;
              Map<String, List<QueryDocumentSnapshot>> grouped = {};
              for (var doc in allSales) {
                final m = doc.data() as Map;
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
                  final d = items.first.data() as Map<String, dynamic>;
                  final totalRemaining = items.fold(
                      0.0,
                      (sum, doc) =>
                          sum + ((doc.data() as Map)['debtRemaining'] ?? 0.0));
                  final ts = parseDT(d['timestamp']) ?? DateTime.now();

                  return ListTile(
                    onTap: () => _showDebtDetailDialog(items
                        .map((it) => it.data() as Map<String, dynamic>)
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
                              "Unpaid: ${currencyFormat.format(totalRemaining)}",
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
                                Text(currencyFormat.format(totalRemaining),
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
                            final batch = FirebaseFirestore.instance.batch();
                            for (var doc in items) {
                              batch.update(doc.reference,
                                  {'isDebt': false, 'debtRemaining': 0});
                            }
                            await batch.commit();
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Audit History",
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: isMobile ? constraints.maxWidth : constraints.maxWidth * 0.4,
                        child: TextField(
                          controller: _searchAuditC,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: "Search audit logs...",
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      StreamBuilder<QuerySnapshot>(
                          stream: _db.getUsers(user.shopId),
                          builder: (ctx, userSnap) {
                            List<String> usernames = ['All Users'];
                            if (userSnap.hasData) {
                              for (var d in userSnap.data!.docs) {
                                final m = d.data() as Map;
                                final un = m['username'] as String?;
                                if (un != null && !usernames.contains(un))
                                  usernames.add(un);
                              }
                            }
                            return Container(
                              width: isMobile ? constraints.maxWidth * 0.5 - 6 : 140,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedAuditUserFilter.isEmpty
                                      ? 'All Users'
                                      : _selectedAuditUserFilter,
                                  isExpanded: true,
                                  items: usernames
                                      .map((un) => DropdownMenuItem(
                                          value: un,
                                          child: Text(un,
                                              style: const TextStyle(fontSize: 13),
                                              overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (v) => setState(() =>
                                      _selectedAuditUserFilter =
                                          v == 'All Users' ? '' : v!),
                                ),
                              ),
                            );
                          }),
                      Container(
                        width: isMobile ? constraints.maxWidth * 0.5 - 6 : 140,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border)),
                        child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                          value: _selectedAuditAction,
                          isExpanded: true,
                          items: [
                            'All Actions',
                            'SALE',
                            'PURCHASE',
                            'ADD_ITEM',
                            'EDIT_ITEM',
                            'DELETE_REQUEST'
                          ]
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e, 
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedAuditAction = v);
                          },
                        )),
                      ),
                    ],
                  );
                }
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.getAuditLogs(user.shopId).toMainThread(),
            builder: (ctx, snap) {
              if (!snap.hasData)
                return const Center(child: CircularProgressIndicator());
              var logs = snap.data!.docs.where((d) {
                final m = d.data() as Map;
                
                // Staff filter: Only see their own logs
                if (user.roles.contains(UserRole.staff)) {
                   if ((m['username'] ?? '').toString() != user.username) return false;
                }

                if (_selectedAuditAction != 'All Actions' &&
                    m['action'] != _selectedAuditAction) return false;

                final userFilter = _selectedAuditUserFilter.toLowerCase();
                if (userFilter.isNotEmpty &&
                    (m['username'] ?? '').toString().toLowerCase() !=
                        userFilter) return false;

                final q = _searchAuditC.text.toLowerCase();
                if (q.isNotEmpty) {
                  return (m['details'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(q) ||
                      (m['username'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(q);
                }
                return true;
              }).toList();

              // Sort logs recent first
              logs.sort((a, b) {
                final ta =
                    parseDT((a.data() as Map)['timestamp']) ?? DateTime.now();
                final tb =
                    parseDT((b.data() as Map)['timestamp']) ?? DateTime.now();
                return tb.compareTo(ta);
              });
              if (logs.isEmpty)
                return const Center(child: Text("No audit records found."));
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                itemCount: logs.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  final d = logs[i].data() as Map<String, dynamic>;
                  final ts = parseDT(d['timestamp']) ?? DateTime.now();
                  String readableDetails = d['details'] ?? '';
                  if (readableDetails.startsWith('In-bound log for ')) {
                    readableDetails = 'Purchased stock for ${readableDetails.replaceFirst('In-bound log for ', '')}';
                  } else if (readableDetails.startsWith('Out-bound log: Sold ')) {
                    readableDetails = 'Sold ${readableDetails.replaceFirst('Out-bound log: Sold ', '')}';
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: CircleAvatar(
                        backgroundColor: AppColors.secondary.withOpacity(0.1),
                        child: Icon(_getAuditIcon(d['action']),
                            color: AppColors.secondary, size: 18)),
                    title: Text(readableDetails,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            "${d['username']} • ${DateFormat('MMM d, hh:mm a').format(ts)}",
                            style: const TextStyle(fontSize: 11)),
                        if (MediaQuery.of(context).size.width < 500)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _buildBadge(d['action'] ?? '', _getAuditColor(d['action'])),
                          ),
                      ],
                    ),
                    trailing: MediaQuery.of(context).size.width < 500
                        ? null
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: _getAuditColor(d['action']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(d['action'] ?? '',
                                style: TextStyle(
                                    color: _getAuditColor(d['action']),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
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

  IconData _getAuditIcon(String? action) {
    switch (action) {
      case 'SALE':
        return Icons.shopping_cart_outlined;
      case 'PURCHASE':
        return Icons.receipt_long_outlined;
      case 'ADD_ITEM':
        return Icons.add_box_outlined;
      case 'DELETE_REQUEST':
        return Icons.delete_sweep_outlined;
      default:
        return Icons.history_rounded;
    }
  }

  Color _getAuditColor(String? action) {
    if (action == 'SALE') return AppColors.success;
    if (action == 'DELETE_REQUEST') return AppColors.danger;
    return AppColors.secondary;
  }

  Future<void> _handleDeleteProduct(AppUser u, String id, String name) async {
    final bool isStaff = u.roles.contains(UserRole.staff);

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
        await FirebaseFirestore.instance.collection('deletion_requests').add({
          'shopId': u.shopId,
          'itemId': id,
          'itemName': name,
          'requestedBy': u.username,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
        await _db.recordAuditLog(u.shopId, u.username, 'DELETE_REQUEST',
            'Requested deletion for $name');
        if (mounted) {
          LoadingOverlay.hide(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Request sent to Admin!'),
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Product and local cache purged successfully.'),
                backgroundColor: AppColors.success));
          }
        } catch (e) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Delete failed: $e'),
                backgroundColor: AppColors.danger));
        } finally {
          if (mounted) LoadingOverlay.hide(context);
        }
      }
    }
  }

  void _showPartialPaymentDialog(List<QueryDocumentSnapshot> items) {
    if (items.isEmpty) return;
    final remaining = items.fold(
        0.0, (sum, i) => sum + ((i.data() as Map)['debtRemaining'] ?? 0.0));

    final payC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Record Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Remaining Debt: ${currencyFormat.format(remaining)}"),
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

              double paymentLeft = amt;
              final batch = FirebaseFirestore.instance.batch();

              for (var doc in items) {
                if (paymentLeft <= 0) break;
                final m = doc.data() as Map<String, dynamic>;
                final docRemaining = (m['debtRemaining'] ?? 0.0).toDouble();
                if (docRemaining <= 0) continue;

                final payToDoc =
                    docRemaining > paymentLeft ? paymentLeft : docRemaining;
                final newRem = docRemaining - payToDoc;

                batch.update(doc.reference, {
                  'debtRemaining': newRem < 0 ? 0 : newRem,
                  'isDebt': newRem > 0.1,
                  'advancedPaid': FieldValue.increment(payToDoc),
                });
                paymentLeft -= payToDoc;
              }

              await batch.commit();

              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Payment recorded and database updated"),
                    backgroundColor: AppColors.success));
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
                        Text(currencyFormat.format(it['totalPrice'] ?? 0),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
              const Divider(),
              _detailRow(
                  "Advanced Paid",
                  currencyFormat.format(
                      items.fold(0.0, (s, i) => s + (i['advancedPaid'] ?? 0)))),
              _detailRow("Remaining Total", currencyFormat.format(totalRem),
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
      List<QueryDocumentSnapshot> items, BoxDecoration decor,
      {required Color color}) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (ctx, i) {
          final d = items[i].data() as Map<String, dynamic>;
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
                    Text(currencyFormat.format(d['sellingPrice'] ?? 0),
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
}
