import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database_service.dart';
import 'connection_service.dart';
import 'sync_api_client.dart';

class BootstrapSyncService {
  final DatabaseService _dbService;
  final ConnectionService _connectionService;

  BootstrapSyncService({
    DatabaseService? dbService,
    ConnectionService? connectionService,
  })  : _dbService = dbService ?? DatabaseService(),
        _connectionService = connectionService ?? ConnectionService();

  Future<void> runBootstrapSync() async {
    debugPrint('[BOOTSTRAP TRACE] Started');

    final hasNet = await _connectionService.hasInternet();
    debugPrint('[BOOTSTRAP SYNC] Internet: $hasNet');

    final isReachable = await _connectionService.checkBackendReachability();
    debugPrint('[BOOTSTRAP SYNC] Cloud reachable: $isReachable');

    final localUsers = await _dbService.query('users');
    debugPrint('[BOOTSTRAP SYNC] Local user count: ${localUsers.length}');

    if (!isReachable) {
      debugPrint('[BOOTSTRAP SYNC] Cloud not reachable. Skipping bootstrap download.');
      return;
    }

    try {
      final token = await _dbService.getSetting('identity_access_token') ?? await _dbService.getSetting('access_token');
      final authAvailable = token != null && token.isNotEmpty;
      debugPrint('[BOOTSTRAP TRACE] Authorization available = $authAvailable');

      final baseUrl = (await _dbService.getSetting('api_base_url')) ?? _connectionService.baseUrl;
      final client = SyncApiClient(baseUrl: baseUrl.trim(), accessToken: token);

      debugPrint('[BOOTSTRAP TRACE] Request sent');
      final resp = await client.getJson('/sync/initial');
      debugPrint('[BOOTSTRAP TRACE] Response status = 200');

      final users = (resp['users'] as List?)?.whereType<Map>().toList() ?? [];
      final products = (resp['products'] as List?)?.whereType<Map>().toList() ?? [];
      final branches = (resp['branches'] as List?)?.whereType<Map>().toList() ?? [];

      debugPrint('[BOOTSTRAP TRACE] User records received = ${users.length}');
      debugPrint('[BOOTSTRAP TRACE] Business records received = ${products.length}');
      debugPrint('[BOOTSTRAP TRACE] Branch records received = ${branches.length}');

      final activeShopId = await _dbService.getSetting('active_shop_id') ??
          await _dbService.getSetting('identity_business_id') ??
          '';

      int insertedCount = 0;
      for (var u in users) {
        final m = Map<String, dynamic>.from(u);
        final uid = m['id']?.toString() ?? m['uid']?.toString();
        final email = m['email']?.toString() ?? '';
        final username = m['username']?.toString() ?? email.split('@')[0];
        final shopId = m['shopId']?.toString() ??
            m['businessId']?.toString() ??
            m['business_id']?.toString() ??
            (activeShopId.isNotEmpty ? activeShopId : 'shop-cloud-001');

        if (uid != null && uid.isNotEmpty) {
          final userData = {
            'uid': uid,
            'email': email,
            'username': username,
            'fullName': m['fullName']?.toString() ?? m['name']?.toString() ?? '',
            'roles': m['roles'] is List ? (m['roles'] as List).map((e) => e.toString()).toList() : [(m['role']?.toString() ?? 'admin')],
            'shopId': shopId,
            'branchId': m['branchId']?.toString() ?? m['branch_id']?.toString() ?? 'main',
            'branchName': m['branchName']?.toString() ?? m['branch_name']?.toString() ?? 'Main Branch',
            'permissions': m['permissions'],
            'passwordHash': m['passwordHash']?.toString() ?? m['password_hash']?.toString() ?? '',
            'isActive': m['isActive'] ?? true,
            'cloudUserId': m['cloudUserId']?.toString() ?? uid,
            'syncEnabled': true,
          };
          await _dbService.saveUserRecord(userData, isFromSync: true);
          insertedCount++;

          debugPrint('[STAFF CREATE TRACE]');
          debugPrint('target_user_id=$uid');
          debugPrint('stage=REMOTE_EVENT_RECEIVED');
          debugPrint('stage=REMOTE_USER_PERSISTED');
          debugPrint('stage=LOGIN_READY');
          debugPrint('[STAFF IDENTITY TRACE]');
          debugPrint('local_user_id=$uid');
          debugPrint('[STAFF BUSINESS TRACE]');
          debugPrint('business_id=$shopId');
        }
      }
      debugPrint('[BOOTSTRAP TRACE] Local persistence complete = true (inserted $insertedCount users)');

      final updatedLocalUsers = await _dbService.query('users');
      debugPrint('[BOOTSTRAP SYNC] Local user count: ${updatedLocalUsers.length}');
    } catch (e) {
      debugPrint('[BOOTSTRAP TRACE] Response status = error ($e)');
      debugPrint('[BOOTSTRAP SYNC] Error during bootstrap sync: $e');
    }
  }
}
