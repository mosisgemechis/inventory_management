import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

enum SyncStatus { synced, pendingUpload, pendingDelete, failed }

abstract class SyncableTable extends Table {
  // Local-first sync metadata (UI reads always from Drift; network is async background sync)
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))(); // synced|pendingUpload|pendingDelete|failed
  DateTimeColumn get lastModified => dateTime().withDefault(currentDateAndTime)(); // UTC
  TextColumn get remoteId => text().nullable()(); // backend authoritative id
  IntColumn get version => integer().withDefault(const Constant(0))(); // optimistic concurrency
}

class Products extends SyncableTable {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get branchId => text()();
  TextColumn get name => text()();
  TextColumn get barcode => text().withDefault(const Constant(''))();
  RealColumn get quantity => real()();
  RealColumn get buyingPrice => real()();
  RealColumn get sellingPrice => real()();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(5))();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get batchNumber => text().nullable()();
  TextColumn get imageUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id, branchId};
}

class ProductStocks extends SyncableTable {
  TextColumn get shopId => text()();
  TextColumn get productId => text()();
  TextColumn get branchId => text()();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {shopId, productId, branchId};
}

class Sales extends SyncableTable {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get branchId => text()();
  TextColumn get itemId => text()();
  TextColumn get itemName => text()();
  RealColumn get quantity => real()();
  RealColumn get totalPrice => real()();
  RealColumn get profit => real()();
  TextColumn get userId => text()();
  TextColumn get username => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get customerName => text().nullable()();
  BoolColumn get isDebt => boolean().withDefault(const Constant(false))();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  RealColumn get debtRemaining => real().withDefault(const Constant(0.0))();
  TextColumn get saleGroupId => text().nullable()();
  RealColumn get refundedQuantity => real().withDefault(const Constant(0.0))();
  /// Stores the primary batch ID deducted during this sale line.
  /// Used at refund time to restore stock to the exact original batch (FEFO/FIFO integrity).
  TextColumn get batchId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Suppliers extends SyncableTable {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get name => text()();
  TextColumn get contact => text().nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get totalTaken => real().withDefault(const Constant(0.0))();
  RealColumn get totalPaid => real().withDefault(const Constant(0.0))();
  RealColumn get remaining => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Purchases extends SyncableTable {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get itemId => text()();
  TextColumn get itemName => text()();
  TextColumn get barcode => text().withDefault(const Constant(''))();
  RealColumn get quantity => real()();
  RealColumn get unitCost => real()();
  RealColumn get totalCost => real()();
  TextColumn get supplierName => text().nullable()();
  TextColumn get batchNumber => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get branchId => text().withDefault(const Constant('main'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Batches extends SyncableTable {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get itemId => text()();
  RealColumn get quantity => real()();
  RealColumn get buyingPrice => real()();
  RealColumn get sellingPrice => real().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get batchNumber => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get branchId => text().withDefault(const Constant('main'))();
  TextColumn get type => text().nullable()(); // initial | restock | import | adjustment

  @override
  Set<Column> get primaryKey => {id};
}

class AuditLogs extends SyncableTable {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get username => text()();
  TextColumn get action => text()();
  TextColumn get details => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get branchId => text().withDefault(const Constant('main'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Branches extends SyncableTable {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Users extends Table {
  TextColumn get uid => text()();
  TextColumn get email => text()();
  TextColumn get roles => text()(); // Semi-colon separated roles
  TextColumn get shopId => text()();
  TextColumn get username => text()();
  TextColumn get branchId => text().nullable()();
  TextColumn get branchName => text().nullable()();
  TextColumn get permissions => text().nullable()(); // JSON string
  TextColumn get passwordHash => text().nullable()(); // SHA-256 hash for offline auth
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get fullName => text().withDefault(const Constant(''))();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get cloudUserId => text().nullable()();
  BoolColumn get syncEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastOnlineLogin => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {uid};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  
  @override
  Set<Column> get primaryKey => {key};
}

class Notifications extends SyncableTable {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get title => text()();
  TextColumn get body => text()(); // Renamed from message for consistency
  TextColumn get type => text()(); // 'pricing_alert', 'low_stock', etc.
  TextColumn get priority => text().withDefault(const Constant('normal'))(); // low|normal|high
  TextColumn get relatedEntityId => text().nullable()(); // productId / saleId / etc
  TextColumn get createdBy => text().nullable()(); // userId/username
  TextColumn get targetRole => text().nullable()();
  TextColumn get itemId => text().nullable()();
  /// Branch that generated this notification (nullable for shop-wide alerts).
  TextColumn get branchId => text().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get route => text().nullable()();
  TextColumn get payloadJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncOutbox extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get shopId => text()();
  TextColumn get branchId => text().withDefault(const Constant('main'))();
  TextColumn get deviceId => text()(); // stable per install
  TextColumn get userId => text()(); // local uid
  TextColumn get entityTable => text()(); // e.g. 'products'
  TextColumn get recordId => text()(); // local pk
  TextColumn get operation => text()(); // e.g. SALE_CREATED, PRODUCT_CREATED
  TextColumn get payloadJson => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)(); // UTC
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))(); // PENDING, UPLOADING, SYNCED, FAILED, CONFLICT
  IntColumn get schemaVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Durable, acknowledgeable record of every business-data sync conflict.
/// Separate from [Notifications] so conflicts persist until explicitly acknowledged,
/// survive app restarts, and carry a full acknowledgement audit trail.
class SyncConflicts extends Table {
  /// Stable identifier — derived from event/entity IDs so re-playing the same
  /// conflict event never creates a duplicate row.
  TextColumn get conflictId => text()();
  TextColumn get shopId => text()();
  TextColumn get branchId => text().withDefault(const Constant('main'))();
  /// conflict_type: product_dedup | sale_oversell | product_edit_conflict |
  ///   delete_tombstone | transfer_conflict | batch_conflict | outbox_rejected |
  ///   purchase_conflict | customer_debt_conflict | stock_snapshot_conflict
  TextColumn get conflictType => text()();
  TextColumn get affectedEntityType => text()(); // products | sales | batches ...
  TextColumn get affectedEntityId => text()();
  TextColumn get affectedEntityName => text().nullable()();
  /// high | medium | low
  TextColumn get severity => text().withDefault(const Constant('medium'))();
  /// Human-readable explanation: what happened / why / what the system did / what action is needed
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get whatHappened => text().nullable()();
  TextColumn get whatSystemDid => text().nullable()();
  TextColumn get requiredAction => text().nullable()(); // null means no action required
  BoolColumn get requiresAction => boolean().withDefault(const Constant(false))();
  /// resolved | unresolved | acknowledged
  TextColumn get resolutionStatus => text().withDefault(const Constant('unresolved'))();
  TextColumn get acknowledgedBy => text().nullable()(); // userId
  TextColumn get acknowledgedByUsername => text().nullable()();
  DateTimeColumn get acknowledgedAt => dateTime().nullable()();
  DateTimeColumn get detectedAt => dateTime().withDefault(currentDateAndTime)();
  /// Original outbox event ID that triggered this conflict (if any)
  TextColumn get sourceEventId => text().nullable()();
  /// Serialised extra data (JSON) – e.g. merged product IDs, old/new stock values
  TextColumn get conflictDataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {conflictId};
}

// --- DAOs ---

@DriftAccessor(tables: [Products])
class ProductsDao extends DatabaseAccessor<AppDatabase> with _$ProductsDaoMixin {
  ProductsDao(AppDatabase db) : super(db);
  
  Stream<List<Product>> watchAll(String shopId) => 
    (select(products)..where((t) => t.shopId.equals(shopId))).watch();
    
  Future<int> upsert(Insertable<Product> product) => 
    into(products).insertOnConflictUpdate(product);
}

@DriftAccessor(tables: [ProductStocks])
class ProductStocksDao extends DatabaseAccessor<AppDatabase>
    with _$ProductStocksDaoMixin {
  ProductStocksDao(AppDatabase db) : super(db);
}

@DriftAccessor(tables: [Sales])
class SalesDao extends DatabaseAccessor<AppDatabase> with _$SalesDaoMixin {
  SalesDao(AppDatabase db) : super(db);
  
  Stream<List<Sale>> watchAll(String shopId) => 
    (select(sales)..where((t) => t.shopId.equals(shopId))).watch();
}

@DriftAccessor(tables: [Suppliers])
class DebtsDao extends DatabaseAccessor<AppDatabase> with _$DebtsDaoMixin {
  DebtsDao(AppDatabase db) : super(db);
}

@DriftAccessor(tables: [Users])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(AppDatabase db) : super(db);
  
  Future<User?> getByUid(String uid) => 
    (select(users)..where((t) => t.uid.equals(uid))).getSingleOrNull();

  Future<int> deleteByUid(String uid) => 
    (delete(users)..where((t) => t.uid.equals(uid))).go();
}

@DriftAccessor(tables: [Purchases, Batches])
class MovementsDao extends DatabaseAccessor<AppDatabase> with _$MovementsDaoMixin {
  MovementsDao(AppDatabase db) : super(db);
}

@DriftAccessor(tables: [Notifications])
class NotificationsDao extends DatabaseAccessor<AppDatabase> with _$NotificationsDaoMixin {
  NotificationsDao(AppDatabase db) : super(db);
  
  Stream<List<Notification>> watchForShop(String shopId) => 
    (select(notifications)..where((t) => t.shopId.equals(shopId))
    ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])).watch();
}

@DriftAccessor(tables: [SyncOutbox])
class SyncOutboxDao extends DatabaseAccessor<AppDatabase>
    with _$SyncOutboxDaoMixin {
  SyncOutboxDao(AppDatabase db) : super(db);

  Stream<int> watchPendingCount() =>
      (select(syncOutbox)..where((t) => t.status.equals('PENDING') | t.status.equals('FAILED')))
          .watch()
          .map((rows) => rows.length);

  Future<int> pendingCount() async {
    final rows = await (select(syncOutbox)
          ..where((t) => t.status.equals('PENDING') | t.status.equals('FAILED')))
        .get();
    return rows.length;
  }

  Future<void> enqueue({
    required String id,
    required String shopId,
    required String branchId,
    required String deviceId,
    required String userId,
    required String tableName,
    required String recordId,
    required String operation,
    String? payloadJson,
  }) async {
    await into(syncOutbox).insert(
      SyncOutboxCompanion.insert(
        id: id,
        shopId: shopId,
        branchId: Value(branchId),
        deviceId: deviceId,
        userId: userId,
        entityTable: tableName,
        recordId: recordId,
        operation: operation,
        payloadJson: Value(payloadJson),
        status: const Value('PENDING'),
        schemaVersion: const Value(1),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<List<SyncOutboxData>> getBatch({
    required int limit,
  }) =>
      (select(syncOutbox)
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
            ..limit(limit))
          .get();

  Future<void> markAttempt(String id, {String? error}) async {
    await (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        lastAttemptAt: Value(DateTime.now().toUtc()),
        attemptCount: const Value.absent(),
        lastError: Value(error),
      ),
    );
    await customUpdate(
      'UPDATE sync_outbox SET attempt_count = attempt_count + 1 WHERE id = ?',
      variables: [Variable.withString(id)],
      updates: {syncOutbox},
    );
  }

  Future<int> deleteById(String id) =>
      (delete(syncOutbox)..where((t) => t.id.equals(id))).go();
}

class Subscriptions extends Table {
  TextColumn get shopId => text()();
  TextColumn get plan => text()(); // 'starter', 'business', 'enterprise'
  DateTimeColumn get activationDate => dateTime()();
  DateTimeColumn get expiryDate => dateTime()();
  TextColumn get addOns => text().nullable()(); // JSON string
  BoolColumn get isTrial => boolean().withDefault(const Constant(true))();
  IntColumn get userLimit => integer().withDefault(const Constant(3))();
  IntColumn get branchLimit => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {shopId};
}

@DriftAccessor(tables: [SyncConflicts])
class SyncConflictsDao extends DatabaseAccessor<AppDatabase>
    with _$SyncConflictsDaoMixin {
  SyncConflictsDao(AppDatabase db) : super(db);

  /// All unacknowledged conflicts for this shop.
  Stream<List<SyncConflict>> watchUnacknowledged(String shopId) =>
      (select(syncConflicts)
            ..where((t) =>
                t.shopId.equals(shopId) &
                t.acknowledgedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm(expression: t.detectedAt, mode: OrderingMode.desc)
            ]))
          .watch();

  Future<List<SyncConflict>> getUnacknowledged(String shopId) =>
      (select(syncConflicts)
            ..where((t) =>
                t.shopId.equals(shopId) &
                t.acknowledgedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm(expression: t.detectedAt, mode: OrderingMode.desc)
            ]))
          .get();

  Future<SyncConflict?> getByConflictId(String conflictId) =>
      (select(syncConflicts)..where((t) => t.conflictId.equals(conflictId)))
          .getSingleOrNull();

  Future<int> upsert(SyncConflictsCompanion entry) =>
      into(syncConflicts).insertOnConflictUpdate(entry);

  Future<void> acknowledge(
    String conflictId, {
    required String userId,
    required String username,
  }) async {
    final now = DateTime.now().toUtc();
    await (update(syncConflicts)..where((t) => t.conflictId.equals(conflictId)))
        .write(SyncConflictsCompanion(
      acknowledgedBy: Value(userId),
      acknowledgedByUsername: Value(username),
      acknowledgedAt: Value(now),
      resolutionStatus: const Value('acknowledged'),
    ));
  }

  Future<int> countUnacknowledged(String shopId) async {
    final rows = await getUnacknowledged(shopId);
    return rows.length;
  }
}

@DriftDatabase(
  tables: [
    Products,
    ProductStocks,
    Sales,
    Suppliers,
    Purchases,
    Batches,
    AuditLogs,
    Users,
    Branches,
    AppSettings,
    Notifications,
    Subscriptions,
    SyncOutbox,
    SyncConflicts,
  ],
  daos: [
    ProductsDao,
    ProductStocksDao,
    SalesDao,
    DebtsDao,
    UsersDao,
    MovementsDao,
    NotificationsDao,
    SyncOutboxDao,
    SyncConflictsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test hook: set `AppDatabase.forceInMemory = true` before constructing
  /// [DatabaseService]/[AppDatabase] to avoid plugin dependencies in widget tests.
  static bool forceInMemory = false;

  /// Bump this together with a new `if (from < N)` block in [migration].
  /// A snapshot of the database is taken automatically before an older file
  /// is upgraded, so a failed migration never destroys local data.
  static const int currentSchemaVersion = 31;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
       if (from < 8) {
         try { await m.addColumn(users, users.isActive); } catch (_) {}
       }
       if (from < 9) {
         try { 
            await m.addColumn(batches, batches.branchId);
            await m.addColumn(purchases, purchases.branchId);
         } catch (_) {}
       }
       if (from < 10) {
         try {
           await m.addColumn(auditLogs, auditLogs.branchId);
         } catch (_) {}
       }
       if (from < 12) {
         try {
           await m.addColumn(users, users.fullName);
           await m.addColumn(users, users.currency);
         } catch (_) {}
       }
       if (from < 13) {
         // Add sync metadata everywhere we use SyncableTable.
         // These are additive migrations; existing rows will default to 'synced' / current timestamp / version 0.
         try { await m.addColumn(products, products.remoteId); } catch (_) {}
         try { await m.addColumn(products, products.version); } catch (_) {}
         try { await m.addColumn(sales, sales.remoteId); } catch (_) {}
         try { await m.addColumn(sales, sales.version); } catch (_) {}
         try { await m.addColumn(suppliers, suppliers.remoteId); } catch (_) {}
         try { await m.addColumn(suppliers, suppliers.version); } catch (_) {}
         try { await m.addColumn(purchases, purchases.remoteId); } catch (_) {}
         try { await m.addColumn(purchases, purchases.version); } catch (_) {}
         try { await m.addColumn(batches, batches.remoteId); } catch (_) {}
         try { await m.addColumn(batches, batches.version); } catch (_) {}
         try { await m.addColumn(auditLogs, auditLogs.remoteId); } catch (_) {}
         try { await m.addColumn(auditLogs, auditLogs.version); } catch (_) {}
         try { await m.addColumn(branches, branches.remoteId); } catch (_) {}
         try { await m.addColumn(branches, branches.version); } catch (_) {}
         try { await m.addColumn(notifications, notifications.remoteId); } catch (_) {}
         try { await m.addColumn(notifications, notifications.version); } catch (_) {}
       }
       if (from < 14) {
         // Sync outbox hardening for multi-device synchronization.
         try { await m.addColumn(syncOutbox, syncOutbox.deviceId); } catch (_) {}
         try { await m.addColumn(syncOutbox, syncOutbox.userId); } catch (_) {}
         try { await m.addColumn(syncOutbox, syncOutbox.updatedAt); } catch (_) {}
       }
       if (from < 15) {
          try { await m.addColumn(notifications, notifications.route as GeneratedColumn<Object>); } catch (_) {}
          try { await m.addColumn(notifications, notifications.payloadJson as GeneratedColumn<Object>); } catch (_) {}
       }
       if (from < 16) {
         try { await m.addColumn(notifications, notifications.priority); } catch (_) {}
         try { await m.addColumn(notifications, notifications.relatedEntityId); } catch (_) {}
         try { await m.addColumn(notifications, notifications.createdBy); } catch (_) {}
       }
       if (from < 17) {
         try { await m.createTable(productStocks); } catch (_) {}
       }
       if (from < 18) {
         try {
            await m.renameColumn(notifications, 'message', notifications.body);
         } catch (_) {}
         try { await m.addColumn(notifications, notifications.body); } catch (_) {}
         try { await m.addColumn(notifications, notifications.priority); } catch (_) {}
         try { await m.addColumn(notifications, notifications.relatedEntityId); } catch (_) {}
         try { await m.addColumn(notifications, notifications.createdBy); } catch (_) {}
         try { await m.addColumn(notifications, notifications.route); } catch (_) {}
         try { await m.addColumn(notifications, notifications.payloadJson); } catch (_) {}
       }
       if (from < 19) {
         try { await m.addColumn(sales, sales.refundedQuantity); } catch (_) {}
       }
       if (from < 20) {
         try { await m.addColumn(batches, batches.type as GeneratedColumn<Object>); } catch (_) {}
       }
       if (from < 22) {
         try { 
           await m.renameColumn(batches, 'expiry', (batches as dynamic).expiryDate); 
           await m.renameColumn(products, 'expiry', (products as dynamic).expiryDate);
         } catch (_) {}
       }
       if (from < 24) {
         try { 
           await m.addColumn(batches, batches.sellingPrice); 
         } catch (_) {}
       }
       if (from < 26) {
         // Critical Architecture Change: Products table needs composite PK {id, branchId}
         // to support independent pricing and thresholds per branch.
         try {
           await customStatement('ALTER TABLE products RENAME TO products_old;');
           await m.createTable(products);
           await customStatement('''
             INSERT INTO products (
               id, shop_id, branch_id, name, barcode, quantity, 
               buying_price, selling_price, low_stock_threshold, 
               expiry_date, batch_number, image_url, 
               remote_id, version, sync_status, last_modified
             ) 
             SELECT 
               id, shop_id, branch_id, name, barcode, quantity, 
               buying_price, selling_price, low_stock_threshold, 
               expiry_date, batch_number, image_url, 
               remote_id, version, sync_status, last_modified 
             FROM products_old;
           ''');
           try { await customStatement('DROP TABLE products_old;'); } catch (_) {}
         } catch (e) {
           print("Migration 26 Failed: $e");
         }
       }
       if (from < 27) {
         try { await m.addColumn(sales, sales.batchId); } catch (_) {}
       }
       if (from < 28) {
         // Add branchId to notifications for per-branch alert isolation.
         try { await m.addColumn(notifications, notifications.branchId); } catch (_) {}
       }
       if (from < 29) {
         try {
           await m.addColumn(syncOutbox, syncOutbox.status);
           await m.addColumn(syncOutbox, syncOutbox.schemaVersion);
         } catch (_) {}
       }
       if (from < 30) {
         try {
           await m.addColumn(users, users.cloudUserId);
           await m.addColumn(users, users.syncEnabled);
           await m.addColumn(users, users.lastOnlineLogin);
         } catch (_) {}
       }
       if (from < 31) {
          // SyncConflicts: persistent, acknowledgeable business-data conflict records.
          try { await m.createTable(syncConflicts); } catch (_) {}
        }
       await m.createAll(); // For any new tables
    },
    beforeOpen: (details) async {
      // Secondary indexes for the hot reactive queries. Without these every
      // drift watch (products, sales, batches, notifications) does a full
      // table scan each time the table changes, which made the UI stutter on
      // every sale / stock update.
      const statements = <String>[
        'CREATE INDEX IF NOT EXISTS idx_products_shop_branch ON products(shop_id, branch_id)',
        'CREATE INDEX IF NOT EXISTS idx_products_shop_name ON products(shop_id, name COLLATE NOCASE)',
        'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(shop_id, barcode)',
        'CREATE INDEX IF NOT EXISTS idx_product_stocks_shop_branch ON product_stocks(shop_id, branch_id, product_id)',
        'CREATE INDEX IF NOT EXISTS idx_batches_shop_item_branch ON batches(shop_id, item_id, branch_id, quantity)',
        'CREATE INDEX IF NOT EXISTS idx_batches_shop_branch_expiry ON batches(shop_id, branch_id, expiry_date)',
        'CREATE INDEX IF NOT EXISTS idx_sales_shop_branch_ts ON sales(shop_id, branch_id, timestamp)',
        'CREATE INDEX IF NOT EXISTS idx_sales_shop_item ON sales(shop_id, item_id)',
        'CREATE INDEX IF NOT EXISTS idx_purchases_shop_branch_ts ON purchases(shop_id, branch_id, timestamp)',
        'CREATE INDEX IF NOT EXISTS idx_audit_shop_ts ON audit_logs(shop_id, timestamp)',
        'CREATE INDEX IF NOT EXISTS idx_notifications_shop_read ON notifications(shop_id, is_read)',
      ];
      for (final sql in statements) {
        try {
          await customStatement(sql);
        } catch (_) {
          // Older/partial schemas may not have the column yet; skip safely.
        }
      }
    },
  );

  /// Copies the live database into `db_backups/` before a schema upgrade.
  ///
  /// Uses `VACUUM INTO`, which produces a consistent single-file snapshot
  /// including rows still sitting in the WAL. The five newest snapshots are
  /// kept. Any failure is swallowed: a backup problem must never block the
  /// app from starting.
  static Future<void> _backupBeforeUpgrade(File file) async {
    sqlite.Database? db;
    try {
      if (!await file.exists()) return;
      db = sqlite.sqlite3.open(file.path);
      final rows = db.select('PRAGMA user_version');
      final fileVersion = rows.isEmpty
          ? 0
          : (rows.first.values.first is int
              ? rows.first.values.first as int
              : int.tryParse('${rows.first.values.first}') ?? 0);
      if (fileVersion >= currentSchemaVersion) return;

      final backupDir = Directory(p.join(p.dirname(file.path), 'db_backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final stamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-');
      final target = p.join(
        backupDir.path,
        'inventory_db_v${fileVersion}_$stamp.sqlite',
      );
      final escaped = target.replaceAll("'", "''");
      db.execute("VACUUM INTO '$escaped'");
      // ignore: avoid_print
      print('[DB] Pre-migration backup written: $target');

      final snapshots = (await backupDir
              .list()
              .where((e) => e is File && e.path.endsWith('.sqlite'))
              .toList())
          .cast<File>()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final old in snapshots.skip(5)) {
        try {
          await old.delete();
        } catch (_) {}
      }
    } catch (e) {
      // ignore: avoid_print
      print('[DB] Pre-migration backup skipped: $e');
    } finally {
      db?.dispose();
    }
  }

  static QueryExecutor _openConnection() {
    // Widget tests run without platform plugins (path_provider). Use in-memory DB there.
    if (forceInMemory) {
      return NativeDatabase.memory(
        setup: (db) {
          db.execute('PRAGMA journal_mode=WAL;');
          db.execute('PRAGMA busy_timeout=5000;');
          db.execute('PRAGMA synchronous=NORMAL;');
        },
      );
    }
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'inventory_db.sqlite'));
      // Data-safety: snapshot the DB before drift applies schema migrations.
      await _backupBeforeUpgrade(file);
      return NativeDatabase.createInBackground(
        file,
        setup: (db) {
          // 1. Set busy_timeout FIRST on every connection so SQLite waits up to 5s for locks to clear.
          db.execute('PRAGMA busy_timeout=5000;');
          // 2. Safely attempt WAL mode (requires exclusive lock if switching modes, safe if already WAL).
          try {
            db.execute('PRAGMA journal_mode=WAL;');
          } catch (_) {}
          // 3. Faster writes; still crash-safe under WAL.
          try {
            db.execute('PRAGMA synchronous=NORMAL;');
          } catch (_) {}
        },
      );
    });
  }
}
