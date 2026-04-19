import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, staff, cashier, manager, stockist, billing, none }

class AppUser {
  final String id;
  final String email;
  final String username;
  final List<UserRole>? _roles;
  List<UserRole> get roles => _roles ?? [UserRole.staff];
  final String shopId;
  final String branchId;
  final String? branchName;

  AppUser({
    required this.id,
    required this.email,
    required this.username,
    required List<UserRole> roles,
    required this.shopId,
    this.branchId = 'main',
    this.branchName,
  }) : _roles = roles;

  UserRole get role => (roles.isNotEmpty) ? roles.first : UserRole.none;

  factory AppUser.fromMap(Map<String, dynamic> map, String docId) {
    List<dynamic> rolesRaw = map['roles'] is List ? map['roles'] : [];
    if (rolesRaw.isEmpty && map['role'] != null) {
      rolesRaw = [map['role']];
    }
    
    List<UserRole> parsedRoles = rolesRaw.map((r) {
      if (r == null) return UserRole.staff;
      final search = r.toString().toLowerCase().trim();
      try {
        return UserRole.values.firstWhere((e) => e.name == search);
      } catch(_) {
        return UserRole.staff;
      }
    }).toList();
    
    if (parsedRoles.isEmpty) {
      parsedRoles = [UserRole.staff];
    }

    return AppUser(
      id: docId,
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      roles: parsedRoles,
      shopId: map['shopId'] ?? 'default_shop',
      branchId: map['branchId'] ?? 'main',
      branchName: _sanitizeBranchName(map['branchName']),
    );
  }

  static String? _sanitizeBranchName(dynamic val) {
    if (val == null) return null;
    String name = val.toString();
    if (name.contains('Text("')) return name.replaceAll('Text("', '').replaceAll('")', '');
    return name;
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'roles': roles.map((r) => r.name).toList(),
      'shopId': shopId,
      'branchId': branchId,
      'branchName': branchName,
    };
  }
}

class Product {
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
  final bool isBundle;
  final List<String>? bundleItems;
  final DateTime? lastUpdated;

  Product({
    required this.id,
    required this.shopId,
    required this.branchId,
    required this.name,
    this.barcode = '',
    required this.quantity,
    required this.buyingPrice,
    required this.sellingPrice,
    this.lowStockThreshold = 5,
    this.expiryDate,
    this.batchNumber,
    this.isBundle = false,
    this.bundleItems,
    this.lastUpdated,
  });

  factory Product.fromMap(Map<String, dynamic> map, String docId) {
    return Product(
      id: docId,
      shopId: map['shopId'] ?? 'default_shop',
      branchId: map['branchId'] ?? 'main',
      name: map['name'] ?? '',
      barcode: map['barcode'] ?? '',
      quantity: (map['quantity'] ?? 0.0).toDouble(),
      buyingPrice: (map['buyingPrice'] ?? 0.0).toDouble(),
      sellingPrice: (map['sellingPrice'] ?? 0.0).toDouble(),
      lowStockThreshold: map['lowStockThreshold'] ?? 5,
      expiryDate: map['expiryDate'] != null ? (map['expiryDate'] as Timestamp).toDate() : null,
      batchNumber: map['batchNumber'],
      isBundle: map['isBundle'] ?? false,
      bundleItems: map['bundleItems'] != null ? List<String>.from(map['bundleItems']) : null,
      lastUpdated: map['lastUpdated'] != null ? (map['lastUpdated'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'branchId': branchId,
      'name': name,
      'barcode': barcode,
      'quantity': quantity,
      'buyingPrice': buyingPrice,
      'sellingPrice': sellingPrice,
      'lowStockThreshold': lowStockThreshold,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'batchNumber': batchNumber,
      'isBundle': isBundle,
      'bundleItems': bundleItems,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : FieldValue.serverTimestamp(),
    };
  }
}

class Sale {
  final String id;
  final String shopId;
  final String branchId;
  final String itemId;
  final String itemName;
  final int quantity;
  final double totalPrice;
  final double profit;
  final String userId;
  final String username;
  final DateTime timestamp;
  final String? customerName;
  final bool isDebt;
  final double amountPaid;
  final double debtRemaining;

  Sale({
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
    this.isDebt = false,
    this.amountPaid = 0.0,
    this.debtRemaining = 0.0,
  });

  factory Sale.fromMap(Map<String, dynamic> map, String docId) {
    return Sale(
      id: docId,
      shopId: map['shopId'] ?? '',
      branchId: map['branchId'] ?? 'main',
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] ?? 0).toInt(),
      totalPrice: (map['totalPrice'] ?? 0.0).toDouble(),
      profit: (map['profit'] ?? 0.0).toDouble(),
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'User',
      timestamp: map['timestamp'] != null ? (map['timestamp'] as Timestamp).toDate() : DateTime.now(),
      customerName: map['customerName'] ?? map['buyerName'],
      isDebt: map['isDebt'] ?? false,
      amountPaid: (map['amountPaid'] ?? 0.0).toDouble(),
      debtRemaining: (map['debtRemaining'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'branchId': branchId,
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'profit': profit,
      'userId': userId,
      'username': username,
      'timestamp': Timestamp.fromDate(timestamp),
      'customerName': customerName,
      'isDebt': isDebt,
      'amountPaid': amountPaid,
      'debtRemaining': debtRemaining,
    };
  }
}

class Supplier {
  final String id;
  final String shopId;
  final String name;
  final String? contact;
  final String? address;
  final double totalTaken;
  final double totalPaid;
  final double remaining;

  Supplier({
    required this.id,
    required this.shopId,
    required this.name,
    this.contact,
    this.address,
    required this.totalTaken,
    required this.totalPaid,
    required this.remaining,
  });

  factory Supplier.fromMap(Map<String, dynamic> map, String docId) {
    return Supplier(
      id: docId,
      shopId: map['shopId'] ?? 'default_shop',
      name: map['name'] ?? '',
      contact: map['contact'],
      address: map['address'],
      totalTaken: (map['totalTaken'] ?? 0.0).toDouble(),
      totalPaid: (map['totalPaid'] ?? 0.0).toDouble(),
      remaining: (map['remaining'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'name': name,
      'contact': contact,
      'address': address,
      'totalTaken': totalTaken,
      'totalPaid': totalPaid,
      'remaining': remaining,
    };
  }
}

class PurchaseRecord {
  final String id;
  final String shopId;
  final String? supplierId;
  final String itemId;
  final String itemName;
  final double quantity;
  final double unitCost;
  final double totalCost;
  final DateTime timestamp;

  PurchaseRecord({
    required this.id,
    required this.shopId,
    this.supplierId,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
    required this.timestamp,
  });

  factory PurchaseRecord.fromMap(Map<String, dynamic> map, String docId) {
    return PurchaseRecord(
      id: docId,
      shopId: map['shopId'] ?? '',
      supplierId: map['supplierId'],
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] ?? 0.0).toDouble(),
      unitCost: (map['unitCost'] ?? 0.0).toDouble(),
      totalCost: (map['totalCost'] ?? 0.0).toDouble(),
      timestamp: map['timestamp'] != null ? (map['timestamp'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'supplierId': supplierId,
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'unitCost': unitCost,
      'totalCost': totalCost,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class AuditLog {
  final String id;
  final String shopId;
  final String userId;
  final String username;
  final String action;
  final String details;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.username,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map, String docId) {
    return AuditLog(
      id: docId,
      shopId: map['shopId'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      action: map['action'] ?? '',
      details: map['details'] ?? '',
      timestamp: map['timestamp'] != null ? (map['timestamp'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'userId': userId,
      'username': username,
      'action': action,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class AppNotification {
  final String id;
  final String shopId;
  final String message;
  final String type; // admin / staff / cashier / both
  final DateTime timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.shopId,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String docId) {
    return AppNotification(
      id: docId,
      shopId: map['shopId'] ?? 'default_shop',
      message: map['message'] ?? '',
      type: map['type'] ?? 'staff',
      timestamp: map['timestamp'] != null ? (map['timestamp'] as Timestamp).toDate() : DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'message': message,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }
}
