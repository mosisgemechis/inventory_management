import 'database_service.dart';

class ValidationService {
  final DatabaseService _db = DatabaseService();

  Future<void> validateProduct(
    String shopId, 
    String name, 
    String barcode, 
    {String? batchNumber, 
    String? currentItemId, 
    String? branchId}
  ) async {
    final normalizedName = name.trim().toLowerCase();
    final normalizedBarcode = barcode.trim();
    final normalizedBatch = batchNumber?.trim();

    if (normalizedName.isEmpty) throw Exception('Product name cannot be empty');

    // Retrieve products for this branch specifically to check for duplicates
    final allItems = await _db.getAllProducts(shopId);
    final targetBranchId = branchId ?? 'main';

    // Check barcode
    if (normalizedBarcode.isNotEmpty) {
      final barcodeDup = allItems.any((item) => 
        (item['branchId'] == targetBranchId || (item['branchId'] == null && targetBranchId == 'main')) &&
        item['barcode'].toString().trim() == normalizedBarcode && 
        item['id'] != currentItemId
      );
      if (barcodeDup) {
        throw Exception('DUPLICATE ERROR: Product with this Barcode already exists in this branch.');
      }
    }

    // Check batchNumber
    if (normalizedBatch != null && normalizedBatch.isNotEmpty) {
      final duplicateBatch = allItems.any((item) => 
        (item['branchId'] == targetBranchId || (item['branchId'] == null && targetBranchId == 'main')) &&
        item['batchNumber']?.toString().trim() == normalizedBatch && 
        item['id'] != currentItemId
      );
      if (duplicateBatch) {
        throw Exception('DUPLICATE ERROR: Product with this Batch Number already exists in this branch.');
      }
    }
  }

}
