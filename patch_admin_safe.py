import sys
import os

path = r'c:\projects\inventory_management\lib\features\admin\admin_dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Normalize
content_norm = content.replace('\r\n', '\n')

old_purchase = '''                        if (isRestock && prefillProduct?['id'] != null) {
                          // Restock existing product
                          await _repo.recordRestock(user, {
                            'shopId': user.shopId,
                            'branchId': dialogBranch,
                            'itemId': prefillProduct!['id'],
                            'itemName': nameC.text.trim(),
                            'barcode': barC.text.trim(),
                            'addedQuantity': qty,
                            'buyingPrice': cost,
                            'sellingPrice': double.tryParse(sellC.text),
                            'expiryDate': expiry,
                            'supplierName': supplierC.text.trim(),
                          }, isPurchase: true);
                        } else {
                          // New product purchase — use registerItem which handles registration
                          await _repo.registerItem(user, {
                            'shopId': user.shopId,
                            'branchId': dialogBranch,
                            'name': nameC.text.trim(),
                            'barcode': barC.text.trim(),
                            'quantity': qty,
                            'buyingPrice': cost,
                            'sellingPrice': double.tryParse(sellC.text) ?? cost * 1.25,
                            'supplierName': supplierC.text.trim(),
                            'expiryDate': expiry?.toIso8601String(),
                          });
                        }'''

new_purchase = '''                        // Unified logic using recordPurchase: it handles find-or-create + restock + purchase log
                        await _repo.recordPurchase(user, {
                          'shopId': user.shopId,
                          'branchId': dialogBranch,
                          'itemId': prefillProduct?['id'], 
                          'itemName': nameC.text.trim(),
                          'barcode': barC.text.trim(),
                          'quantity': qty,
                          'unitCost': cost,
                          'totalCost': qty * cost,
                          'sellingPrice': double.tryParse(sellC.text),
                          'expiryDate': expiry,
                          'supplierName': supplierC.text.trim(),
                          'lowStockThreshold': int.tryParse(thresholdC.text) ?? 5,
                        });'''

def normalize_ws(s):
    return "\n".join([l.strip() for l in s.split("\n") if l.strip()])

# Try to find it by ignoring some indentation if exact match fails
import re

def flexible_replace(content, old, new):
    # Escape special characters in old
    pattern = re.escape(old.replace('\r\n', '\n').strip())
    # Replace whitespace/newlines with flexible regex
    pattern = pattern.replace(r'\ ', r'\s+')
    pattern = pattern.replace(r'\n', r'\s+')
    
    match = re.search(pattern, content)
    if match:
        print(f"Found match at {match.start()}")
        return content[:match.start()] + new + content[match.end():]
    return None

updated = flexible_replace(content_norm, old_purchase, new_purchase)

if updated:
    with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(updated)
    print("SUCCESS: Purchase logic updated")
else:
    print("FAILURE: Snippet not found")
