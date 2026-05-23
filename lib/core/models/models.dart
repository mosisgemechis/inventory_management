import 'dart:convert';
import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 4)
enum UserRole { 
  @HiveField(0) admin, 
  @HiveField(1) coAdmin,
  @HiveField(2) manager,
  @HiveField(3) staff, 
  @HiveField(4) none 
}

@HiveType(typeId: 0)
class AppUser {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String email;
  @HiveField(2)
  final String username;
  final List<UserRole>? _roles;
  @HiveField(3)
  List<UserRole> get roles => _roles ?? [UserRole.staff];
  @HiveField(4)
  final String shopId;
  @HiveField(5)
  final String branchId;
  @HiveField(6)
  final String? branchName;

  @HiveField(7)
  final Map<String, bool>? permissions;

  @HiveField(8)
  final String? currency;
  @HiveField(9)
  final String? country;
  @HiveField(10)
  final bool isActive;
  @HiveField(11)
  final String fullName;

  AppUser({
    required this.id,
    required this.email,
    required this.username,
    required List<UserRole> roles,
    required this.shopId,
    this.branchId = 'main',
    this.branchName,
    this.permissions,
    this.currency = 'USD',
    this.country,
    this.isActive = true,
    this.fullName = '',
  }) : _roles = roles;

  UserRole get role => (roles.isNotEmpty) ? roles.first : UserRole.none;

  bool hasRole(UserRole r) => roles.contains(r);

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

    Map<String, bool>? perms;
    if (map['permissions'] != null) {
      if (map['permissions'] is String) {
        try {
          perms = Map<String, bool>.from(jsonDecode(map['permissions'] as String));
        } catch(_) {}
      } else if (map['permissions'] is Map) {
        perms = Map<String, bool>.from(map['permissions'] as Map);
      }
    }

    return AppUser(
      id: docId.toString(),
      email: map['email']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? map['username']?.toString() ?? '',
      roles: parsedRoles,
      shopId: map['shopId']?.toString() ?? 'default_shop',
      branchId: map['branchId']?.toString() ?? 'main',
      branchName: _sanitizeBranchName(map['branchName'] ?? 'Main Branch'),
      permissions: perms,
      currency: map['currency']?.toString() ?? 'USD',
      country: map['country']?.toString(),
      isActive: map['isActive'] == true || map['isActive'] == 1,
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
      'fullName': fullName,
      'roles': roles.map((r) => r.name).toList(),
      'shopId': shopId,
      'branchId': branchId,
      'branchName': branchName,
      'permissions': permissions,
      'currency': currency,
      'country': country,
      'isActive': isActive,
    };
  }

  /// Permission constants
  static const String pViewInventory = 'canViewInventory';
  static const String pAddProduct = 'canAddProduct';
  static const String pEditProduct = 'canEditProduct';
  static const String pDeleteProduct = 'canDeleteProduct';
  static const String pAdjustStock = 'canAdjustStock';
  static const String pViewBuyingPrice = 'canViewBuyingPrice';
  static const String pSetSellingPrice = 'canSetSellingPrice';
  static const String pEditSellingPrice = 'canEditSellingPrice';
  static const String pAccessPOS = 'canAccessPOS';
  static const String pAddPurchases = 'canAddPurchases';
  static const String pEditPurchases = 'canEditPurchases';
  static const String pViewReports = 'canViewReports';
  static const String pViewProfitReports = 'canViewProfitReports';
  static const String pExportReports = 'canExportReports';
  static const String pAddUsers = 'canAddUsers';
  static const String pEditUsers = 'canEditUsers';
  static const String pDisableUsers = 'canDisableUsers';
  static const String pManagePermissions = 'canManagePermissions';
  static const String pAccessSettings = 'canAccessSettings';
  static const String pBackupRestore = 'canBackupRestore';
  static const String pViewAdminDashboard = 'canViewAdminDashboard';

  static const allPermissions = [
    pViewInventory, pAddProduct, pEditProduct, pDeleteProduct, pAdjustStock,
    pViewBuyingPrice, pSetSellingPrice, pEditSellingPrice, pAccessPOS,
    pAddPurchases, pEditPurchases, pViewReports, pViewProfitReports,
    pExportReports, pAddUsers, pEditUsers, pDisableUsers, pManagePermissions,
    pAccessSettings, pBackupRestore, pViewAdminDashboard
  ];

  /// Permission Check with Role Fallback
  bool hasPermission(String permission) {
    // 1. Admins have absolute power
    if (roles.contains(UserRole.admin)) return true;

    // 2. Explicit Permission Override check (from Drift string/JSON)
    if (permissions != null && permissions!.containsKey(permission)) {
      return permissions![permission] == true;
    }
    
    // 3. Role-based Defaults (Fallbacks)
    final r = role;
    switch (permission) {
      case pAccessPOS:
      case pViewInventory:
        return true; // Staff/Managers can do these by default
      case pAddProduct:
      case pEditProduct:
      case pAdjustStock:
      case pAddPurchases:
        return r == UserRole.coAdmin || r == UserRole.manager;
      case pDeleteProduct:
      case pEditSellingPrice:
      case pViewBuyingPrice:
        return r == UserRole.coAdmin; // Restricted mostly to Co-Admin
      case pSetSellingPrice:
      case pViewReports:
      case pViewProfitReports:
      case pExportReports:
        return r == UserRole.coAdmin || r == UserRole.manager;
      case pAddUsers:
      case pEditUsers:
      case pDisableUsers:
      case pManagePermissions:
      case pAccessSettings:
      case pBackupRestore:
        return r == UserRole.coAdmin;
      case pViewAdminDashboard:
        return r == UserRole.coAdmin || r == UserRole.manager;
      default:
        return false;
    }
  }
}

@HiveType(typeId: 1)
class Product {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String shopId;
  @HiveField(2)
  final String branchId;
  @HiveField(3)
  final String name;
  @HiveField(4)
  final String barcode;
  @HiveField(5)
  final double quantity;
  @HiveField(6)
  final double buyingPrice;
  @HiveField(7)
  final double sellingPrice;
  @HiveField(8)
  final int lowStockThreshold;
  @HiveField(9)
  final DateTime? expiryDate;
  @HiveField(10)
  final String? batchNumber;
  @HiveField(11)
  final bool isBundle;
  @HiveField(12)
  final List<String>? bundleItems;
  @HiveField(13)
  final DateTime? lastUpdated;
  @HiveField(14)
  final String? imageUrl;

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
    this.imageUrl,
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
      expiryDate: parseDT(map['expiryDate']),
      batchNumber: map['batchNumber'],
      isBundle: map['isBundle'] ?? false,
      bundleItems: map['bundleItems'] != null ? List<String>.from(map['bundleItems']) : null,
      lastUpdated: parseDT(map['lastUpdated']),
      imageUrl: map['imageUrl'],
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
      'expiryDate': expiryDate?.toIso8601String(),
      'batchNumber': batchNumber,
      'isBundle': isBundle,
      'bundleItems': bundleItems,
      'lastUpdated': (lastUpdated ?? DateTime.now()).toIso8601String(),
      'imageUrl': imageUrl,
    };
  }
}

@HiveType(typeId: 2)
class Sale {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String shopId;
  @HiveField(2)
  final String branchId;
  @HiveField(3)
  final String itemId;
  @HiveField(4)
  final String itemName;
  @HiveField(5)
  final int quantity;
  @HiveField(6)
  final double totalPrice;
  @HiveField(7)
  final double profit;
  @HiveField(8)
  final String userId;
  @HiveField(9)
  final String username;
  @HiveField(10)
  final DateTime timestamp;
  @HiveField(11)
  final String? customerName;
  @HiveField(12)
  final bool isDebt;
  @HiveField(13)
  final double amountPaid;
  @HiveField(14)
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
      timestamp: parseDT(map['timestamp']) ?? DateTime.now(),
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
      'timestamp': timestamp.toIso8601String(),
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

@HiveType(typeId: 3)
class PurchaseRecord {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String shopId;
  @HiveField(2)
  final String? supplierId;
  @HiveField(3)
  final String itemId;
  @HiveField(4)
  final String itemName;
  @HiveField(5)
  final double quantity;
  @HiveField(6)
  final double unitCost;
  @HiveField(7)
  final double totalCost;
  @HiveField(8)
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
      timestamp: parseDT(map['timestamp']) ?? DateTime.now(),
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
      'timestamp': timestamp.toIso8601String(),
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
      timestamp: parseDT(map['timestamp']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'userId': userId,
      'username': username,
      'action': action,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
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
      timestamp: parseDT(map['timestamp']) ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'message': message,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }
}

@HiveType(typeId: 6)
class CartItem {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final double price;
  @HiveField(3)
  int quantity;
  @HiveField(4)
  final String? batchNumber;
  @HiveField(5)
  final double? cost;
  @HiveField(6)
  final String? branchId;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.batchNumber,
    this.cost,
    this.branchId,
  });

  double get total => price * quantity;
}

DateTime? parseDT(dynamic timestamp) {
  if (timestamp == null) return null;
  if (timestamp is String) return DateTime.tryParse(timestamp);
  if (timestamp is DateTime) return timestamp;
  if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
  return null;
}

