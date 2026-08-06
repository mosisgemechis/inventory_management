// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
mixin _$ProductsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProductsTable get products => attachedDatabase.products;
}
mixin _$ProductStocksDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProductStocksTable get productStocks => attachedDatabase.productStocks;
}
mixin _$SalesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SalesTable get sales => attachedDatabase.sales;
}
mixin _$DebtsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
}
mixin _$UsersDaoMixin on DatabaseAccessor<AppDatabase> {
  $UsersTable get users => attachedDatabase.users;
}
mixin _$MovementsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PurchasesTable get purchases => attachedDatabase.purchases;
  $BatchesTable get batches => attachedDatabase.batches;
}
mixin _$NotificationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $NotificationsTable get notifications => attachedDatabase.notifications;
}
mixin _$SyncOutboxDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncOutboxTable get syncOutbox => attachedDatabase.syncOutbox;
}

class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('synced'));
  static const VerificationMeta _lastModifiedMeta =
      const VerificationMeta('lastModified');
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
      'last_modified', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
      'shop_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _barcodeMeta =
      const VerificationMeta('barcode');
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
      'barcode', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _buyingPriceMeta =
      const VerificationMeta('buyingPrice');
  @override
  late final GeneratedColumn<double> buyingPrice = GeneratedColumn<double>(
      'buying_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _sellingPriceMeta =
      const VerificationMeta('sellingPrice');
  @override
  late final GeneratedColumn<double> sellingPrice = GeneratedColumn<double>(
      'selling_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _lowStockThresholdMeta =
      const VerificationMeta('lowStockThreshold');
  @override
  late final GeneratedColumn<int> lowStockThreshold = GeneratedColumn<int>(
      'low_stock_threshold', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(5));
  static const VerificationMeta _expiryDateMeta =
      const VerificationMeta('expiryDate');
  @override
  late final GeneratedColumn<DateTime> expiryDate = GeneratedColumn<DateTime>(
      'expiry_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _batchNumberMeta =
      const VerificationMeta('batchNumber');
  @override
  late final GeneratedColumn<String> batchNumber = GeneratedColumn<String>(
      'batch_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStatus,
        lastModified,
        remoteId,
        version,
        id,
        shopId,
        branchId,
        name,
        barcode,
        quantity,
        buyingPrice,
        sellingPrice,
        lowStockThreshold,
        expiryDate,
        batchNumber,
        imageUrl
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(Insertable<Product> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('last_modified')) {
      context.handle(
          _lastModifiedMeta,
          lastModified.isAcceptableOrUnknown(
              data['last_modified']!, _lastModifiedMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(_shopIdMeta,
          shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta));
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    } else if (isInserting) {
      context.missing(_branchIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('barcode')) {
      context.handle(_barcodeMeta,
          barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta));
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('buying_price')) {
      context.handle(
          _buyingPriceMeta,
          buyingPrice.isAcceptableOrUnknown(
              data['buying_price']!, _buyingPriceMeta));
    } else if (isInserting) {
      context.missing(_buyingPriceMeta);
    }
    if (data.containsKey('selling_price')) {
      context.handle(
          _sellingPriceMeta,
          sellingPrice.isAcceptableOrUnknown(
              data['selling_price']!, _sellingPriceMeta));
    } else if (isInserting) {
      context.missing(_sellingPriceMeta);
    }
    if (data.containsKey('low_stock_threshold')) {
      context.handle(
          _lowStockThresholdMeta,
          lowStockThreshold.isAcceptableOrUnknown(
              data['low_stock_threshold']!, _lowStockThresholdMeta));
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
          _expiryDateMeta,
          expiryDate.isAcceptableOrUnknown(
              data['expiry_date']!, _expiryDateMeta));
    }
    if (data.containsKey('batch_number')) {
      context.handle(
          _batchNumberMeta,
          batchNumber.isAcceptableOrUnknown(
              data['batch_number']!, _batchNumberMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, branchId};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      lastModified: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_modified'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      shopId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shop_id'])!,
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      barcode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}barcode'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      buyingPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}buying_price'])!,
      sellingPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}selling_price'])!,
      lowStockThreshold: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}low_stock_threshold'])!,
      expiryDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expiry_date']),
      batchNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}batch_number']),
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final String syncStatus;
  final DateTime lastModified;
  final String? remoteId;
  final int version;
  final String id;
  final String shopId;
  final String branchId;
  final String name;
  final String barcode;
  final double quantity;
  final double buyingPrice;
  final double sellingPrice;
  final int lowStockThreshold;
  final DateTime? expiryDate;
  final String? batchNumber;
  final String? imageUrl;
  const Product(
      {required this.syncStatus,
      required this.lastModified,
      this.remoteId,
      required this.version,
      required this.id,
      required this.shopId,
      required this.branchId,
      required this.name,
      required this.barcode,
      required this.quantity,
      required this.buyingPrice,
      required this.sellingPrice,
      required this.lowStockThreshold,
      this.expiryDate,
      this.batchNumber,
      this.imageUrl});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_status'] = Variable<String>(syncStatus);
    map['last_modified'] = Variable<DateTime>(lastModified);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    map['shop_id'] = Variable<String>(shopId);
    map['branch_id'] = Variable<String>(branchId);
    map['name'] = Variable<String>(name);
    map['barcode'] = Variable<String>(barcode);
    map['quantity'] = Variable<double>(quantity);
    map['buying_price'] = Variable<double>(buyingPrice);
    map['selling_price'] = Variable<double>(sellingPrice);
    map['low_stock_threshold'] = Variable<int>(lowStockThreshold);
    if (!nullToAbsent || expiryDate != null) {
      map['expiry_date'] = Variable<DateTime>(expiryDate);
    }
    if (!nullToAbsent || batchNumber != null) {
      map['batch_number'] = Variable<String>(batchNumber);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      syncStatus: Value(syncStatus),
      lastModified: Value(lastModified),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      version: Value(version),
      id: Value(id),
      shopId: Value(shopId),
      branchId: Value(branchId),
      name: Value(name),
      barcode: Value(barcode),
      quantity: Value(quantity),
      buyingPrice: Value(buyingPrice),
      sellingPrice: Value(sellingPrice),
      lowStockThreshold: Value(lowStockThreshold),
      expiryDate: expiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDate),
      batchNumber: batchNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(batchNumber),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
    );
  }

  factory Product.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      shopId: serializer.fromJson<String>(json['shopId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      name: serializer.fromJson<String>(json['name']),
      barcode: serializer.fromJson<String>(json['barcode']),
      quantity: serializer.fromJson<double>(json['quantity']),
      buyingPrice: serializer.fromJson<double>(json['buyingPrice']),
      sellingPrice: serializer.fromJson<double>(json['sellingPrice']),
      lowStockThreshold: serializer.fromJson<int>(json['lowStockThreshold']),
      expiryDate: serializer.fromJson<DateTime?>(json['expiryDate']),
      batchNumber: serializer.fromJson<String?>(json['batchNumber']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastModified': serializer.toJson<DateTime>(lastModified),
      'remoteId': serializer.toJson<String?>(remoteId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'shopId': serializer.toJson<String>(shopId),
      'branchId': serializer.toJson<String>(branchId),
      'name': serializer.toJson<String>(name),
      'barcode': serializer.toJson<String>(barcode),
      'quantity': serializer.toJson<double>(quantity),
      'buyingPrice': serializer.toJson<double>(buyingPrice),
      'sellingPrice': serializer.toJson<double>(sellingPrice),
      'lowStockThreshold': serializer.toJson<int>(lowStockThreshold),
      'expiryDate': serializer.toJson<DateTime?>(expiryDate),
      'batchNumber': serializer.toJson<String?>(batchNumber),
      'imageUrl': serializer.toJson<String?>(imageUrl),
    };
  }

  Product copyWith(
          {String? syncStatus,
          DateTime? lastModified,
          Value<String?> remoteId = const Value.absent(),
          int? version,
          String? id,
          String? shopId,
          String? branchId,
          String? name,
          String? barcode,
          double? quantity,
          double? buyingPrice,
          double? sellingPrice,
          int? lowStockThreshold,
          Value<DateTime?> expiryDate = const Value.absent(),
          Value<String?> batchNumber = const Value.absent(),
          Value<String?> imageUrl = const Value.absent()}) =>
      Product(
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        version: version ?? this.version,
        id: id ?? this.id,
        shopId: shopId ?? this.shopId,
        branchId: branchId ?? this.branchId,
        name: name ?? this.name,
        barcode: barcode ?? this.barcode,
        quantity: quantity ?? this.quantity,
        buyingPrice: buyingPrice ?? this.buyingPrice,
        sellingPrice: sellingPrice ?? this.sellingPrice,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        expiryDate: expiryDate.present ? expiryDate.value : this.expiryDate,
        batchNumber: batchNumber.present ? batchNumber.value : this.batchNumber,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
      );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      name: data.name.present ? data.name.value : this.name,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      buyingPrice:
          data.buyingPrice.present ? data.buyingPrice.value : this.buyingPrice,
      sellingPrice: data.sellingPrice.present
          ? data.sellingPrice.value
          : this.sellingPrice,
      lowStockThreshold: data.lowStockThreshold.present
          ? data.lowStockThreshold.value
          : this.lowStockThreshold,
      expiryDate:
          data.expiryDate.present ? data.expiryDate.value : this.expiryDate,
      batchNumber:
          data.batchNumber.present ? data.batchNumber.value : this.batchNumber,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('branchId: $branchId, ')
          ..write('name: $name, ')
          ..write('barcode: $barcode, ')
          ..write('quantity: $quantity, ')
          ..write('buyingPrice: $buyingPrice, ')
          ..write('sellingPrice: $sellingPrice, ')
          ..write('lowStockThreshold: $lowStockThreshold, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('batchNumber: $batchNumber, ')
          ..write('imageUrl: $imageUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      syncStatus,
      lastModified,
      remoteId,
      version,
      id,
      shopId,
      branchId,
      name,
      barcode,
      quantity,
      buyingPrice,
      sellingPrice,
      lowStockThreshold,
      expiryDate,
      batchNumber,
      imageUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.syncStatus == this.syncStatus &&
          other.lastModified == this.lastModified &&
          other.remoteId == this.remoteId &&
          other.version == this.version &&
          other.id == this.id &&
          other.shopId == this.shopId &&
          other.branchId == this.branchId &&
          other.name == this.name &&
          other.barcode == this.barcode &&
          other.quantity == this.quantity &&
          other.buyingPrice == this.buyingPrice &&
          other.sellingPrice == this.sellingPrice &&
          other.lowStockThreshold == this.lowStockThreshold &&
          other.expiryDate == this.expiryDate &&
          other.batchNumber == this.batchNumber &&
          other.imageUrl == this.imageUrl);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<String> syncStatus;
  final Value<DateTime> lastModified;
  final Value<String?> remoteId;
  final Value<int> version;
  final Value<String> id;
  final Value<String> shopId;
  final Value<String> branchId;
  final Value<String> name;
  final Value<String> barcode;
  final Value<double> quantity;
  final Value<double> buyingPrice;
  final Value<double> sellingPrice;
  final Value<int> lowStockThreshold;
  final Value<DateTime?> expiryDate;
  final Value<String?> batchNumber;
  final Value<String?> imageUrl;
  final Value<int> rowid;
  const ProductsCompanion({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.name = const Value.absent(),
    this.barcode = const Value.absent(),
    this.quantity = const Value.absent(),
    this.buyingPrice = const Value.absent(),
    this.sellingPrice = const Value.absent(),
    this.lowStockThreshold = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.batchNumber = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    required String id,
    required String shopId,
    required String branchId,
    required String name,
    this.barcode = const Value.absent(),
    required double quantity,
    required double buyingPrice,
    required double sellingPrice,
    this.lowStockThreshold = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.batchNumber = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        shopId = Value(shopId),
        branchId = Value(branchId),
        name = Value(name),
        quantity = Value(quantity),
        buyingPrice = Value(buyingPrice),
        sellingPrice = Value(sellingPrice);
  static Insertable<Product> custom({
    Expression<String>? syncStatus,
    Expression<DateTime>? lastModified,
    Expression<String>? remoteId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? shopId,
    Expression<String>? branchId,
    Expression<String>? name,
    Expression<String>? barcode,
    Expression<double>? quantity,
    Expression<double>? buyingPrice,
    Expression<double>? sellingPrice,
    Expression<int>? lowStockThreshold,
    Expression<DateTime>? expiryDate,
    Expression<String>? batchNumber,
    Expression<String>? imageUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastModified != null) 'last_modified': lastModified,
      if (remoteId != null) 'remote_id': remoteId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (branchId != null) 'branch_id': branchId,
      if (name != null) 'name': name,
      if (barcode != null) 'barcode': barcode,
      if (quantity != null) 'quantity': quantity,
      if (buyingPrice != null) 'buying_price': buyingPrice,
      if (sellingPrice != null) 'selling_price': sellingPrice,
      if (lowStockThreshold != null) 'low_stock_threshold': lowStockThreshold,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (batchNumber != null) 'batch_number': batchNumber,
      if (imageUrl != null) 'image_url': imageUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith(
      {Value<String>? syncStatus,
      Value<DateTime>? lastModified,
      Value<String?>? remoteId,
      Value<int>? version,
      Value<String>? id,
      Value<String>? shopId,
      Value<String>? branchId,
      Value<String>? name,
      Value<String>? barcode,
      Value<double>? quantity,
      Value<double>? buyingPrice,
      Value<double>? sellingPrice,
      Value<int>? lowStockThreshold,
      Value<DateTime?>? expiryDate,
      Value<String?>? batchNumber,
      Value<String?>? imageUrl,
      Value<int>? rowid}) {
    return ProductsCompanion(
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      remoteId: remoteId ?? this.remoteId,
      version: version ?? this.version,
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      branchId: branchId ?? this.branchId,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      expiryDate: expiryDate ?? this.expiryDate,
      batchNumber: batchNumber ?? this.batchNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (buyingPrice.present) {
      map['buying_price'] = Variable<double>(buyingPrice.value);
    }
    if (sellingPrice.present) {
      map['selling_price'] = Variable<double>(sellingPrice.value);
    }
    if (lowStockThreshold.present) {
      map['low_stock_threshold'] = Variable<int>(lowStockThreshold.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<DateTime>(expiryDate.value);
    }
    if (batchNumber.present) {
      map['batch_number'] = Variable<String>(batchNumber.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('branchId: $branchId, ')
          ..write('name: $name, ')
          ..write('barcode: $barcode, ')
          ..write('quantity: $quantity, ')
          ..write('buyingPrice: $buyingPrice, ')
          ..write('sellingPrice: $sellingPrice, ')
          ..write('lowStockThreshold: $lowStockThreshold, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('batchNumber: $batchNumber, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductStocksTable extends ProductStocks
    with TableInfo<$ProductStocksTable, ProductStock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductStocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('synced'));
  static const VerificationMeta _lastModifiedMeta =
      const VerificationMeta('lastModified');
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
      'last_modified', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
      'shop_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  @override
  List<GeneratedColumn> get $columns => [
        syncStatus,
        lastModified,
        remoteId,
        version,
        shopId,
        productId,
        branchId,
        quantity
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_stocks';
  @override
  VerificationContext validateIntegrity(Insertable<ProductStock> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('last_modified')) {
      context.handle(
          _lastModifiedMeta,
          lastModified.isAcceptableOrUnknown(
              data['last_modified']!, _lastModifiedMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('shop_id')) {
      context.handle(_shopIdMeta,
          shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta));
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    } else if (isInserting) {
      context.missing(_branchIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {shopId, productId, branchId};
  @override
  ProductStock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductStock(
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      lastModified: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_modified'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      shopId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shop_id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
    );
  }

  @override
  $ProductStocksTable createAlias(String alias) {
    return $ProductStocksTable(attachedDatabase, alias);
  }
}

class ProductStock extends DataClass implements Insertable<ProductStock> {
  final String syncStatus;
  final DateTime lastModified;
  final String? remoteId;
  final int version;
  final String shopId;
  final String productId;
  final String branchId;
  final double quantity;
  const ProductStock(
      {required this.syncStatus,
      required this.lastModified,
      this.remoteId,
      required this.version,
      required this.shopId,
      required this.productId,
      required this.branchId,
      required this.quantity});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_status'] = Variable<String>(syncStatus);
    map['last_modified'] = Variable<DateTime>(lastModified);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['version'] = Variable<int>(version);
    map['shop_id'] = Variable<String>(shopId);
    map['product_id'] = Variable<String>(productId);
    map['branch_id'] = Variable<String>(branchId);
    map['quantity'] = Variable<double>(quantity);
    return map;
  }

  ProductStocksCompanion toCompanion(bool nullToAbsent) {
    return ProductStocksCompanion(
      syncStatus: Value(syncStatus),
      lastModified: Value(lastModified),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      version: Value(version),
      shopId: Value(shopId),
      productId: Value(productId),
      branchId: Value(branchId),
      quantity: Value(quantity),
    );
  }

  factory ProductStock.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductStock(
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      version: serializer.fromJson<int>(json['version']),
      shopId: serializer.fromJson<String>(json['shopId']),
      productId: serializer.fromJson<String>(json['productId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      quantity: serializer.fromJson<double>(json['quantity']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastModified': serializer.toJson<DateTime>(lastModified),
      'remoteId': serializer.toJson<String?>(remoteId),
      'version': serializer.toJson<int>(version),
      'shopId': serializer.toJson<String>(shopId),
      'productId': serializer.toJson<String>(productId),
      'branchId': serializer.toJson<String>(branchId),
      'quantity': serializer.toJson<double>(quantity),
    };
  }

  ProductStock copyWith(
          {String? syncStatus,
          DateTime? lastModified,
          Value<String?> remoteId = const Value.absent(),
          int? version,
          String? shopId,
          String? productId,
          String? branchId,
          double? quantity}) =>
      ProductStock(
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        version: version ?? this.version,
        shopId: shopId ?? this.shopId,
        productId: productId ?? this.productId,
        branchId: branchId ?? this.branchId,
        quantity: quantity ?? this.quantity,
      );
  ProductStock copyWithCompanion(ProductStocksCompanion data) {
    return ProductStock(
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      version: data.version.present ? data.version.value : this.version,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      productId: data.productId.present ? data.productId.value : this.productId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductStock(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('shopId: $shopId, ')
          ..write('productId: $productId, ')
          ..write('branchId: $branchId, ')
          ..write('quantity: $quantity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncStatus, lastModified, remoteId, version,
      shopId, productId, branchId, quantity);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductStock &&
          other.syncStatus == this.syncStatus &&
          other.lastModified == this.lastModified &&
          other.remoteId == this.remoteId &&
          other.version == this.version &&
          other.shopId == this.shopId &&
          other.productId == this.productId &&
          other.branchId == this.branchId &&
          other.quantity == this.quantity);
}

class ProductStocksCompanion extends UpdateCompanion<ProductStock> {
  final Value<String> syncStatus;
  final Value<DateTime> lastModified;
  final Value<String?> remoteId;
  final Value<int> version;
  final Value<String> shopId;
  final Value<String> productId;
  final Value<String> branchId;
  final Value<double> quantity;
  final Value<int> rowid;
  const ProductStocksCompanion({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    this.shopId = const Value.absent(),
    this.productId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductStocksCompanion.insert({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    required String shopId,
    required String productId,
    required String branchId,
    this.quantity = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : shopId = Value(shopId),
        productId = Value(productId),
        branchId = Value(branchId);
  static Insertable<ProductStock> custom({
    Expression<String>? syncStatus,
    Expression<DateTime>? lastModified,
    Expression<String>? remoteId,
    Expression<int>? version,
    Expression<String>? shopId,
    Expression<String>? productId,
    Expression<String>? branchId,
    Expression<double>? quantity,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastModified != null) 'last_modified': lastModified,
      if (remoteId != null) 'remote_id': remoteId,
      if (version != null) 'version': version,
      if (shopId != null) 'shop_id': shopId,
      if (productId != null) 'product_id': productId,
      if (branchId != null) 'branch_id': branchId,
      if (quantity != null) 'quantity': quantity,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductStocksCompanion copyWith(
      {Value<String>? syncStatus,
      Value<DateTime>? lastModified,
      Value<String?>? remoteId,
      Value<int>? version,
      Value<String>? shopId,
      Value<String>? productId,
      Value<String>? branchId,
      Value<double>? quantity,
      Value<int>? rowid}) {
    return ProductStocksCompanion(
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      remoteId: remoteId ?? this.remoteId,
      version: version ?? this.version,
      shopId: shopId ?? this.shopId,
      productId: productId ?? this.productId,
      branchId: branchId ?? this.branchId,
      quantity: quantity ?? this.quantity,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductStocksCompanion(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('shopId: $shopId, ')
          ..write('productId: $productId, ')
          ..write('branchId: $branchId, ')
          ..write('quantity: $quantity, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SalesTable extends Sales with TableInfo<$SalesTable, Sale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('synced'));
  static const VerificationMeta _lastModifiedMeta =
      const VerificationMeta('lastModified');
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
      'last_modified', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
      'shop_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemNameMeta =
      const VerificationMeta('itemName');
  @override
  late final GeneratedColumn<String> itemName = GeneratedColumn<String>(
      'item_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _totalPriceMeta =
      const VerificationMeta('totalPrice');
  @override
  late final GeneratedColumn<double> totalPrice = GeneratedColumn<double>(
      'total_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _profitMeta = const VerificationMeta('profit');
  @override
  late final GeneratedColumn<double> profit = GeneratedColumn<double>(
      'profit', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _customerNameMeta =
      const VerificationMeta('customerName');
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
      'customer_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isDebtMeta = const VerificationMeta('isDebt');
  @override
  late final GeneratedColumn<bool> isDebt = GeneratedColumn<bool>(
      'is_debt', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_debt" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _amountPaidMeta =
      const VerificationMeta('amountPaid');
  @override
  late final GeneratedColumn<double> amountPaid = GeneratedColumn<double>(
      'amount_paid', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _debtRemainingMeta =
      const VerificationMeta('debtRemaining');
  @override
  late final GeneratedColumn<double> debtRemaining = GeneratedColumn<double>(
      'debt_remaining', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _saleGroupIdMeta =
      const VerificationMeta('saleGroupId');
  @override
  late final GeneratedColumn<String> saleGroupId = GeneratedColumn<String>(
      'sale_group_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _refundedQuantityMeta =
      const VerificationMeta('refundedQuantity');
  @override
  late final GeneratedColumn<double> refundedQuantity = GeneratedColumn<double>(
      'refunded_quantity', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _batchIdMeta =
      const VerificationMeta('batchId');
  @override
  late final GeneratedColumn<String> batchId = GeneratedColumn<String>(
      'batch_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStatus,
        lastModified,
        remoteId,
        version,
        id,
        shopId,
        branchId,
        itemId,
        itemName,
        quantity,
        totalPrice,
        profit,
        userId,
        username,
        timestamp,
        customerName,
        isDebt,
        amountPaid,
        debtRemaining,
        saleGroupId,
        refundedQuantity,
        batchId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales';
  @override
  VerificationContext validateIntegrity(Insertable<Sale> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('last_modified')) {
      context.handle(
          _lastModifiedMeta,
          lastModified.isAcceptableOrUnknown(
              data['last_modified']!, _lastModifiedMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(_shopIdMeta,
          shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta));
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    } else if (isInserting) {
      context.missing(_branchIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('item_name')) {
      context.handle(_itemNameMeta,
          itemName.isAcceptableOrUnknown(data['item_name']!, _itemNameMeta));
    } else if (isInserting) {
      context.missing(_itemNameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('total_price')) {
      context.handle(
          _totalPriceMeta,
          totalPrice.isAcceptableOrUnknown(
              data['total_price']!, _totalPriceMeta));
    } else if (isInserting) {
      context.missing(_totalPriceMeta);
    }
    if (data.containsKey('profit')) {
      context.handle(_profitMeta,
          profit.isAcceptableOrUnknown(data['profit']!, _profitMeta));
    } else if (isInserting) {
      context.missing(_profitMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('customer_name')) {
      context.handle(
          _customerNameMeta,
          customerName.isAcceptableOrUnknown(
              data['customer_name']!, _customerNameMeta));
    }
    if (data.containsKey('is_debt')) {
      context.handle(_isDebtMeta,
          isDebt.isAcceptableOrUnknown(data['is_debt']!, _isDebtMeta));
    }
    if (data.containsKey('amount_paid')) {
      context.handle(
          _amountPaidMeta,
          amountPaid.isAcceptableOrUnknown(
              data['amount_paid']!, _amountPaidMeta));
    }
    if (data.containsKey('debt_remaining')) {
      context.handle(
          _debtRemainingMeta,
          debtRemaining.isAcceptableOrUnknown(
              data['debt_remaining']!, _debtRemainingMeta));
    }
    if (data.containsKey('sale_group_id')) {
      context.handle(
          _saleGroupIdMeta,
          saleGroupId.isAcceptableOrUnknown(
              data['sale_group_id']!, _saleGroupIdMeta));
    }
    if (data.containsKey('refunded_quantity')) {
      context.handle(
          _refundedQuantityMeta,
          refundedQuantity.isAcceptableOrUnknown(
              data['refunded_quantity']!, _refundedQuantityMeta));
    }
    if (data.containsKey('batch_id')) {
      context.handle(_batchIdMeta,
          batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sale(
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      lastModified: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_modified'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      shopId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shop_id'])!,
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      itemName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_name'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      totalPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_price'])!,
      profit: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}profit'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      customerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_name']),
      isDebt: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_debt'])!,
      amountPaid: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_paid'])!,
      debtRemaining: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}debt_remaining'])!,
      saleGroupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sale_group_id']),
      refundedQuantity: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}refunded_quantity'])!,
      batchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}batch_id']),
    );
  }

  @override
  $SalesTable createAlias(String alias) {
    return $SalesTable(attachedDatabase, alias);
  }
}

class Sale extends DataClass implements Insertable<Sale> {
  final String syncStatus;
  final DateTime lastModified;
  final String? remoteId;
  final int version;
  final String id;
  final String shopId;
  final String branchId;
  final String itemId;
  final String itemName;
  final double quantity;
  final double totalPrice;
  final double profit;
  final String userId;
  final String username;
  final DateTime timestamp;
  final String? customerName;
  final bool isDebt;
  final double amountPaid;
  final double debtRemaining;
  final String? saleGroupId;
  final double refundedQuantity;

  /// Stores the primary batch ID deducted during this sale line.
  /// Used at refund time to restore stock to the exact original batch (FEFO/FIFO integrity).
  final String? batchId;
  const Sale(
      {required this.syncStatus,
      required this.lastModified,
      this.remoteId,
      required this.version,
      required this.id,
      required this.shopId,
      required this.branchId,
      required this.itemId,
      required this.itemName,
      required this.quantity,
      required this.totalPrice,
      required this.profit,
      required this.userId,
      required this.username,
      required this.timestamp,
      this.customerName,
      required this.isDebt,
      required this.amountPaid,
      required this.debtRemaining,
      this.saleGroupId,
      required this.refundedQuantity,
      this.batchId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_status'] = Variable<String>(syncStatus);
    map['last_modified'] = Variable<DateTime>(lastModified);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    map['shop_id'] = Variable<String>(shopId);
    map['branch_id'] = Variable<String>(branchId);
    map['item_id'] = Variable<String>(itemId);
    map['item_name'] = Variable<String>(itemName);
    map['quantity'] = Variable<double>(quantity);
    map['total_price'] = Variable<double>(totalPrice);
    map['profit'] = Variable<double>(profit);
    map['user_id'] = Variable<String>(userId);
    map['username'] = Variable<String>(username);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || customerName != null) {
      map['customer_name'] = Variable<String>(customerName);
    }
    map['is_debt'] = Variable<bool>(isDebt);
    map['amount_paid'] = Variable<double>(amountPaid);
    map['debt_remaining'] = Variable<double>(debtRemaining);
    if (!nullToAbsent || saleGroupId != null) {
      map['sale_group_id'] = Variable<String>(saleGroupId);
    }
    map['refunded_quantity'] = Variable<double>(refundedQuantity);
    if (!nullToAbsent || batchId != null) {
      map['batch_id'] = Variable<String>(batchId);
    }
    return map;
  }

  SalesCompanion toCompanion(bool nullToAbsent) {
    return SalesCompanion(
      syncStatus: Value(syncStatus),
      lastModified: Value(lastModified),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      version: Value(version),
      id: Value(id),
      shopId: Value(shopId),
      branchId: Value(branchId),
      itemId: Value(itemId),
      itemName: Value(itemName),
      quantity: Value(quantity),
      totalPrice: Value(totalPrice),
      profit: Value(profit),
      userId: Value(userId),
      username: Value(username),
      timestamp: Value(timestamp),
      customerName: customerName == null && nullToAbsent
          ? const Value.absent()
          : Value(customerName),
      isDebt: Value(isDebt),
      amountPaid: Value(amountPaid),
      debtRemaining: Value(debtRemaining),
      saleGroupId: saleGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(saleGroupId),
      refundedQuantity: Value(refundedQuantity),
      batchId: batchId == null && nullToAbsent
          ? const Value.absent()
          : Value(batchId),
    );
  }

  factory Sale.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sale(
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      shopId: serializer.fromJson<String>(json['shopId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      itemName: serializer.fromJson<String>(json['itemName']),
      quantity: serializer.fromJson<double>(json['quantity']),
      totalPrice: serializer.fromJson<double>(json['totalPrice']),
      profit: serializer.fromJson<double>(json['profit']),
      userId: serializer.fromJson<String>(json['userId']),
      username: serializer.fromJson<String>(json['username']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      customerName: serializer.fromJson<String?>(json['customerName']),
      isDebt: serializer.fromJson<bool>(json['isDebt']),
      amountPaid: serializer.fromJson<double>(json['amountPaid']),
      debtRemaining: serializer.fromJson<double>(json['debtRemaining']),
      saleGroupId: serializer.fromJson<String?>(json['saleGroupId']),
      refundedQuantity: serializer.fromJson<double>(json['refundedQuantity']),
      batchId: serializer.fromJson<String?>(json['batchId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastModified': serializer.toJson<DateTime>(lastModified),
      'remoteId': serializer.toJson<String?>(remoteId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'shopId': serializer.toJson<String>(shopId),
      'branchId': serializer.toJson<String>(branchId),
      'itemId': serializer.toJson<String>(itemId),
      'itemName': serializer.toJson<String>(itemName),
      'quantity': serializer.toJson<double>(quantity),
      'totalPrice': serializer.toJson<double>(totalPrice),
      'profit': serializer.toJson<double>(profit),
      'userId': serializer.toJson<String>(userId),
      'username': serializer.toJson<String>(username),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'customerName': serializer.toJson<String?>(customerName),
      'isDebt': serializer.toJson<bool>(isDebt),
      'amountPaid': serializer.toJson<double>(amountPaid),
      'debtRemaining': serializer.toJson<double>(debtRemaining),
      'saleGroupId': serializer.toJson<String?>(saleGroupId),
      'refundedQuantity': serializer.toJson<double>(refundedQuantity),
      'batchId': serializer.toJson<String?>(batchId),
    };
  }

  Sale copyWith(
          {String? syncStatus,
          DateTime? lastModified,
          Value<String?> remoteId = const Value.absent(),
          int? version,
          String? id,
          String? shopId,
          String? branchId,
          String? itemId,
          String? itemName,
          double? quantity,
          double? totalPrice,
          double? profit,
          String? userId,
          String? username,
          DateTime? timestamp,
          Value<String?> customerName = const Value.absent(),
          bool? isDebt,
          double? amountPaid,
          double? debtRemaining,
          Value<String?> saleGroupId = const Value.absent(),
          double? refundedQuantity,
          Value<String?> batchId = const Value.absent()}) =>
      Sale(
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        version: version ?? this.version,
        id: id ?? this.id,
        shopId: shopId ?? this.shopId,
        branchId: branchId ?? this.branchId,
        itemId: itemId ?? this.itemId,
        itemName: itemName ?? this.itemName,
        quantity: quantity ?? this.quantity,
        totalPrice: totalPrice ?? this.totalPrice,
        profit: profit ?? this.profit,
        userId: userId ?? this.userId,
        username: username ?? this.username,
        timestamp: timestamp ?? this.timestamp,
        customerName:
            customerName.present ? customerName.value : this.customerName,
        isDebt: isDebt ?? this.isDebt,
        amountPaid: amountPaid ?? this.amountPaid,
        debtRemaining: debtRemaining ?? this.debtRemaining,
        saleGroupId: saleGroupId.present ? saleGroupId.value : this.saleGroupId,
        refundedQuantity: refundedQuantity ?? this.refundedQuantity,
        batchId: batchId.present ? batchId.value : this.batchId,
      );
  Sale copyWithCompanion(SalesCompanion data) {
    return Sale(
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      itemName: data.itemName.present ? data.itemName.value : this.itemName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      totalPrice:
          data.totalPrice.present ? data.totalPrice.value : this.totalPrice,
      profit: data.profit.present ? data.profit.value : this.profit,
      userId: data.userId.present ? data.userId.value : this.userId,
      username: data.username.present ? data.username.value : this.username,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      isDebt: data.isDebt.present ? data.isDebt.value : this.isDebt,
      amountPaid:
          data.amountPaid.present ? data.amountPaid.value : this.amountPaid,
      debtRemaining: data.debtRemaining.present
          ? data.debtRemaining.value
          : this.debtRemaining,
      saleGroupId:
          data.saleGroupId.present ? data.saleGroupId.value : this.saleGroupId,
      refundedQuantity: data.refundedQuantity.present
          ? data.refundedQuantity.value
          : this.refundedQuantity,
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sale(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('branchId: $branchId, ')
          ..write('itemId: $itemId, ')
          ..write('itemName: $itemName, ')
          ..write('quantity: $quantity, ')
          ..write('totalPrice: $totalPrice, ')
          ..write('profit: $profit, ')
          ..write('userId: $userId, ')
          ..write('username: $username, ')
          ..write('timestamp: $timestamp, ')
          ..write('customerName: $customerName, ')
          ..write('isDebt: $isDebt, ')
          ..write('amountPaid: $amountPaid, ')
          ..write('debtRemaining: $debtRemaining, ')
          ..write('saleGroupId: $saleGroupId, ')
          ..write('refundedQuantity: $refundedQuantity, ')
          ..write('batchId: $batchId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        syncStatus,
        lastModified,
        remoteId,
        version,
        id,
        shopId,
        branchId,
        itemId,
        itemName,
        quantity,
        totalPrice,
        profit,
        userId,
        username,
        timestamp,
        customerName,
        isDebt,
        amountPaid,
        debtRemaining,
        saleGroupId,
        refundedQuantity,
        batchId
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sale &&
          other.syncStatus == this.syncStatus &&
          other.lastModified == this.lastModified &&
          other.remoteId == this.remoteId &&
          other.version == this.version &&
          other.id == this.id &&
          other.shopId == this.shopId &&
          other.branchId == this.branchId &&
          other.itemId == this.itemId &&
          other.itemName == this.itemName &&
          other.quantity == this.quantity &&
          other.totalPrice == this.totalPrice &&
          other.profit == this.profit &&
          other.userId == this.userId &&
          other.username == this.username &&
          other.timestamp == this.timestamp &&
          other.customerName == this.customerName &&
          other.isDebt == this.isDebt &&
          other.amountPaid == this.amountPaid &&
          other.debtRemaining == this.debtRemaining &&
          other.saleGroupId == this.saleGroupId &&
          other.refundedQuantity == this.refundedQuantity &&
          other.batchId == this.batchId);
}

class SalesCompanion extends UpdateCompanion<Sale> {
  final Value<String> syncStatus;
  final Value<DateTime> lastModified;
  final Value<String?> remoteId;
  final Value<int> version;
  final Value<String> id;
  final Value<String> shopId;
  final Value<String> branchId;
  final Value<String> itemId;
  final Value<String> itemName;
  final Value<double> quantity;
  final Value<double> totalPrice;
  final Value<double> profit;
  final Value<String> userId;
  final Value<String> username;
  final Value<DateTime> timestamp;
  final Value<String?> customerName;
  final Value<bool> isDebt;
  final Value<double> amountPaid;
  final Value<double> debtRemaining;
  final Value<String?> saleGroupId;
  final Value<double> refundedQuantity;
  final Value<String?> batchId;
  final Value<int> rowid;
  const SalesCompanion({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.itemName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.totalPrice = const Value.absent(),
    this.profit = const Value.absent(),
    this.userId = const Value.absent(),
    this.username = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.customerName = const Value.absent(),
    this.isDebt = const Value.absent(),
    this.amountPaid = const Value.absent(),
    this.debtRemaining = const Value.absent(),
    this.saleGroupId = const Value.absent(),
    this.refundedQuantity = const Value.absent(),
    this.batchId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalesCompanion.insert({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    required String id,
    required String shopId,
    required String branchId,
    required String itemId,
    required String itemName,
    required double quantity,
    required double totalPrice,
    required double profit,
    required String userId,
    required String username,
    required DateTime timestamp,
    this.customerName = const Value.absent(),
    this.isDebt = const Value.absent(),
    this.amountPaid = const Value.absent(),
    this.debtRemaining = const Value.absent(),
    this.saleGroupId = const Value.absent(),
    this.refundedQuantity = const Value.absent(),
    this.batchId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        shopId = Value(shopId),
        branchId = Value(branchId),
        itemId = Value(itemId),
        itemName = Value(itemName),
        quantity = Value(quantity),
        totalPrice = Value(totalPrice),
        profit = Value(profit),
        userId = Value(userId),
        username = Value(username),
        timestamp = Value(timestamp);
  static Insertable<Sale> custom({
    Expression<String>? syncStatus,
    Expression<DateTime>? lastModified,
    Expression<String>? remoteId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? shopId,
    Expression<String>? branchId,
    Expression<String>? itemId,
    Expression<String>? itemName,
    Expression<double>? quantity,
    Expression<double>? totalPrice,
    Expression<double>? profit,
    Expression<String>? userId,
    Expression<String>? username,
    Expression<DateTime>? timestamp,
    Expression<String>? customerName,
    Expression<bool>? isDebt,
    Expression<double>? amountPaid,
    Expression<double>? debtRemaining,
    Expression<String>? saleGroupId,
    Expression<double>? refundedQuantity,
    Expression<String>? batchId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastModified != null) 'last_modified': lastModified,
      if (remoteId != null) 'remote_id': remoteId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (branchId != null) 'branch_id': branchId,
      if (itemId != null) 'item_id': itemId,
      if (itemName != null) 'item_name': itemName,
      if (quantity != null) 'quantity': quantity,
      if (totalPrice != null) 'total_price': totalPrice,
      if (profit != null) 'profit': profit,
      if (userId != null) 'user_id': userId,
      if (username != null) 'username': username,
      if (timestamp != null) 'timestamp': timestamp,
      if (customerName != null) 'customer_name': customerName,
      if (isDebt != null) 'is_debt': isDebt,
      if (amountPaid != null) 'amount_paid': amountPaid,
      if (debtRemaining != null) 'debt_remaining': debtRemaining,
      if (saleGroupId != null) 'sale_group_id': saleGroupId,
      if (refundedQuantity != null) 'refunded_quantity': refundedQuantity,
      if (batchId != null) 'batch_id': batchId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalesCompanion copyWith(
      {Value<String>? syncStatus,
      Value<DateTime>? lastModified,
      Value<String?>? remoteId,
      Value<int>? version,
      Value<String>? id,
      Value<String>? shopId,
      Value<String>? branchId,
      Value<String>? itemId,
      Value<String>? itemName,
      Value<double>? quantity,
      Value<double>? totalPrice,
      Value<double>? profit,
      Value<String>? userId,
      Value<String>? username,
      Value<DateTime>? timestamp,
      Value<String?>? customerName,
      Value<bool>? isDebt,
      Value<double>? amountPaid,
      Value<double>? debtRemaining,
      Value<String?>? saleGroupId,
      Value<double>? refundedQuantity,
      Value<String?>? batchId,
      Value<int>? rowid}) {
    return SalesCompanion(
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      remoteId: remoteId ?? this.remoteId,
      version: version ?? this.version,
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      branchId: branchId ?? this.branchId,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      profit: profit ?? this.profit,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      timestamp: timestamp ?? this.timestamp,
      customerName: customerName ?? this.customerName,
      isDebt: isDebt ?? this.isDebt,
      amountPaid: amountPaid ?? this.amountPaid,
      debtRemaining: debtRemaining ?? this.debtRemaining,
      saleGroupId: saleGroupId ?? this.saleGroupId,
      refundedQuantity: refundedQuantity ?? this.refundedQuantity,
      batchId: batchId ?? this.batchId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (itemName.present) {
      map['item_name'] = Variable<String>(itemName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (totalPrice.present) {
      map['total_price'] = Variable<double>(totalPrice.value);
    }
    if (profit.present) {
      map['profit'] = Variable<double>(profit.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (isDebt.present) {
      map['is_debt'] = Variable<bool>(isDebt.value);
    }
    if (amountPaid.present) {
      map['amount_paid'] = Variable<double>(amountPaid.value);
    }
    if (debtRemaining.present) {
      map['debt_remaining'] = Variable<double>(debtRemaining.value);
    }
    if (saleGroupId.present) {
      map['sale_group_id'] = Variable<String>(saleGroupId.value);
    }
    if (refundedQuantity.present) {
      map['refunded_quantity'] = Variable<double>(refundedQuantity.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<String>(batchId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesCompanion(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('branchId: $branchId, ')
          ..write('itemId: $itemId, ')
          ..write('itemName: $itemName, ')
          ..write('quantity: $quantity, ')
          ..write('totalPrice: $totalPrice, ')
          ..write('profit: $profit, ')
          ..write('userId: $userId, ')
          ..write('username: $username, ')
          ..write('timestamp: $timestamp, ')
          ..write('customerName: $customerName, ')
          ..write('isDebt: $isDebt, ')
          ..write('amountPaid: $amountPaid, ')
          ..write('debtRemaining: $debtRemaining, ')
          ..write('saleGroupId: $saleGroupId, ')
          ..write('refundedQuantity: $refundedQuantity, ')
          ..write('batchId: $batchId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SuppliersTable extends Suppliers
    with TableInfo<$SuppliersTable, Supplier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuppliersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('synced'));
  static const VerificationMeta _lastModifiedMeta =
      const VerificationMeta('lastModified');
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
      'last_modified', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
      'shop_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contactMeta =
      const VerificationMeta('contact');
  @override
  late final GeneratedColumn<String> contact = GeneratedColumn<String>(
      'contact', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _totalTakenMeta =
      const VerificationMeta('totalTaken');
  @override
  late final GeneratedColumn<double> totalTaken = GeneratedColumn<double>(
      'total_taken', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _totalPaidMeta =
      const VerificationMeta('totalPaid');
  @override
  late final GeneratedColumn<double> totalPaid = GeneratedColumn<double>(
      'total_paid', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _remainingMeta =
      const VerificationMeta('remaining');
  @override
  late final GeneratedColumn<double> remaining = GeneratedColumn<double>(
      'remaining', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  @override
  List<GeneratedColumn> get $columns => [
        syncStatus,
        lastModified,
        remoteId,
        version,
        id,
        shopId,
        name,
        contact,
        address,
        totalTaken,
        totalPaid,
        remaining
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'suppliers';
  @override
  VerificationContext validateIntegrity(Insertable<Supplier> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('last_modified')) {
      context.handle(
          _lastModifiedMeta,
          lastModified.isAcceptableOrUnknown(
              data['last_modified']!, _lastModifiedMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(_shopIdMeta,
          shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta));
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('contact')) {
      context.handle(_contactMeta,
          contact.isAcceptableOrUnknown(data['contact']!, _contactMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('total_taken')) {
      context.handle(
          _totalTakenMeta,
          totalTaken.isAcceptableOrUnknown(
              data['total_taken']!, _totalTakenMeta));
    }
    if (data.containsKey('total_paid')) {
      context.handle(_totalPaidMeta,
          totalPaid.isAcceptableOrUnknown(data['total_paid']!, _totalPaidMeta));
    }
    if (data.containsKey('remaining')) {
      context.handle(_remainingMeta,
          remaining.isAcceptableOrUnknown(data['remaining']!, _remainingMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Supplier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Supplier(
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      lastModified: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_modified'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      shopId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shop_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      contact: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact']),
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      totalTaken: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_taken'])!,
      totalPaid: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_paid'])!,
      remaining: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}remaining'])!,
    );
  }

  @override
  $SuppliersTable createAlias(String alias) {
    return $SuppliersTable(attachedDatabase, alias);
  }
}

class Supplier extends DataClass implements Insertable<Supplier> {
  final String syncStatus;
  final DateTime lastModified;
  final String? remoteId;
  final int version;
  final String id;
  final String shopId;
  final String name;
  final String? contact;
  final String? address;
  final double totalTaken;
  final double totalPaid;
  final double remaining;
  const Supplier(
      {required this.syncStatus,
      required this.lastModified,
      this.remoteId,
      required this.version,
      required this.id,
      required this.shopId,
      required this.name,
      this.contact,
      this.address,
      required this.totalTaken,
      required this.totalPaid,
      required this.remaining});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_status'] = Variable<String>(syncStatus);
    map['last_modified'] = Variable<DateTime>(lastModified);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    map['shop_id'] = Variable<String>(shopId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || contact != null) {
      map['contact'] = Variable<String>(contact);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    map['total_taken'] = Variable<double>(totalTaken);
    map['total_paid'] = Variable<double>(totalPaid);
    map['remaining'] = Variable<double>(remaining);
    return map;
  }

  SuppliersCompanion toCompanion(bool nullToAbsent) {
    return SuppliersCompanion(
      syncStatus: Value(syncStatus),
      lastModified: Value(lastModified),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      version: Value(version),
      id: Value(id),
      shopId: Value(shopId),
      name: Value(name),
      contact: contact == null && nullToAbsent
          ? const Value.absent()
          : Value(contact),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      totalTaken: Value(totalTaken),
      totalPaid: Value(totalPaid),
      remaining: Value(remaining),
    );
  }

  factory Supplier.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Supplier(
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      shopId: serializer.fromJson<String>(json['shopId']),
      name: serializer.fromJson<String>(json['name']),
      contact: serializer.fromJson<String?>(json['contact']),
      address: serializer.fromJson<String?>(json['address']),
      totalTaken: serializer.fromJson<double>(json['totalTaken']),
      totalPaid: serializer.fromJson<double>(json['totalPaid']),
      remaining: serializer.fromJson<double>(json['remaining']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastModified': serializer.toJson<DateTime>(lastModified),
      'remoteId': serializer.toJson<String?>(remoteId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'shopId': serializer.toJson<String>(shopId),
      'name': serializer.toJson<String>(name),
      'contact': serializer.toJson<String?>(contact),
      'address': serializer.toJson<String?>(address),
      'totalTaken': serializer.toJson<double>(totalTaken),
      'totalPaid': serializer.toJson<double>(totalPaid),
      'remaining': serializer.toJson<double>(remaining),
    };
  }

  Supplier copyWith(
          {String? syncStatus,
          DateTime? lastModified,
          Value<String?> remoteId = const Value.absent(),
          int? version,
          String? id,
          String? shopId,
          String? name,
          Value<String?> contact = const Value.absent(),
          Value<String?> address = const Value.absent(),
          double? totalTaken,
          double? totalPaid,
          double? remaining}) =>
      Supplier(
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        version: version ?? this.version,
        id: id ?? this.id,
        shopId: shopId ?? this.shopId,
        name: name ?? this.name,
        contact: contact.present ? contact.value : this.contact,
        address: address.present ? address.value : this.address,
        totalTaken: totalTaken ?? this.totalTaken,
        totalPaid: totalPaid ?? this.totalPaid,
        remaining: remaining ?? this.remaining,
      );
  Supplier copyWithCompanion(SuppliersCompanion data) {
    return Supplier(
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      name: data.name.present ? data.name.value : this.name,
      contact: data.contact.present ? data.contact.value : this.contact,
      address: data.address.present ? data.address.value : this.address,
      totalTaken:
          data.totalTaken.present ? data.totalTaken.value : this.totalTaken,
      totalPaid: data.totalPaid.present ? data.totalPaid.value : this.totalPaid,
      remaining: data.remaining.present ? data.remaining.value : this.remaining,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Supplier(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('name: $name, ')
          ..write('contact: $contact, ')
          ..write('address: $address, ')
          ..write('totalTaken: $totalTaken, ')
          ..write('totalPaid: $totalPaid, ')
          ..write('remaining: $remaining')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncStatus, lastModified, remoteId, version,
      id, shopId, name, contact, address, totalTaken, totalPaid, remaining);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Supplier &&
          other.syncStatus == this.syncStatus &&
          other.lastModified == this.lastModified &&
          other.remoteId == this.remoteId &&
          other.version == this.version &&
          other.id == this.id &&
          other.shopId == this.shopId &&
          other.name == this.name &&
          other.contact == this.contact &&
          other.address == this.address &&
          other.totalTaken == this.totalTaken &&
          other.totalPaid == this.totalPaid &&
          other.remaining == this.remaining);
}

class SuppliersCompanion extends UpdateCompanion<Supplier> {
  final Value<String> syncStatus;
  final Value<DateTime> lastModified;
  final Value<String?> remoteId;
  final Value<int> version;
  final Value<String> id;
  final Value<String> shopId;
  final Value<String> name;
  final Value<String?> contact;
  final Value<String?> address;
  final Value<double> totalTaken;
  final Value<double> totalPaid;
  final Value<double> remaining;
  final Value<int> rowid;
  const SuppliersCompanion({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.name = const Value.absent(),
    this.contact = const Value.absent(),
    this.address = const Value.absent(),
    this.totalTaken = const Value.absent(),
    this.totalPaid = const Value.absent(),
    this.remaining = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SuppliersCompanion.insert({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    required String id,
    required String shopId,
    required String name,
    this.contact = const Value.absent(),
    this.address = const Value.absent(),
    this.totalTaken = const Value.absent(),
    this.totalPaid = const Value.absent(),
    this.remaining = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        shopId = Value(shopId),
        name = Value(name);
  static Insertable<Supplier> custom({
    Expression<String>? syncStatus,
    Expression<DateTime>? lastModified,
    Expression<String>? remoteId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? shopId,
    Expression<String>? name,
    Expression<String>? contact,
    Expression<String>? address,
    Expression<double>? totalTaken,
    Expression<double>? totalPaid,
    Expression<double>? remaining,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastModified != null) 'last_modified': lastModified,
      if (remoteId != null) 'remote_id': remoteId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (name != null) 'name': name,
      if (contact != null) 'contact': contact,
      if (address != null) 'address': address,
      if (totalTaken != null) 'total_taken': totalTaken,
      if (totalPaid != null) 'total_paid': totalPaid,
      if (remaining != null) 'remaining': remaining,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SuppliersCompanion copyWith(
      {Value<String>? syncStatus,
      Value<DateTime>? lastModified,
      Value<String?>? remoteId,
      Value<int>? version,
      Value<String>? id,
      Value<String>? shopId,
      Value<String>? name,
      Value<String?>? contact,
      Value<String?>? address,
      Value<double>? totalTaken,
      Value<double>? totalPaid,
      Value<double>? remaining,
      Value<int>? rowid}) {
    return SuppliersCompanion(
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      remoteId: remoteId ?? this.remoteId,
      version: version ?? this.version,
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      address: address ?? this.address,
      totalTaken: totalTaken ?? this.totalTaken,
      totalPaid: totalPaid ?? this.totalPaid,
      remaining: remaining ?? this.remaining,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (contact.present) {
      map['contact'] = Variable<String>(contact.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (totalTaken.present) {
      map['total_taken'] = Variable<double>(totalTaken.value);
    }
    if (totalPaid.present) {
      map['total_paid'] = Variable<double>(totalPaid.value);
    }
    if (remaining.present) {
      map['remaining'] = Variable<double>(remaining.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuppliersCompanion(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('name: $name, ')
          ..write('contact: $contact, ')
          ..write('address: $address, ')
          ..write('totalTaken: $totalTaken, ')
          ..write('totalPaid: $totalPaid, ')
          ..write('remaining: $remaining, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PurchasesTable extends Purchases
    with TableInfo<$PurchasesTable, Purchase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PurchasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('synced'));
  static const VerificationMeta _lastModifiedMeta =
      const VerificationMeta('lastModified');
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
      'last_modified', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
      'shop_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemNameMeta =
      const VerificationMeta('itemName');
  @override
  late final GeneratedColumn<String> itemName = GeneratedColumn<String>(
      'item_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _barcodeMeta =
      const VerificationMeta('barcode');
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
      'barcode', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _unitCostMeta =
      const VerificationMeta('unitCost');
  @override
  late final GeneratedColumn<double> unitCost = GeneratedColumn<double>(
      'unit_cost', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _totalCostMeta =
      const VerificationMeta('totalCost');
  @override
  late final GeneratedColumn<double> totalCost = GeneratedColumn<double>(
      'total_cost', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _supplierNameMeta =
      const VerificationMeta('supplierName');
  @override
  late final GeneratedColumn<String> supplierName = GeneratedColumn<String>(
      'supplier_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _batchNumberMeta =
      const VerificationMeta('batchNumber');
  @override
  late final GeneratedColumn<String> batchNumber = GeneratedColumn<String>(
      'batch_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _expiryDateMeta =
      const VerificationMeta('expiryDate');
  @override
  late final GeneratedColumn<DateTime> expiryDate = GeneratedColumn<DateTime>(
      'expiry_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('main'));
  @override
  List<GeneratedColumn> get $columns => [
        syncStatus,
        lastModified,
        remoteId,
        version,
        id,
        shopId,
        itemId,
        itemName,
        barcode,
        quantity,
        unitCost,
        totalCost,
        supplierName,
        batchNumber,
        expiryDate,
        timestamp,
        branchId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'purchases';
  @override
  VerificationContext validateIntegrity(Insertable<Purchase> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('last_modified')) {
      context.handle(
          _lastModifiedMeta,
          lastModified.isAcceptableOrUnknown(
              data['last_modified']!, _lastModifiedMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(_shopIdMeta,
          shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta));
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('item_name')) {
      context.handle(_itemNameMeta,
          itemName.isAcceptableOrUnknown(data['item_name']!, _itemNameMeta));
    } else if (isInserting) {
      context.missing(_itemNameMeta);
    }
    if (data.containsKey('barcode')) {
      context.handle(_barcodeMeta,
          barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta));
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_cost')) {
      context.handle(_unitCostMeta,
          unitCost.isAcceptableOrUnknown(data['unit_cost']!, _unitCostMeta));
    } else if (isInserting) {
      context.missing(_unitCostMeta);
    }
    if (data.containsKey('total_cost')) {
      context.handle(_totalCostMeta,
          totalCost.isAcceptableOrUnknown(data['total_cost']!, _totalCostMeta));
    } else if (isInserting) {
      context.missing(_totalCostMeta);
    }
    if (data.containsKey('supplier_name')) {
      context.handle(
          _supplierNameMeta,
          supplierName.isAcceptableOrUnknown(
              data['supplier_name']!, _supplierNameMeta));
    }
    if (data.containsKey('batch_number')) {
      context.handle(
          _batchNumberMeta,
          batchNumber.isAcceptableOrUnknown(
              data['batch_number']!, _batchNumberMeta));
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
          _expiryDateMeta,
          expiryDate.isAcceptableOrUnknown(
              data['expiry_date']!, _expiryDateMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Purchase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Purchase(
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      lastModified: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_modified'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      shopId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shop_id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      itemName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_name'])!,
      barcode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}barcode'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      unitCost: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}unit_cost'])!,
      totalCost: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_cost'])!,
      supplierName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}supplier_name']),
      batchNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}batch_number']),
      expiryDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expiry_date']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id'])!,
    );
  }

  @override
  $PurchasesTable createAlias(String alias) {
    return $PurchasesTable(attachedDatabase, alias);
  }
}

class Purchase extends DataClass implements Insertable<Purchase> {
  final String syncStatus;
  final DateTime lastModified;
  final String? remoteId;
  final int version;
  final String id;
  final String shopId;
  final String itemId;
  final String itemName;
  final String barcode;
  final double quantity;
  final double unitCost;
  final double totalCost;
  final String? supplierName;
  final String? batchNumber;
  final DateTime? expiryDate;
  final DateTime timestamp;
  final String branchId;
  const Purchase(
      {required this.syncStatus,
      required this.lastModified,
      this.remoteId,
      required this.version,
      required this.id,
      required this.shopId,
      required this.itemId,
      required this.itemName,
      required this.barcode,
      required this.quantity,
      required this.unitCost,
      required this.totalCost,
      this.supplierName,
      this.batchNumber,
      this.expiryDate,
      required this.timestamp,
      required this.branchId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_status'] = Variable<String>(syncStatus);
    map['last_modified'] = Variable<DateTime>(lastModified);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    map['shop_id'] = Variable<String>(shopId);
    map['item_id'] = Variable<String>(itemId);
    map['item_name'] = Variable<String>(itemName);
    map['barcode'] = Variable<String>(barcode);
    map['quantity'] = Variable<double>(quantity);
    map['unit_cost'] = Variable<double>(unitCost);
    map['total_cost'] = Variable<double>(totalCost);
    if (!nullToAbsent || supplierName != null) {
      map['supplier_name'] = Variable<String>(supplierName);
    }
    if (!nullToAbsent || batchNumber != null) {
      map['batch_number'] = Variable<String>(batchNumber);
    }
    if (!nullToAbsent || expiryDate != null) {
      map['expiry_date'] = Variable<DateTime>(expiryDate);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['branch_id'] = Variable<String>(branchId);
    return map;
  }

  PurchasesCompanion toCompanion(bool nullToAbsent) {
    return PurchasesCompanion(
      syncStatus: Value(syncStatus),
      lastModified: Value(lastModified),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      version: Value(version),
      id: Value(id),
      shopId: Value(shopId),
      itemId: Value(itemId),
      itemName: Value(itemName),
      barcode: Value(barcode),
      quantity: Value(quantity),
      unitCost: Value(unitCost),
      totalCost: Value(totalCost),
      supplierName: supplierName == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierName),
      batchNumber: batchNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(batchNumber),
      expiryDate: expiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDate),
      timestamp: Value(timestamp),
      branchId: Value(branchId),
    );
  }

  factory Purchase.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Purchase(
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      shopId: serializer.fromJson<String>(json['shopId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      itemName: serializer.fromJson<String>(json['itemName']),
      barcode: serializer.fromJson<String>(json['barcode']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unitCost: serializer.fromJson<double>(json['unitCost']),
      totalCost: serializer.fromJson<double>(json['totalCost']),
      supplierName: serializer.fromJson<String?>(json['supplierName']),
      batchNumber: serializer.fromJson<String?>(json['batchNumber']),
      expiryDate: serializer.fromJson<DateTime?>(json['expiryDate']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      branchId: serializer.fromJson<String>(json['branchId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastModified': serializer.toJson<DateTime>(lastModified),
      'remoteId': serializer.toJson<String?>(remoteId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'shopId': serializer.toJson<String>(shopId),
      'itemId': serializer.toJson<String>(itemId),
      'itemName': serializer.toJson<String>(itemName),
      'barcode': serializer.toJson<String>(barcode),
      'quantity': serializer.toJson<double>(quantity),
      'unitCost': serializer.toJson<double>(unitCost),
      'totalCost': serializer.toJson<double>(totalCost),
      'supplierName': serializer.toJson<String?>(supplierName),
      'batchNumber': serializer.toJson<String?>(batchNumber),
      'expiryDate': serializer.toJson<DateTime?>(expiryDate),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'branchId': serializer.toJson<String>(branchId),
    };
  }

  Purchase copyWith(
          {String? syncStatus,
          DateTime? lastModified,
          Value<String?> remoteId = const Value.absent(),
          int? version,
          String? id,
          String? shopId,
          String? itemId,
          String? itemName,
          String? barcode,
          double? quantity,
          double? unitCost,
          double? totalCost,
          Value<String?> supplierName = const Value.absent(),
          Value<String?> batchNumber = const Value.absent(),
          Value<DateTime?> expiryDate = const Value.absent(),
          DateTime? timestamp,
          String? branchId}) =>
      Purchase(
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        version: version ?? this.version,
        id: id ?? this.id,
        shopId: shopId ?? this.shopId,
        itemId: itemId ?? this.itemId,
        itemName: itemName ?? this.itemName,
        barcode: barcode ?? this.barcode,
        quantity: quantity ?? this.quantity,
        unitCost: unitCost ?? this.unitCost,
        totalCost: totalCost ?? this.totalCost,
        supplierName:
            supplierName.present ? supplierName.value : this.supplierName,
        batchNumber: batchNumber.present ? batchNumber.value : this.batchNumber,
        expiryDate: expiryDate.present ? expiryDate.value : this.expiryDate,
        timestamp: timestamp ?? this.timestamp,
        branchId: branchId ?? this.branchId,
      );
  Purchase copyWithCompanion(PurchasesCompanion data) {
    return Purchase(
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      itemName: data.itemName.present ? data.itemName.value : this.itemName,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
      totalCost: data.totalCost.present ? data.totalCost.value : this.totalCost,
      supplierName: data.supplierName.present
          ? data.supplierName.value
          : this.supplierName,
      batchNumber:
          data.batchNumber.present ? data.batchNumber.value : this.batchNumber,
      expiryDate:
          data.expiryDate.present ? data.expiryDate.value : this.expiryDate,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Purchase(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('itemId: $itemId, ')
          ..write('itemName: $itemName, ')
          ..write('barcode: $barcode, ')
          ..write('quantity: $quantity, ')
          ..write('unitCost: $unitCost, ')
          ..write('totalCost: $totalCost, ')
          ..write('supplierName: $supplierName, ')
          ..write('batchNumber: $batchNumber, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('timestamp: $timestamp, ')
          ..write('branchId: $branchId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      syncStatus,
      lastModified,
      remoteId,
      version,
      id,
      shopId,
      itemId,
      itemName,
      barcode,
      quantity,
      unitCost,
      totalCost,
      supplierName,
      batchNumber,
      expiryDate,
      timestamp,
      branchId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Purchase &&
          other.syncStatus == this.syncStatus &&
          other.lastModified == this.lastModified &&
          other.remoteId == this.remoteId &&
          other.version == this.version &&
          other.id == this.id &&
          other.shopId == this.shopId &&
          other.itemId == this.itemId &&
          other.itemName == this.itemName &&
          other.barcode == this.barcode &&
          other.quantity == this.quantity &&
          other.unitCost == this.unitCost &&
          other.totalCost == this.totalCost &&
          other.supplierName == this.supplierName &&
          other.batchNumber == this.batchNumber &&
          other.expiryDate == this.expiryDate &&
          other.timestamp == this.timestamp &&
          other.branchId == this.branchId);
}

class PurchasesCompanion extends UpdateCompanion<Purchase> {
  final Value<String> syncStatus;
  final Value<DateTime> lastModified;
  final Value<String?> remoteId;
  final Value<int> version;
  final Value<String> id;
  final Value<String> shopId;
  final Value<String> itemId;
  final Value<String> itemName;
  final Value<String> barcode;
  final Value<double> quantity;
  final Value<double> unitCost;
  final Value<double> totalCost;
  final Value<String?> supplierName;
  final Value<String?> batchNumber;
  final Value<DateTime?> expiryDate;
  final Value<DateTime> timestamp;
  final Value<String> branchId;
  final Value<int> rowid;
  const PurchasesCompanion({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.itemName = const Value.absent(),
    this.barcode = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.totalCost = const Value.absent(),
    this.supplierName = const Value.absent(),
    this.batchNumber = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.branchId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PurchasesCompanion.insert({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    required String id,
    required String shopId,
    required String itemId,
    required String itemName,
    this.barcode = const Value.absent(),
    required double quantity,
    required double unitCost,
    required double totalCost,
    this.supplierName = const Value.absent(),
    this.batchNumber = const Value.absent(),
    this.expiryDate = const Value.absent(),
    required DateTime timestamp,
    this.branchId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        shopId = Value(shopId),
        itemId = Value(itemId),
        itemName = Value(itemName),
        quantity = Value(quantity),
        unitCost = Value(unitCost),
        totalCost = Value(totalCost),
        timestamp = Value(timestamp);
  static Insertable<Purchase> custom({
    Expression<String>? syncStatus,
    Expression<DateTime>? lastModified,
    Expression<String>? remoteId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? shopId,
    Expression<String>? itemId,
    Expression<String>? itemName,
    Expression<String>? barcode,
    Expression<double>? quantity,
    Expression<double>? unitCost,
    Expression<double>? totalCost,
    Expression<String>? supplierName,
    Expression<String>? batchNumber,
    Expression<DateTime>? expiryDate,
    Expression<DateTime>? timestamp,
    Expression<String>? branchId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastModified != null) 'last_modified': lastModified,
      if (remoteId != null) 'remote_id': remoteId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (itemId != null) 'item_id': itemId,
      if (itemName != null) 'item_name': itemName,
      if (barcode != null) 'barcode': barcode,
      if (quantity != null) 'quantity': quantity,
      if (unitCost != null) 'unit_cost': unitCost,
      if (totalCost != null) 'total_cost': totalCost,
      if (supplierName != null) 'supplier_name': supplierName,
      if (batchNumber != null) 'batch_number': batchNumber,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (timestamp != null) 'timestamp': timestamp,
      if (branchId != null) 'branch_id': branchId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PurchasesCompanion copyWith(
      {Value<String>? syncStatus,
      Value<DateTime>? lastModified,
      Value<String?>? remoteId,
      Value<int>? version,
      Value<String>? id,
      Value<String>? shopId,
      Value<String>? itemId,
      Value<String>? itemName,
      Value<String>? barcode,
      Value<double>? quantity,
      Value<double>? unitCost,
      Value<double>? totalCost,
      Value<String?>? supplierName,
      Value<String?>? batchNumber,
      Value<DateTime?>? expiryDate,
      Value<DateTime>? timestamp,
      Value<String>? branchId,
      Value<int>? rowid}) {
    return PurchasesCompanion(
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      remoteId: remoteId ?? this.remoteId,
      version: version ?? this.version,
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      totalCost: totalCost ?? this.totalCost,
      supplierName: supplierName ?? this.supplierName,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      timestamp: timestamp ?? this.timestamp,
      branchId: branchId ?? this.branchId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (itemName.present) {
      map['item_name'] = Variable<String>(itemName.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unitCost.present) {
      map['unit_cost'] = Variable<double>(unitCost.value);
    }
    if (totalCost.present) {
      map['total_cost'] = Variable<double>(totalCost.value);
    }
    if (supplierName.present) {
      map['supplier_name'] = Variable<String>(supplierName.value);
    }
    if (batchNumber.present) {
      map['batch_number'] = Variable<String>(batchNumber.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<DateTime>(expiryDate.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PurchasesCompanion(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('itemId: $itemId, ')
          ..write('itemName: $itemName, ')
          ..write('barcode: $barcode, ')
          ..write('quantity: $quantity, ')
          ..write('unitCost: $unitCost, ')
          ..write('totalCost: $totalCost, ')
          ..write('supplierName: $supplierName, ')
          ..write('batchNumber: $batchNumber, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('timestamp: $timestamp, ')
          ..write('branchId: $branchId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BatchesTable extends Batches with TableInfo<$BatchesTable, Batche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('synced'));
  static const VerificationMeta _lastModifiedMeta =
      const VerificationMeta('lastModified');
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
      'last_modified', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
      'shop_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _buyingPriceMeta =
      const VerificationMeta('buyingPrice');
  @override
  late final GeneratedColumn<double> buyingPrice = GeneratedColumn<double>(
      'buying_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _sellingPriceMeta =
      const VerificationMeta('sellingPrice');
  @override
  late final GeneratedColumn<double> sellingPrice = GeneratedColumn<double>(
      'selling_price', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _expiryDateMeta =
      const VerificationMeta('expiryDate');
  @override
  late final GeneratedColumn<DateTime> expiryDate = GeneratedColumn<DateTime>(
      'expiry_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _batchNumberMeta =
      const VerificationMeta('batchNumber');
  @override
  late final GeneratedColumn<String> batchNumber = GeneratedColumn<String>(
      'batch_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('main'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStatus,
        lastModified,
        remoteId,
        version,
        id,
        shopId,
        itemId,
        quantity,
        buyingPrice,
        sellingPrice,
        expiryDate,
        batchNumber,
        timestamp,
        branchId,
        type
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'batches';
  @override
  VerificationContext validateIntegrity(Insertable<Batche> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('last_modified')) {
      context.handle(
          _lastModifiedMeta,
          lastModified.isAcceptableOrUnknown(
              data['last_modified']!, _lastModifiedMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(_shopIdMeta,
          shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta));
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('buying_price')) {
      context.handle(
          _buyingPriceMeta,
          buyingPrice.isAcceptableOrUnknown(
              data['buying_price']!, _buyingPriceMeta));
    } else if (isInserting) {
      context.missing(_buyingPriceMeta);
    }
    if (data.containsKey('selling_price')) {
      context.handle(
          _sellingPriceMeta,
          sellingPrice.isAcceptableOrUnknown(
              data['selling_price']!, _sellingPriceMeta));
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
          _expiryDateMeta,
          expiryDate.isAcceptableOrUnknown(
              data['expiry_date']!, _expiryDateMeta));
    }
    if (data.containsKey('batch_number')) {
      context.handle(
          _batchNumberMeta,
          batchNumber.isAcceptableOrUnknown(
              data['batch_number']!, _batchNumberMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Batche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Batche(
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      lastModified: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_modified'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      shopId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shop_id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      buyingPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}buying_price'])!,
      sellingPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}selling_price']),
      expiryDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expiry_date']),
      batchNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}batch_number']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type']),
    );
  }

  @override
  $BatchesTable createAlias(String alias) {
    return $BatchesTable(attachedDatabase, alias);
  }
}

class Batche extends DataClass implements Insertable<Batche> {
  final String syncStatus;
  final DateTime lastModified;
  final String? remoteId;
  final int version;
  final String id;
  final String shopId;
  final String itemId;
  final double quantity;
  final double buyingPrice;
  final double? sellingPrice;
  final DateTime? expiryDate;
  final String? batchNumber;
  final DateTime timestamp;
  final String branchId;
  final String? type;
  const Batche(
      {required this.syncStatus,
      required this.lastModified,
      this.remoteId,
      required this.version,
      required this.id,
      required this.shopId,
      required this.itemId,
      required this.quantity,
      required this.buyingPrice,
      this.sellingPrice,
      this.expiryDate,
      this.batchNumber,
      required this.timestamp,
      required this.branchId,
      this.type});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_status'] = Variable<String>(syncStatus);
    map['last_modified'] = Variable<DateTime>(lastModified);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    map['shop_id'] = Variable<String>(shopId);
    map['item_id'] = Variable<String>(itemId);
    map['quantity'] = Variable<double>(quantity);
    map['buying_price'] = Variable<double>(buyingPrice);
    if (!nullToAbsent || sellingPrice != null) {
      map['selling_price'] = Variable<double>(sellingPrice);
    }
    if (!nullToAbsent || expiryDate != null) {
      map['expiry_date'] = Variable<DateTime>(expiryDate);
    }
    if (!nullToAbsent || batchNumber != null) {
      map['batch_number'] = Variable<String>(batchNumber);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['branch_id'] = Variable<String>(branchId);
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    return map;
  }

  BatchesCompanion toCompanion(bool nullToAbsent) {
    return BatchesCompanion(
      syncStatus: Value(syncStatus),
      lastModified: Value(lastModified),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      version: Value(version),
      id: Value(id),
      shopId: Value(shopId),
      itemId: Value(itemId),
      quantity: Value(quantity),
      buyingPrice: Value(buyingPrice),
      sellingPrice: sellingPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(sellingPrice),
      expiryDate: expiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDate),
      batchNumber: batchNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(batchNumber),
      timestamp: Value(timestamp),
      branchId: Value(branchId),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
    );
  }

  factory Batche.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Batche(
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      shopId: serializer.fromJson<String>(json['shopId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      buyingPrice: serializer.fromJson<double>(json['buyingPrice']),
      sellingPrice: serializer.fromJson<double?>(json['sellingPrice']),
      expiryDate: serializer.fromJson<DateTime?>(json['expiryDate']),
      batchNumber: serializer.fromJson<String?>(json['batchNumber']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      branchId: serializer.fromJson<String>(json['branchId']),
      type: serializer.fromJson<String?>(json['type']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastModified': serializer.toJson<DateTime>(lastModified),
      'remoteId': serializer.toJson<String?>(remoteId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'shopId': serializer.toJson<String>(shopId),
      'itemId': serializer.toJson<String>(itemId),
      'quantity': serializer.toJson<double>(quantity),
      'buyingPrice': serializer.toJson<double>(buyingPrice),
      'sellingPrice': serializer.toJson<double?>(sellingPrice),
      'expiryDate': serializer.toJson<DateTime?>(expiryDate),
      'batchNumber': serializer.toJson<String?>(batchNumber),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'branchId': serializer.toJson<String>(branchId),
      'type': serializer.toJson<String?>(type),
    };
  }

  Batche copyWith(
          {String? syncStatus,
          DateTime? lastModified,
          Value<String?> remoteId = const Value.absent(),
          int? version,
          String? id,
          String? shopId,
          String? itemId,
          double? quantity,
          double? buyingPrice,
          Value<double?> sellingPrice = const Value.absent(),
          Value<DateTime?> expiryDate = const Value.absent(),
          Value<String?> batchNumber = const Value.absent(),
          DateTime? timestamp,
          String? branchId,
          Value<String?> type = const Value.absent()}) =>
      Batche(
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        version: version ?? this.version,
        id: id ?? this.id,
        shopId: shopId ?? this.shopId,
        itemId: itemId ?? this.itemId,
        quantity: quantity ?? this.quantity,
        buyingPrice: buyingPrice ?? this.buyingPrice,
        sellingPrice:
            sellingPrice.present ? sellingPrice.value : this.sellingPrice,
        expiryDate: expiryDate.present ? expiryDate.value : this.expiryDate,
        batchNumber: batchNumber.present ? batchNumber.value : this.batchNumber,
        timestamp: timestamp ?? this.timestamp,
        branchId: branchId ?? this.branchId,
        type: type.present ? type.value : this.type,
      );
  Batche copyWithCompanion(BatchesCompanion data) {
    return Batche(
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      buyingPrice:
          data.buyingPrice.present ? data.buyingPrice.value : this.buyingPrice,
      sellingPrice: data.sellingPrice.present
          ? data.sellingPrice.value
          : this.sellingPrice,
      expiryDate:
          data.expiryDate.present ? data.expiryDate.value : this.expiryDate,
      batchNumber:
          data.batchNumber.present ? data.batchNumber.value : this.batchNumber,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      type: data.type.present ? data.type.value : this.type,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Batche(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('itemId: $itemId, ')
          ..write('quantity: $quantity, ')
          ..write('buyingPrice: $buyingPrice, ')
          ..write('sellingPrice: $sellingPrice, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('batchNumber: $batchNumber, ')
          ..write('timestamp: $timestamp, ')
          ..write('branchId: $branchId, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      syncStatus,
      lastModified,
      remoteId,
      version,
      id,
      shopId,
      itemId,
      quantity,
      buyingPrice,
      sellingPrice,
      expiryDate,
      batchNumber,
      timestamp,
      branchId,
      type);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Batche &&
          other.syncStatus == this.syncStatus &&
          other.lastModified == this.lastModified &&
          other.remoteId == this.remoteId &&
          other.version == this.version &&
          other.id == this.id &&
          other.shopId == this.shopId &&
          other.itemId == this.itemId &&
          other.quantity == this.quantity &&
          other.buyingPrice == this.buyingPrice &&
          other.sellingPrice == this.sellingPrice &&
          other.expiryDate == this.expiryDate &&
          other.batchNumber == this.batchNumber &&
          other.timestamp == this.timestamp &&
          other.branchId == this.branchId &&
          other.type == this.type);
}

class BatchesCompanion extends UpdateCompanion<Batche> {
  final Value<String> syncStatus;
  final Value<DateTime> lastModified;
  final Value<String?> remoteId;
  final Value<int> version;
  final Value<String> id;
  final Value<String> shopId;
  final Value<String> itemId;
  final Value<double> quantity;
  final Value<double> buyingPrice;
  final Value<double?> sellingPrice;
  final Value<DateTime?> expiryDate;
  final Value<String?> batchNumber;
  final Value<DateTime> timestamp;
  final Value<String> branchId;
  final Value<String?> type;
  final Value<int> rowid;
  const BatchesCompanion({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.buyingPrice = const Value.absent(),
    this.sellingPrice = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.batchNumber = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.branchId = const Value.absent(),
    this.type = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BatchesCompanion.insert({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    required String id,
    required String shopId,
    required String itemId,
    required double quantity,
    required double buyingPrice,
    this.sellingPrice = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.batchNumber = const Value.absent(),
    required DateTime timestamp,
    this.branchId = const Value.absent(),
    this.type = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        shopId = Value(shopId),
        itemId = Value(itemId),
        quantity = Value(quantity),
        buyingPrice = Value(buyingPrice),
        timestamp = Value(timestamp);
  static Insertable<Batche> custom({
    Expression<String>? syncStatus,
    Expression<DateTime>? lastModified,
    Expression<String>? remoteId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? shopId,
    Expression<String>? itemId,
    Expression<double>? quantity,
    Expression<double>? buyingPrice,
    Expression<double>? sellingPrice,
    Expression<DateTime>? expiryDate,
    Expression<String>? batchNumber,
    Expression<DateTime>? timestamp,
    Expression<String>? branchId,
    Expression<String>? type,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastModified != null) 'last_modified': lastModified,
      if (remoteId != null) 'remote_id': remoteId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (itemId != null) 'item_id': itemId,
      if (quantity != null) 'quantity': quantity,
      if (buyingPrice != null) 'buying_price': buyingPrice,
      if (sellingPrice != null) 'selling_price': sellingPrice,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (batchNumber != null) 'batch_number': batchNumber,
      if (timestamp != null) 'timestamp': timestamp,
      if (branchId != null) 'branch_id': branchId,
      if (type != null) 'type': type,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BatchesCompanion copyWith(
      {Value<String>? syncStatus,
      Value<DateTime>? lastModified,
      Value<String?>? remoteId,
      Value<int>? version,
      Value<String>? id,
      Value<String>? shopId,
      Value<String>? itemId,
      Value<double>? quantity,
      Value<double>? buyingPrice,
      Value<double?>? sellingPrice,
      Value<DateTime?>? expiryDate,
      Value<String?>? batchNumber,
      Value<DateTime>? timestamp,
      Value<String>? branchId,
      Value<String?>? type,
      Value<int>? rowid}) {
    return BatchesCompanion(
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      remoteId: remoteId ?? this.remoteId,
      version: version ?? this.version,
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      expiryDate: expiryDate ?? this.expiryDate,
      batchNumber: batchNumber ?? this.batchNumber,
      timestamp: timestamp ?? this.timestamp,
      branchId: branchId ?? this.branchId,
      type: type ?? this.type,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (buyingPrice.present) {
      map['buying_price'] = Variable<double>(buyingPrice.value);
    }
    if (sellingPrice.present) {
      map['selling_price'] = Variable<double>(sellingPrice.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<DateTime>(expiryDate.value);
    }
    if (batchNumber.present) {
      map['batch_number'] = Variable<String>(batchNumber.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BatchesCompanion(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('itemId: $itemId, ')
          ..write('quantity: $quantity, ')
          ..write('buyingPrice: $buyingPrice, ')
          ..write('sellingPrice: $sellingPrice, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('batchNumber: $batchNumber, ')
          ..write('timestamp: $timestamp, ')
          ..write('branchId: $branchId, ')
          ..write('type: $type, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditLogsTable extends AuditLogs
    with TableInfo<$AuditLogsTable, AuditLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('synced'));
  static const VerificationMeta _lastModifiedMeta =
      const VerificationMeta('lastModified');
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
      'last_modified', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
      'shop_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _detailsMeta =
      const VerificationMeta('details');
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
      'details', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('main'));
  @override
  List<GeneratedColumn> get $columns => [
        syncStatus,
        lastModified,
        remoteId,
        version,
        id,
        shopId,
        username,
        action,
        details,
        timestamp,
        branchId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_logs';
  @override
  VerificationContext validateIntegrity(Insertable<AuditLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('last_modified')) {
      context.handle(
          _lastModifiedMeta,
          lastModified.isAcceptableOrUnknown(
              data['last_modified']!, _lastModifiedMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(_shopIdMeta,
          shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta));
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('details')) {
      context.handle(_detailsMeta,
          details.isAcceptableOrUnknown(data['details']!, _detailsMeta));
    } else if (isInserting) {
      context.missing(_detailsMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLog(
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      lastModified: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_modified'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      shopId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shop_id'])!,
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username'])!,
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      details: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}details'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id'])!,
    );
  }

  @override
  $AuditLogsTable createAlias(String alias) {
    return $AuditLogsTable(attachedDatabase, alias);
  }
}

class AuditLog extends DataClass implements Insertable<AuditLog> {
  final String syncStatus;
  final DateTime lastModified;
  final String? remoteId;
  final int version;
  final String id;
  final String shopId;
  final String username;
  final String action;
  final String details;
  final DateTime timestamp;
  final String branchId;
  const AuditLog(
      {required this.syncStatus,
      required this.lastModified,
      this.remoteId,
      required this.version,
      required this.id,
      required this.shopId,
      required this.username,
      required this.action,
      required this.details,
      required this.timestamp,
      required this.branchId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_status'] = Variable<String>(syncStatus);
    map['last_modified'] = Variable<DateTime>(lastModified);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    map['shop_id'] = Variable<String>(shopId);
    map['username'] = Variable<String>(username);
    map['action'] = Variable<String>(action);
    map['details'] = Variable<String>(details);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['branch_id'] = Variable<String>(branchId);
    return map;
  }

  AuditLogsCompanion toCompanion(bool nullToAbsent) {
    return AuditLogsCompanion(
      syncStatus: Value(syncStatus),
      lastModified: Value(lastModified),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      version: Value(version),
      id: Value(id),
      shopId: Value(shopId),
      username: Value(username),
      action: Value(action),
      details: Value(details),
      timestamp: Value(timestamp),
      branchId: Value(branchId),
    );
  }

  factory AuditLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLog(
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      shopId: serializer.fromJson<String>(json['shopId']),
      username: serializer.fromJson<String>(json['username']),
      action: serializer.fromJson<String>(json['action']),
      details: serializer.fromJson<String>(json['details']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      branchId: serializer.fromJson<String>(json['branchId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastModified': serializer.toJson<DateTime>(lastModified),
      'remoteId': serializer.toJson<String?>(remoteId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'shopId': serializer.toJson<String>(shopId),
      'username': serializer.toJson<String>(username),
      'action': serializer.toJson<String>(action),
      'details': serializer.toJson<String>(details),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'branchId': serializer.toJson<String>(branchId),
    };
  }

  AuditLog copyWith(
          {String? syncStatus,
          DateTime? lastModified,
          Value<String?> remoteId = const Value.absent(),
          int? version,
          String? id,
          String? shopId,
          String? username,
          String? action,
          String? details,
          DateTime? timestamp,
          String? branchId}) =>
      AuditLog(
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        version: version ?? this.version,
        id: id ?? this.id,
        shopId: shopId ?? this.shopId,
        username: username ?? this.username,
        action: action ?? this.action,
        details: details ?? this.details,
        timestamp: timestamp ?? this.timestamp,
        branchId: branchId ?? this.branchId,
      );
  AuditLog copyWithCompanion(AuditLogsCompanion data) {
    return AuditLog(
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      username: data.username.present ? data.username.value : this.username,
      action: data.action.present ? data.action.value : this.action,
      details: data.details.present ? data.details.value : this.details,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLog(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('username: $username, ')
          ..write('action: $action, ')
          ..write('details: $details, ')
          ..write('timestamp: $timestamp, ')
          ..write('branchId: $branchId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncStatus, lastModified, remoteId, version,
      id, shopId, username, action, details, timestamp, branchId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLog &&
          other.syncStatus == this.syncStatus &&
          other.lastModified == this.lastModified &&
          other.remoteId == this.remoteId &&
          other.version == this.version &&
          other.id == this.id &&
          other.shopId == this.shopId &&
          other.username == this.username &&
          other.action == this.action &&
          other.details == this.details &&
          other.timestamp == this.timestamp &&
          other.branchId == this.branchId);
}

class AuditLogsCompanion extends UpdateCompanion<AuditLog> {
  final Value<String> syncStatus;
  final Value<DateTime> lastModified;
  final Value<String?> remoteId;
  final Value<int> version;
  final Value<String> id;
  final Value<String> shopId;
  final Value<String> username;
  final Value<String> action;
  final Value<String> details;
  final Value<DateTime> timestamp;
  final Value<String> branchId;
  final Value<int> rowid;
  const AuditLogsCompanion({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.username = const Value.absent(),
    this.action = const Value.absent(),
    this.details = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.branchId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditLogsCompanion.insert({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    required String id,
    required String shopId,
    required String username,
    required String action,
    required String details,
    required DateTime timestamp,
    this.branchId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        shopId = Value(shopId),
        username = Value(username),
        action = Value(action),
        details = Value(details),
        timestamp = Value(timestamp);
  static Insertable<AuditLog> custom({
    Expression<String>? syncStatus,
    Expression<DateTime>? lastModified,
    Expression<String>? remoteId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? shopId,
    Expression<String>? username,
    Expression<String>? action,
    Expression<String>? details,
    Expression<DateTime>? timestamp,
    Expression<String>? branchId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastModified != null) 'last_modified': lastModified,
      if (remoteId != null) 'remote_id': remoteId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (username != null) 'username': username,
      if (action != null) 'action': action,
      if (details != null) 'details': details,
      if (timestamp != null) 'timestamp': timestamp,
      if (branchId != null) 'branch_id': branchId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditLogsCompanion copyWith(
      {Value<String>? syncStatus,
      Value<DateTime>? lastModified,
      Value<String?>? remoteId,
      Value<int>? version,
      Value<String>? id,
      Value<String>? shopId,
      Value<String>? username,
      Value<String>? action,
      Value<String>? details,
      Value<DateTime>? timestamp,
      Value<String>? branchId,
      Value<int>? rowid}) {
    return AuditLogsCompanion(
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      remoteId: remoteId ?? this.remoteId,
      version: version ?? this.version,
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      username: username ?? this.username,
      action: action ?? this.action,
      details: details ?? this.details,
      timestamp: timestamp ?? this.timestamp,
      branchId: branchId ?? this.branchId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogsCompanion(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('username: $username, ')
          ..write('action: $action, ')
          ..write('details: $details, ')
          ..write('timestamp: $timestamp, ')
          ..write('branchId: $branchId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
      'uid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rolesMeta = const VerificationMeta('roles');
  @override
  late final GeneratedColumn<String> roles = GeneratedColumn<String>(
      'roles', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
      'shop_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _branchNameMeta =
      const VerificationMeta('branchName');
  @override
  late final GeneratedColumn<String> branchName = GeneratedColumn<String>(
      'branch_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _permissionsMeta =
      const VerificationMeta('permissions');
  @override
  late final GeneratedColumn<String> permissions = GeneratedColumn<String>(
      'permissions', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _passwordHashMeta =
      const VerificationMeta('passwordHash');
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
      'password_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _fullNameMeta =
      const VerificationMeta('fullName');
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
      'full_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('USD'));
  @override
  List<GeneratedColumn> get $columns => [
        uid,
        email,
        roles,
        shopId,
        username,
        branchId,
        branchName,
        permissions,
        passwordHash,
        isActive,
        fullName,
        currency
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(Insertable<User> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uid')) {
      context.handle(
          _uidMeta, uid.isAcceptableOrUnknown(data['uid']!, _uidMeta));
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('roles')) {
      context.handle(
          _rolesMeta, roles.isAcceptableOrUnknown(data['roles']!, _rolesMeta));
    } else if (isInserting) {
      context.missing(_rolesMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(_shopIdMeta,
          shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta));
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    if (data.containsKey('branch_name')) {
      context.handle(
          _branchNameMeta,
          branchName.isAcceptableOrUnknown(
              data['branch_name']!, _branchNameMeta));
    }
    if (data.containsKey('permissions')) {
      context.handle(
          _permissionsMeta,
          permissions.isAcceptableOrUnknown(
              data['permissions']!, _permissionsMeta));
    }
    if (data.containsKey('password_hash')) {
      context.handle(
          _passwordHashMeta,
          passwordHash.isAcceptableOrUnknown(
              data['password_hash']!, _passwordHashMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('full_name')) {
      context.handle(_fullNameMeta,
          fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uid};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      uid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uid'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email'])!,
      roles: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}roles'])!,
      shopId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shop_id'])!,
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username'])!,
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id']),
      branchName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_name']),
      permissions: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}permissions']),
      passwordHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}password_hash']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      fullName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}full_name'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String uid;
  final String email;
  final String roles;
  final String shopId;
  final String username;
  final String? branchId;
  final String? branchName;
  final String? permissions;
  final String? passwordHash;
  final bool isActive;
  final String fullName;
  final String currency;
  const User(
      {required this.uid,
      required this.email,
      required this.roles,
      required this.shopId,
      required this.username,
      this.branchId,
      this.branchName,
      this.permissions,
      this.passwordHash,
      required this.isActive,
      required this.fullName,
      required this.currency});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uid'] = Variable<String>(uid);
    map['email'] = Variable<String>(email);
    map['roles'] = Variable<String>(roles);
    map['shop_id'] = Variable<String>(shopId);
    map['username'] = Variable<String>(username);
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<String>(branchId);
    }
    if (!nullToAbsent || branchName != null) {
      map['branch_name'] = Variable<String>(branchName);
    }
    if (!nullToAbsent || permissions != null) {
      map['permissions'] = Variable<String>(permissions);
    }
    if (!nullToAbsent || passwordHash != null) {
      map['password_hash'] = Variable<String>(passwordHash);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['full_name'] = Variable<String>(fullName);
    map['currency'] = Variable<String>(currency);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      uid: Value(uid),
      email: Value(email),
      roles: Value(roles),
      shopId: Value(shopId),
      username: Value(username),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      branchName: branchName == null && nullToAbsent
          ? const Value.absent()
          : Value(branchName),
      permissions: permissions == null && nullToAbsent
          ? const Value.absent()
          : Value(permissions),
      passwordHash: passwordHash == null && nullToAbsent
          ? const Value.absent()
          : Value(passwordHash),
      isActive: Value(isActive),
      fullName: Value(fullName),
      currency: Value(currency),
    );
  }

  factory User.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      uid: serializer.fromJson<String>(json['uid']),
      email: serializer.fromJson<String>(json['email']),
      roles: serializer.fromJson<String>(json['roles']),
      shopId: serializer.fromJson<String>(json['shopId']),
      username: serializer.fromJson<String>(json['username']),
      branchId: serializer.fromJson<String?>(json['branchId']),
      branchName: serializer.fromJson<String?>(json['branchName']),
      permissions: serializer.fromJson<String?>(json['permissions']),
      passwordHash: serializer.fromJson<String?>(json['passwordHash']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      fullName: serializer.fromJson<String>(json['fullName']),
      currency: serializer.fromJson<String>(json['currency']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uid': serializer.toJson<String>(uid),
      'email': serializer.toJson<String>(email),
      'roles': serializer.toJson<String>(roles),
      'shopId': serializer.toJson<String>(shopId),
      'username': serializer.toJson<String>(username),
      'branchId': serializer.toJson<String?>(branchId),
      'branchName': serializer.toJson<String?>(branchName),
      'permissions': serializer.toJson<String?>(permissions),
      'passwordHash': serializer.toJson<String?>(passwordHash),
      'isActive': serializer.toJson<bool>(isActive),
      'fullName': serializer.toJson<String>(fullName),
      'currency': serializer.toJson<String>(currency),
    };
  }

  User copyWith(
          {String? uid,
          String? email,
          String? roles,
          String? shopId,
          String? username,
          Value<String?> branchId = const Value.absent(),
          Value<String?> branchName = const Value.absent(),
          Value<String?> permissions = const Value.absent(),
          Value<String?> passwordHash = const Value.absent(),
          bool? isActive,
          String? fullName,
          String? currency}) =>
      User(
        uid: uid ?? this.uid,
        email: email ?? this.email,
        roles: roles ?? this.roles,
        shopId: shopId ?? this.shopId,
        username: username ?? this.username,
        branchId: branchId.present ? branchId.value : this.branchId,
        branchName: branchName.present ? branchName.value : this.branchName,
        permissions: permissions.present ? permissions.value : this.permissions,
        passwordHash:
            passwordHash.present ? passwordHash.value : this.passwordHash,
        isActive: isActive ?? this.isActive,
        fullName: fullName ?? this.fullName,
        currency: currency ?? this.currency,
      );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      uid: data.uid.present ? data.uid.value : this.uid,
      email: data.email.present ? data.email.value : this.email,
      roles: data.roles.present ? data.roles.value : this.roles,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      username: data.username.present ? data.username.value : this.username,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      branchName:
          data.branchName.present ? data.branchName.value : this.branchName,
      permissions:
          data.permissions.present ? data.permissions.value : this.permissions,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      currency: data.currency.present ? data.currency.value : this.currency,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('uid: $uid, ')
          ..write('email: $email, ')
          ..write('roles: $roles, ')
          ..write('shopId: $shopId, ')
          ..write('username: $username, ')
          ..write('branchId: $branchId, ')
          ..write('branchName: $branchName, ')
          ..write('permissions: $permissions, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('isActive: $isActive, ')
          ..write('fullName: $fullName, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uid, email, roles, shopId, username, branchId,
      branchName, permissions, passwordHash, isActive, fullName, currency);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.uid == this.uid &&
          other.email == this.email &&
          other.roles == this.roles &&
          other.shopId == this.shopId &&
          other.username == this.username &&
          other.branchId == this.branchId &&
          other.branchName == this.branchName &&
          other.permissions == this.permissions &&
          other.passwordHash == this.passwordHash &&
          other.isActive == this.isActive &&
          other.fullName == this.fullName &&
          other.currency == this.currency);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> uid;
  final Value<String> email;
  final Value<String> roles;
  final Value<String> shopId;
  final Value<String> username;
  final Value<String?> branchId;
  final Value<String?> branchName;
  final Value<String?> permissions;
  final Value<String?> passwordHash;
  final Value<bool> isActive;
  final Value<String> fullName;
  final Value<String> currency;
  final Value<int> rowid;
  const UsersCompanion({
    this.uid = const Value.absent(),
    this.email = const Value.absent(),
    this.roles = const Value.absent(),
    this.shopId = const Value.absent(),
    this.username = const Value.absent(),
    this.branchId = const Value.absent(),
    this.branchName = const Value.absent(),
    this.permissions = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.isActive = const Value.absent(),
    this.fullName = const Value.absent(),
    this.currency = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String uid,
    required String email,
    required String roles,
    required String shopId,
    required String username,
    this.branchId = const Value.absent(),
    this.branchName = const Value.absent(),
    this.permissions = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.isActive = const Value.absent(),
    this.fullName = const Value.absent(),
    this.currency = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : uid = Value(uid),
        email = Value(email),
        roles = Value(roles),
        shopId = Value(shopId),
        username = Value(username);
  static Insertable<User> custom({
    Expression<String>? uid,
    Expression<String>? email,
    Expression<String>? roles,
    Expression<String>? shopId,
    Expression<String>? username,
    Expression<String>? branchId,
    Expression<String>? branchName,
    Expression<String>? permissions,
    Expression<String>? passwordHash,
    Expression<bool>? isActive,
    Expression<String>? fullName,
    Expression<String>? currency,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uid != null) 'uid': uid,
      if (email != null) 'email': email,
      if (roles != null) 'roles': roles,
      if (shopId != null) 'shop_id': shopId,
      if (username != null) 'username': username,
      if (branchId != null) 'branch_id': branchId,
      if (branchName != null) 'branch_name': branchName,
      if (permissions != null) 'permissions': permissions,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (isActive != null) 'is_active': isActive,
      if (fullName != null) 'full_name': fullName,
      if (currency != null) 'currency': currency,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith(
      {Value<String>? uid,
      Value<String>? email,
      Value<String>? roles,
      Value<String>? shopId,
      Value<String>? username,
      Value<String?>? branchId,
      Value<String?>? branchName,
      Value<String?>? permissions,
      Value<String?>? passwordHash,
      Value<bool>? isActive,
      Value<String>? fullName,
      Value<String>? currency,
      Value<int>? rowid}) {
    return UsersCompanion(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      roles: roles ?? this.roles,
      shopId: shopId ?? this.shopId,
      username: username ?? this.username,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      permissions: permissions ?? this.permissions,
      passwordHash: passwordHash ?? this.passwordHash,
      isActive: isActive ?? this.isActive,
      fullName: fullName ?? this.fullName,
      currency: currency ?? this.currency,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (roles.present) {
      map['roles'] = Variable<String>(roles.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (branchName.present) {
      map['branch_name'] = Variable<String>(branchName.value);
    }
    if (permissions.present) {
      map['permissions'] = Variable<String>(permissions.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('uid: $uid, ')
          ..write('email: $email, ')
          ..write('roles: $roles, ')
          ..write('shopId: $shopId, ')
          ..write('username: $username, ')
          ..write('branchId: $branchId, ')
          ..write('branchName: $branchName, ')
          ..write('permissions: $permissions, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('isActive: $isActive, ')
          ..write('fullName: $fullName, ')
          ..write('currency: $currency, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BranchesTable extends Branches with TableInfo<$BranchesTable, Branche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BranchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('synced'));
  static const VerificationMeta _lastModifiedMeta =
      const VerificationMeta('lastModified');
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
      'last_modified', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
      'shop_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        syncStatus,
        lastModified,
        remoteId,
        version,
        id,
        shopId,
        name,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'branches';
  @override
  VerificationContext validateIntegrity(Insertable<Branche> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('last_modified')) {
      context.handle(
          _lastModifiedMeta,
          lastModified.isAcceptableOrUnknown(
              data['last_modified']!, _lastModifiedMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(_shopIdMeta,
          shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta));
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Branche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Branche(
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      lastModified: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_modified'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      shopId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shop_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $BranchesTable createAlias(String alias) {
    return $BranchesTable(attachedDatabase, alias);
  }
}

class Branche extends DataClass implements Insertable<Branche> {
  final String syncStatus;
  final DateTime lastModified;
  final String? remoteId;
  final int version;
  final String id;
  final String shopId;
  final String name;
  final DateTime createdAt;
  const Branche(
      {required this.syncStatus,
      required this.lastModified,
      this.remoteId,
      required this.version,
      required this.id,
      required this.shopId,
      required this.name,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_status'] = Variable<String>(syncStatus);
    map['last_modified'] = Variable<DateTime>(lastModified);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    map['shop_id'] = Variable<String>(shopId);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BranchesCompanion toCompanion(bool nullToAbsent) {
    return BranchesCompanion(
      syncStatus: Value(syncStatus),
      lastModified: Value(lastModified),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      version: Value(version),
      id: Value(id),
      shopId: Value(shopId),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory Branche.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Branche(
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      shopId: serializer.fromJson<String>(json['shopId']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastModified': serializer.toJson<DateTime>(lastModified),
      'remoteId': serializer.toJson<String?>(remoteId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'shopId': serializer.toJson<String>(shopId),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Branche copyWith(
          {String? syncStatus,
          DateTime? lastModified,
          Value<String?> remoteId = const Value.absent(),
          int? version,
          String? id,
          String? shopId,
          String? name,
          DateTime? createdAt}) =>
      Branche(
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        version: version ?? this.version,
        id: id ?? this.id,
        shopId: shopId ?? this.shopId,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  Branche copyWithCompanion(BranchesCompanion data) {
    return Branche(
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Branche(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      syncStatus, lastModified, remoteId, version, id, shopId, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Branche &&
          other.syncStatus == this.syncStatus &&
          other.lastModified == this.lastModified &&
          other.remoteId == this.remoteId &&
          other.version == this.version &&
          other.id == this.id &&
          other.shopId == this.shopId &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class BranchesCompanion extends UpdateCompanion<Branche> {
  final Value<String> syncStatus;
  final Value<DateTime> lastModified;
  final Value<String?> remoteId;
  final Value<int> version;
  final Value<String> id;
  final Value<String> shopId;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BranchesCompanion({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BranchesCompanion.insert({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    required String id,
    required String shopId,
    required String name,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        shopId = Value(shopId),
        name = Value(name),
        createdAt = Value(createdAt);
  static Insertable<Branche> custom({
    Expression<String>? syncStatus,
    Expression<DateTime>? lastModified,
    Expression<String>? remoteId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? shopId,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastModified != null) 'last_modified': lastModified,
      if (remoteId != null) 'remote_id': remoteId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BranchesCompanion copyWith(
      {Value<String>? syncStatus,
      Value<DateTime>? lastModified,
      Value<String?>? remoteId,
      Value<int>? version,
      Value<String>? id,
      Value<String>? shopId,
      Value<String>? name,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return BranchesCompanion(
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      remoteId: remoteId ?? this.remoteId,
      version: version ?? this.version,
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BranchesCompanion(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory AppSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) => AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationsTable extends Notifications
    with TableInfo<$NotificationsTable, Notification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('synced'));
  static const VerificationMeta _lastModifiedMeta =
      const VerificationMeta('lastModified');
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
      'last_modified', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
      'shop_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
      'priority', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('normal'));
  static const VerificationMeta _relatedEntityIdMeta =
      const VerificationMeta('relatedEntityId');
  @override
  late final GeneratedColumn<String> relatedEntityId = GeneratedColumn<String>(
      'related_entity_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdByMeta =
      const VerificationMeta('createdBy');
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
      'created_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _targetRoleMeta =
      const VerificationMeta('targetRole');
  @override
  late final GeneratedColumn<String> targetRole = GeneratedColumn<String>(
      'target_role', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
      'is_read', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_read" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _routeMeta = const VerificationMeta('route');
  @override
  late final GeneratedColumn<String> route = GeneratedColumn<String>(
      'route', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStatus,
        lastModified,
        remoteId,
        version,
        id,
        shopId,
        title,
        body,
        type,
        priority,
        relatedEntityId,
        createdBy,
        targetRole,
        itemId,
        branchId,
        isRead,
        timestamp,
        route,
        payloadJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notifications';
  @override
  VerificationContext validateIntegrity(Insertable<Notification> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('last_modified')) {
      context.handle(
          _lastModifiedMeta,
          lastModified.isAcceptableOrUnknown(
              data['last_modified']!, _lastModifiedMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(_shopIdMeta,
          shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta));
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    }
    if (data.containsKey('related_entity_id')) {
      context.handle(
          _relatedEntityIdMeta,
          relatedEntityId.isAcceptableOrUnknown(
              data['related_entity_id']!, _relatedEntityIdMeta));
    }
    if (data.containsKey('created_by')) {
      context.handle(_createdByMeta,
          createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta));
    }
    if (data.containsKey('target_role')) {
      context.handle(
          _targetRoleMeta,
          targetRole.isAcceptableOrUnknown(
              data['target_role']!, _targetRoleMeta));
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    if (data.containsKey('is_read')) {
      context.handle(_isReadMeta,
          isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    if (data.containsKey('route')) {
      context.handle(
          _routeMeta, route.isAcceptableOrUnknown(data['route']!, _routeMeta));
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Notification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Notification(
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      lastModified: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_modified'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      shopId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shop_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}priority'])!,
      relatedEntityId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}related_entity_id']),
      createdBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_by']),
      targetRole: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_role']),
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id']),
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id']),
      isRead: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_read'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      route: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}route']),
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json']),
    );
  }

  @override
  $NotificationsTable createAlias(String alias) {
    return $NotificationsTable(attachedDatabase, alias);
  }
}

class Notification extends DataClass implements Insertable<Notification> {
  final String syncStatus;
  final DateTime lastModified;
  final String? remoteId;
  final int version;
  final String id;
  final String shopId;
  final String title;
  final String body;
  final String type;
  final String priority;
  final String? relatedEntityId;
  final String? createdBy;
  final String? targetRole;
  final String? itemId;

  /// Branch that generated this notification (nullable for shop-wide alerts).
  final String? branchId;
  final bool isRead;
  final DateTime timestamp;
  final String? route;
  final String? payloadJson;
  const Notification(
      {required this.syncStatus,
      required this.lastModified,
      this.remoteId,
      required this.version,
      required this.id,
      required this.shopId,
      required this.title,
      required this.body,
      required this.type,
      required this.priority,
      this.relatedEntityId,
      this.createdBy,
      this.targetRole,
      this.itemId,
      this.branchId,
      required this.isRead,
      required this.timestamp,
      this.route,
      this.payloadJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_status'] = Variable<String>(syncStatus);
    map['last_modified'] = Variable<DateTime>(lastModified);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    map['shop_id'] = Variable<String>(shopId);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['type'] = Variable<String>(type);
    map['priority'] = Variable<String>(priority);
    if (!nullToAbsent || relatedEntityId != null) {
      map['related_entity_id'] = Variable<String>(relatedEntityId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || targetRole != null) {
      map['target_role'] = Variable<String>(targetRole);
    }
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<String>(branchId);
    }
    map['is_read'] = Variable<bool>(isRead);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || route != null) {
      map['route'] = Variable<String>(route);
    }
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    return map;
  }

  NotificationsCompanion toCompanion(bool nullToAbsent) {
    return NotificationsCompanion(
      syncStatus: Value(syncStatus),
      lastModified: Value(lastModified),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      version: Value(version),
      id: Value(id),
      shopId: Value(shopId),
      title: Value(title),
      body: Value(body),
      type: Value(type),
      priority: Value(priority),
      relatedEntityId: relatedEntityId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedEntityId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      targetRole: targetRole == null && nullToAbsent
          ? const Value.absent()
          : Value(targetRole),
      itemId:
          itemId == null && nullToAbsent ? const Value.absent() : Value(itemId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      isRead: Value(isRead),
      timestamp: Value(timestamp),
      route:
          route == null && nullToAbsent ? const Value.absent() : Value(route),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
    );
  }

  factory Notification.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Notification(
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      shopId: serializer.fromJson<String>(json['shopId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      type: serializer.fromJson<String>(json['type']),
      priority: serializer.fromJson<String>(json['priority']),
      relatedEntityId: serializer.fromJson<String?>(json['relatedEntityId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      targetRole: serializer.fromJson<String?>(json['targetRole']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      branchId: serializer.fromJson<String?>(json['branchId']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      route: serializer.fromJson<String?>(json['route']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastModified': serializer.toJson<DateTime>(lastModified),
      'remoteId': serializer.toJson<String?>(remoteId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'shopId': serializer.toJson<String>(shopId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'type': serializer.toJson<String>(type),
      'priority': serializer.toJson<String>(priority),
      'relatedEntityId': serializer.toJson<String?>(relatedEntityId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'targetRole': serializer.toJson<String?>(targetRole),
      'itemId': serializer.toJson<String?>(itemId),
      'branchId': serializer.toJson<String?>(branchId),
      'isRead': serializer.toJson<bool>(isRead),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'route': serializer.toJson<String?>(route),
      'payloadJson': serializer.toJson<String?>(payloadJson),
    };
  }

  Notification copyWith(
          {String? syncStatus,
          DateTime? lastModified,
          Value<String?> remoteId = const Value.absent(),
          int? version,
          String? id,
          String? shopId,
          String? title,
          String? body,
          String? type,
          String? priority,
          Value<String?> relatedEntityId = const Value.absent(),
          Value<String?> createdBy = const Value.absent(),
          Value<String?> targetRole = const Value.absent(),
          Value<String?> itemId = const Value.absent(),
          Value<String?> branchId = const Value.absent(),
          bool? isRead,
          DateTime? timestamp,
          Value<String?> route = const Value.absent(),
          Value<String?> payloadJson = const Value.absent()}) =>
      Notification(
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        version: version ?? this.version,
        id: id ?? this.id,
        shopId: shopId ?? this.shopId,
        title: title ?? this.title,
        body: body ?? this.body,
        type: type ?? this.type,
        priority: priority ?? this.priority,
        relatedEntityId: relatedEntityId.present
            ? relatedEntityId.value
            : this.relatedEntityId,
        createdBy: createdBy.present ? createdBy.value : this.createdBy,
        targetRole: targetRole.present ? targetRole.value : this.targetRole,
        itemId: itemId.present ? itemId.value : this.itemId,
        branchId: branchId.present ? branchId.value : this.branchId,
        isRead: isRead ?? this.isRead,
        timestamp: timestamp ?? this.timestamp,
        route: route.present ? route.value : this.route,
        payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
      );
  Notification copyWithCompanion(NotificationsCompanion data) {
    return Notification(
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      type: data.type.present ? data.type.value : this.type,
      priority: data.priority.present ? data.priority.value : this.priority,
      relatedEntityId: data.relatedEntityId.present
          ? data.relatedEntityId.value
          : this.relatedEntityId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      targetRole:
          data.targetRole.present ? data.targetRole.value : this.targetRole,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      route: data.route.present ? data.route.value : this.route,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Notification(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('type: $type, ')
          ..write('priority: $priority, ')
          ..write('relatedEntityId: $relatedEntityId, ')
          ..write('createdBy: $createdBy, ')
          ..write('targetRole: $targetRole, ')
          ..write('itemId: $itemId, ')
          ..write('branchId: $branchId, ')
          ..write('isRead: $isRead, ')
          ..write('timestamp: $timestamp, ')
          ..write('route: $route, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      syncStatus,
      lastModified,
      remoteId,
      version,
      id,
      shopId,
      title,
      body,
      type,
      priority,
      relatedEntityId,
      createdBy,
      targetRole,
      itemId,
      branchId,
      isRead,
      timestamp,
      route,
      payloadJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Notification &&
          other.syncStatus == this.syncStatus &&
          other.lastModified == this.lastModified &&
          other.remoteId == this.remoteId &&
          other.version == this.version &&
          other.id == this.id &&
          other.shopId == this.shopId &&
          other.title == this.title &&
          other.body == this.body &&
          other.type == this.type &&
          other.priority == this.priority &&
          other.relatedEntityId == this.relatedEntityId &&
          other.createdBy == this.createdBy &&
          other.targetRole == this.targetRole &&
          other.itemId == this.itemId &&
          other.branchId == this.branchId &&
          other.isRead == this.isRead &&
          other.timestamp == this.timestamp &&
          other.route == this.route &&
          other.payloadJson == this.payloadJson);
}

class NotificationsCompanion extends UpdateCompanion<Notification> {
  final Value<String> syncStatus;
  final Value<DateTime> lastModified;
  final Value<String?> remoteId;
  final Value<int> version;
  final Value<String> id;
  final Value<String> shopId;
  final Value<String> title;
  final Value<String> body;
  final Value<String> type;
  final Value<String> priority;
  final Value<String?> relatedEntityId;
  final Value<String?> createdBy;
  final Value<String?> targetRole;
  final Value<String?> itemId;
  final Value<String?> branchId;
  final Value<bool> isRead;
  final Value<DateTime> timestamp;
  final Value<String?> route;
  final Value<String?> payloadJson;
  final Value<int> rowid;
  const NotificationsCompanion({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.type = const Value.absent(),
    this.priority = const Value.absent(),
    this.relatedEntityId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.targetRole = const Value.absent(),
    this.itemId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.isRead = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.route = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationsCompanion.insert({
    this.syncStatus = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.version = const Value.absent(),
    required String id,
    required String shopId,
    required String title,
    required String body,
    required String type,
    this.priority = const Value.absent(),
    this.relatedEntityId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.targetRole = const Value.absent(),
    this.itemId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.isRead = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.route = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        shopId = Value(shopId),
        title = Value(title),
        body = Value(body),
        type = Value(type);
  static Insertable<Notification> custom({
    Expression<String>? syncStatus,
    Expression<DateTime>? lastModified,
    Expression<String>? remoteId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? shopId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? type,
    Expression<String>? priority,
    Expression<String>? relatedEntityId,
    Expression<String>? createdBy,
    Expression<String>? targetRole,
    Expression<String>? itemId,
    Expression<String>? branchId,
    Expression<bool>? isRead,
    Expression<DateTime>? timestamp,
    Expression<String>? route,
    Expression<String>? payloadJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastModified != null) 'last_modified': lastModified,
      if (remoteId != null) 'remote_id': remoteId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (type != null) 'type': type,
      if (priority != null) 'priority': priority,
      if (relatedEntityId != null) 'related_entity_id': relatedEntityId,
      if (createdBy != null) 'created_by': createdBy,
      if (targetRole != null) 'target_role': targetRole,
      if (itemId != null) 'item_id': itemId,
      if (branchId != null) 'branch_id': branchId,
      if (isRead != null) 'is_read': isRead,
      if (timestamp != null) 'timestamp': timestamp,
      if (route != null) 'route': route,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationsCompanion copyWith(
      {Value<String>? syncStatus,
      Value<DateTime>? lastModified,
      Value<String?>? remoteId,
      Value<int>? version,
      Value<String>? id,
      Value<String>? shopId,
      Value<String>? title,
      Value<String>? body,
      Value<String>? type,
      Value<String>? priority,
      Value<String?>? relatedEntityId,
      Value<String?>? createdBy,
      Value<String?>? targetRole,
      Value<String?>? itemId,
      Value<String?>? branchId,
      Value<bool>? isRead,
      Value<DateTime>? timestamp,
      Value<String?>? route,
      Value<String?>? payloadJson,
      Value<int>? rowid}) {
    return NotificationsCompanion(
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      remoteId: remoteId ?? this.remoteId,
      version: version ?? this.version,
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      createdBy: createdBy ?? this.createdBy,
      targetRole: targetRole ?? this.targetRole,
      itemId: itemId ?? this.itemId,
      branchId: branchId ?? this.branchId,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
      route: route ?? this.route,
      payloadJson: payloadJson ?? this.payloadJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (relatedEntityId.present) {
      map['related_entity_id'] = Variable<String>(relatedEntityId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (targetRole.present) {
      map['target_role'] = Variable<String>(targetRole.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (route.present) {
      map['route'] = Variable<String>(route.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationsCompanion(')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastModified: $lastModified, ')
          ..write('remoteId: $remoteId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('type: $type, ')
          ..write('priority: $priority, ')
          ..write('relatedEntityId: $relatedEntityId, ')
          ..write('createdBy: $createdBy, ')
          ..write('targetRole: $targetRole, ')
          ..write('itemId: $itemId, ')
          ..write('branchId: $branchId, ')
          ..write('isRead: $isRead, ')
          ..write('timestamp: $timestamp, ')
          ..write('route: $route, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubscriptionsTable extends Subscriptions
    with TableInfo<$SubscriptionsTable, Subscription> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubscriptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
      'shop_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _planMeta = const VerificationMeta('plan');
  @override
  late final GeneratedColumn<String> plan = GeneratedColumn<String>(
      'plan', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _activationDateMeta =
      const VerificationMeta('activationDate');
  @override
  late final GeneratedColumn<DateTime> activationDate =
      GeneratedColumn<DateTime>('activation_date', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _expiryDateMeta =
      const VerificationMeta('expiryDate');
  @override
  late final GeneratedColumn<DateTime> expiryDate = GeneratedColumn<DateTime>(
      'expiry_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _addOnsMeta = const VerificationMeta('addOns');
  @override
  late final GeneratedColumn<String> addOns = GeneratedColumn<String>(
      'add_ons', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isTrialMeta =
      const VerificationMeta('isTrial');
  @override
  late final GeneratedColumn<bool> isTrial = GeneratedColumn<bool>(
      'is_trial', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_trial" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _userLimitMeta =
      const VerificationMeta('userLimit');
  @override
  late final GeneratedColumn<int> userLimit = GeneratedColumn<int>(
      'user_limit', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(3));
  static const VerificationMeta _branchLimitMeta =
      const VerificationMeta('branchLimit');
  @override
  late final GeneratedColumn<int> branchLimit = GeneratedColumn<int>(
      'branch_limit', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns => [
        shopId,
        plan,
        activationDate,
        expiryDate,
        addOns,
        isTrial,
        userLimit,
        branchLimit
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subscriptions';
  @override
  VerificationContext validateIntegrity(Insertable<Subscription> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('shop_id')) {
      context.handle(_shopIdMeta,
          shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta));
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('plan')) {
      context.handle(
          _planMeta, plan.isAcceptableOrUnknown(data['plan']!, _planMeta));
    } else if (isInserting) {
      context.missing(_planMeta);
    }
    if (data.containsKey('activation_date')) {
      context.handle(
          _activationDateMeta,
          activationDate.isAcceptableOrUnknown(
              data['activation_date']!, _activationDateMeta));
    } else if (isInserting) {
      context.missing(_activationDateMeta);
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
          _expiryDateMeta,
          expiryDate.isAcceptableOrUnknown(
              data['expiry_date']!, _expiryDateMeta));
    } else if (isInserting) {
      context.missing(_expiryDateMeta);
    }
    if (data.containsKey('add_ons')) {
      context.handle(_addOnsMeta,
          addOns.isAcceptableOrUnknown(data['add_ons']!, _addOnsMeta));
    }
    if (data.containsKey('is_trial')) {
      context.handle(_isTrialMeta,
          isTrial.isAcceptableOrUnknown(data['is_trial']!, _isTrialMeta));
    }
    if (data.containsKey('user_limit')) {
      context.handle(_userLimitMeta,
          userLimit.isAcceptableOrUnknown(data['user_limit']!, _userLimitMeta));
    }
    if (data.containsKey('branch_limit')) {
      context.handle(
          _branchLimitMeta,
          branchLimit.isAcceptableOrUnknown(
              data['branch_limit']!, _branchLimitMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {shopId};
  @override
  Subscription map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subscription(
      shopId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shop_id'])!,
      plan: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan'])!,
      activationDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}activation_date'])!,
      expiryDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expiry_date'])!,
      addOns: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}add_ons']),
      isTrial: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_trial'])!,
      userLimit: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}user_limit'])!,
      branchLimit: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}branch_limit'])!,
    );
  }

  @override
  $SubscriptionsTable createAlias(String alias) {
    return $SubscriptionsTable(attachedDatabase, alias);
  }
}

class Subscription extends DataClass implements Insertable<Subscription> {
  final String shopId;
  final String plan;
  final DateTime activationDate;
  final DateTime expiryDate;
  final String? addOns;
  final bool isTrial;
  final int userLimit;
  final int branchLimit;
  const Subscription(
      {required this.shopId,
      required this.plan,
      required this.activationDate,
      required this.expiryDate,
      this.addOns,
      required this.isTrial,
      required this.userLimit,
      required this.branchLimit});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['shop_id'] = Variable<String>(shopId);
    map['plan'] = Variable<String>(plan);
    map['activation_date'] = Variable<DateTime>(activationDate);
    map['expiry_date'] = Variable<DateTime>(expiryDate);
    if (!nullToAbsent || addOns != null) {
      map['add_ons'] = Variable<String>(addOns);
    }
    map['is_trial'] = Variable<bool>(isTrial);
    map['user_limit'] = Variable<int>(userLimit);
    map['branch_limit'] = Variable<int>(branchLimit);
    return map;
  }

  SubscriptionsCompanion toCompanion(bool nullToAbsent) {
    return SubscriptionsCompanion(
      shopId: Value(shopId),
      plan: Value(plan),
      activationDate: Value(activationDate),
      expiryDate: Value(expiryDate),
      addOns:
          addOns == null && nullToAbsent ? const Value.absent() : Value(addOns),
      isTrial: Value(isTrial),
      userLimit: Value(userLimit),
      branchLimit: Value(branchLimit),
    );
  }

  factory Subscription.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subscription(
      shopId: serializer.fromJson<String>(json['shopId']),
      plan: serializer.fromJson<String>(json['plan']),
      activationDate: serializer.fromJson<DateTime>(json['activationDate']),
      expiryDate: serializer.fromJson<DateTime>(json['expiryDate']),
      addOns: serializer.fromJson<String?>(json['addOns']),
      isTrial: serializer.fromJson<bool>(json['isTrial']),
      userLimit: serializer.fromJson<int>(json['userLimit']),
      branchLimit: serializer.fromJson<int>(json['branchLimit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'shopId': serializer.toJson<String>(shopId),
      'plan': serializer.toJson<String>(plan),
      'activationDate': serializer.toJson<DateTime>(activationDate),
      'expiryDate': serializer.toJson<DateTime>(expiryDate),
      'addOns': serializer.toJson<String?>(addOns),
      'isTrial': serializer.toJson<bool>(isTrial),
      'userLimit': serializer.toJson<int>(userLimit),
      'branchLimit': serializer.toJson<int>(branchLimit),
    };
  }

  Subscription copyWith(
          {String? shopId,
          String? plan,
          DateTime? activationDate,
          DateTime? expiryDate,
          Value<String?> addOns = const Value.absent(),
          bool? isTrial,
          int? userLimit,
          int? branchLimit}) =>
      Subscription(
        shopId: shopId ?? this.shopId,
        plan: plan ?? this.plan,
        activationDate: activationDate ?? this.activationDate,
        expiryDate: expiryDate ?? this.expiryDate,
        addOns: addOns.present ? addOns.value : this.addOns,
        isTrial: isTrial ?? this.isTrial,
        userLimit: userLimit ?? this.userLimit,
        branchLimit: branchLimit ?? this.branchLimit,
      );
  Subscription copyWithCompanion(SubscriptionsCompanion data) {
    return Subscription(
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      plan: data.plan.present ? data.plan.value : this.plan,
      activationDate: data.activationDate.present
          ? data.activationDate.value
          : this.activationDate,
      expiryDate:
          data.expiryDate.present ? data.expiryDate.value : this.expiryDate,
      addOns: data.addOns.present ? data.addOns.value : this.addOns,
      isTrial: data.isTrial.present ? data.isTrial.value : this.isTrial,
      userLimit: data.userLimit.present ? data.userLimit.value : this.userLimit,
      branchLimit:
          data.branchLimit.present ? data.branchLimit.value : this.branchLimit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subscription(')
          ..write('shopId: $shopId, ')
          ..write('plan: $plan, ')
          ..write('activationDate: $activationDate, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('addOns: $addOns, ')
          ..write('isTrial: $isTrial, ')
          ..write('userLimit: $userLimit, ')
          ..write('branchLimit: $branchLimit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(shopId, plan, activationDate, expiryDate,
      addOns, isTrial, userLimit, branchLimit);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subscription &&
          other.shopId == this.shopId &&
          other.plan == this.plan &&
          other.activationDate == this.activationDate &&
          other.expiryDate == this.expiryDate &&
          other.addOns == this.addOns &&
          other.isTrial == this.isTrial &&
          other.userLimit == this.userLimit &&
          other.branchLimit == this.branchLimit);
}

class SubscriptionsCompanion extends UpdateCompanion<Subscription> {
  final Value<String> shopId;
  final Value<String> plan;
  final Value<DateTime> activationDate;
  final Value<DateTime> expiryDate;
  final Value<String?> addOns;
  final Value<bool> isTrial;
  final Value<int> userLimit;
  final Value<int> branchLimit;
  final Value<int> rowid;
  const SubscriptionsCompanion({
    this.shopId = const Value.absent(),
    this.plan = const Value.absent(),
    this.activationDate = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.addOns = const Value.absent(),
    this.isTrial = const Value.absent(),
    this.userLimit = const Value.absent(),
    this.branchLimit = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubscriptionsCompanion.insert({
    required String shopId,
    required String plan,
    required DateTime activationDate,
    required DateTime expiryDate,
    this.addOns = const Value.absent(),
    this.isTrial = const Value.absent(),
    this.userLimit = const Value.absent(),
    this.branchLimit = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : shopId = Value(shopId),
        plan = Value(plan),
        activationDate = Value(activationDate),
        expiryDate = Value(expiryDate);
  static Insertable<Subscription> custom({
    Expression<String>? shopId,
    Expression<String>? plan,
    Expression<DateTime>? activationDate,
    Expression<DateTime>? expiryDate,
    Expression<String>? addOns,
    Expression<bool>? isTrial,
    Expression<int>? userLimit,
    Expression<int>? branchLimit,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (shopId != null) 'shop_id': shopId,
      if (plan != null) 'plan': plan,
      if (activationDate != null) 'activation_date': activationDate,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (addOns != null) 'add_ons': addOns,
      if (isTrial != null) 'is_trial': isTrial,
      if (userLimit != null) 'user_limit': userLimit,
      if (branchLimit != null) 'branch_limit': branchLimit,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubscriptionsCompanion copyWith(
      {Value<String>? shopId,
      Value<String>? plan,
      Value<DateTime>? activationDate,
      Value<DateTime>? expiryDate,
      Value<String?>? addOns,
      Value<bool>? isTrial,
      Value<int>? userLimit,
      Value<int>? branchLimit,
      Value<int>? rowid}) {
    return SubscriptionsCompanion(
      shopId: shopId ?? this.shopId,
      plan: plan ?? this.plan,
      activationDate: activationDate ?? this.activationDate,
      expiryDate: expiryDate ?? this.expiryDate,
      addOns: addOns ?? this.addOns,
      isTrial: isTrial ?? this.isTrial,
      userLimit: userLimit ?? this.userLimit,
      branchLimit: branchLimit ?? this.branchLimit,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (plan.present) {
      map['plan'] = Variable<String>(plan.value);
    }
    if (activationDate.present) {
      map['activation_date'] = Variable<DateTime>(activationDate.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<DateTime>(expiryDate.value);
    }
    if (addOns.present) {
      map['add_ons'] = Variable<String>(addOns.value);
    }
    if (isTrial.present) {
      map['is_trial'] = Variable<bool>(isTrial.value);
    }
    if (userLimit.present) {
      map['user_limit'] = Variable<int>(userLimit.value);
    }
    if (branchLimit.present) {
      map['branch_limit'] = Variable<int>(branchLimit.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubscriptionsCompanion(')
          ..write('shopId: $shopId, ')
          ..write('plan: $plan, ')
          ..write('activationDate: $activationDate, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('addOns: $addOns, ')
          ..write('isTrial: $isTrial, ')
          ..write('userLimit: $userLimit, ')
          ..write('branchLimit: $branchLimit, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
      'shop_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('main'));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTableMeta =
      const VerificationMeta('entityTable');
  @override
  late final GeneratedColumn<String> entityTable = GeneratedColumn<String>(
      'entity_table', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastAttemptAtMeta =
      const VerificationMeta('lastAttemptAt');
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>('last_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _attemptCountMeta =
      const VerificationMeta('attemptCount');
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
      'attempt_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        shopId,
        branchId,
        deviceId,
        userId,
        entityTable,
        recordId,
        operation,
        payloadJson,
        updatedAt,
        createdAt,
        lastAttemptAt,
        attemptCount,
        lastError
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(Insertable<SyncOutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(_shopIdMeta,
          shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta));
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('entity_table')) {
      context.handle(
          _entityTableMeta,
          entityTable.isAcceptableOrUnknown(
              data['entity_table']!, _entityTableMeta));
    } else if (isInserting) {
      context.missing(_entityTableMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
          _lastAttemptAtMeta,
          lastAttemptAt.isAcceptableOrUnknown(
              data['last_attempt_at']!, _lastAttemptAtMeta));
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
          _attemptCountMeta,
          attemptCount.isAcceptableOrUnknown(
              data['attempt_count']!, _attemptCountMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      shopId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shop_id'])!,
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      entityTable: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_table'])!,
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_attempt_at']),
      attemptCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempt_count'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  final String id;
  final String shopId;
  final String branchId;
  final String deviceId;
  final String userId;
  final String entityTable;
  final String recordId;
  final String operation;
  final String? payloadJson;
  final DateTime updatedAt;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final int attemptCount;
  final String? lastError;
  const SyncOutboxData(
      {required this.id,
      required this.shopId,
      required this.branchId,
      required this.deviceId,
      required this.userId,
      required this.entityTable,
      required this.recordId,
      required this.operation,
      this.payloadJson,
      required this.updatedAt,
      required this.createdAt,
      this.lastAttemptAt,
      required this.attemptCount,
      this.lastError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['shop_id'] = Variable<String>(shopId);
    map['branch_id'] = Variable<String>(branchId);
    map['device_id'] = Variable<String>(deviceId);
    map['user_id'] = Variable<String>(userId);
    map['entity_table'] = Variable<String>(entityTable);
    map['record_id'] = Variable<String>(recordId);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      id: Value(id),
      shopId: Value(shopId),
      branchId: Value(branchId),
      deviceId: Value(deviceId),
      userId: Value(userId),
      entityTable: Value(entityTable),
      recordId: Value(recordId),
      operation: Value(operation),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncOutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      id: serializer.fromJson<String>(json['id']),
      shopId: serializer.fromJson<String>(json['shopId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      userId: serializer.fromJson<String>(json['userId']),
      entityTable: serializer.fromJson<String>(json['entityTable']),
      recordId: serializer.fromJson<String>(json['recordId']),
      operation: serializer.fromJson<String>(json['operation']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'shopId': serializer.toJson<String>(shopId),
      'branchId': serializer.toJson<String>(branchId),
      'deviceId': serializer.toJson<String>(deviceId),
      'userId': serializer.toJson<String>(userId),
      'entityTable': serializer.toJson<String>(entityTable),
      'recordId': serializer.toJson<String>(recordId),
      'operation': serializer.toJson<String>(operation),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncOutboxData copyWith(
          {String? id,
          String? shopId,
          String? branchId,
          String? deviceId,
          String? userId,
          String? entityTable,
          String? recordId,
          String? operation,
          Value<String?> payloadJson = const Value.absent(),
          DateTime? updatedAt,
          DateTime? createdAt,
          Value<DateTime?> lastAttemptAt = const Value.absent(),
          int? attemptCount,
          Value<String?> lastError = const Value.absent()}) =>
      SyncOutboxData(
        id: id ?? this.id,
        shopId: shopId ?? this.shopId,
        branchId: branchId ?? this.branchId,
        deviceId: deviceId ?? this.deviceId,
        userId: userId ?? this.userId,
        entityTable: entityTable ?? this.entityTable,
        recordId: recordId ?? this.recordId,
        operation: operation ?? this.operation,
        payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
        updatedAt: updatedAt ?? this.updatedAt,
        createdAt: createdAt ?? this.createdAt,
        lastAttemptAt:
            lastAttemptAt.present ? lastAttemptAt.value : this.lastAttemptAt,
        attemptCount: attemptCount ?? this.attemptCount,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      id: data.id.present ? data.id.value : this.id,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      userId: data.userId.present ? data.userId.value : this.userId,
      entityTable:
          data.entityTable.present ? data.entityTable.value : this.entityTable,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('branchId: $branchId, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('entityTable: $entityTable, ')
          ..write('recordId: $recordId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      shopId,
      branchId,
      deviceId,
      userId,
      entityTable,
      recordId,
      operation,
      payloadJson,
      updatedAt,
      createdAt,
      lastAttemptAt,
      attemptCount,
      lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.id == this.id &&
          other.shopId == this.shopId &&
          other.branchId == this.branchId &&
          other.deviceId == this.deviceId &&
          other.userId == this.userId &&
          other.entityTable == this.entityTable &&
          other.recordId == this.recordId &&
          other.operation == this.operation &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<String> id;
  final Value<String> shopId;
  final Value<String> branchId;
  final Value<String> deviceId;
  final Value<String> userId;
  final Value<String> entityTable;
  final Value<String> recordId;
  final Value<String> operation;
  final Value<String?> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.userId = const Value.absent(),
    this.entityTable = const Value.absent(),
    this.recordId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String id,
    required String shopId,
    this.branchId = const Value.absent(),
    required String deviceId,
    required String userId,
    required String entityTable,
    required String recordId,
    required String operation,
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        shopId = Value(shopId),
        deviceId = Value(deviceId),
        userId = Value(userId),
        entityTable = Value(entityTable),
        recordId = Value(recordId),
        operation = Value(operation);
  static Insertable<SyncOutboxData> custom({
    Expression<String>? id,
    Expression<String>? shopId,
    Expression<String>? branchId,
    Expression<String>? deviceId,
    Expression<String>? userId,
    Expression<String>? entityTable,
    Expression<String>? recordId,
    Expression<String>? operation,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (branchId != null) 'branch_id': branchId,
      if (deviceId != null) 'device_id': deviceId,
      if (userId != null) 'user_id': userId,
      if (entityTable != null) 'entity_table': entityTable,
      if (recordId != null) 'record_id': recordId,
      if (operation != null) 'operation': operation,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith(
      {Value<String>? id,
      Value<String>? shopId,
      Value<String>? branchId,
      Value<String>? deviceId,
      Value<String>? userId,
      Value<String>? entityTable,
      Value<String>? recordId,
      Value<String>? operation,
      Value<String?>? payloadJson,
      Value<DateTime>? updatedAt,
      Value<DateTime>? createdAt,
      Value<DateTime?>? lastAttemptAt,
      Value<int>? attemptCount,
      Value<String?>? lastError,
      Value<int>? rowid}) {
    return SyncOutboxCompanion(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      branchId: branchId ?? this.branchId,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      entityTable: entityTable ?? this.entityTable,
      recordId: recordId ?? this.recordId,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (entityTable.present) {
      map['entity_table'] = Variable<String>(entityTable.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('branchId: $branchId, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('entityTable: $entityTable, ')
          ..write('recordId: $recordId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $ProductStocksTable productStocks = $ProductStocksTable(this);
  late final $SalesTable sales = $SalesTable(this);
  late final $SuppliersTable suppliers = $SuppliersTable(this);
  late final $PurchasesTable purchases = $PurchasesTable(this);
  late final $BatchesTable batches = $BatchesTable(this);
  late final $AuditLogsTable auditLogs = $AuditLogsTable(this);
  late final $UsersTable users = $UsersTable(this);
  late final $BranchesTable branches = $BranchesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $NotificationsTable notifications = $NotificationsTable(this);
  late final $SubscriptionsTable subscriptions = $SubscriptionsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final ProductsDao productsDao = ProductsDao(this as AppDatabase);
  late final ProductStocksDao productStocksDao =
      ProductStocksDao(this as AppDatabase);
  late final SalesDao salesDao = SalesDao(this as AppDatabase);
  late final DebtsDao debtsDao = DebtsDao(this as AppDatabase);
  late final UsersDao usersDao = UsersDao(this as AppDatabase);
  late final MovementsDao movementsDao = MovementsDao(this as AppDatabase);
  late final NotificationsDao notificationsDao =
      NotificationsDao(this as AppDatabase);
  late final SyncOutboxDao syncOutboxDao = SyncOutboxDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        products,
        productStocks,
        sales,
        suppliers,
        purchases,
        batches,
        auditLogs,
        users,
        branches,
        appSettings,
        notifications,
        subscriptions,
        syncOutbox
      ];
}

typedef $$ProductsTableCreateCompanionBuilder = ProductsCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  required String id,
  required String shopId,
  required String branchId,
  required String name,
  Value<String> barcode,
  required double quantity,
  required double buyingPrice,
  required double sellingPrice,
  Value<int> lowStockThreshold,
  Value<DateTime?> expiryDate,
  Value<String?> batchNumber,
  Value<String?> imageUrl,
  Value<int> rowid,
});
typedef $$ProductsTableUpdateCompanionBuilder = ProductsCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  Value<String> id,
  Value<String> shopId,
  Value<String> branchId,
  Value<String> name,
  Value<String> barcode,
  Value<double> quantity,
  Value<double> buyingPrice,
  Value<double> sellingPrice,
  Value<int> lowStockThreshold,
  Value<DateTime?> expiryDate,
  Value<String?> batchNumber,
  Value<String?> imageUrl,
  Value<int> rowid,
});

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get buyingPrice => $composableBuilder(
      column: $table.buyingPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get sellingPrice => $composableBuilder(
      column: $table.sellingPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lowStockThreshold => $composableBuilder(
      column: $table.lowStockThreshold,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get buyingPrice => $composableBuilder(
      column: $table.buyingPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get sellingPrice => $composableBuilder(
      column: $table.sellingPrice,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lowStockThreshold => $composableBuilder(
      column: $table.lowStockThreshold,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get buyingPrice => $composableBuilder(
      column: $table.buyingPrice, builder: (column) => column);

  GeneratedColumn<double> get sellingPrice => $composableBuilder(
      column: $table.sellingPrice, builder: (column) => column);

  GeneratedColumn<int> get lowStockThreshold => $composableBuilder(
      column: $table.lowStockThreshold, builder: (column) => column);

  GeneratedColumn<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => column);

  GeneratedColumn<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);
}

class $$ProductsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProductsTable,
    Product,
    $$ProductsTableFilterComposer,
    $$ProductsTableOrderingComposer,
    $$ProductsTableAnnotationComposer,
    $$ProductsTableCreateCompanionBuilder,
    $$ProductsTableUpdateCompanionBuilder,
    (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
    Product,
    PrefetchHooks Function()> {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> shopId = const Value.absent(),
            Value<String> branchId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> barcode = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<double> buyingPrice = const Value.absent(),
            Value<double> sellingPrice = const Value.absent(),
            Value<int> lowStockThreshold = const Value.absent(),
            Value<DateTime?> expiryDate = const Value.absent(),
            Value<String?> batchNumber = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProductsCompanion(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            branchId: branchId,
            name: name,
            barcode: barcode,
            quantity: quantity,
            buyingPrice: buyingPrice,
            sellingPrice: sellingPrice,
            lowStockThreshold: lowStockThreshold,
            expiryDate: expiryDate,
            batchNumber: batchNumber,
            imageUrl: imageUrl,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            required String id,
            required String shopId,
            required String branchId,
            required String name,
            Value<String> barcode = const Value.absent(),
            required double quantity,
            required double buyingPrice,
            required double sellingPrice,
            Value<int> lowStockThreshold = const Value.absent(),
            Value<DateTime?> expiryDate = const Value.absent(),
            Value<String?> batchNumber = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProductsCompanion.insert(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            branchId: branchId,
            name: name,
            barcode: barcode,
            quantity: quantity,
            buyingPrice: buyingPrice,
            sellingPrice: sellingPrice,
            lowStockThreshold: lowStockThreshold,
            expiryDate: expiryDate,
            batchNumber: batchNumber,
            imageUrl: imageUrl,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProductsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProductsTable,
    Product,
    $$ProductsTableFilterComposer,
    $$ProductsTableOrderingComposer,
    $$ProductsTableAnnotationComposer,
    $$ProductsTableCreateCompanionBuilder,
    $$ProductsTableUpdateCompanionBuilder,
    (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
    Product,
    PrefetchHooks Function()>;
typedef $$ProductStocksTableCreateCompanionBuilder = ProductStocksCompanion
    Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  required String shopId,
  required String productId,
  required String branchId,
  Value<double> quantity,
  Value<int> rowid,
});
typedef $$ProductStocksTableUpdateCompanionBuilder = ProductStocksCompanion
    Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  Value<String> shopId,
  Value<String> productId,
  Value<String> branchId,
  Value<double> quantity,
  Value<int> rowid,
});

class $$ProductStocksTableFilterComposer
    extends Composer<_$AppDatabase, $ProductStocksTable> {
  $$ProductStocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));
}

class $$ProductStocksTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductStocksTable> {
  $$ProductStocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));
}

class $$ProductStocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductStocksTable> {
  $$ProductStocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);
}

class $$ProductStocksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProductStocksTable,
    ProductStock,
    $$ProductStocksTableFilterComposer,
    $$ProductStocksTableOrderingComposer,
    $$ProductStocksTableAnnotationComposer,
    $$ProductStocksTableCreateCompanionBuilder,
    $$ProductStocksTableUpdateCompanionBuilder,
    (
      ProductStock,
      BaseReferences<_$AppDatabase, $ProductStocksTable, ProductStock>
    ),
    ProductStock,
    PrefetchHooks Function()> {
  $$ProductStocksTableTableManager(_$AppDatabase db, $ProductStocksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductStocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductStocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductStocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> shopId = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<String> branchId = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProductStocksCompanion(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            shopId: shopId,
            productId: productId,
            branchId: branchId,
            quantity: quantity,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            required String shopId,
            required String productId,
            required String branchId,
            Value<double> quantity = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProductStocksCompanion.insert(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            shopId: shopId,
            productId: productId,
            branchId: branchId,
            quantity: quantity,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProductStocksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProductStocksTable,
    ProductStock,
    $$ProductStocksTableFilterComposer,
    $$ProductStocksTableOrderingComposer,
    $$ProductStocksTableAnnotationComposer,
    $$ProductStocksTableCreateCompanionBuilder,
    $$ProductStocksTableUpdateCompanionBuilder,
    (
      ProductStock,
      BaseReferences<_$AppDatabase, $ProductStocksTable, ProductStock>
    ),
    ProductStock,
    PrefetchHooks Function()>;
typedef $$SalesTableCreateCompanionBuilder = SalesCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  required String id,
  required String shopId,
  required String branchId,
  required String itemId,
  required String itemName,
  required double quantity,
  required double totalPrice,
  required double profit,
  required String userId,
  required String username,
  required DateTime timestamp,
  Value<String?> customerName,
  Value<bool> isDebt,
  Value<double> amountPaid,
  Value<double> debtRemaining,
  Value<String?> saleGroupId,
  Value<double> refundedQuantity,
  Value<String?> batchId,
  Value<int> rowid,
});
typedef $$SalesTableUpdateCompanionBuilder = SalesCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  Value<String> id,
  Value<String> shopId,
  Value<String> branchId,
  Value<String> itemId,
  Value<String> itemName,
  Value<double> quantity,
  Value<double> totalPrice,
  Value<double> profit,
  Value<String> userId,
  Value<String> username,
  Value<DateTime> timestamp,
  Value<String?> customerName,
  Value<bool> isDebt,
  Value<double> amountPaid,
  Value<double> debtRemaining,
  Value<String?> saleGroupId,
  Value<double> refundedQuantity,
  Value<String?> batchId,
  Value<int> rowid,
});

class $$SalesTableFilterComposer extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemName => $composableBuilder(
      column: $table.itemName, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalPrice => $composableBuilder(
      column: $table.totalPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get profit => $composableBuilder(
      column: $table.profit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDebt => $composableBuilder(
      column: $table.isDebt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountPaid => $composableBuilder(
      column: $table.amountPaid, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get debtRemaining => $composableBuilder(
      column: $table.debtRemaining, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get saleGroupId => $composableBuilder(
      column: $table.saleGroupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get refundedQuantity => $composableBuilder(
      column: $table.refundedQuantity,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get batchId => $composableBuilder(
      column: $table.batchId, builder: (column) => ColumnFilters(column));
}

class $$SalesTableOrderingComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemName => $composableBuilder(
      column: $table.itemName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalPrice => $composableBuilder(
      column: $table.totalPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get profit => $composableBuilder(
      column: $table.profit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerName => $composableBuilder(
      column: $table.customerName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDebt => $composableBuilder(
      column: $table.isDebt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountPaid => $composableBuilder(
      column: $table.amountPaid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get debtRemaining => $composableBuilder(
      column: $table.debtRemaining,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get saleGroupId => $composableBuilder(
      column: $table.saleGroupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get refundedQuantity => $composableBuilder(
      column: $table.refundedQuantity,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get batchId => $composableBuilder(
      column: $table.batchId, builder: (column) => ColumnOrderings(column));
}

class $$SalesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get itemName =>
      $composableBuilder(column: $table.itemName, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get totalPrice => $composableBuilder(
      column: $table.totalPrice, builder: (column) => column);

  GeneratedColumn<double> get profit =>
      $composableBuilder(column: $table.profit, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => column);

  GeneratedColumn<bool> get isDebt =>
      $composableBuilder(column: $table.isDebt, builder: (column) => column);

  GeneratedColumn<double> get amountPaid => $composableBuilder(
      column: $table.amountPaid, builder: (column) => column);

  GeneratedColumn<double> get debtRemaining => $composableBuilder(
      column: $table.debtRemaining, builder: (column) => column);

  GeneratedColumn<String> get saleGroupId => $composableBuilder(
      column: $table.saleGroupId, builder: (column) => column);

  GeneratedColumn<double> get refundedQuantity => $composableBuilder(
      column: $table.refundedQuantity, builder: (column) => column);

  GeneratedColumn<String> get batchId =>
      $composableBuilder(column: $table.batchId, builder: (column) => column);
}

class $$SalesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SalesTable,
    Sale,
    $$SalesTableFilterComposer,
    $$SalesTableOrderingComposer,
    $$SalesTableAnnotationComposer,
    $$SalesTableCreateCompanionBuilder,
    $$SalesTableUpdateCompanionBuilder,
    (Sale, BaseReferences<_$AppDatabase, $SalesTable, Sale>),
    Sale,
    PrefetchHooks Function()> {
  $$SalesTableTableManager(_$AppDatabase db, $SalesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> shopId = const Value.absent(),
            Value<String> branchId = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<String> itemName = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<double> totalPrice = const Value.absent(),
            Value<double> profit = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> username = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String?> customerName = const Value.absent(),
            Value<bool> isDebt = const Value.absent(),
            Value<double> amountPaid = const Value.absent(),
            Value<double> debtRemaining = const Value.absent(),
            Value<String?> saleGroupId = const Value.absent(),
            Value<double> refundedQuantity = const Value.absent(),
            Value<String?> batchId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SalesCompanion(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            branchId: branchId,
            itemId: itemId,
            itemName: itemName,
            quantity: quantity,
            totalPrice: totalPrice,
            profit: profit,
            userId: userId,
            username: username,
            timestamp: timestamp,
            customerName: customerName,
            isDebt: isDebt,
            amountPaid: amountPaid,
            debtRemaining: debtRemaining,
            saleGroupId: saleGroupId,
            refundedQuantity: refundedQuantity,
            batchId: batchId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            required String id,
            required String shopId,
            required String branchId,
            required String itemId,
            required String itemName,
            required double quantity,
            required double totalPrice,
            required double profit,
            required String userId,
            required String username,
            required DateTime timestamp,
            Value<String?> customerName = const Value.absent(),
            Value<bool> isDebt = const Value.absent(),
            Value<double> amountPaid = const Value.absent(),
            Value<double> debtRemaining = const Value.absent(),
            Value<String?> saleGroupId = const Value.absent(),
            Value<double> refundedQuantity = const Value.absent(),
            Value<String?> batchId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SalesCompanion.insert(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            branchId: branchId,
            itemId: itemId,
            itemName: itemName,
            quantity: quantity,
            totalPrice: totalPrice,
            profit: profit,
            userId: userId,
            username: username,
            timestamp: timestamp,
            customerName: customerName,
            isDebt: isDebt,
            amountPaid: amountPaid,
            debtRemaining: debtRemaining,
            saleGroupId: saleGroupId,
            refundedQuantity: refundedQuantity,
            batchId: batchId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SalesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SalesTable,
    Sale,
    $$SalesTableFilterComposer,
    $$SalesTableOrderingComposer,
    $$SalesTableAnnotationComposer,
    $$SalesTableCreateCompanionBuilder,
    $$SalesTableUpdateCompanionBuilder,
    (Sale, BaseReferences<_$AppDatabase, $SalesTable, Sale>),
    Sale,
    PrefetchHooks Function()>;
typedef $$SuppliersTableCreateCompanionBuilder = SuppliersCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  required String id,
  required String shopId,
  required String name,
  Value<String?> contact,
  Value<String?> address,
  Value<double> totalTaken,
  Value<double> totalPaid,
  Value<double> remaining,
  Value<int> rowid,
});
typedef $$SuppliersTableUpdateCompanionBuilder = SuppliersCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  Value<String> id,
  Value<String> shopId,
  Value<String> name,
  Value<String?> contact,
  Value<String?> address,
  Value<double> totalTaken,
  Value<double> totalPaid,
  Value<double> remaining,
  Value<int> rowid,
});

class $$SuppliersTableFilterComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contact => $composableBuilder(
      column: $table.contact, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalTaken => $composableBuilder(
      column: $table.totalTaken, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalPaid => $composableBuilder(
      column: $table.totalPaid, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get remaining => $composableBuilder(
      column: $table.remaining, builder: (column) => ColumnFilters(column));
}

class $$SuppliersTableOrderingComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contact => $composableBuilder(
      column: $table.contact, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalTaken => $composableBuilder(
      column: $table.totalTaken, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalPaid => $composableBuilder(
      column: $table.totalPaid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get remaining => $composableBuilder(
      column: $table.remaining, builder: (column) => ColumnOrderings(column));
}

class $$SuppliersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get contact =>
      $composableBuilder(column: $table.contact, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<double> get totalTaken => $composableBuilder(
      column: $table.totalTaken, builder: (column) => column);

  GeneratedColumn<double> get totalPaid =>
      $composableBuilder(column: $table.totalPaid, builder: (column) => column);

  GeneratedColumn<double> get remaining =>
      $composableBuilder(column: $table.remaining, builder: (column) => column);
}

class $$SuppliersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SuppliersTable,
    Supplier,
    $$SuppliersTableFilterComposer,
    $$SuppliersTableOrderingComposer,
    $$SuppliersTableAnnotationComposer,
    $$SuppliersTableCreateCompanionBuilder,
    $$SuppliersTableUpdateCompanionBuilder,
    (Supplier, BaseReferences<_$AppDatabase, $SuppliersTable, Supplier>),
    Supplier,
    PrefetchHooks Function()> {
  $$SuppliersTableTableManager(_$AppDatabase db, $SuppliersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SuppliersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SuppliersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SuppliersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> shopId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> contact = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<double> totalTaken = const Value.absent(),
            Value<double> totalPaid = const Value.absent(),
            Value<double> remaining = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SuppliersCompanion(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            name: name,
            contact: contact,
            address: address,
            totalTaken: totalTaken,
            totalPaid: totalPaid,
            remaining: remaining,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            required String id,
            required String shopId,
            required String name,
            Value<String?> contact = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<double> totalTaken = const Value.absent(),
            Value<double> totalPaid = const Value.absent(),
            Value<double> remaining = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SuppliersCompanion.insert(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            name: name,
            contact: contact,
            address: address,
            totalTaken: totalTaken,
            totalPaid: totalPaid,
            remaining: remaining,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SuppliersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SuppliersTable,
    Supplier,
    $$SuppliersTableFilterComposer,
    $$SuppliersTableOrderingComposer,
    $$SuppliersTableAnnotationComposer,
    $$SuppliersTableCreateCompanionBuilder,
    $$SuppliersTableUpdateCompanionBuilder,
    (Supplier, BaseReferences<_$AppDatabase, $SuppliersTable, Supplier>),
    Supplier,
    PrefetchHooks Function()>;
typedef $$PurchasesTableCreateCompanionBuilder = PurchasesCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  required String id,
  required String shopId,
  required String itemId,
  required String itemName,
  Value<String> barcode,
  required double quantity,
  required double unitCost,
  required double totalCost,
  Value<String?> supplierName,
  Value<String?> batchNumber,
  Value<DateTime?> expiryDate,
  required DateTime timestamp,
  Value<String> branchId,
  Value<int> rowid,
});
typedef $$PurchasesTableUpdateCompanionBuilder = PurchasesCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  Value<String> id,
  Value<String> shopId,
  Value<String> itemId,
  Value<String> itemName,
  Value<String> barcode,
  Value<double> quantity,
  Value<double> unitCost,
  Value<double> totalCost,
  Value<String?> supplierName,
  Value<String?> batchNumber,
  Value<DateTime?> expiryDate,
  Value<DateTime> timestamp,
  Value<String> branchId,
  Value<int> rowid,
});

class $$PurchasesTableFilterComposer
    extends Composer<_$AppDatabase, $PurchasesTable> {
  $$PurchasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemName => $composableBuilder(
      column: $table.itemName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get unitCost => $composableBuilder(
      column: $table.unitCost, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalCost => $composableBuilder(
      column: $table.totalCost, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get supplierName => $composableBuilder(
      column: $table.supplierName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));
}

class $$PurchasesTableOrderingComposer
    extends Composer<_$AppDatabase, $PurchasesTable> {
  $$PurchasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemName => $composableBuilder(
      column: $table.itemName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get unitCost => $composableBuilder(
      column: $table.unitCost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalCost => $composableBuilder(
      column: $table.totalCost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get supplierName => $composableBuilder(
      column: $table.supplierName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));
}

class $$PurchasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PurchasesTable> {
  $$PurchasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get itemName =>
      $composableBuilder(column: $table.itemName, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get unitCost =>
      $composableBuilder(column: $table.unitCost, builder: (column) => column);

  GeneratedColumn<double> get totalCost =>
      $composableBuilder(column: $table.totalCost, builder: (column) => column);

  GeneratedColumn<String> get supplierName => $composableBuilder(
      column: $table.supplierName, builder: (column) => column);

  GeneratedColumn<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);
}

class $$PurchasesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PurchasesTable,
    Purchase,
    $$PurchasesTableFilterComposer,
    $$PurchasesTableOrderingComposer,
    $$PurchasesTableAnnotationComposer,
    $$PurchasesTableCreateCompanionBuilder,
    $$PurchasesTableUpdateCompanionBuilder,
    (Purchase, BaseReferences<_$AppDatabase, $PurchasesTable, Purchase>),
    Purchase,
    PrefetchHooks Function()> {
  $$PurchasesTableTableManager(_$AppDatabase db, $PurchasesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PurchasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PurchasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PurchasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> shopId = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<String> itemName = const Value.absent(),
            Value<String> barcode = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<double> unitCost = const Value.absent(),
            Value<double> totalCost = const Value.absent(),
            Value<String?> supplierName = const Value.absent(),
            Value<String?> batchNumber = const Value.absent(),
            Value<DateTime?> expiryDate = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String> branchId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchasesCompanion(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            itemId: itemId,
            itemName: itemName,
            barcode: barcode,
            quantity: quantity,
            unitCost: unitCost,
            totalCost: totalCost,
            supplierName: supplierName,
            batchNumber: batchNumber,
            expiryDate: expiryDate,
            timestamp: timestamp,
            branchId: branchId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            required String id,
            required String shopId,
            required String itemId,
            required String itemName,
            Value<String> barcode = const Value.absent(),
            required double quantity,
            required double unitCost,
            required double totalCost,
            Value<String?> supplierName = const Value.absent(),
            Value<String?> batchNumber = const Value.absent(),
            Value<DateTime?> expiryDate = const Value.absent(),
            required DateTime timestamp,
            Value<String> branchId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchasesCompanion.insert(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            itemId: itemId,
            itemName: itemName,
            barcode: barcode,
            quantity: quantity,
            unitCost: unitCost,
            totalCost: totalCost,
            supplierName: supplierName,
            batchNumber: batchNumber,
            expiryDate: expiryDate,
            timestamp: timestamp,
            branchId: branchId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PurchasesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PurchasesTable,
    Purchase,
    $$PurchasesTableFilterComposer,
    $$PurchasesTableOrderingComposer,
    $$PurchasesTableAnnotationComposer,
    $$PurchasesTableCreateCompanionBuilder,
    $$PurchasesTableUpdateCompanionBuilder,
    (Purchase, BaseReferences<_$AppDatabase, $PurchasesTable, Purchase>),
    Purchase,
    PrefetchHooks Function()>;
typedef $$BatchesTableCreateCompanionBuilder = BatchesCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  required String id,
  required String shopId,
  required String itemId,
  required double quantity,
  required double buyingPrice,
  Value<double?> sellingPrice,
  Value<DateTime?> expiryDate,
  Value<String?> batchNumber,
  required DateTime timestamp,
  Value<String> branchId,
  Value<String?> type,
  Value<int> rowid,
});
typedef $$BatchesTableUpdateCompanionBuilder = BatchesCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  Value<String> id,
  Value<String> shopId,
  Value<String> itemId,
  Value<double> quantity,
  Value<double> buyingPrice,
  Value<double?> sellingPrice,
  Value<DateTime?> expiryDate,
  Value<String?> batchNumber,
  Value<DateTime> timestamp,
  Value<String> branchId,
  Value<String?> type,
  Value<int> rowid,
});

class $$BatchesTableFilterComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get buyingPrice => $composableBuilder(
      column: $table.buyingPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get sellingPrice => $composableBuilder(
      column: $table.sellingPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));
}

class $$BatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get buyingPrice => $composableBuilder(
      column: $table.buyingPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get sellingPrice => $composableBuilder(
      column: $table.sellingPrice,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));
}

class $$BatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get buyingPrice => $composableBuilder(
      column: $table.buyingPrice, builder: (column) => column);

  GeneratedColumn<double> get sellingPrice => $composableBuilder(
      column: $table.sellingPrice, builder: (column) => column);

  GeneratedColumn<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => column);

  GeneratedColumn<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);
}

class $$BatchesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BatchesTable,
    Batche,
    $$BatchesTableFilterComposer,
    $$BatchesTableOrderingComposer,
    $$BatchesTableAnnotationComposer,
    $$BatchesTableCreateCompanionBuilder,
    $$BatchesTableUpdateCompanionBuilder,
    (Batche, BaseReferences<_$AppDatabase, $BatchesTable, Batche>),
    Batche,
    PrefetchHooks Function()> {
  $$BatchesTableTableManager(_$AppDatabase db, $BatchesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> shopId = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<double> buyingPrice = const Value.absent(),
            Value<double?> sellingPrice = const Value.absent(),
            Value<DateTime?> expiryDate = const Value.absent(),
            Value<String?> batchNumber = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String> branchId = const Value.absent(),
            Value<String?> type = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BatchesCompanion(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            itemId: itemId,
            quantity: quantity,
            buyingPrice: buyingPrice,
            sellingPrice: sellingPrice,
            expiryDate: expiryDate,
            batchNumber: batchNumber,
            timestamp: timestamp,
            branchId: branchId,
            type: type,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            required String id,
            required String shopId,
            required String itemId,
            required double quantity,
            required double buyingPrice,
            Value<double?> sellingPrice = const Value.absent(),
            Value<DateTime?> expiryDate = const Value.absent(),
            Value<String?> batchNumber = const Value.absent(),
            required DateTime timestamp,
            Value<String> branchId = const Value.absent(),
            Value<String?> type = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BatchesCompanion.insert(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            itemId: itemId,
            quantity: quantity,
            buyingPrice: buyingPrice,
            sellingPrice: sellingPrice,
            expiryDate: expiryDate,
            batchNumber: batchNumber,
            timestamp: timestamp,
            branchId: branchId,
            type: type,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BatchesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BatchesTable,
    Batche,
    $$BatchesTableFilterComposer,
    $$BatchesTableOrderingComposer,
    $$BatchesTableAnnotationComposer,
    $$BatchesTableCreateCompanionBuilder,
    $$BatchesTableUpdateCompanionBuilder,
    (Batche, BaseReferences<_$AppDatabase, $BatchesTable, Batche>),
    Batche,
    PrefetchHooks Function()>;
typedef $$AuditLogsTableCreateCompanionBuilder = AuditLogsCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  required String id,
  required String shopId,
  required String username,
  required String action,
  required String details,
  required DateTime timestamp,
  Value<String> branchId,
  Value<int> rowid,
});
typedef $$AuditLogsTableUpdateCompanionBuilder = AuditLogsCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  Value<String> id,
  Value<String> shopId,
  Value<String> username,
  Value<String> action,
  Value<String> details,
  Value<DateTime> timestamp,
  Value<String> branchId,
  Value<int> rowid,
});

class $$AuditLogsTableFilterComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get details => $composableBuilder(
      column: $table.details, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));
}

class $$AuditLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get details => $composableBuilder(
      column: $table.details, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));
}

class $$AuditLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);
}

class $$AuditLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AuditLogsTable,
    AuditLog,
    $$AuditLogsTableFilterComposer,
    $$AuditLogsTableOrderingComposer,
    $$AuditLogsTableAnnotationComposer,
    $$AuditLogsTableCreateCompanionBuilder,
    $$AuditLogsTableUpdateCompanionBuilder,
    (AuditLog, BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog>),
    AuditLog,
    PrefetchHooks Function()> {
  $$AuditLogsTableTableManager(_$AppDatabase db, $AuditLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> shopId = const Value.absent(),
            Value<String> username = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<String> details = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String> branchId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AuditLogsCompanion(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            username: username,
            action: action,
            details: details,
            timestamp: timestamp,
            branchId: branchId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            required String id,
            required String shopId,
            required String username,
            required String action,
            required String details,
            required DateTime timestamp,
            Value<String> branchId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AuditLogsCompanion.insert(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            username: username,
            action: action,
            details: details,
            timestamp: timestamp,
            branchId: branchId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AuditLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AuditLogsTable,
    AuditLog,
    $$AuditLogsTableFilterComposer,
    $$AuditLogsTableOrderingComposer,
    $$AuditLogsTableAnnotationComposer,
    $$AuditLogsTableCreateCompanionBuilder,
    $$AuditLogsTableUpdateCompanionBuilder,
    (AuditLog, BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog>),
    AuditLog,
    PrefetchHooks Function()>;
typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  required String uid,
  required String email,
  required String roles,
  required String shopId,
  required String username,
  Value<String?> branchId,
  Value<String?> branchName,
  Value<String?> permissions,
  Value<String?> passwordHash,
  Value<bool> isActive,
  Value<String> fullName,
  Value<String> currency,
  Value<int> rowid,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<String> uid,
  Value<String> email,
  Value<String> roles,
  Value<String> shopId,
  Value<String> username,
  Value<String?> branchId,
  Value<String?> branchName,
  Value<String?> permissions,
  Value<String?> passwordHash,
  Value<bool> isActive,
  Value<String> fullName,
  Value<String> currency,
  Value<int> rowid,
});

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get roles => $composableBuilder(
      column: $table.roles, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchName => $composableBuilder(
      column: $table.branchName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get permissions => $composableBuilder(
      column: $table.permissions, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fullName => $composableBuilder(
      column: $table.fullName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get roles => $composableBuilder(
      column: $table.roles, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchName => $composableBuilder(
      column: $table.branchName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get permissions => $composableBuilder(
      column: $table.permissions, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fullName => $composableBuilder(
      column: $table.fullName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get roles =>
      $composableBuilder(column: $table.roles, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get branchName => $composableBuilder(
      column: $table.branchName, builder: (column) => column);

  GeneratedColumn<String> get permissions => $composableBuilder(
      column: $table.permissions, builder: (column) => column);

  GeneratedColumn<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);
}

class $$UsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
    User,
    PrefetchHooks Function()> {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> uid = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<String> roles = const Value.absent(),
            Value<String> shopId = const Value.absent(),
            Value<String> username = const Value.absent(),
            Value<String?> branchId = const Value.absent(),
            Value<String?> branchName = const Value.absent(),
            Value<String?> permissions = const Value.absent(),
            Value<String?> passwordHash = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> fullName = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion(
            uid: uid,
            email: email,
            roles: roles,
            shopId: shopId,
            username: username,
            branchId: branchId,
            branchName: branchName,
            permissions: permissions,
            passwordHash: passwordHash,
            isActive: isActive,
            fullName: fullName,
            currency: currency,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String uid,
            required String email,
            required String roles,
            required String shopId,
            required String username,
            Value<String?> branchId = const Value.absent(),
            Value<String?> branchName = const Value.absent(),
            Value<String?> permissions = const Value.absent(),
            Value<String?> passwordHash = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> fullName = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion.insert(
            uid: uid,
            email: email,
            roles: roles,
            shopId: shopId,
            username: username,
            branchId: branchId,
            branchName: branchName,
            permissions: permissions,
            passwordHash: passwordHash,
            isActive: isActive,
            fullName: fullName,
            currency: currency,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UsersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
    User,
    PrefetchHooks Function()>;
typedef $$BranchesTableCreateCompanionBuilder = BranchesCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  required String id,
  required String shopId,
  required String name,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$BranchesTableUpdateCompanionBuilder = BranchesCompanion Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  Value<String> id,
  Value<String> shopId,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$BranchesTableFilterComposer
    extends Composer<_$AppDatabase, $BranchesTable> {
  $$BranchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$BranchesTableOrderingComposer
    extends Composer<_$AppDatabase, $BranchesTable> {
  $$BranchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$BranchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BranchesTable> {
  $$BranchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BranchesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BranchesTable,
    Branche,
    $$BranchesTableFilterComposer,
    $$BranchesTableOrderingComposer,
    $$BranchesTableAnnotationComposer,
    $$BranchesTableCreateCompanionBuilder,
    $$BranchesTableUpdateCompanionBuilder,
    (Branche, BaseReferences<_$AppDatabase, $BranchesTable, Branche>),
    Branche,
    PrefetchHooks Function()> {
  $$BranchesTableTableManager(_$AppDatabase db, $BranchesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BranchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BranchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BranchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> shopId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BranchesCompanion(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            name: name,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            required String id,
            required String shopId,
            required String name,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              BranchesCompanion.insert(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            name: name,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BranchesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BranchesTable,
    Branche,
    $$BranchesTableFilterComposer,
    $$BranchesTableOrderingComposer,
    $$BranchesTableAnnotationComposer,
    $$BranchesTableCreateCompanionBuilder,
    $$BranchesTableUpdateCompanionBuilder,
    (Branche, BaseReferences<_$AppDatabase, $BranchesTable, Branche>),
    Branche,
    PrefetchHooks Function()>;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()>;
typedef $$NotificationsTableCreateCompanionBuilder = NotificationsCompanion
    Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  required String id,
  required String shopId,
  required String title,
  required String body,
  required String type,
  Value<String> priority,
  Value<String?> relatedEntityId,
  Value<String?> createdBy,
  Value<String?> targetRole,
  Value<String?> itemId,
  Value<String?> branchId,
  Value<bool> isRead,
  Value<DateTime> timestamp,
  Value<String?> route,
  Value<String?> payloadJson,
  Value<int> rowid,
});
typedef $$NotificationsTableUpdateCompanionBuilder = NotificationsCompanion
    Function({
  Value<String> syncStatus,
  Value<DateTime> lastModified,
  Value<String?> remoteId,
  Value<int> version,
  Value<String> id,
  Value<String> shopId,
  Value<String> title,
  Value<String> body,
  Value<String> type,
  Value<String> priority,
  Value<String?> relatedEntityId,
  Value<String?> createdBy,
  Value<String?> targetRole,
  Value<String?> itemId,
  Value<String?> branchId,
  Value<bool> isRead,
  Value<DateTime> timestamp,
  Value<String?> route,
  Value<String?> payloadJson,
  Value<int> rowid,
});

class $$NotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationsTable> {
  $$NotificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get relatedEntityId => $composableBuilder(
      column: $table.relatedEntityId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetRole => $composableBuilder(
      column: $table.targetRole, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get route => $composableBuilder(
      column: $table.route, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));
}

class $$NotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationsTable> {
  $$NotificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get relatedEntityId => $composableBuilder(
      column: $table.relatedEntityId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetRole => $composableBuilder(
      column: $table.targetRole, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get route => $composableBuilder(
      column: $table.route, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));
}

class $$NotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationsTable> {
  $$NotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get relatedEntityId => $composableBuilder(
      column: $table.relatedEntityId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get targetRole => $composableBuilder(
      column: $table.targetRole, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get route =>
      $composableBuilder(column: $table.route, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);
}

class $$NotificationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotificationsTable,
    Notification,
    $$NotificationsTableFilterComposer,
    $$NotificationsTableOrderingComposer,
    $$NotificationsTableAnnotationComposer,
    $$NotificationsTableCreateCompanionBuilder,
    $$NotificationsTableUpdateCompanionBuilder,
    (
      Notification,
      BaseReferences<_$AppDatabase, $NotificationsTable, Notification>
    ),
    Notification,
    PrefetchHooks Function()> {
  $$NotificationsTableTableManager(_$AppDatabase db, $NotificationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> shopId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> priority = const Value.absent(),
            Value<String?> relatedEntityId = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            Value<String?> targetRole = const Value.absent(),
            Value<String?> itemId = const Value.absent(),
            Value<String?> branchId = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String?> route = const Value.absent(),
            Value<String?> payloadJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NotificationsCompanion(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            title: title,
            body: body,
            type: type,
            priority: priority,
            relatedEntityId: relatedEntityId,
            createdBy: createdBy,
            targetRole: targetRole,
            itemId: itemId,
            branchId: branchId,
            isRead: isRead,
            timestamp: timestamp,
            route: route,
            payloadJson: payloadJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> version = const Value.absent(),
            required String id,
            required String shopId,
            required String title,
            required String body,
            required String type,
            Value<String> priority = const Value.absent(),
            Value<String?> relatedEntityId = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            Value<String?> targetRole = const Value.absent(),
            Value<String?> itemId = const Value.absent(),
            Value<String?> branchId = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String?> route = const Value.absent(),
            Value<String?> payloadJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NotificationsCompanion.insert(
            syncStatus: syncStatus,
            lastModified: lastModified,
            remoteId: remoteId,
            version: version,
            id: id,
            shopId: shopId,
            title: title,
            body: body,
            type: type,
            priority: priority,
            relatedEntityId: relatedEntityId,
            createdBy: createdBy,
            targetRole: targetRole,
            itemId: itemId,
            branchId: branchId,
            isRead: isRead,
            timestamp: timestamp,
            route: route,
            payloadJson: payloadJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NotificationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NotificationsTable,
    Notification,
    $$NotificationsTableFilterComposer,
    $$NotificationsTableOrderingComposer,
    $$NotificationsTableAnnotationComposer,
    $$NotificationsTableCreateCompanionBuilder,
    $$NotificationsTableUpdateCompanionBuilder,
    (
      Notification,
      BaseReferences<_$AppDatabase, $NotificationsTable, Notification>
    ),
    Notification,
    PrefetchHooks Function()>;
typedef $$SubscriptionsTableCreateCompanionBuilder = SubscriptionsCompanion
    Function({
  required String shopId,
  required String plan,
  required DateTime activationDate,
  required DateTime expiryDate,
  Value<String?> addOns,
  Value<bool> isTrial,
  Value<int> userLimit,
  Value<int> branchLimit,
  Value<int> rowid,
});
typedef $$SubscriptionsTableUpdateCompanionBuilder = SubscriptionsCompanion
    Function({
  Value<String> shopId,
  Value<String> plan,
  Value<DateTime> activationDate,
  Value<DateTime> expiryDate,
  Value<String?> addOns,
  Value<bool> isTrial,
  Value<int> userLimit,
  Value<int> branchLimit,
  Value<int> rowid,
});

class $$SubscriptionsTableFilterComposer
    extends Composer<_$AppDatabase, $SubscriptionsTable> {
  $$SubscriptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plan => $composableBuilder(
      column: $table.plan, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get activationDate => $composableBuilder(
      column: $table.activationDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get addOns => $composableBuilder(
      column: $table.addOns, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isTrial => $composableBuilder(
      column: $table.isTrial, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get userLimit => $composableBuilder(
      column: $table.userLimit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get branchLimit => $composableBuilder(
      column: $table.branchLimit, builder: (column) => ColumnFilters(column));
}

class $$SubscriptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubscriptionsTable> {
  $$SubscriptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plan => $composableBuilder(
      column: $table.plan, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get activationDate => $composableBuilder(
      column: $table.activationDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get addOns => $composableBuilder(
      column: $table.addOns, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isTrial => $composableBuilder(
      column: $table.isTrial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get userLimit => $composableBuilder(
      column: $table.userLimit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get branchLimit => $composableBuilder(
      column: $table.branchLimit, builder: (column) => ColumnOrderings(column));
}

class $$SubscriptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubscriptionsTable> {
  $$SubscriptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get plan =>
      $composableBuilder(column: $table.plan, builder: (column) => column);

  GeneratedColumn<DateTime> get activationDate => $composableBuilder(
      column: $table.activationDate, builder: (column) => column);

  GeneratedColumn<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => column);

  GeneratedColumn<String> get addOns =>
      $composableBuilder(column: $table.addOns, builder: (column) => column);

  GeneratedColumn<bool> get isTrial =>
      $composableBuilder(column: $table.isTrial, builder: (column) => column);

  GeneratedColumn<int> get userLimit =>
      $composableBuilder(column: $table.userLimit, builder: (column) => column);

  GeneratedColumn<int> get branchLimit => $composableBuilder(
      column: $table.branchLimit, builder: (column) => column);
}

class $$SubscriptionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SubscriptionsTable,
    Subscription,
    $$SubscriptionsTableFilterComposer,
    $$SubscriptionsTableOrderingComposer,
    $$SubscriptionsTableAnnotationComposer,
    $$SubscriptionsTableCreateCompanionBuilder,
    $$SubscriptionsTableUpdateCompanionBuilder,
    (
      Subscription,
      BaseReferences<_$AppDatabase, $SubscriptionsTable, Subscription>
    ),
    Subscription,
    PrefetchHooks Function()> {
  $$SubscriptionsTableTableManager(_$AppDatabase db, $SubscriptionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubscriptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubscriptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubscriptionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> shopId = const Value.absent(),
            Value<String> plan = const Value.absent(),
            Value<DateTime> activationDate = const Value.absent(),
            Value<DateTime> expiryDate = const Value.absent(),
            Value<String?> addOns = const Value.absent(),
            Value<bool> isTrial = const Value.absent(),
            Value<int> userLimit = const Value.absent(),
            Value<int> branchLimit = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SubscriptionsCompanion(
            shopId: shopId,
            plan: plan,
            activationDate: activationDate,
            expiryDate: expiryDate,
            addOns: addOns,
            isTrial: isTrial,
            userLimit: userLimit,
            branchLimit: branchLimit,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String shopId,
            required String plan,
            required DateTime activationDate,
            required DateTime expiryDate,
            Value<String?> addOns = const Value.absent(),
            Value<bool> isTrial = const Value.absent(),
            Value<int> userLimit = const Value.absent(),
            Value<int> branchLimit = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SubscriptionsCompanion.insert(
            shopId: shopId,
            plan: plan,
            activationDate: activationDate,
            expiryDate: expiryDate,
            addOns: addOns,
            isTrial: isTrial,
            userLimit: userLimit,
            branchLimit: branchLimit,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SubscriptionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SubscriptionsTable,
    Subscription,
    $$SubscriptionsTableFilterComposer,
    $$SubscriptionsTableOrderingComposer,
    $$SubscriptionsTableAnnotationComposer,
    $$SubscriptionsTableCreateCompanionBuilder,
    $$SubscriptionsTableUpdateCompanionBuilder,
    (
      Subscription,
      BaseReferences<_$AppDatabase, $SubscriptionsTable, Subscription>
    ),
    Subscription,
    PrefetchHooks Function()>;
typedef $$SyncOutboxTableCreateCompanionBuilder = SyncOutboxCompanion Function({
  required String id,
  required String shopId,
  Value<String> branchId,
  required String deviceId,
  required String userId,
  required String entityTable,
  required String recordId,
  required String operation,
  Value<String?> payloadJson,
  Value<DateTime> updatedAt,
  Value<DateTime> createdAt,
  Value<DateTime?> lastAttemptAt,
  Value<int> attemptCount,
  Value<String?> lastError,
  Value<int> rowid,
});
typedef $$SyncOutboxTableUpdateCompanionBuilder = SyncOutboxCompanion Function({
  Value<String> id,
  Value<String> shopId,
  Value<String> branchId,
  Value<String> deviceId,
  Value<String> userId,
  Value<String> entityTable,
  Value<String> recordId,
  Value<String> operation,
  Value<String?> payloadJson,
  Value<DateTime> updatedAt,
  Value<DateTime> createdAt,
  Value<DateTime?> lastAttemptAt,
  Value<int> attemptCount,
  Value<String?> lastError,
  Value<int> rowid,
});

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityTable => $composableBuilder(
      column: $table.entityTable, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shopId => $composableBuilder(
      column: $table.shopId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityTable => $composableBuilder(
      column: $table.entityTable, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get entityTable => $composableBuilder(
      column: $table.entityTable, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncOutboxTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncOutboxTable,
    SyncOutboxData,
    $$SyncOutboxTableFilterComposer,
    $$SyncOutboxTableOrderingComposer,
    $$SyncOutboxTableAnnotationComposer,
    $$SyncOutboxTableCreateCompanionBuilder,
    $$SyncOutboxTableUpdateCompanionBuilder,
    (
      SyncOutboxData,
      BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>
    ),
    SyncOutboxData,
    PrefetchHooks Function()> {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> shopId = const Value.absent(),
            Value<String> branchId = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> entityTable = const Value.absent(),
            Value<String> recordId = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String?> payloadJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncOutboxCompanion(
            id: id,
            shopId: shopId,
            branchId: branchId,
            deviceId: deviceId,
            userId: userId,
            entityTable: entityTable,
            recordId: recordId,
            operation: operation,
            payloadJson: payloadJson,
            updatedAt: updatedAt,
            createdAt: createdAt,
            lastAttemptAt: lastAttemptAt,
            attemptCount: attemptCount,
            lastError: lastError,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String shopId,
            Value<String> branchId = const Value.absent(),
            required String deviceId,
            required String userId,
            required String entityTable,
            required String recordId,
            required String operation,
            Value<String?> payloadJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncOutboxCompanion.insert(
            id: id,
            shopId: shopId,
            branchId: branchId,
            deviceId: deviceId,
            userId: userId,
            entityTable: entityTable,
            recordId: recordId,
            operation: operation,
            payloadJson: payloadJson,
            updatedAt: updatedAt,
            createdAt: createdAt,
            lastAttemptAt: lastAttemptAt,
            attemptCount: attemptCount,
            lastError: lastError,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncOutboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncOutboxTable,
    SyncOutboxData,
    $$SyncOutboxTableFilterComposer,
    $$SyncOutboxTableOrderingComposer,
    $$SyncOutboxTableAnnotationComposer,
    $$SyncOutboxTableCreateCompanionBuilder,
    $$SyncOutboxTableUpdateCompanionBuilder,
    (
      SyncOutboxData,
      BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>
    ),
    SyncOutboxData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$ProductStocksTableTableManager get productStocks =>
      $$ProductStocksTableTableManager(_db, _db.productStocks);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db, _db.sales);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db, _db.suppliers);
  $$PurchasesTableTableManager get purchases =>
      $$PurchasesTableTableManager(_db, _db.purchases);
  $$BatchesTableTableManager get batches =>
      $$BatchesTableTableManager(_db, _db.batches);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db, _db.auditLogs);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$BranchesTableTableManager get branches =>
      $$BranchesTableTableManager(_db, _db.branches);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$NotificationsTableTableManager get notifications =>
      $$NotificationsTableTableManager(_db, _db.notifications);
  $$SubscriptionsTableTableManager get subscriptions =>
      $$SubscriptionsTableTableManager(_db, _db.subscriptions);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
}
