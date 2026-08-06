import 'database_service.dart';

class ValidationService {
  final DatabaseService _db = DatabaseService();

  /// Validates a product definition before insert or update.
  ///
  /// [currentItemId] — when provided (edit/restock/purchase of existing item),
  ///   this ID is excluded from all duplicate checks so the item never flags
  ///   itself as a duplicate.
  Future<void> validateProduct(
    String shopId,
    String name,
    String barcode, {
    String? batchNumber,
    String? currentItemId,
    String? branchId,
  }) async {
    final normalizedName = name.trim().toLowerCase();
    final normalizedBarcode = barcode.trim();
    final normalizedBatch = batchNumber?.trim();

    if (normalizedName.isEmpty) throw Exception('Product name cannot be empty.');

    // If we already know the item ID (edit / restock / purchase of existing
    // product), skip ALL duplicate checks — those paths are never "new".
    if (currentItemId != null && currentItemId.isNotEmpty) return;

    final allItems = await _db.getAllProducts(shopId);
    final targetBranchId = branchId ?? 'main';

    // Barcode duplicate check — only for genuinely NEW items (no currentItemId).
    if (normalizedBarcode.isNotEmpty) {
      final barcodeDup = allItems.any((item) =>
          (item['branchId'] == targetBranchId ||
              (item['branchId'] == null && targetBranchId == 'main')) &&
          item['barcode'].toString().trim() == normalizedBarcode);
      if (barcodeDup) {
        throw Exception(
            'DUPLICATE ERROR: Product with this Barcode already exists in this branch.');
      }
    }

    // Batch-number duplicate check — only for genuinely NEW items.
    if (normalizedBatch != null && normalizedBatch.isNotEmpty) {
      final duplicateBatch = allItems.any((item) =>
          (item['branchId'] == targetBranchId ||
              (item['branchId'] == null && targetBranchId == 'main')) &&
          item['batchNumber']?.toString().trim() == normalizedBatch);
      if (duplicateBatch) {
        throw Exception(
            'DUPLICATE ERROR: Product with this Batch Number already exists in this branch.');
      }
    }
  }
}
