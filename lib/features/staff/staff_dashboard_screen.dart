import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/validation_service.dart';
import '../../core/l10n/l10n.dart';
import '../../core/widgets/erp_components.dart';
import '../../core/models/models.dart';
import '../../core/constants/colors.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:badges/badges.dart' as badges;
import '../../core/repositories/inventory_repository.dart';
import '../../core/utils/thread_safe_stream.dart';
import '../../core/widgets/loading_overlay.dart';

class StaffDashboardScreen extends StatefulWidget {
  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final FirestoreService _db = FirestoreService();
  final ValidationService _validator = ValidationService();
  final InventoryRepository _repo = InventoryRepository();
  int _selectedIndex = 0;
  final currencyFormat = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 2);
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final sidebarItems = [
          SidebarItem(icon: Icons.point_of_sale_rounded, label: 'sell'.tr(context)),
          SidebarItem(icon: Icons.inventory_2_outlined, label: 'inventory'.tr(context)),
          SidebarItem(icon: Icons.bar_chart_rounded, label: 'reports'.tr(context)),
          SidebarItem(icon: Icons.payments_rounded, label: 'Kibid (Debt)'),
          SidebarItem(icon: Icons.settings_outlined, label: 'settings'.tr(context)),
        ];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: isDesktop ? null : _buildAppBar(context, user),
          body: Row(
            children: [
              if (isDesktop)
                ERPSidebar(
                  selectedIndex: _selectedIndex,
                  onItemSelected: (i) => setState(() => _selectedIndex = i),
                  items: sidebarItems,
                ),
              Expanded(
                child: Column(
                  children: [
                    if (isDesktop) _buildDesktopHeader(user),
                    Expanded(child: _buildActiveTab(user)),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
          floatingActionButton: _selectedIndex == 1 ? _buildAddStockFAB(user) : null,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppUser user) {
    String bName = user.branchName ?? 'Main Shop';
    if (bName.contains('Text("')) bName = bName.replaceAll('Text("', '').replaceAll('")', '');
    
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bName, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(user.username, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [_buildNotificationBadge(user), const SizedBox(width: 8)],
    );
  }

  Widget _buildDesktopHeader(AppUser user) {
    String bName = user.branchName ?? 'Main Shop';
    if (bName.contains('Text("')) bName = bName.replaceAll('Text("', '').replaceAll('")', '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      color: Colors.white,
      child: Row(
        children: [
          Text(_getTabTitle(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: -0.5)),
          const Spacer(),
          Text('${user.username} | $bName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 24),
          _buildNotificationBadge(user),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20), onPressed: () => context.read<AuthService>().signOut()),
        ],
      ),
    );
  }

  String _getTabTitle() {
    switch (_selectedIndex) {
      case 0: return 'Point of Sale';
      case 1: return 'Inventory Management';
      case 2: return 'Sales Reports';
      case 3: return 'Customer Debt Ledger';
      case 4: return 'System Settings';
      default: return 'Staff Panel';
    }
  }

  Widget _buildNotificationBadge(AppUser user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('notifications').where('shopId', isEqualTo: user.shopId).snapshots().toMainThread(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.where((d) {
          final m = d.data() as Map<String, dynamic>;
          final t = m['type']?.toString() ?? '';
          return (user.roles.any((r) => r.name == t) || t == 'staff' || t == 'both') && m['isRead'] != true;
        }).length : 0;
        return badges.Badge(
          showBadge: count > 0,
          badgeContent: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10)),
          child: IconButton(icon: const Icon(Icons.notifications_none_rounded), onPressed: () => _showNotifs(user)),
        );
      },
    );
  }

  Widget _buildActiveTab(AppUser user) {
    switch (_selectedIndex) {
      case 0: return _buildSellTab(user);
      case 1: return _buildInventoryTab(user);
      case 2: return _buildReportTab(user);
      case 3: return _buildDebtTab(user);
      case 4: return _buildSettingsTab(user);
      default: return const SizedBox();
    }
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      destinations: [
        NavigationDestination(icon: const Icon(Icons.point_of_sale_rounded), label: 'sell'.tr(context)),
        NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), label: 'inventory'.tr(context)),
        NavigationDestination(icon: const Icon(Icons.assessment_outlined), label: 'reports'.tr(context)),
        NavigationDestination(icon: const Icon(Icons.payments_rounded), label: 'Debt'),
        NavigationDestination(icon: const Icon(Icons.settings_outlined), label: 'settings'.tr(context)),
      ],
    );
  }

  Widget _buildSellTab(AppUser user) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(32),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search medication or scan...',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: IconButton(onPressed: _startBarcodeScanner, icon: const Icon(Icons.qr_code_scanner_rounded)),
          ),
        ),
      ),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        // FIXED: Query by shopId only (global shop scope). Removing branchId
        // filter ensures Admin-added items are visible to all Staff.
        stream: FirebaseFirestore.instance.collection('items').where('shopId', isEqualTo: user.shopId).snapshots().toMainThread(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!.docs.where((doc) {
            final m = doc.data() as Map<String, dynamic>;
            final match = (m['name']?.toString().toLowerCase() ?? '').contains(_searchQuery) || (m['barcode']?.toString() ?? '').contains(_searchQuery);
            return match && ((m['sellingPrice'] ?? 0) as num) > 0;
          }).toList();

          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 5 : (MediaQuery.of(context).size.width > 800 ? 3 : 2),
              childAspectRatio: 0.8, mainAxisSpacing: 20, crossAxisSpacing: 20,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final d = items[i].data() as Map<String, dynamic>;
              final qty = (d['quantity'] ?? 0) as int;
              return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.medication_liquid_rounded, color: AppColors.secondary, size: 28),
                const Spacer(),
                Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2),
                Text('Stock: $qty', style: TextStyle(fontSize: 10, color: qty < 5 ? AppColors.danger : AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(currencyFormat.format(d['sellingPrice'] ?? 0), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: qty > 0 ? () => _showSellDialog(items[i], user) : null, child: const Text('SELL'))),
              ])));
            },
          );
        },
      )),
    ]);
  }

  Widget _buildInventoryTab(AppUser user) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.getInventory(user.shopId).toMainThread(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((d) => (d.data() as Map)['branchId'] == user.branchId).toList();
        return ListView.builder(padding: const EdgeInsets.all(32), itemCount: docs.length, itemBuilder: (context, i) {
          final d = docs[i].data() as Map<String, dynamic>;
          final low = (d['quantity'] ?? 0) <= (d['lowStockThreshold'] ?? 5);
          return Card(margin: const EdgeInsets.only(bottom: 12), borderOnForeground: true, child: ListTile(
            title: Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Batch: ${d['batchNumber'] ?? "N/A"} | Price: ${currencyFormat.format(d['sellingPrice'] ?? 0)}'),
            trailing: SizedBox(width: 160, child: Row(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: low ? AppColors.danger.withOpacity(0.1) : AppColors.background, borderRadius: BorderRadius.circular(10)), child: Text('${d['quantity']} left', style: TextStyle(color: low ? AppColors.danger : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11))),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.secondary), onPressed: () => _showAddStockDialog(user, d, docs[i].id)),
            ])),
          ));
        });
      },
    );
  }

  Widget _buildReportTab(AppUser user) {
    return StreamBuilder<QuerySnapshot>(stream: _db.getSales(user.shopId).toMainThread(), builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      double total = 0; final now = DateTime.now();
      final docs = snapshot.data!.docs.where((d) {
        final m = d.data() as Map;
        final ts = (m['timestamp'] as Timestamp?)?.toDate() ?? now;
        return m['branchId'] == user.branchId && ts.day == now.day && ts.month == now.month && ts.year == now.year;
      }).toList();
      for (var d in docs) total += ((d.data() as Map)['totalPrice'] ?? 0.0).toDouble();

      return ListView(padding: const EdgeInsets.all(32), children: [
        StatCard(title: 'Today Revenue', value: currencyFormat.format(total), color: AppColors.success, icon: Icons.payments_rounded),
        const SizedBox(height: 32),
        const Text("Today's Transaction History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        ...docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(title: Text(data['itemName'] ?? ''), subtitle: Text(DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate())), trailing: Text(currencyFormat.format(data['totalPrice'] ?? 0))));
        }),
      ]);
    });
  }

  Widget _buildDebtTab(AppUser user) {
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('sales').where('shopId', isEqualTo: user.shopId).where('branchId', isEqualTo: user.branchId).where('isDebt', isEqualTo: true).snapshots().toMainThread(), builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final docs = snapshot.data!.docs.where((d) => ((d.data() as Map)['debtRemaining'] ?? 0) > 0).toList();
      return ListView.builder(padding: const EdgeInsets.all(32), itemCount: docs.length, itemBuilder: (context, i) {
        final d = docs[i].data() as Map<String, dynamic>;
        return Card(child: ListTile(title: Text(d['itemName'] ?? 'Unknown Item'), subtitle: Text('Customer: ${d['buyerName'] ?? "Guest"}'), trailing: SizedBox(width: 160, child: Row(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text(currencyFormat.format(d['debtRemaining'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 13)),
          IconButton(icon: const Icon(Icons.check_circle_rounded, color: AppColors.success), onPressed: () => docs[i].reference.update({'debtRemaining': 0.0, 'isDebt': false})),
        ]))));
      });
    });
  }

  Widget _buildSettingsTab(AppUser user) {
    return ListView(padding: const EdgeInsets.all(32), children: [
      const Text("App Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.translate_rounded), title: const Text('Switch Language'), trailing: DropdownButton<AppLanguage>(
          value: Provider.of<LocalizationService>(context).currentLanguage,
          items: [DropdownMenuItem(value: AppLanguage.en, child: const Text('English')), DropdownMenuItem(value: AppLanguage.am, child: const Text('Amharic'))],
          onChanged: (v) { if (v != null) Provider.of<LocalizationService>(context, listen: false).setLanguage(v); },
        )),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.person_outline_rounded), title: const Text('Edit Profile'), subtitle: const Text('Change your credentials'), onTap: () => _showEditProfile(user)),
      ])),
    ]);
  }

  void _showEditProfile(AppUser user) {
    final nameC = TextEditingController(text: user.username); final emailC = TextEditingController(text: user.email); final passC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Edit Profile'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Username')),
      TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email')),
      TextField(controller: passC, decoration: const InputDecoration(labelText: 'New Password')),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), ElevatedButton(onPressed: () async {
      final u = {'username': nameC.text, 'email': emailC.text}; if (passC.text.isNotEmpty) u['password'] = passC.text;
      await FirebaseFirestore.instance.collection('users').doc(user.id).update(u); Navigator.pop(c);
    }, child: const Text('Save Changes'))]));
  }

  void _startBarcodeScanner() {
    showDialog(context: context, builder: (c) => AlertDialog(content: SizedBox(width: 300, height: 300, child: MobileScanner(onDetect: (cap) {
      final code = cap.barcodes.first.rawValue; if (code != null) { setState(() => _searchQuery = code.toLowerCase()); Navigator.pop(c); }
    }))));
  }

  void _showSellDialog(DocumentSnapshot doc, AppUser user) {
    final d = doc.data() as Map<String, dynamic>;
    final qtyC = TextEditingController(text: '1'); final buyerC = TextEditingController(); bool isDebt = false;
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setS) => AlertDialog(title: Text('Sell ${d['name']}'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
      TextField(controller: buyerC, decoration: const InputDecoration(labelText: 'Buyer Name (Optional)')),
      SwitchListTile(title: const Text('Credit/Debt (Kibid)'), value: isDebt, onChanged: (v) => setS(() => isDebt = v)),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), ElevatedButton(onPressed: () async {
      final q = int.tryParse(qtyC.text) ?? 0; if (q <= 0 || q > (d['quantity'] ?? 0)) return;
      final sp = (d['sellingPrice'] ?? 0.0).toDouble(); final bp = (d['buyingPrice'] ?? 0.0).toDouble();
      try {
        LoadingOverlay.show(context);
        await _repo.recordSale(user, {
          'shopId': user.shopId, 'branchId': user.branchId, 'itemId': doc.id, 'itemName': d['name'], 'quantity': q,
          'totalPrice': sp * q, 'profit': (sp - bp) * q, 'userId': user.id, 'username': user.username, 'isDebt': isDebt,
          'customerName': buyerC.text.isEmpty ? 'Guest' : buyerC.text, 'debtRemaining': isDebt ? sp * q : 0.0,
        });
        if (c.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale Confirmed')));
        if (c.mounted && Navigator.canPop(c)) Navigator.pop(c);
      } catch (e) {
        if (c.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale Failed: $e'), backgroundColor: AppColors.danger));
      } finally {
        if (context.mounted) LoadingOverlay.hide(context);
      }
    }, child: const Text('CONFIRM SELL'))])));
  }

  void _showAddStockDialog(AppUser user, [Map<String, dynamic>? item, String? id]) {
     final n = TextEditingController(text: item?['name'] ?? ''); final b = TextEditingController(text: '${item?['buyingPrice'] ?? ''}');
     final q = TextEditingController(); final bar = TextEditingController(text: item?['barcode'] ?? '');
     final batch = TextEditingController(text: item?['batchNumber'] ?? '');
     DateTime? expDate;
     if (item?['expiryDate'] != null) {
        final ex = item!['expiryDate'];
        if (ex is Timestamp) expDate = ex.toDate();
        else if (ex is String) expDate = DateTime.tryParse(ex);
     }

     showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setS) => AlertDialog(title: Text(id == null ? 'New Item Registry' : 'Edit Item'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
       if (id == null) TextField(controller: n, decoration: const InputDecoration(labelText: 'Item Name')),
       if (id == null) Row(children: [
         Expanded(child: TextField(controller: bar, decoration: const InputDecoration(labelText: 'Scan/Type Barcode'))),
         IconButton(icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.secondary), onPressed: () => showDialog(context: context, builder: (c2) => AlertDialog(content: SizedBox(width: 300, height: 300, child: MobileScanner(onDetect: (cap){
           final code = cap.barcodes.first.rawValue; if (code != null) { bar.text = code; Navigator.pop(c2); setS((){}); }
         }))))),
       ]),
       TextField(controller: batch, decoration: const InputDecoration(labelText: 'Batch Number')),
       TextField(controller: b, decoration: const InputDecoration(labelText: 'Unit Cost')),
       TextField(controller: q, decoration: const InputDecoration(labelText: 'Quantity Arriving')),
       ListTile(title: Text(expDate == null ? 'No Expiry Date' : 'Exp: ${DateFormat('yyyy-MM-dd').format(expDate!)}'), trailing: const Icon(Icons.event_rounded), onTap: () async {
         final p = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 365)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
         if (p != null) setS(() => expDate = p);
       }),
     ])), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), ElevatedButton(onPressed: () async {
      try {
         LoadingOverlay.show(context);
         final addQty = int.tryParse(q.text) ?? 0;
         final cost = double.tryParse(b.text) ?? 0.0;
         final expiry = expDate != null ? Timestamp.fromDate(expDate!) : null;

         if (id != null) { 
           await _db.recordPurchase({
             'shopId': user.shopId, 'branchId': user.branchId, 'userId': user.id, 'username': user.username,
             'itemId': id, 'itemName': n.text, 'quantity': addQty, 'unitCost': cost,
             'batchNumber': batch.text, 'expiryDate': expiry,
           }); 
         } else { 
           await _repo.registerItem(user, {
             'shopId': user.shopId, 'branchId': user.branchId, 'branchName': user.branchName ?? 'Main',
             'name': n.text, 'barcode': bar.text, 'quantity': addQty, 'buyingPrice': cost,
             'batchNumber': batch.text, 'expiryDate': expiry,
           }); 
         }
         if (c.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intake Recorded!')));
         if (c.mounted && Navigator.canPop(c)) Navigator.pop(c);
       } catch (e) {
         if (c.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Intake Failed: $e'), backgroundColor: AppColors.danger));
       } finally {
         if (context.mounted) LoadingOverlay.hide(context);
       }
     }, child: const Text('RECORD INTAKE'))])));
  }

  Widget _buildAddStockFAB(AppUser u) => FloatingActionButton(backgroundColor: AppColors.secondary, child: const Icon(Icons.add_rounded, color: Colors.white), onPressed: () => _showAddStockDialog(u));

  void _showNotifs(AppUser user) {
    FirebaseFirestore.instance.collection('notifications').where('shopId', isEqualTo: user.shopId).get().then((snapshot) {
      final docs = snapshot.docs.where((d) {
        final m = d.data();
        final t = m['type']?.toString() ?? '';
        return (user.roles.any((r) => r.name == t) || t == 'staff' || t == 'both');
      }).toList();
      showModalBottomSheet(context: context, builder: (c) => Padding(padding: const EdgeInsets.all(24), child: ListView.builder(itemCount: docs.length, itemBuilder: (c, i) => ListTile(title: Text(docs[i]['message']), subtitle: Text('Just Now'), onTap: () { docs[i].reference.update({'isRead': true}); Navigator.pop(c); }))));
    });
  }
}
