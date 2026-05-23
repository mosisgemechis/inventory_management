import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  Set<Column> get primaryKey => {id};
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
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get batchNumber => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get branchId => text().withDefault(const Constant('main'))();

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
  TextColumn get message => text()();
  TextColumn get type => text()(); // 'pricing_alert', 'low_stock', etc.
  TextColumn get targetRole => text().nullable()();
  TextColumn get itemId => text().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

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
  TextColumn get operation => text()(); // upsert|delete|stock_delta
  TextColumn get payloadJson => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)(); // UTC
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
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
      (select(syncOutbox)..where((t) => t.attemptCount.isSmallerThanValue(25)))
          .watch()
          .map((rows) => rows.length);

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

@DriftDatabase(
  tables: [
    Products,
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
  ],
  daos: [
    ProductsDao,
    SalesDao,
    DebtsDao,
    UsersDao,
    MovementsDao,
    NotificationsDao,
    SyncOutboxDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 14;

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
       await m.createAll(); // For any new tables
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'inventory_db');
  }
}
