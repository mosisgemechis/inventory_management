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
import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/repositories/inventory_repository.dart';
import '../../core/utils/thread_safe_stream.dart';
import '../../core/widgets/loading_overlay.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

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
  final TextEditingController _searchPOSC = TextEditingController();
  final TextEditingController _searchInvC = TextEditingController();
  final TextEditingController _searchDebtC = TextEditingController();
  final List<CartItem> _staffCart = [];

  void _calculateTotal() => setState(() {});
  double get _cartTotal => _staffCart.fold(0, (sum, i) => sum + i.total);

  void _addToCart(Map d, DocumentSnapshot doc) async {
    final stock = (d['quantity'] ?? 0).toInt();
    if (stock <= 0) return;
    
    final qtyC = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Add to Cart: ${d['name']}"),
        content: TextField(controller: qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Quantity")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(qtyC.text) ?? 0;
              if (val <= 0) return;
              if (val > stock) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text('Stock limit not enough! Only $stock remaining.')));
                return;
              }
              setState(() {
                final exIdx = _staffCart.indexWhere((i) => i.id == doc.id);
                if (exIdx != -1) {
                  _staffCart[exIdx].quantity = val.toInt();
                } else {
                  _staffCart.add(CartItem(
                    id: doc.id,
                    name: d['name'],
                    price: (d['sellingPrice'] ?? 0).toDouble(),
                    quantity: val.toInt(),
                    batchNumber: d['batchNumber'],
                    cost: (d['buyingPrice'] ?? 0).toDouble(),
                  ));
                }
              });
              Navigator.pop(c);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCartCheckout() async {
    if (_staffCart.isEmpty) return;
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) return;
    
    final customerC = TextEditingController();
    final advancedC = TextEditingController(text: '0');
    bool isDebt = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Staff Checkout"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: customerC, decoration: const InputDecoration(labelText: "Customer Name (Optional)")),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text("Payment Method: "),
                  const Spacer(),
                  ChoiceChip(label: const Text("Cash"), selected: !isDebt, onSelected: (_) => setDialogState(() => isDebt = false)),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text("Debt"), selected: isDebt, onSelected: (_) => setDialogState(() => isDebt = true)),
                ],
              ),
              if (isDebt) ...[
                const SizedBox(height: 16),
                TextField(controller: advancedC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Advanced Payment (ETB)")),
              ]
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final advanced = double.tryParse(advancedC.text) ?? 0.0;
                Navigator.pop(ctx);
                
                try {
                  for (var item in _staffCart) {
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
                      'profit': (item.price - (item.cost ?? 0)) * item.quantity,
                    });
                  }
                  setState(() => _staffCart.clear());
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: AppColors.success, content: Text('Sale processed successfully!')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(e.toString())));
                }
              }, 
              child: const Text("Confirm Sale")
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchPOSC.dispose();
    _searchInvC.dispose();
    _searchDebtC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthService, AppUser?>((auth) => auth.user);
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final isDesktop = outerConstraints.maxWidth > 900;
        final sidebarItems = _getSidebarItems(context);

        return Scaffold(
          key: const ValueKey('staff_scaffold'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: isDesktop ? null : _buildAppBar(context, user),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDesktop)
                Column(
                  children: [
                    Expanded(
                      child: ERPSidebar(
                        key: const ValueKey('staff_sidebar'),
                        selectedIndex: _selectedIndex,
                        onItemSelected: (i) => setState(() => _selectedIndex = i),
                        items: sidebarItems,
                      ),
                    ),
                    _buildStaffLogoutButton(),
                  ],
                ),
              Expanded(
                child: Column(
                  key: const ValueKey('staff_main_content'),
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

  Widget _buildStaffLogoutButton() {
     return Container(
       width: 260,
       padding: const EdgeInsets.all(16),
       decoration: const BoxDecoration(
         color: AppColors.primary,
         border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
       ),
       child: ElevatedButton.icon(
         onPressed: () async {
           await Provider.of<AuthService>(context, listen: false).signOut();
           // Auth stream in main.dart will automatically redirect to LoginScreen
         },
         icon: const Icon(Icons.logout_rounded, size: 18),
         label: const Text("Logout"),
         style: ElevatedButton.styleFrom(
           backgroundColor: AppColors.danger.withOpacity(0.1),
           foregroundColor: AppColors.danger,
           elevation: 0,
           minimumSize: const Size(double.infinity, 44),
         ),
       ),
     );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppUser user) {
    String bName = user.branchName ?? 'Main Shop';
    if (bName.contains('Text("')) bName = bName.replaceAll('Text("', '').replaceAll('")', '');
    
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bName, style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(user.username, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [_buildNotificationBadge(user), const SizedBox(width: 8)],
    );
  }

  Widget _buildDesktopHeader(AppUser user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_getTabTitle(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1)),
            Text("${user.branchName ?? 'Main Shop'} | ${user.username}", style: TextStyle(fontSize: 14)),
          ])),
          _buildNotificationBadge(user),
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
      stream: _db.getNotifications(user.shopId).toMainThread(),
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

  List<SidebarItem> _getSidebarItems(BuildContext context) {
    return [
      SidebarItem(uid: 'sell', icon: Icons.point_of_sale_rounded, label: 'Sell'),
      SidebarItem(uid: 'inventory', icon: Icons.inventory_2_outlined, label: 'Inventory'),
      SidebarItem(uid: 'reports', icon: Icons.bar_chart_rounded, label: 'Reports'),
      SidebarItem(uid: 'debt', icon: Icons.payments_rounded, label: 'Debt'),
      SidebarItem(uid: 'settings', icon: Icons.settings_outlined, label: 'Settings'),
    ];
  }

  Widget _buildActiveTab(AppUser user) {
    return IndexedStack(index: _selectedIndex, children: [
        _buildSellTab(user),
        _buildInventoryTab(user),
        _buildReportTab(user),
        _buildDebtTab(user),
        _buildSettingsTab(user),
    ]);

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: TextField(
            controller: _searchPOSC,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search product or scan barcode...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   if (_searchPOSC.text.isNotEmpty) IconButton(onPressed: () { _searchPOSC.clear(); setState(() => _searchQuery = ""); }, icon: const Icon(Icons.clear_rounded, size: 18)),
                   IconButton(onPressed: () => _launchScanner(_searchPOSC), icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppColors.secondary)),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _categoryChip("All", true),
                _categoryChip("Common", false),
                _categoryChip("Drinks", false),
                _categoryChip("Cosmetics", false),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.getInventory(user.shopId).toMainThread(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!.docs.where((doc) {
                final m = doc.data() as Map<String, dynamic>;
                final price = (m['sellingPrice'] ?? 0).toDouble();
                return ((m['name']?.toString().toLowerCase() ?? '').contains(_searchQuery) || 
                       (m['barcode']?.toString() ?? '').contains(_searchQuery)) && price > 0;
              }).toList();

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 5 : 3, 
                  childAspectRatio: 0.72, 
                  crossAxisSpacing: 12, 
                  mainAxisSpacing: 12,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final d = items[i].data() as Map<String, dynamic>;
                  return _productCard(d, items[i], user);
                },
              );
            },
          ),
        ),
        _buildViewCartBar(),
      ],
    );
  }

  Widget _buildViewCartBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _staffCart.isEmpty ? null : _handleCartCheckout,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            shadowColor: AppColors.secondary.withOpacity(0.4),
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 20),
                   const SizedBox(width: 12),
                   Text("View Cart (${_staffCart.length} items)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ],
              ),
              Text(currencyFormat.format(_cartTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String label, bool active) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.secondary : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: active ? Colors.white : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _productCard(Map<String, dynamic> d, DocumentSnapshot doc, AppUser user) {
    final qty = d['quantity'] ?? 0;
    final imageUrl = d['imageUrl'];
    
    return InkWell(
      onTap: qty > 0 ? () => _addToCart(d, doc) : null,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
        decoration: AppColors.glassDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.secondary.withOpacity(0.2), AppColors.secondary.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: imageUrl != null 
                  ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: Image.network(imageUrl, fit: BoxFit.cover))
                  : const Center(
                      child: Icon(Icons.inventory_2_rounded, color: AppColors.secondary, size: 48),
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(currencyFormat.format(d['sellingPrice'] ?? 0), style: const TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: qty < 5 ? AppColors.danger.withOpacity(0.1) : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                    child: Text("Stock: $qty", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: qty < 5 ? AppColors.danger : AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildInventoryTab(AppUser user) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
          child: TextField(
            controller: _searchInvC,
            onChanged: (v) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search inventory...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(onPressed: () => _launchScanner(_searchInvC), icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.secondary)),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.getInventory(user.shopId).toMainThread(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs.where((d) => (d.data() as Map)['branchId'] == user.branchId).toList();
              
              if (_searchInvC.text.isNotEmpty) {
                final q = _searchInvC.text.toLowerCase();
                docs = docs.where((d) {
                  final m = d.data() as Map;
                  return (m['name'] ?? '').toString().toLowerCase().contains(q) || (m['barcode'] ?? '').toString().toLowerCase().contains(q);
                }).toList();
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final low = (d['quantity'] ?? 0) <= (d['lowStockThreshold'] ?? 5);
                  return Card(
                    key: ValueKey('inv_item_${docs[i].id}'),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Batch: ${d['batchNumber'] ?? "N/A"} | Price: ${currencyFormat.format(d['sellingPrice'] ?? 0)}'),
                      trailing: SizedBox(width: 160, child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: low ? AppColors.danger.withOpacity(0.1) : AppColors.background, borderRadius: BorderRadius.circular(10)), child: Text('${d['quantity']} left', style: TextStyle(color: low ? AppColors.danger : AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 11))),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.secondary),
                            onPressed: () => _showAddStockDialog(user, d, docs[i].id)
                          ),
                        ],
                      )),
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

  Widget _buildReportTab(AppUser user) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.getSales(user.shopId).toMainThread(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final sales = snapshot.data!.docs.where((d) => (d.data() as Map)['branchId'] == user.branchId).toList();
        double totalRev = 0;
        double totalProfit = 0;
        int count = 0;

        for (var doc in sales) {
          final m = doc.data() as Map<String, dynamic>;
          totalRev += (m['totalPrice'] ?? 0).toDouble();
          totalProfit += (m['profit'] ?? 0).toDouble();
          count++;
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatCard(title: "Transactions", value: "$count", color: AppColors.secondary, icon: Icons.receipt_long_rounded, change: "", isPositive: true),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: StatCard(title: "Sales", value: currencyFormat.format(totalRev), color: AppColors.success, icon: Icons.attach_money_rounded, change: "", isPositive: true)),
                      const SizedBox(width: 24),
                      Expanded(child: StatCard(title: "Profit", value: currencyFormat.format(totalProfit), color: AppColors.info, icon: Icons.trending_up_rounded, change: "", isPositive: true)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildDebtTab(AppUser user) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
          child: TextField(
            controller: _searchDebtC,
            onChanged: (v) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search debtors or items...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.getDebtSales(user.shopId, branchId: user.branchId).toMainThread(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs.where((d) => ((d.data() as Map)['debtRemaining'] ?? 0) > 0).toList();
              
              if (_searchDebtC.text.isNotEmpty) {
                 final q = _searchDebtC.text.toLowerCase();
                 docs = docs.where((d) {
                    final m = d.data() as Map;
                    return (m['buyerName'] ?? '').toString().toLowerCase().contains(q) || (m['itemName'] ?? '').toString().toLowerCase().contains(q);
                 }).toList();
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  return Card(
                    key: ValueKey('debt_item_${docs[i].id}'),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(d['itemName'] ?? 'Unknown Item', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Customer: ${d['customerName'] ?? "Guest"}'),
                      trailing: SizedBox(width: 140, child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(currencyFormat.format(d['totalPrice'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 13)),
                          IconButton(
                            icon: const Icon(Icons.check_circle_rounded, color: AppColors.success), 
                            onPressed: () => docs[i].reference.update({
                              'isDebt': false,
                              'debtRemaining': 0.0,
                            })
                          ),
                        ],
                      )),
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

  Widget _buildSettingsTab(AppUser user) {
    return ListView(
      padding: const EdgeInsets.all(32), 
      children: [
        const Text("Settings & Profile", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        
        // Language Controls
        Card(
          child: Column(
            children: [
               ListTile(
                 leading: const Icon(Icons.language_rounded, color: AppColors.secondary),
                 title: const Text("App Language"),
                 subtitle: const Text("Select your preferred language"),
                 trailing: DropdownButton<AppLanguage>(
                    value: Provider.of<LocalizationService>(context).currentLanguage,
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(value: AppLanguage.en, child: const Text('English')), 
                      DropdownMenuItem(value: AppLanguage.am, child: const Text('አማርኛ (Amharic)'))
                    ],
                    onChanged: (v) { if (v != null) Provider.of<LocalizationService>(context, listen: false).setLanguage(v); },
                  ),
               ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Profile Info (Read Only for Staff)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: AppColors.secondary, size: 20),
                    SizedBox(width: 8),
                    Text("Profile Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: TextEditingController(text: user.username),
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Username",
                    prefixIcon: Icon(Icons.person, size: 20),
                    helperText: "Contact Admin to change username",
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: "••••••••"),
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock, size: 20),
                    helperText: "Contact Admin to reset password",
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        // Mobile Logout
        if (MediaQuery.of(context).size.width <= 900)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Provider.of<AuthService>(context, listen: false).signOut();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text("Sign Out"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
      ],
    );
  }

  void _launchScanner(TextEditingController controller) {
    if (!kIsWeb && Platform.isWindows) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Use Physical Scanner"),
          content: const Text("Camera-based scanning is unsupported on Windows. Please click the search field and use a physical plug-and-play barcode scanner instead."),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))],
        ),
      );
      return;
    }
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        content: SizedBox(
          width: 300, 
          height: 300, 
          child: MobileScanner(onDetect: (cap) {
            final code = cap.barcodes.first.rawValue; 
            if (code != null) { 
              if (!mounted) return;
              controller.text = code;
              setState(() => _searchQuery = code.toLowerCase()); 
              if (c.mounted) Navigator.pop(c); 
            }
          }),
        ),
      ),
    );
  }

  void _showSellDialog(DocumentSnapshot doc, AppUser user) {
    final d = doc.data() as Map<String, dynamic>;
    final qtyC = TextEditingController(text: '1'); 
    final buyerC = TextEditingController(); 
    final advancedC = TextEditingController(text: '0');
    String paymentType = 'Cash';
    
    showDialog(
      context: context, 
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Checkout: ${d['name']}', style: const TextStyle(fontWeight: FontWeight.bold)), 
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                TextField(controller: qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
                const SizedBox(height: 16),
                TextField(controller: buyerC, decoration: const InputDecoration(labelText: 'Customer Name')),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _payTypeBtn('Cash', paymentType == 'Cash', () => setS(() => paymentType = 'Cash')),
                    const SizedBox(width: 8),
                    _payTypeBtn('Debt', paymentType == 'Debt', () => setS(() => paymentType = 'Debt')),
                  ],
                ),
                if (paymentType == 'Debt') ...[
                  const SizedBox(height: 16),
                  TextField(controller: advancedC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Advanced Payment (ETB)')),
                ]
              ],
            ),
          ), 
          actionsPadding: const EdgeInsets.all(24),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  FocusScope.of(context).unfocus();
                  final q = int.tryParse(qtyC.text) ?? 0;
                  final stock = (d['quantity'] ?? 0).toInt();
                  if (q <= 0) return;
                  if (q > stock) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text('Stock limit not enough! Only $stock remaining.')));
                    return;
                  }
                  
                  final isDebt = paymentType == 'Debt';
                  final sp = (d['sellingPrice'] ?? 0.0).toDouble(); 
                  final bp = (d['buyingPrice'] ?? 0.0).toDouble();
                  final total = sp * q;
                  final advanced = double.tryParse(advancedC.text) ?? 0.0;

                  try {
                    LoadingOverlay.show(context);
                    await _repo.recordSale(user, {
                      'shopId': user.shopId, 
                      'branchId': user.branchId, 
                      'itemId': doc.id, 
                      'itemName': d['name'], 
                      'quantity': q,
                      'totalPrice': total, 
                      'profit': (sp - bp) * q, 
                      'userId': user.id, 
                      'username': user.username, 
                      'isDebt': isDebt && (total - advanced) > 0,
                      'customerName': buyerC.text.isEmpty ? 'Guest' : buyerC.text, 
                      'advancedPaid': advanced,
                      'debtRemaining': isDebt ? (total - advanced) : 0.0,
                    });
                    if (context.mounted) LoadingOverlay.hide(context);
                    if (c.mounted) Navigator.pop(c);
                  } catch (e) {
                    if (context.mounted) LoadingOverlay.hide(context);
                    if (c.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }, 
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                child: const Text('Confirm Sale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payTypeBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.secondary : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? AppColors.secondary : Colors.white10),
          ),
          child: Center(child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 13))),
        ),
      ),
    );
  }

  void _showAddStockDialog(AppUser user, [Map<String, dynamic>? item, String? id]) {
    final n = TextEditingController(text: item?['name'] ?? ''); 
    final b = TextEditingController(text: '${item?['buyingPrice'] ?? ''}');
    final q = TextEditingController(); 
    final bar = TextEditingController(text: item?['barcode'] ?? '');
    final batch = TextEditingController(text: item?['batchNumber'] ?? '');
    DateTime? expDate;
    if (item?['expiryDate'] != null) {
      final ex = item!['expiryDate'];
      if (ex is Timestamp) {
        expDate = ex.toDate();
      } else if (ex is String) expDate = DateTime.tryParse(ex);
    }

    showDialog(
      context: context, 
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(id == null ? 'New Item Registry' : 'Edit Item'), 
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (id == null) TextField(controller: n, decoration: const InputDecoration(labelText: 'Item Name')),
              if (id == null) TextField(
                controller: bar,
                decoration: InputDecoration(
                  labelText: 'Scan/Type Barcode',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.secondary),
                    onPressed: () {
                      if (!kIsWeb && Platform.isWindows) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a physical barcode scanner on Windows Desktop.')));
                        return;
                      }
                      showDialog(
                        context: context,
                        builder: (c2) => AlertDialog(
                          content: SizedBox(
                            width: 300,
                            height: 300,
                            child: MobileScanner(onDetect: (cap) {
                              final code = cap.barcodes.first.rawValue;
                              if (code != null) {
                                bar.text = code;
                                if (c2.mounted) Navigator.pop(c2);
                                setS(() {});
                              }
                            }),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              TextField(controller: batch, decoration: const InputDecoration(labelText: 'Batch Number')),
              TextField(
                controller: b, 
                readOnly: id != null, 
                decoration: InputDecoration(
                  labelText: id != null ? 'Unit Cost (Locked)' : 'Unit Cost',
                  helperText: id != null ? 'Staff cannot rewrite past buying prices.' : null,
                ),
              ),
              TextField(controller: q, decoration: const InputDecoration(labelText: 'Quantity Arriving')),
              ListTile(
                title: Text(expDate == null ? 'No Expiry Date' : 'Exp: ${DateFormat('yyyy-MM-dd').format(expDate!)}'), 
                trailing: const Icon(Icons.event_rounded), 
                onTap: () async {
                  final p = await showDatePicker(
                    context: context, 
                    initialDate: DateTime.now().add(const Duration(days: 365)), 
                    firstDate: DateTime.now(), 
                    lastDate: DateTime.now().add(const Duration(days: 3650))
                  );
                  if (p != null) setS(() => expDate = p);
                },
              ),
            ]),
          ), 
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), 
            ElevatedButton(
              onPressed: () async {
                FocusScope.of(context).unfocus();
                if (!c.mounted) return;
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
                    }).timeout(const Duration(seconds: 10)); 
                  } else { 
                    await _repo.registerItem(user, {
                      'shopId': user.shopId, 'branchId': user.branchId, 'branchName': user.branchName ?? 'Main',
                      'name': n.text, 'barcode': bar.text, 'quantity': addQty, 'buyingPrice': cost,
                      'batchNumber': batch.text, 'expiryDate': expiry,
                    }).timeout(const Duration(seconds: 10)); 
                  }
                  
                  if (id == null) {
                    n.clear(); b.clear(); q.clear(); bar.clear(); batch.clear();
                  }
                  
                  if (c.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intake Recorded!'), backgroundColor: AppColors.success));
                  if (context.mounted) LoadingOverlay.hide(context);
                  if (c.mounted) Navigator.pop(c);
                } catch (e) {
                  if (context.mounted) LoadingOverlay.hide(context);
                  if (c.mounted) {
                    showDialog(
                      context: c,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        title: Row(children: const [Icon(Icons.error_outline_rounded, color: AppColors.danger), SizedBox(width: 8), Text('Error', style: TextStyle(color: Colors.white))]),
                        content: Text(e.toString().replaceAll('Exception: ', ''), style: const TextStyle(color: AppColors.textSecondary)),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                      )
                    );
                  }
                }
              }, 
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
              child: const Text('RECORD INTAKE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddStockFAB(AppUser u) => FloatingActionButton(backgroundColor: AppColors.secondary, child: const Icon(Icons.add_rounded, color: Colors.white), onPressed: () => _showAddStockDialog(u));

  void _showNotifs(AppUser user) {
    FirebaseFirestore.instance.collection('notifications').where('shopId', isEqualTo: user.shopId).get().then((snapshot) {
      final docs = snapshot.docs.where((d) {
        final m = d.data();
        final t = m['type']?.toString() ?? '';
        return (user.roles.any((r) => r.name == t) || t == 'staff' || t == 'both');
      }).toList();
      showModalBottomSheet(
        context: context, 
        builder: (c) => Padding(
          padding: const EdgeInsets.all(24), 
          child: ListView.builder(
            itemCount: docs.length, 
            itemBuilder: (context, i) => ListTile(
              key: ValueKey('notif_${docs[i].id}'), 
              title: Text(docs[i]['message']), 
              subtitle: const Text('Just Now'), 
              onTap: () { 
                docs[i].reference.update({'isRead': true}); 
                if (c.mounted) Navigator.pop(c); 
              }
            ),
          ),
        ),
      );
    });
  }
}
