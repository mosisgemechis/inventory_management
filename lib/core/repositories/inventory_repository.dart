import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/validation_service.dart';
import '../models/models.dart';

class InventoryRepository {
  final DatabaseService _local = DatabaseService();
  final FirestoreService _remote = FirestoreService();
  final ValidationService _validator = ValidationService();

  Future<void> registerItem(AppUser user, Map<String, dynamic> data) async {
    // 1. Mandatory Local Validation (Local-First Strategy)
    await _validator.validateProduct(
      user.shopId, 
      data['name'], 
      data['barcode'] ?? ''
    );

    // 2. Prep data for local and remote
    final id = DateTime.now().millisecondsSinceEpoch.toString(); // or uuid
    final finalData = {
      ...data,
      'id': id,
      'isSynced': 0,
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    // 3. Save Locally First
    await _local.saveProduct(finalData);

    // 4. Fire-and-forget sync to Cloud (SyncService will handle if it fails here)
    try {
      await _remote.addItem(finalData, addedBy: user.username);
      await _local.markSynced('products', id);
    } catch (e) {
      print("Local-First: Item saved locally, pending sync... ($e)");
    }
  }

  Future<void> recordSale(AppUser user, Map<String, dynamic> saleData) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final finalSale = {
      ...saleData,
      'id': id,
      'isSynced': 0,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _local.saveSale(finalSale);
    
    try {
      await _remote.recordSale(finalSale);
      await _local.markSynced('sales', id);
    } catch (e) {
       print("Local-First: Sale saved locally ($e)");
    }
  }
}
