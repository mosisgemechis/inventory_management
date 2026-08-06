import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'database_service.dart';
import '../models/models.dart';

class FirestoreService {
  // OFFLINE MODE OVERRIDE:
  // All cloud-sync logic is deactivated. 
  // This service now acting as a local-only stub to bridge legacy calls.

  final DatabaseService _offline = DatabaseService();
  final _uuid = const Uuid();

  // --- STUBS ---

  Future<void> syncAll(String shopId) async {
    return; // No-op
  }

  Future<void> pushPendingChanges(String shopId) async {
    return; // No-op
  }

  Future<void> pullChanges(String shopId) async {
    return; // No-op
  }

  // --- BRANCH ACTIONS ---
  Future<void> addBranch(Map<String, dynamic> data) async {}

  Future<void> addUser(Map<String, dynamic> data) async {}

  dynamic getBranches(String shopId) => const Stream.empty();
  dynamic getInventory(String shopId, {String? branchId}) => const Stream.empty();
  dynamic getPurchases(String shopId, {String? branchId}) => const Stream.empty();
  dynamic getSuppliers(String shopId) => const Stream.empty();
  dynamic getNotifications(String shopId) => const Stream.empty();
  dynamic getDebtSales(String shopId, {String? branchId}) => const Stream.empty();
  dynamic getAuditLogs(String shopId) => const Stream.empty();
  dynamic getUsers(String shopId) => const Stream.empty();

  // --- ITEM / PRODUCT ACTIONS ---
  Future<void> addItem(Map<String, dynamic> data, {String? addedBy}) async {}
  Future<void> deleteItem(String productId) async {}
  Future<void> updateItem(String id, Map<String, dynamic> data, {String? updatedBy}) async {}
  Future<void> recordBatch(Map<String, dynamic> data, {Map<String, dynamic>? itemSummaryUpdate}) async {}
  Future<void> recordSaleWithBatches(Map<String, dynamic> saleData, List<Map<String, dynamic>> updatedBatches, {Map<String, dynamic>? itemSummaryUpdate}) async {}
  Future<void> updatePurchase(String purchaseId, Map<String, dynamic> data) async {}
  Future<void> recordSale(Map<String, dynamic> saleData) async {}
  Future<void> processBulkCheckoutSync(List<Map<String, dynamic>> items) async {}
  Future<void> recordPurchase(Map<String, dynamic> purchaseData) async {}
  Future<void> addSupplier(Map<String, dynamic> data) async {}
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {}
  Future<void> recordAuditLog(String shopId, String username, String action, String details) async {}

  Future<void> addNotification(String shopId, String message, String type, {Map<String, dynamic>? extraData}) async {}

  Future<void> updateDebtPayments(AppUser user, List<Map<String, dynamic>> sales, double amount) async {
    for (var sale in sales) {
       await _offline.update('sales', sale['id'], {'isDebt': 0, 'debtRemaining': 0.0});
    }
  }

  Future<void> deleteUser(String userId) async {
    await _offline.delete('users', userId);
  }

  Future<void> deleteEntireShop(String shopId) async {
    await _offline.factoryReset(shopId);
  }

  Future<bool> isUsernameTaken(String username) async {
    final res = await _offline.query('users', where: 'username = ?', whereArgs: [username.toLowerCase()]);
    return res.isNotEmpty;
  }

  Future<void> checkExpiryAlerts(String shopId) async {}

  Future<void> fullFactoryReset(String shopId) async {
    await _offline.factoryReset(shopId);
  }
}

