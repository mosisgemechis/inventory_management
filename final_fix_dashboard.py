import sys
import re

path = r'c:\projects\inventory_management\lib\features\admin\admin_dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

original = content

# -----------------------------------------------------------------------
# 1. The notification stream uses a Firestore QuerySnapshot stream which
#    still has .toMainThread() called on it – that works because the
#    toMainThread() extension is on Stream<T> (generic). BUT the field
#    type is now Stream<List<Map>> which is wrong.  Leave the Firestore
#    part as is and just change the field types for existing Drift streams.
# -----------------------------------------------------------------------

# Fix declaration types to be nullable, keeping them as is (they may be
# either Firestore or Drift depending on what they represent).
content = content.replace(
    "Stream<List<Map<String, dynamic>>>? _notificationStream;\n"
    "  Stream<List<Map<String, dynamic>>>? _homeSalesStream;\n"
    "  Stream<List<Map<String, dynamic>>>? _homeInventoryStream;",
    "Stream? _notificationStream;\n"
    "  Stream? _homeSalesStream;\n"
    "  Stream? _homeInventoryStream;"
)

# -----------------------------------------------------------------------
# 2. shopStream – used in settings tab as Stream<DocumentSnapshot>
#    Change that StreamBuilder to a FutureBuilder or simple StreamBuilder<Map>
# -----------------------------------------------------------------------
content = content.replace(
    "stream: Provider.of<AuthService>(context).shopStream,",
    "stream: _db.watchShop(Provider.of<AuthService>(context, listen: false).user?.shopId ?? '').asStream(),"
)

# -----------------------------------------------------------------------
# 3. exportSalesExcel receives List<QueryDocumentSnapshot> – change callers
#    to pass the map list instead.
# -----------------------------------------------------------------------
content = content.replace(
    "pathStr = await\n                            _reporting.exportSalesExcel(filtered);",
    "final filteredMaps = filtered.map((doc) => doc is Map<String, dynamic> ? doc : (doc.data() as Map<String, dynamic>)).toList();\n"
    "                            pathStr = await _reporting.exportSalesExcel(filteredMaps);"
)
content = content.replace(
    "await _reporting.exportSalesExcel(snapBatch.docs);",
    "await _reporting.exportSalesExcel(snapBatch.map((d) => d is Map<String, dynamic> ? d : (d as dynamic).data() as Map<String, dynamic>).toList());"
)

# -----------------------------------------------------------------------
# 4. StreamBuilder data access – when using watchSales / watchProducts,
#    snap.data! returns List<Map<String,dynamic>>, not QuerySnapshot.
#    The script already changed snap.data!.docs -> snap.data!, but some
#    places do things like doc.data() as Map which need fixing.
# -----------------------------------------------------------------------
# Any remaining .data() as Map<String, dynamic> calls that wrap a Map
content = re.sub(r'(\w+)\.data\(\)\s+as\s+Map<String,\s*dynamic>', r'\1', content)
content = re.sub(r'(\w+)\.data\(\)\s+as\s+Map', r'\1', content)

# -----------------------------------------------------------------------
# 5. The _buildManageUsersTab rename – the method is still called
#    _buildManageBranchesTab internally but the watchBranches stream
#    returns branch maps, not user maps.  Mark OK - already renamed.
# -----------------------------------------------------------------------

# -----------------------------------------------------------------------
# 6. In _buildManageBranchesTab there's _db.watchBranches(adminUser.shopId)
#    and also _db.getUsers(adminUser.shopId) leftover. Replace the latter.
# -----------------------------------------------------------------------
content = content.replace(
    "_db.getUsers(", "_db.watchBranches("
)

# -----------------------------------------------------------------------
# 7. snap.data?.docs remaining instances
# -----------------------------------------------------------------------
content = content.replace("snap.data?.docs ?? []", "snap.data ?? []")
content = content.replace("snap.data!.docs", "snap.data!")
content = content.replace("snap.data?.docs", "snap.data ?? []")

# -----------------------------------------------------------------------
# 8. snap.data!.length -> snap.data!.length (fine) but
#    itemCount: snap.data!.docs.length -> itemCount: snap.data!.length
# -----------------------------------------------------------------------
# Already covered by docs replacement above.

# -----------------------------------------------------------------------
# 9. List<DocumentSnapshot> parameters – used in _buildRecentSalesList etc.
#    Replace with List<Map<String, dynamic>>
# -----------------------------------------------------------------------
content = content.replace(
    "List<DocumentSnapshot> sales,",
    "List<Map<String, dynamic>> sales,"
)
content = content.replace(
    "List<DocumentSnapshot> allSales,",
    "List<Map<String, dynamic>> allSales,"
)
content = content.replace(
    "List<DocumentSnapshot> deletionRequests",
    "List<Map<String, dynamic>> deletionRequests"
)

# -----------------------------------------------------------------------
# 10. Missing cloud_firestore imports – keep them for Firestore notification
#     stream, Timestamp, etc.
# -----------------------------------------------------------------------
# They are still imported.

# -----------------------------------------------------------------------
# 11. watchProducts and watchSales return Stream<List<Map>> – calls in
#     StreamBuilder<QuerySnapshot> that now say StreamBuilder<List<Map>>
# -----------------------------------------------------------------------
# Already replaced above.

# -----------------------------------------------------------------------
# 12. QuickSellDialog / ShowQuickSellDialog type: DocumentSnapshot doc
#     -> Map<String, dynamic> doc
# -----------------------------------------------------------------------
content = content.replace(
    "void _showQuickSellDialog(DocumentSnapshot doc, AppUser user)",
    "void _showQuickSellDialog(Map<String, dynamic> doc, AppUser user)"
)
content = content.replace(
    "void _showAdminSellDialog(DocumentSnapshot doc, AppUser user)",
    "void _showAdminSellDialog(Map<String, dynamic> doc, AppUser user)"
)

# -----------------------------------------------------------------------
# 13. _buildBody references to snapData that still use .docs
# -----------------------------------------------------------------------

# -----------------------------------------------------------------------
# 14. CartItem – it IS in models.dart (imported). The issue was that
#     'package:inventory_manager/core/models/models.dart' wasn't imported
#     (now fixed). Verify CartItem will be found.
# -----------------------------------------------------------------------

# -----------------------------------------------------------------------
# 15. UserRole – also in models.dart. Same fix.
# -----------------------------------------------------------------------

# -----------------------------------------------------------------------
# 16. parseDT – top-level function in models.dart. Since models.dart is
#     now imported it should resolve. No change needed.
# -----------------------------------------------------------------------

# -----------------------------------------------------------------------
# 17. cloud_firestore still imported → remove any stale unused warning
#     but leave it since Firestore is still used for notifications.
# -----------------------------------------------------------------------

print(f"Modified {content != original}")

with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(content)

print("SUCCESS")
