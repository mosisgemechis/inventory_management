import sys
import os
import re

path = r'c:\projects\inventory_management\lib\features\admin\admin_dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix Imports
if 'import \'package:inventory_manager/core/models/models.dart\';' not in content:
    content = content.replace(
        "import 'package:inventory_manager/core/services/auth_service.dart';",
        "import 'package:inventory_manager/core/services/auth_service.dart';\nimport 'package:inventory_manager/core/models/models.dart';\nimport 'package:inventory_manager/core/utils/thread_safe_stream.dart';"
    )

content = content.replace(
    "import 'package:inventory_manager/core/services/firestore_service.dart';",
    "import 'package:inventory_manager/core/services/database_service.dart';"
)

# 2. Change Service Class
content = content.replace("final FirestoreService _db = FirestoreService();", "final DatabaseService _db = DatabaseService();")

# 3. StreamBuilder Types
content = content.replace("StreamBuilder<QuerySnapshot>", "StreamBuilder<List<Map<String, dynamic>>>")

# 4. Method calls
content = content.replace("_db.getSales", "_db.watchSales")
content = content.replace("_db.getInventory", "_db.watchProducts")
content = content.replace("_db.getUsers", "_db.watchBranches")

# 5. Data access fixes
# doc.data() as Map<String, dynamic> -> doc
content = re.sub(r'final (\w+) = snap\.data!\.docs\[i\]\.data\(\) as Map<String, dynamic>;', r'final \1 = snap.data![i];', content)
content = re.sub(r'final (\w+) = doc\.data\(\) as Map<String, dynamic>;', r'final \1 = doc;', content)
content = re.sub(r'final (\w+) = d\.data\(\) as Map<String, dynamic>;', r'final \1 = d;', content)
content = re.sub(r'final (\w+) = (doc|d|m)\.data\(\) as Map;', r'final \1 = \2;', content)
# (m.data() as Map) -> m
content = re.sub(r'\((doc|d|m)\.data\(\) as Map\)', r'\1', content)

# snack.data!.docs -> snap.data!
content = content.replace("snap.data!.docs", "snap.data!")
content = content.replace("snap.data?.docs", "snap.data!") # Might need ? handling but usually snap.hasData is checked

# doc.id -> doc['id']
# This is tricky because doc.id might be legitimate in some contexts, but usually it's drift map.
# I'll look for specific patterns
content = content.replace("doc.id", "doc['id']")
content = content.replace("d.id", "d['id']")

# 6. Stream definitions
content = content.replace("Stream<QuerySnapshot>?", "Stream<List<Map<String, dynamic>>>?")

# 7. Specific field fixes
content = content.replace("user.roles.contains(UserRole.staff)", "user.hasRole(UserRole.staff)")
content = content.replace("user.roles.contains(UserRole.admin)", "user.hasRole(UserRole.admin)")
content = content.replace("user.roles.contains(UserRole.manager)", "user.hasRole(UserRole.manager)")

# 8. User Management Rename
content = content.replace("User Management", "Manage Branches")
content = content.replace("Manage Users/Branches", "Manage Branches")

# 9. parseDT is now in models.dart but let's check if it's called correctly
# Error says: The method 'parseDT' isn't defined for the type '_AdminDashboardScreenState'
# This means it's called as parseDT(...) but it's a top-level function.
# Dart should find it if models.dart is imported.

with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(content)
print("SUCCESS: AdminDashboardScreen fixed via script")
