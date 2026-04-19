import 'database_service.dart';

class ValidationService {
  final DatabaseService _db = DatabaseService();

  Future<void> validateProduct(String shopId, String name, String barcode) async {
    final normalizedName = name.trim().toLowerCase();
    final normalizedBarcode = barcode.trim();

    final results = await _db.searchItems(shopId, normalizedName, normalizedBarcode);

    if (results.isNotEmpty) {
      throw Exception('Duplicate detected: An item with this name or barcode already exists in the local inventory.');
    }
  }
}
