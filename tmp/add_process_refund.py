import os

file_path = r'c:\projects\inventory_management\lib\core\repositories\inventory_repository.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

refund_logic = r'''
  Future<void> processRefund(AppUser user, Map<String, dynamic> saleData, double refundQty) async {
    if (!user.hasPermission(AppUser.pRefundSales)) {
      throw Exception('Permission denied: cannot refund sales.');
    }
    
    if (refundQty <= 0) throw Exception("Refund quantity must be greater than zero.");
    
    final saleId = saleData['id']?.toString() ?? '';
    final shopId = saleData['shopId']?.toString() ?? user.shopId;
    final branchId = saleData['branchId']?.toString() ?? user.branchId;
    final saleQty = (saleData['quantity'] ?? 0.0).toDouble();
    final prevRefunded = (saleData['refundedQuantity'] ?? 0.0).toDouble();
    final itemId = saleData['itemId']?.toString() ?? '';
    final itemName = saleData['itemName']?.toString() ?? '';
    
    if (prevRefunded + refundQty > saleQty + 0.001) {
      throw Exception("Cannot refund more than sold quantity.");
    }

    await _local.runTransaction(() async {
      // 1. Update Sale record
      final newRefunded = prevRefunded + refundQty;
      await _local.update('sales', saleId, {'refundedQuantity': newRefunded});
      
      // 2. We must restore stock into product_stocks. The simplest way is to manually adjust product_stocks or record a restock
      // Since `recordRestock` does a positive inventory change via tracking batches, we can just use that.
      // We will mimic a restock. We need a basic fallback price, use selling price or 0 for cost.
      await recordRestock(user, {
         'shopId': shopId,
         'branchId': branchId,
         'itemId': itemId,
         'itemName': itemName,
         'addedQuantity': refundQty,
         'buyingPrice': 0.0, // Best effort since we don't track which batch price was sold in refund easily yet
         'supplierName': 'Refunded Customer',
         'expiryDate': null,
      });

      // 3. Audit Log
      await _local.recordAuditLog(
        shopId, 
        user.username, 
        'REFUND', 
        'Refunded $refundQty units of $itemName. Sale ID: $saleId',
        branchId: branchId
      );

      // 4. Notifications
      await _local.addNotification({
        'shopId': shopId,
        'branchId': branchId,
        'title': 'Sale Refunded',
        'message': 'Refund completed for $itemName ($refundQty items restored)',
        'type': 'refund',
        'priority': 'normal',
      });
    });
  }
'''

# Find a good place to insert it. Just before `Future<void> recordSale`
old_content = r'''  Future<void> recordSale(AppUser user, Map<String, dynamic> saleData) async {'''
new_content = refund_logic + "\n" + old_content

if 'Future<void> processRefund' not in content:
    content = content.replace(old_content, new_content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
