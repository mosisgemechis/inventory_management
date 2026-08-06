import os

file_path = r'c:\projects\inventory_management\lib\core\services\reporting_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if "import 'package:cloud_firestore/cloud_firestore.dart';" in line:
        continue
    # Remove Timestamp checks
    line = line.replace("if (v is Timestamp) m[k] = v.toDate().toIso8601String();", "if (v is DateTime) m[k] = v.toIso8601String();")
    line = line.replace("if (tsRaw is Timestamp) ts = tsRaw.toDate();", "if (tsRaw is DateTime) ts = tsRaw;")
    new_lines.append(line)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
