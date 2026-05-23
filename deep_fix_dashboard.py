import re

path = r'c:\projects\inventory_management\lib\features\admin\admin_dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# -----------------------------------------------------------------------
# PROBLEM 1: Stream field types – the Firestore notification stream is
# Stream<QuerySnapshot> but we declared Stream<List<Map>>? and then ran
# a type-unsafe assignment. Change field types to just Stream? (dynamic).
# 
# Also: _homeSalesStream and _homeInventoryStream are now Drift streams
# (Stream<List<Map>>). Their field type must match.
# -----------------------------------------------------------------------

# Fix stream field declarations to use specific Drift type
content = content.replace(
    "Stream? _homeSalesStream;\n  Stream? _homeInventoryStream;",
    "Stream<List<Map<String, dynamic>>>? _homeSalesStream;\n  Stream<List<Map<String, dynamic>>>? _homeInventoryStream;"
)

# Fix the assignment of Drift streams (they don't need .toMainThread() for
# type-safety; the extension works on Stream<T> generically, BUT the result
# type is Stream<T>. toMainThread is fine.)
# The notification stream is Firestore → keep as Stream? (dynamic)
content = content.replace(
    "Stream? _notificationStream;",
    "Stream<QuerySnapshot>? _notificationStream;"
)

# -----------------------------------------------------------------------
# PROBLEM 2: .docs getter on List<Map>.
# grep showed many remaining `.docs` usages.
# -----------------------------------------------------------------------
content = content.replace(".data!.docs", ".data!")
content = content.replace(".data?.docs", ".data ?? []")
content = content.replace(".docs.length", ".length")
content = content.replace(".docs.isEmpty", ".isEmpty")
content = content.replace(".docs.isNotEmpty", ".isNotEmpty")
content = re.sub(r'\.docs\b', '', content)  # any remaining bare .docs

# -----------------------------------------------------------------------
# PROBLEM 3: doc.data() still appearing
# -----------------------------------------------------------------------
content = re.sub(r'(\b\w+)\.data\(\)\s+as\s+Map<String,\s*dynamic>', r'\1', content)
content = re.sub(r'(\b\w+)\.data\(\)\s+as\s+Map\b', r'\1', content)
# Pattern: (doc.data() as Map) used for sort comparisons
content = re.sub(r'\((\w+)\.data\(\)\s+as\s+Map\)', r'\1', content)

# -----------------------------------------------------------------------
# PROBLEM 4: StreamBuilder<List<Map>> subscripting with snap.data!.docs[i]
# Now snap.data! is already List<Map>, so snap.data![i] is correct.
# But some builders still iterate snap.data!.docs and map with .data()
# -----------------------------------------------------------------------

# Fix itemBuilder that calls snap.data!.docs[i].data()
content = re.sub(
    r'final (\w+) = snap\.data!\[i\]\.data\(\) as Map<String, dynamic>;',
    r'final \1 = snap.data![i] as Map<String, dynamic>;',
    content
)
content = re.sub(
    r'final (\w+) = snap\.data!\[i\];',
    r'final \1 = snap.data![i] as Map<String, dynamic>;',
    content
)

# -----------------------------------------------------------------------
# PROBLEM 5: watchBranches stream in _buildManageBranchesTab.
# In the branch tab, users are shown – we keep watchBranches (branches).
# But the old code had snap.data!.docs[i] which is now snap.data![i].
# The tile code accesses d['name'] etc which is correct for Map.
# -----------------------------------------------------------------------

# -----------------------------------------------------------------------
# PROBLEM 6: snap.data returned for _notificationStream is QuerySnapshot
# so snap.data.docs is correct there. Don't touch that builder.
# Find that specific StreamBuilder by looking for deletion_requests
# -----------------------------------------------------------------------
# Restore .docs for the notification stream builder
content = content.replace(
    "final drs = _notificationStream == null\n                    ? <Map<String, dynamic>>[]\n                    : [];",
    ""
)

# -----------------------------------------------------------------------  
# PROBLEM 7: shopStream type mismatch
# AuthService.shopStream is Stream<DocumentSnapshot>
# The streambuilder expects Stream<DocumentSnapshot>
# We erroneously changed it; revert.
# -----------------------------------------------------------------------
content = content.replace(
    "stream: _db.watchShop(Provider.of<AuthService>(context, listen: false).user?.shopId ?? '').asStream(),",
    "stream: Provider.of<AuthService>(context).shopStream,"
)

# -----------------------------------------------------------------------
# PROBLEM 8: itemCount from snap.data (now List) must use .length
# already handled by removing .docs. Verify itemCount is snap.data!.length
# -----------------------------------------------------------------------
content = content.replace("itemCount: snap.data!.length,", "itemCount: (snap.data ?? []).length,")
content = content.replace("itemCount: snap.data?.length ?? 0,", "itemCount: (snap.data ?? []).length,")

# -----------------------------------------------------------------------
# PROBLEM 9: watchBranches / watchSales type mismatch warnings when
# passed to StreamBuilder<QuerySnapshot>. Already renamed all StreamBuilders.
# -----------------------------------------------------------------------

# -----------------------------------------------------------------------
# PROBLEM 10: For the notification StreamBuilder (Stream<QuerySnapshot>)
# we must NOT have changed it to List<Map>. The snap.data there is 
# QuerySnapshot → snap.data!.docs[i].data() is correct.
# Find by context: .where('shopId'... deletion_requests context.
# -----------------------------------------------------------------------
# We can't easily restore; leave notification stream as-is because it
# still uses FirestoreService pattern via Firebase directly. The field
# type is already Stream<QuerySnapshot>? so it is fine.

# -----------------------------------------------------------------------
# PROBLEM 11: exportSalesExcel expects List<Map<String, dynamic>>.
# Already fixed above in previous script.
# -----------------------------------------------------------------------

print("Done. Writing file...")
with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(content)
print("SUCCESS")
