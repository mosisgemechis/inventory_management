import 'dart:convert';
import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 4)
enum UserRole { 
  @HiveField(0) admin, 
  @HiveField(1) manager,
  @HiveField(2) cashier,
  @HiveField(3) inventoryStaff,
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
  List<UserRole> get roles => _roles ?? [UserRole.inventoryStaff];
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
      if (r == null) return UserRole.inventoryStaff;
      final search = r.toString().toLowerCase().trim();
      try {
        return UserRole.values.firstWhere((e) => e.name == search);
      } catch(_) {
        if (search == 'coadmin') return UserRole.manager;
        if (search == 'staff') return UserRole.inventoryStaff;
        if (search == 'inventorystaff' || search == 'inventory_staff') return UserRole.inventoryStaff;
        return UserRole.inventoryStaff;
      }
    }).toList();
    
    if (parsedRoles.isEmpty) {
      parsedRoles = [UserRole.inventoryStaff];
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

  // --- Standardized Permissions (Requirement 2) ---
  static const String pManageInventory = 'Manage Inventory';
  static const String pManageSales = 'Manage Sales';
  static const String pManagePurchases = 'Manage Purchases';
  static const String pManageCustomers = 'Manage Customers';
  static const String pManageStockTransfers = 'Manage Stock Transfers';
  static const String pViewReports = 'View Reports';
  static const String pViewFinancialData = 'View Financial Data';
  static const String pManageUsers = 'Manage Users';
  static const String pManageSettings = 'Manage Settings';
  static const String pManageBilling = 'Manage Billing';
  static const String pManageBranches = 'Manage Branches';

  // Legacy mappings for backward compat
  static const String pViewInventory = 'canViewInventory';
  static const String pAddInventory = 'canAddInventory';
  static const String pEditInventory = 'canEditInventory';
  static const String pDeleteInventory = 'canDeleteInventory';
  static const String pRestockInventory = 'canRestockInventory';
  static const String pTransferStock = 'canTransferStock';
  static const String pViewPrices = 'canViewPrices';
  static const String pEditPrices = 'canEditPrices';
  static const String pApprovePrices = 'canApprovePriceChanges';
  static const String pCreateSales = 'canCreateSales';
  static const String pRefundSales = 'canRefundSales';
  static const String pDeleteSales = 'canDeleteSales';
  static const String pViewSalesHistory = 'canViewSalesHistory';
  static const String pCreatePurchase = 'canCreatePurchase';
  static const String pEditPurchase = 'canEditPurchase';
  static const String pDeletePurchase = 'canDeletePurchase';
  static const String pManageSuppliers = 'canManageSuppliers';
  static const String pViewPurchases = 'canViewPurchases';
  static const String pExportReports = 'canExportReports';
  static const String pViewProfit = 'canViewProfit';
  static const String pCreateUsers = 'canCreateUsers';
  static const String pEditUsers = 'canEditUsers';
  static const String pDeleteUsers = 'canDeleteUsers';
  static const String pAssignPermissions = 'canAssignPermissions';
  static const String pViewBranches = 'canViewBranches';
  static const String pSendNotifications = 'canSendNotifications';
  static const String pViewNotifications = 'View Notifications';
  static const String pViewAuditLogs = 'canViewAuditLogs';
  static const String pAddEditProducts = 'canEditInventory';
  static const String pAccessPOS = 'canCreateSales';
  static const String pSetSellingPrice = 'canEditPrices';
  static const String pSellProducts = 'canCreateSales';
  static const String pManageSubscription = 'canManageSettings';

  static const allPermissions = [
    pManageInventory,
    pManageSales,
    pManagePurchases,
    pManageCustomers,
    pManageStockTransfers,
    pViewReports,
    pViewFinancialData,
    pManageUsers,
    pManageSettings,
    pManageBilling,
    pManageBranches,
    pViewNotifications,
  ];

  static const Map<String, List<String>> permissionGroups = {
    'Core Permissions': [
      pManageInventory,
      pManageSales,
      pManagePurchases,
      pManageCustomers,
      pManageStockTransfers,
    ],
    'Reporting Permissions': [
      pViewReports,
      pViewFinancialData,
    ],
    'Administrative Permissions': [
      pManageUsers,
      pManageSettings,
      pManageBilling,
      pManageBranches,
      pViewNotifications,
    ],
  };

  /// Permission Check with Role Fallback
  bool hasPermission(String permission) {
    // 1. ADMINS have absolute power (Master Key)
    if (roles.contains(UserRole.admin)) return true;

    // Resolve legacy constants to their respective new permissions first:
    String resolved = permission;
    switch (permission) {
      case 'canViewInventory':
      case 'canAddInventory':
      case 'canEditInventory':
      case 'canDeleteInventory':
      case 'canRestockInventory':
      case 'canViewPrices':
      case 'canEditPrices':
      case 'canApprovePriceChanges':
        resolved = pManageInventory;
        break;

      case 'canCreateSales':
      case 'canRefundSales':
      case 'canDeleteSales':
      case 'canViewSalesHistory':
      case 'canAccessPOS':
      case 'canSellProducts':
        resolved = pManageSales;
        break;

      case 'canCreatePurchase':
      case 'canEditPurchase':
      case 'canDeletePurchase':
      case 'canManageSuppliers':
      case 'canViewPurchases':
      case 'canManagePurchases':
        resolved = pManagePurchases;
        break;

      case 'canTransferStock':
        resolved = pManageStockTransfers;
        break;

      case 'canViewReports':
      case 'canExportReports':
        resolved = pViewReports;
        break;
      
      case 'canViewProfit':
        resolved = pViewFinancialData;
        break;

      case 'canManageUsers':
      case 'canCreateUsers':
      case 'canEditUsers':
      case 'canDeleteUsers':
      case 'canAssignPermissions':
        resolved = pManageUsers;
        break;

      case 'canManageSettings':
      case 'canSendNotifications':
      case 'canViewNotifications':
      case 'canViewAuditLogs':
        resolved = pManageSettings;
        break;

      case 'canManageSubscription':
        resolved = pManageBilling;
        break;

      case 'canViewBranches':
      case 'canManageBranches':
        resolved = pManageBranches;
        break;
    }

    // 2. Explicit Permission Overrides (e.g. from JSON permissions map)
    if (permissions != null && permissions!.containsKey(resolved)) {
      return permissions![resolved] == true;
    }
    
    // 3. Role-based Defaults (Strategic Logic)
    final r = role;

    // MANAGER Logic: Inventory, Sales, Purchases, Reports, Financial Data, Transfers, Branches, Settings (except Billing/Users)
    if (r == UserRole.manager) {
       switch (resolved) {
         case pManageInventory:
         case pManageSales:
         case pManagePurchases:
         case pManageCustomers:
         case pManageStockTransfers:
         case pViewReports:
         case pViewFinancialData:
         case pManageSettings:
         case pManageBranches:
           return true;
         default:
           return false; 
       }
    }

    // CASHIER Logic: POS/Sales, Customer management (debt)
    if (r == UserRole.cashier) {
       switch (resolved) {
         case pManageSales:
         case pManageCustomers:
           return true;
         default:
           return false;
       }
    }

    // INVENTORY STAFF Logic: Basic Inventory, Stock Transfers
    if (r == UserRole.inventoryStaff) {
       switch (resolved) {
         case pManageInventory:
         case pManageStockTransfers:
           return true;
         default:
           return false;
       }
    }

    return false;
  }

  bool hasBranchAccess(String targetBranchId) {
    if (roles.contains(UserRole.admin)) return true;
    if (permissions != null && permissions!['branch_access_all'] == true) return true;
    if (targetBranchId == 'all') {
      return roles.contains(UserRole.admin) || (permissions != null && permissions!['branch_access_all'] == true);
    }
    if (permissions != null && permissions!['branch_access_$targetBranchId'] == true) return true;
    return branchId == targetBranchId;
  }

  List<String> getAssignedBranchIds(List<String> allShopBranchIds) {
    if (roles.contains(UserRole.admin) || (permissions != null && permissions!['branch_access_all'] == true)) {
      return ['all', ...allShopBranchIds];
    }
    final list = <String>[];
    for (final bid in allShopBranchIds) {
      if (permissions != null && permissions!['branch_access_$bid'] == true) {
        list.add(bid);
      }
    }
    if (!list.contains(branchId) && branchId.isNotEmpty) {
      list.add(branchId);
    }
    if (list.isEmpty) {
      list.add('main');
    }
    return list;
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
      expiryDate: parseDT(map['expiry'] ?? map['exp'] ?? map['expiryDate']),
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
  final String? route;
  final String? payloadJson;

  AppNotification({
    required this.id,
    required this.shopId,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.route,
    this.payloadJson,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String docId) {
    return AppNotification(
      id: docId,
      shopId: map['shopId'] ?? 'default_shop',
      message: map['message'] ?? '',
      type: map['type'] ?? 'staff',
      timestamp: parseDT(map['timestamp']) ?? DateTime.now(),
      isRead: map['isRead'] == true || map['isRead'] == 1,
      route: map['route']?.toString(),
      payloadJson: map['payloadJson']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'message': message,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'route': route,
      'payloadJson': payloadJson,
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
  if (timestamp is DateTime) return timestamp;
  DateTime? dt;
  if (timestamp is int) {
    if (timestamp < 10000000000) {
      dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    } else {
      dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
  } else if (timestamp is String && timestamp.isNotEmpty) {
    dt = DateTime.tryParse(timestamp);
    if (dt == null) {
      final numVal = int.tryParse(timestamp);
      if (numVal != null) {
        if (numVal < 10000000000) {
          dt = DateTime.fromMillisecondsSinceEpoch(numVal * 1000);
        } else {
          dt = DateTime.fromMillisecondsSinceEpoch(numVal);
        }
      }
    }
  }
  
  // Sanity check: If date is too far in future (e.g. 178001 bug), reject it.
  if (dt != null && (dt.year > 2100 || dt.year < 1980)) {
    return null;
  }
  return dt?.toLocal();
}

