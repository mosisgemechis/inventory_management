import os
import re

file_path = r'c:\projects\inventory_management\lib\features\admin\admin_dashboard_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update _AdminDashboardScreenState to include a map of tab widgets for IndexedStack
# We define them lazily or inside build to preserve state.
# Actually, the easiest way to use IndexedStack with dynamic items is to build the list in build().

# 2. Refactor _buildBody to return IndexedStack
old_build_body = r'''  Widget _buildBody(AppUser user) {
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
      case 'branches':
        return _buildManageBranchesTab(user);
      case 'audit':
        return _buildAuditLogTab(user);
      case 'settings':
        return _buildSettingsTab(user);
      default:
        return _buildHomeTab(user, items);
    }
  }'''

new_build_body = r'''  Widget _buildBody(AppUser user) {
    final items = _getSidebarItems(user);
    final safeIndex = _selectedIndex < items.length ? _selectedIndex : 0;

    return IndexedStack(
      index: safeIndex,
      children: items.map((it) {
        switch (it.uid) {
          case 'overview': return _buildHomeTab(user, items);
          case 'inventory': return _buildInventoryTab(user);
          case 'sales': return _buildSalesTab(user);
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
  }'''

content = content.replace(old_build_body, new_build_body)

# 3. Add _handleNotificationTap and improve _showNotificationsPanel
old_notif_build = r'''                          title: Text(req['title']?.toString() ?? 'Notification'),
                          subtitle: Text(req['message']?.toString() ?? ''),
                          trailing: (!isRead && id.isNotEmpty)'''

new_notif_build = r'''                          title: Text(req['title']?.toString() ?? 'Notification', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                          subtitle: Text(req['message']?.toString() ?? ''),
                          onTap: () => _handleNotificationTap(user, req),
                          trailing: (!isRead && id.isNotEmpty)'''

content = content.replace(old_notif_build, new_notif_build)

# 4. Add _handleNotificationTap implementation
notif_handler = r'''
  void _handleNotificationTap(AppUser user, Map<String, dynamic> req) {
    final payload = jsonDecode(req['payloadJson'] ?? '{}');
    final type = req['type'] ?? 'info';
    
    if (type == 'stock_transfer' && payload['recordId'] != null) {
       // Logic to jump to audit or specific item
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Transfer Details: ${req['message']}")));
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
'''

if "void _handleNotificationTap" not in content:
    content = content.replace("void _showNotificationsPanel", notif_handler + "\n  void _showNotificationsPanel")

# 5. Fix _getTabTitle to be based on UID for robustness with IndexedStack
old_get_title = r'''  String _getTabTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'dashboard'.tr(context);
      case 1:
        return 'inventory_control'.tr(context);
      case 2:
        return 'sales_pos'.tr(context);
      case 3:
        return 'purchases'.tr(context);
      case 4:
        return 'debt'.tr(context);
      case 5:
        return 'reports'.tr(context);
      case 6:
        return 'manage_users'.tr(context);
      case 7:
        return 'audit_history'.tr(context);
      case 8:
        return 'settings'.tr(context);
      default:
        return 'Dashboard';
    }
  }'''

new_get_title = r'''  String _getTabTitle() {
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) return "ERP";
    final items = _getSidebarItems(user);
    if (_selectedIndex >= items.length) return "ERP";
    return items[_selectedIndex].label;
  }'''

content = content.replace(old_get_title, new_get_title)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
