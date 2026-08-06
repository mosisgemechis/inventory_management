// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppUserAdapter extends TypeAdapter<AppUser> {
  @override
  final int typeId = 0;

  @override
  AppUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppUser(
      id: fields[0] as String,
      email: fields[1] as String,
      username: fields[2] as String,
      roles: (fields[3] as List).cast<UserRole>(),
      shopId: fields[4] as String,
      branchId: fields[5] as String,
      branchName: fields[6] as String?,
      permissions: (fields[7] as Map?)?.cast<String, bool>(),
      currency: fields[8] as String?,
      country: fields[9] as String?,
      isActive: fields[10] as bool,
      fullName: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AppUser obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.username)
      ..writeByte(4)
      ..write(obj.shopId)
      ..writeByte(5)
      ..write(obj.branchId)
      ..writeByte(6)
      ..write(obj.branchName)
      ..writeByte(7)
      ..write(obj.permissions)
      ..writeByte(8)
      ..write(obj.currency)
      ..writeByte(9)
      ..write(obj.country)
      ..writeByte(10)
      ..write(obj.isActive)
      ..writeByte(11)
      ..write(obj.fullName)
      ..writeByte(3)
      ..write(obj.roles);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 1;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Product(
      id: fields[0] as String,
      shopId: fields[1] as String,
      branchId: fields[2] as String,
      name: fields[3] as String,
      barcode: fields[4] as String,
      quantity: fields[5] as double,
      buyingPrice: fields[6] as double,
      sellingPrice: fields[7] as double,
      lowStockThreshold: fields[8] as int,
      expiryDate: fields[9] as DateTime?,
      batchNumber: fields[10] as String?,
      isBundle: fields[11] as bool,
      bundleItems: (fields[12] as List?)?.cast<String>(),
      lastUpdated: fields[13] as DateTime?,
      imageUrl: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.shopId)
      ..writeByte(2)
      ..write(obj.branchId)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.barcode)
      ..writeByte(5)
      ..write(obj.quantity)
      ..writeByte(6)
      ..write(obj.buyingPrice)
      ..writeByte(7)
      ..write(obj.sellingPrice)
      ..writeByte(8)
      ..write(obj.lowStockThreshold)
      ..writeByte(9)
      ..write(obj.expiryDate)
      ..writeByte(10)
      ..write(obj.batchNumber)
      ..writeByte(11)
      ..write(obj.isBundle)
      ..writeByte(12)
      ..write(obj.bundleItems)
      ..writeByte(13)
      ..write(obj.lastUpdated)
      ..writeByte(14)
      ..write(obj.imageUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SaleAdapter extends TypeAdapter<Sale> {
  @override
  final int typeId = 2;

  @override
  Sale read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Sale(
      id: fields[0] as String,
      shopId: fields[1] as String,
      branchId: fields[2] as String,
      itemId: fields[3] as String,
      itemName: fields[4] as String,
      quantity: fields[5] as int,
      totalPrice: fields[6] as double,
      profit: fields[7] as double,
      userId: fields[8] as String,
      username: fields[9] as String,
      timestamp: fields[10] as DateTime,
      customerName: fields[11] as String?,
      isDebt: fields[12] as bool,
      amountPaid: fields[13] as double,
      debtRemaining: fields[14] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Sale obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.shopId)
      ..writeByte(2)
      ..write(obj.branchId)
      ..writeByte(3)
      ..write(obj.itemId)
      ..writeByte(4)
      ..write(obj.itemName)
      ..writeByte(5)
      ..write(obj.quantity)
      ..writeByte(6)
      ..write(obj.totalPrice)
      ..writeByte(7)
      ..write(obj.profit)
      ..writeByte(8)
      ..write(obj.userId)
      ..writeByte(9)
      ..write(obj.username)
      ..writeByte(10)
      ..write(obj.timestamp)
      ..writeByte(11)
      ..write(obj.customerName)
      ..writeByte(12)
      ..write(obj.isDebt)
      ..writeByte(13)
      ..write(obj.amountPaid)
      ..writeByte(14)
      ..write(obj.debtRemaining);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PurchaseRecordAdapter extends TypeAdapter<PurchaseRecord> {
  @override
  final int typeId = 3;

  @override
  PurchaseRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PurchaseRecord(
      id: fields[0] as String,
      shopId: fields[1] as String,
      supplierId: fields[2] as String?,
      itemId: fields[3] as String,
      itemName: fields[4] as String,
      quantity: fields[5] as double,
      unitCost: fields[6] as double,
      totalCost: fields[7] as double,
      timestamp: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PurchaseRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.shopId)
      ..writeByte(2)
      ..write(obj.supplierId)
      ..writeByte(3)
      ..write(obj.itemId)
      ..writeByte(4)
      ..write(obj.itemName)
      ..writeByte(5)
      ..write(obj.quantity)
      ..writeByte(6)
      ..write(obj.unitCost)
      ..writeByte(7)
      ..write(obj.totalCost)
      ..writeByte(8)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CartItemAdapter extends TypeAdapter<CartItem> {
  @override
  final int typeId = 6;

  @override
  CartItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CartItem(
      id: fields[0] as String,
      name: fields[1] as String,
      price: fields[2] as double,
      quantity: fields[3] as int,
      batchNumber: fields[4] as String?,
      cost: fields[5] as double?,
      branchId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CartItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.batchNumber)
      ..writeByte(5)
      ..write(obj.cost)
      ..writeByte(6)
      ..write(obj.branchId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserRoleAdapter extends TypeAdapter<UserRole> {
  @override
  final int typeId = 4;

  @override
  UserRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UserRole.admin;
      case 1:
        return UserRole.manager;
      case 2:
        return UserRole.cashier;
      case 3:
        return UserRole.inventoryStaff;
      case 4:
        return UserRole.none;
      default:
        return UserRole.admin;
    }
  }

  @override
  void write(BinaryWriter writer, UserRole obj) {
    switch (obj) {
      case UserRole.admin:
        writer.writeByte(0);
        break;
      case UserRole.manager:
        writer.writeByte(1);
        break;
      case UserRole.cashier:
        writer.writeByte(2);
        break;
      case UserRole.inventoryStaff:
        writer.writeByte(3);
        break;
      case UserRole.none:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
