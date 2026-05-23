import sys
import os

path = r'c:\projects\inventory_management\lib\features\admin\admin_dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old = '''                        if (isRestock && prefillProduct?['id'] != null) {
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

new = '''                        // Unified logic using recordPurchase: it handles find-or-create + restock + purchase log
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

# Normalize and replace
def normalize(s):
    return s.replace('\r\n', '\n').strip()

content_norm = content.replace('\r\n', '\n')
old_norm = normalize(old)

if old_norm in content_norm:
    new_content = content_norm.replace(old_norm, normalize(new))
    with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(new_content)
    print("SUCCESS")
else:
    print("FAILURE: Snippet not found")
    # Debug: print a portion of the content to see what it looks like
    start_idx = content_norm.find('if (isRestock')
    if start_idx != -1:
        print("Found 'if (isRestock' at:", start_idx)
        print("Context:", repr(content_norm[start_idx:start_idx+100]))
    else:
        print("Could not even find 'if (isRestock'")
