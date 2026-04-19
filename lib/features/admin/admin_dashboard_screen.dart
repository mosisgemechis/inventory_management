import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/utils/file_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:badges/badges.dart' as badges;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/validation_service.dart';
import '../../core/services/import_service.dart';
import '../../core/services/reporting_service.dart';
import '../../core/repositories/inventory_repository.dart';
import '../../core/constants/colors.dart';
import '../../core/widgets/erp_components.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../core/utils/thread_safe_stream.dart';
import '../../core/models/models.dart';
import 'package:file_picker/file_picker.dart';

class AdminDashboardScreen extends StatefulWidget {
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
  final currencyFormat = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 2);
  String _searchQuery = "";
  String _selectedBranchId = "all";

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth > 900;
      final sidebarItems = [
        SidebarItem(icon: Icons.grid_view_rounded, label: 'Overview'),
        SidebarItem(icon: Icons.analytics_outlined, label: 'Analytics'),
        SidebarItem(icon: Icons.inventory_2_outlined, label: 'Inventory'),
        SidebarItem(icon: Icons.receipt_long_rounded, label: 'Sales Feed'),
        SidebarItem(icon: Icons.local_shipping_outlined, label: 'Suppliers'),
        SidebarItem(icon: Icons.payments_rounded, label: 'Kibid (Debt)'),
        SidebarItem(icon: Icons.history_edu_rounded, label: 'Audit Logs'),
        SidebarItem(icon: Icons.settings_suggest_outlined, label: 'Settings'),
      ];

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: desktop ? null : _buildMobileAppBar(user),
        body: Row(
          children: [
            if (desktop) ERPSidebar(
              selectedIndex: _selectedIndex, 
              items: sidebarItems,
              onItemSelected: _onItemTapped,
            ),
            Expanded(child: Column(children: [
              if (desktop) _buildDesktopHeader(user),
              Expanded(child: _buildBody(user)),
            ])),
          ],
        ),
        bottomNavigationBar: desktop ? null : _buildBottomNav(),
        floatingActionButton: _selectedIndex == 2 ? _buildAddItemFAB(user) : null,
      );
    });
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  PreferredSizeWidget _buildMobileAppBar(AppUser user) {
    return AppBar(
      elevation: 0, backgroundColor: Colors.white,
      title: Text("Admin Console", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
      actions: [_buildNotificationBadge(user.shopId), const SizedBox(width: 8)],
    );
  }

  Widget _buildDesktopHeader(AppUser user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      color: Colors.white,
      child: Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_getTabTitle(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: -1)),
            Text(user.username, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ]),
          const Spacer(),
          _buildBranchFilter(user.shopId),
          const SizedBox(width: 24),
          _buildNotificationBadge(user.shopId),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20), onPressed: () => context.read<AuthService>().signOut()),
        ],
      ),
    );
  }

  String _getTabTitle() {
    switch (_selectedIndex) {
      case 0: return 'Dashboard Overview';
      case 1: return 'Detailed Analytics';
      case 2: return 'Inventory Management';
      case 3: return 'Live Sales Stream';
      case 4: return 'Supplier Relations';
      case 5: return 'Credit Ledger';
      case 6: return 'System Audit';
      case 7: return 'Global Settings';
      default: return 'Admin Panel';
    }
  }

  Widget _buildBranchFilter(String shopId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.getBranches(shopId),
      builder: (context, snapshot) {
        List<DropdownMenuItem<String>> items = [
          const DropdownMenuItem(value: "all", child: Text("All Branches", style: TextStyle(fontSize: 12))),
        ];
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            String name = (doc.data() as Map)['name'] ?? 'Unknown';
            items.add(DropdownMenuItem(value: doc.id, child: Text(name, style: const TextStyle(fontSize: 12)))); 
          }
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
          child: DropdownButton<String>(
            value: _selectedBranchId, items: items, underline: const SizedBox(), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
            onChanged: (v) => setState(() => _selectedBranchId = v!),
          ),
        );
      },
    );
  }

  Widget _buildNotificationBadge(String shopId) {
    return badges.Badge(
      showBadge: false,
      child: IconButton(icon: const Icon(Icons.notifications_none_rounded, size: 20), onPressed: () {}),
    );
  }

  Widget _buildBody(AppUser user) {
    return IndexedStack(index: _selectedIndex, children: [
      _KeepAliveWrapper(child: _buildHomeTab(user)),
      _KeepAliveWrapper(child: _buildReportsTab(user)),
      _KeepAliveWrapper(child: _buildInventoryTab(user)),
      _KeepAliveWrapper(child: _buildSalesTab(user)),
      _KeepAliveWrapper(child: _buildSupplierTab(user)),
      _KeepAliveWrapper(child: _buildDebtTab(user)),
      _KeepAliveWrapper(child: _buildAuditLogTab(user)),
      _KeepAliveWrapper(child: _buildSettingsTab(user)),
    ]);
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _selectedIndex > 4 ? 4 : _selectedIndex, onDestinationSelected: _onItemTapped,
      destinations: [
        NavigationDestination(icon: const Icon(Icons.grid_view_rounded), label: 'Home'),
        NavigationDestination(icon: const Icon(Icons.bar_chart_rounded), label: 'Report'),
        NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), label: 'Stock'),
        NavigationDestination(icon: const Icon(Icons.shopping_bag_outlined), label: 'Sales'),
        NavigationDestination(icon: const Icon(Icons.settings_outlined), label: 'Settings'),
      ],
    );
  }

  // --- TAB IMPLEMENTATIONS ---

  Widget _buildHomeTab(AppUser user) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.getSales(user.shopId).toMainThread(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        double rev = 0; double prof = 0; Map<String, double> chart = {};
        final now = DateTime.now();
        for(var doc in snapshot.data!.docs) {
           final m = doc.data() as Map;
           if (_selectedBranchId != "all" && m['branchId'] != _selectedBranchId) continue;
           final ts = (m['timestamp'] as Timestamp?)?.toDate() ?? now;
           rev += (m['totalPrice'] ?? 0).toDouble(); prof += (m['profit'] ?? 0).toDouble();
           String k = DateFormat('MM/dd').format(ts); chart[k] = (chart[k] ?? 0.0) + (m['profit'] ?? 0).toDouble();
        }
        return ListView(padding: const EdgeInsets.all(32), children: [
          Row(children: [
            Expanded(child: StatCard(title: 'REVENUE', value: currencyFormat.format(rev), color: AppColors.secondary, icon: Icons.insights)),
            const SizedBox(width: 24),
            Expanded(child: StatCard(title: 'PROFIT', value: currencyFormat.format(prof), color: AppColors.success, icon: Icons.trending_up)),
          ]),
          const SizedBox(height: 32),
          _buildChartSection(chart),
          const SizedBox(height: 32),
          _buildDetailedReportSection(user),
        ]);
      },
    );
  }

  Widget _buildReportsTab(AppUser user) {
    return StreamBuilder<QuerySnapshot>(stream: _db.getSales(user.shopId).toMainThread(), builder: (c, salesSnap) {
      if (!salesSnap.hasData) return const Center(child: CircularProgressIndicator());
      return StreamBuilder<QuerySnapshot>(stream: _db.getInventory(user.shopId).toMainThread(), builder: (c, invSnap) {
        if (!invSnap.hasData) return const Center(child: CircularProgressIndicator());
        
        final allSales = salesSnap.data!.docs.where((d) => _selectedBranchId == 'all' || (d.data() as Map)['branchId'] == _selectedBranchId).toList();
        final allInv = invSnap.data!.docs.where((d) => _selectedBranchId == 'all' || (d.data() as Map)['branchId'] == _selectedBranchId).toList();
        final now = DateTime.now();
        
        final todaySales = allSales.where((d) { final ts = ((d.data() as Map)['timestamp'] as Timestamp?)?.toDate() ?? now; return ts.day == now.day && ts.month == now.month && ts.year == now.year; }).toList();
        double dRev = todaySales.fold(0.0, (p, e) => p + ((e.data() as Map)['totalPrice'] ?? 0).toDouble());
        double dProf = todaySales.fold(0.0, (p, e) => p + ((e.data() as Map)['profit'] ?? 0).toDouble());
        
        final weekSales = allSales.where((d) { final ts = ((d.data() as Map)['timestamp'] as Timestamp?)?.toDate() ?? now; return ts.isAfter(now.subtract(const Duration(days: 7))); }).toList();
        double wRev = weekSales.fold(0.0, (p, e) => p + ((e.data() as Map)['totalPrice'] ?? 0).toDouble());
        double wProf = weekSales.fold(0.0, (p, e) => p + ((e.data() as Map)['profit'] ?? 0).toDouble());

        double stockValue = allInv.fold(0.0, (p, e) => p + ((e.data() as Map)['buyingPrice'] ?? 0) * ((e.data() as Map)['quantity'] ?? 0));
        final debtSales = allSales.where((d) => (d.data() as Map)['isDebt'] == true && ((d.data() as Map)['debtRemaining'] ?? 0) > 0).toList();
        double totalDebt = debtSales.fold(0.0, (p, e) => p + ((e.data() as Map)['debtRemaining'] ?? 0).toDouble());

        return ListView(padding: const EdgeInsets.all(32), children: [
          Row(children: [
            const Text("Financial Reports", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(onPressed: () => _exportSalesReport(allSales), icon: const Icon(Icons.download_rounded, size: 16), label: const Text("EXPORT"), style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white)),
          ]),
          const SizedBox(height: 16),
          _buildReportSummaryGrid(dRev, dProf, wRev, wProf, stockValue, totalDebt),
          const SizedBox(height: 32),
          _buildDetailedReportSection(user),
        ]);
      });
    });
  }

  Widget _buildInventoryTab(AppUser user) {
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20), child: Row(children: [
        Expanded(child: TextField(onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()), decoration: const InputDecoration(hintText: 'Filter inventory...', prefixIcon: Icon(Icons.search, size: 18)))),
        const SizedBox(width: 16),
        ElevatedButton.icon(onPressed: () => _handleImport(user), icon: const Icon(Icons.upload_file_rounded, size: 18), label: const Text("IMPORT"), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
      ])),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: _db.getInventory(user.shopId).toMainThread(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!.docs.where((d) {
            final m = d.data() as Map;
            final matchesSearch = (m['name']??'').toLowerCase().contains(_searchQuery) || (m['barcode']??'').contains(_searchQuery);
            final matchesBranch = _selectedBranchId == 'all' || m['branchId'] == _selectedBranchId;
            return matchesSearch && matchesBranch;
          }).toList();
          return ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 32), itemCount: items.length, separatorBuilder: (c, i) => const Divider(height: 1), itemBuilder: (context, index) {
            final item = items[index].data() as Map<String, dynamic>;
            final qty = item['quantity'] ?? 0;
            return ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 8), title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Price: ${currencyFormat.format(item['sellingPrice'] ?? 0)} | Barcode: ${item['barcode'] ?? 'N/A'}'), trailing: SizedBox(width: 160, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('$qty units', style: TextStyle(color: qty < (item['lowStockThreshold'] ?? 5) ? AppColors.danger : AppColors.success, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showEditItemDialog(items[index])),
            ])));
          });
        },
      ))
    ]);
  }

  Widget _buildSalesTab(AppUser user) {
     return StreamBuilder<QuerySnapshot>(stream: _db.getSales(user.shopId).toMainThread(), builder: (c, s) {
       if (!s.hasData) return const Center(child: CircularProgressIndicator());
       final docs = s.data?.docs.where((d) => _selectedBranchId == 'all' || (d.data() as Map)['branchId'] == _selectedBranchId).toList() ?? [];
       return ListView.builder(padding: const EdgeInsets.all(32), itemCount: docs.length, itemBuilder: (c, i) {
          final data = docs[i].data() as Map<String, dynamic>;
          return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
            title: Text(data['itemName'] ?? 'Unknown Item'), 
            subtitle: Text('Sold by: ${data['username'] ?? 'User'} | Qty: ${data['quantity']}'), 
            trailing: SizedBox(width: 160, child: Align(alignment: Alignment.centerRight, child: Text(currencyFormat.format(data['totalPrice'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))))));
       });
     });
  }

  Widget _buildSupplierTab(AppUser user) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(32), child: Row(children: [
        const Expanded(child: Text("Active Suppliers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ElevatedButton.icon(onPressed: () => _showAddSupplierDialog(user.shopId), icon: const Icon(Icons.add_business_rounded, size: 16), label: const Text("NEW")),
      ])),
      Expanded(child: StreamBuilder<QuerySnapshot>(stream: _db.getSuppliers(user.shopId).toMainThread(), builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = s.data?.docs ?? [];
        return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 32), itemCount: docs.length, itemBuilder: (c, i) {
          final doc = docs[i];
          final m = doc.data() as Map<String, dynamic>;
          return Card(child: ListTile(
             title: Text(m['name'] ?? 'Supplier'),
             subtitle: Text('Debt: ${currencyFormat.format(m['outstandingDebt'] ?? 0)}\nTotal Paid: ${currencyFormat.format(m['totalPaid'] ?? 0)}'),
             isThreeLine: true,
             trailing: SizedBox(width: 160, child: Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                 if ((m['outstandingDebt'] ?? 0.0) > 0)
                   ElevatedButton(onPressed: () => _showPaySupplierDialog(doc.id, m['outstandingDebt']), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(horizontal: 8)), child: const Text('PAY', style: TextStyle(fontSize: 10, color: Colors.white))),
                 IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), onPressed: () => doc.reference.delete())
             ])),
          ));
        });
      })),
    ]);
  }

  Widget _buildDebtTab(AppUser user) {
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('sales').where('shopId', isEqualTo: user.shopId).where('isDebt', isEqualTo: true).snapshots().toMainThread(), builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final docs = snapshot.data?.docs.where((d) => _selectedBranchId == 'all' || (d.data() as Map)['branchId'] == _selectedBranchId).where((d) => ((d.data() as Map)['debtRemaining'] ?? 0) > 0).toList() ?? [];
      if (docs.isEmpty) return const Center(child: Text("No upcoming debts (Kibid) found.", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)));
      return ListView.builder(padding: const EdgeInsets.all(32), itemCount: docs.length, itemBuilder: (context, i) {
        final d = docs[i].data() as Map<String, dynamic>;
        return Card(child: ListTile(title: Text(d['itemName'] ?? 'Unknown Item'), subtitle: Text('Customer: ${d['customerName'] ?? "Guest"} | Sold By: ${d['username']}'), trailing: SizedBox(width: 160, child: Row(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text(currencyFormat.format(d['debtRemaining'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 13)),
          IconButton(icon: const Icon(Icons.check_circle_rounded, color: AppColors.success), onPressed: () => docs[i].reference.update({'debtRemaining': 0.0, 'isDebt': false})),
        ]))));
      });
    });
  }

  Widget _buildAuditLogTab(AppUser user) {
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('audit_logs').where('shopId', isEqualTo: user.shopId).snapshots().toMainThread(), builder: (c, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final docs = s.data?.docs.toList() ?? [];
      docs.sort((a,b) {
        final ta = (a.data() as Map)['timestamp'] as Timestamp?;
        final tb = (b.data() as Map)['timestamp'] as Timestamp?;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });
      return ListView.builder(padding: const EdgeInsets.all(32), itemCount: docs.length, itemBuilder: (c, i) => ListTile(title: Text("${(docs[i].data() as Map)['username'] ?? 'User'}: ${(docs[i].data() as Map)['action'] ?? ''}"), subtitle: Text("${(docs[i].data() as Map)['details'] ?? ''}"), leading: const Icon(Icons.history_toggle_off_rounded, size: 20)));
    });
  }

  Widget _buildSettingsTab(AppUser user) {
    return ListView(padding: const EdgeInsets.all(32), children: [
       Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.security_rounded, color: AppColors.primary), title: const Text("Edit My Credentials"), subtitle: const Text("Update username or password"), onTap: () => _showEditSelfDialog(user)),
          ListTile(leading: const Icon(Icons.manage_accounts_rounded), title: const Text("Manage Staff & Roles"), onTap: _showManageUsers),
          ListTile(leading: const Icon(Icons.business_rounded), title: const Text("Manage Branches"), onTap: _showManageBranches),
          ListTile(leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger), title: const Text("WIPE SHOP DATA"), onTap: () => _showWipeConfirm(user.shopId)),
       ])),
    ]);
  }

  // --- HELPER METHODS ---

  void _showEditSelfDialog(AppUser u) {
    final n = TextEditingController(text: u.username); 
    final p = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Update Credentials'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: n, decoration: const InputDecoration(labelText: 'New Username')),
      TextField(controller: p, decoration: const InputDecoration(labelText: 'New Password (Optional)')),
    ]), actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
      ElevatedButton(onPressed: () async {
         await Provider.of<AuthService>(context, listen: false).updateUsername(n.text);
         if (c.mounted) Navigator.pop(c);
      }, child: const Text('Update'))
    ]));
  }

  void _showManageUsers() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Management interface coming in next update.")));
  }

  void _showManageBranches() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Branch Management interface coming in next update.")));
  }

  void _showWipeConfirm(String shopId) {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("WIPE ALL DATA?"), content: const Text("This will permanently delete all items, sales, and suppliers for this shop. This cannot be undone."), actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
      ElevatedButton(onPressed: () async {
        await _db.clearAllData(shopId);
        if (c.mounted) Navigator.pop(c);
      }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text("WIPE EVERYTHING")),
    ]));
  }

  void _showEditItemDialog(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final nameC = TextEditingController(text: d['name']);
    final buyC = TextEditingController(text: d['buyingPrice'].toString());
    final sellC = TextEditingController(text: d['sellingPrice'].toString());
    final qtyC = TextEditingController(text: d['quantity'].toString());
    final thresholdC = TextEditingController(text: (d['lowStockThreshold'] ?? 5).toString());

    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Edit Item'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Item Name')),
        TextField(controller: buyC, decoration: const InputDecoration(labelText: 'Buying Price')),
        TextField(controller: sellC, decoration: const InputDecoration(labelText: 'Selling Price')),
        TextField(controller: qtyC, decoration: const InputDecoration(labelText: 'Manual Qty Correction')),
        TextField(controller: thresholdC, decoration: const InputDecoration(labelText: 'Low Stock Threshold')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          LoadingOverlay.show(context);
          try {
            await _db.updateItem(doc.id, {
              'name': nameC.text,
              'buyingPrice': double.tryParse(buyC.text) ?? 0.0,
              'sellingPrice': double.tryParse(sellC.text) ?? 0.0,
              'quantity': int.tryParse(qtyC.text) ?? 0,
              'lowStockThreshold': int.tryParse(thresholdC.text) ?? 5,
            });
            if (c.mounted) Navigator.pop(c);
          } finally {
            if (context.mounted) LoadingOverlay.hide(context);
          }
        }, child: const Text('Save')),
      ],
    ));
  }

  void _showAddItemDialog(AppUser u) {
    final nameC = TextEditingController();
    final barC = TextEditingController();
    final batchC = TextEditingController();
    final buyC = TextEditingController();
    final sellC = TextEditingController();
    final qtyC = TextEditingController();
    String branchId = _selectedBranchId == 'all' ? 'main' : _selectedBranchId;
    DateTime? expDate;

    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setS) => AlertDialog(
      title: const Text('New Item Registry'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Item Name')),
        Row(children: [
          Expanded(child: TextField(controller: barC, decoration: const InputDecoration(labelText: 'Barcode'))),
          IconButton(icon: const Icon(Icons.qr_code_scanner_rounded), onPressed: () {}),
        ]),
        const SizedBox(height: 8),
        ListTile(contentPadding: EdgeInsets.zero, title: Text(expDate == null ? 'Select Expiry Date' : 'Exp: ${DateFormat('yyyy-MM-dd').format(expDate!)}'), trailing: const Icon(Icons.calendar_month_rounded), onTap: () async {
           final p = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 365)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
           if (p != null) setS(() => expDate = p);
        }),
        TextField(controller: batchC, decoration: const InputDecoration(labelText: 'Batch Number')),
        Row(children: [
          Expanded(child: TextField(controller: buyC, decoration: const InputDecoration(labelText: 'Cost Price'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: sellC, decoration: const InputDecoration(labelText: 'Selling Price'))),
        ]),
        TextField(controller: qtyC, decoration: const InputDecoration(labelText: 'Initial Quantity')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (nameC.text.isEmpty) return;
          LoadingOverlay.show(context);
          try {
            await _repo.registerItem(u, {
              'shopId': u.shopId, 'branchId': branchId, 'name': nameC.text, 'barcode': barC.text, 'batchNumber': batchC.text,
              'buyingPrice': double.tryParse(buyC.text) ?? 0.0, 'sellingPrice': double.tryParse(sellC.text) ?? 0.0,
              'quantity': int.tryParse(qtyC.text) ?? 0, 'branchName': 'Main Office', 'expiryDate': expDate?.toIso8601String(),
            });
            if (c.mounted) Navigator.pop(c);
          } catch(e) {
            if (c.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
          } finally {
            if (context.mounted) LoadingOverlay.hide(context);
          }
        }, child: const Text('Add Item'))
      ],
    )));
  }

  Future<void> _handleImport(AppUser user) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'xlsx']);
    if (result != null) {
      LoadingOverlay.show(context);
      try {
        Uint8List bytes;
        if (kIsWeb) {
          bytes = result.files.single.bytes!;
        } else {
          bytes = await readFileAsBytes(result.files.single.path!);
        }
        Map<String, int> stats;
        if (result.files.single.extension == 'csv') {
          stats = await _importService.importFromCSV(bytes, user.shopId, user.username);
        } else {
          stats = await _importService.importFromExcel(bytes, user.shopId, user.username);
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import Complete: ${stats['imported']} added, ${stats['skipped']} skipped."), backgroundColor: AppColors.success));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import Failed: $e"), backgroundColor: AppColors.danger));
      } finally {
        LoadingOverlay.hide(context);
      }
    }
  }

  Future<void> _exportSalesReport(List<DocumentSnapshot> sales) async {
    final List<String> headers = ['Item', 'Qty', 'Total', 'Profit', 'Customer', 'Date'];
    final List<List<dynamic>> rows = sales.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final ts = (d['timestamp'] as Timestamp).toDate();
      return [d['itemName'], d['quantity'], d['totalPrice'], d['profit'], d['customerName']??'Guest', DateFormat('yyyy-MM-dd').format(ts)];
    }).toList();

    LoadingOverlay.show(context);
    try {
      final path = await _reporting.exportToExcel('Sales_Report_${DateTime.now().millisecond}', 'Sales', headers, rows);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Exported to: $path"), backgroundColor: AppColors.success));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Failed: $e"), backgroundColor: AppColors.danger));
    } finally {
      LoadingOverlay.hide(context);
    }
  }

  void _showAddSupplierDialog(String shopId) {
    final n = TextEditingController(); 
    final d = TextEditingController(text: '0');
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Add Supplier'), content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: n, decoration: const InputDecoration(labelText: 'Supplier Name')),
        TextField(controller: d, decoration: const InputDecoration(labelText: 'Initial Debt')),
      ]), actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          await _db.addSupplier({'shopId': shopId, 'name': n.text, 'outstandingDebt': double.tryParse(d.text) ?? 0.0, 'totalPaid': 0.0});
          if (c.mounted) Navigator.pop(c);
        }, child: const Text('Add'))
    ]));
  }

  void _showPaySupplierDialog(String id, num currentDebt) {
    final amountC = TextEditingController(text: currentDebt.toString());
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Pay Supplier"), content: TextField(controller: amountC, decoration: const InputDecoration(labelText: "Amount Paying")), actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
           await _db.addSupplierPayment(id, double.tryParse(amountC.text) ?? 0.0);
           if (ctx.mounted) Navigator.pop(ctx);
        }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.success), child: const Text("Confirm Payment", style: TextStyle(color: Colors.white)))
    ]));
  }

  Widget _buildChartSection(Map<String, double> data) {
    return Container(
      height: 250, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border.withOpacity(0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("PROFIT TRENDS (LAST 7 DAYS)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
        const Spacer(),
        Center(child: Text("Chart data visualization active for ${data.length} days.", style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        const Spacer(),
      ]),
    );
  }

  Widget _buildReportSummaryGrid(double dr, double dp, double wr, double wp, double sv, double td) {
    return GridView.count(crossAxisCount: isDesktop(context) ? 3 : 2, crossAxisSpacing: 16, mainAxisSpacing: 16, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: isDesktop(context) ? 2.5 : 2, children: [
        _miniStat('Today Revenue', currencyFormat.format(dr), AppColors.secondary),
        _miniStat('Today Profit', currencyFormat.format(dp), AppColors.success),
        _miniStat('Weekly Revenue', currencyFormat.format(wr), AppColors.primary),
        _miniStat('Weekly Profit', currencyFormat.format(wp), AppColors.success),
        _miniStat('Current Stock Value', currencyFormat.format(sv), AppColors.warning),
        _miniStat('Outstanding Credit', currencyFormat.format(td), AppColors.danger),
    ]);
  }

  Widget _miniStat(String t, String v, Color c) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(t, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.bold)),
      Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    ]));
  }

  Widget _buildDetailedReportSection(AppUser u) => Card(child: ListTile(leading: const Icon(Icons.analytics_outlined, color: AppColors.primary), title: const Text("View Detailed Reports"), subtitle: const Text("Deep dive into sales and inventory history"), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => setState(() => _selectedIndex = 1)));

  Widget _buildAddItemFAB(AppUser u) => FloatingActionButton(backgroundColor: AppColors.secondary, child: const Icon(Icons.add_rounded, color: Colors.white), onPressed: () => _showAddItemDialog(u));
  bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width > 900;
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});
  @override _KeepAliveWrapperState createState() => _KeepAliveWrapperState();
}
class _KeepAliveWrapperState extends State<_KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  @override Widget build(BuildContext context) { super.build(context); return widget.child; }
}
