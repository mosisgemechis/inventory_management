import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final String id;
  final String shopId;
  final String name;
  final int quantity;
  final double buyingPrice;
  final double? sellingPrice;
  final int lowStockThreshold;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? addedBy;

  Item({
    required this.id,
    required this.shopId,
    required this.name,
    required this.quantity,
    required this.buyingPrice,
    this.sellingPrice,
    this.lowStockThreshold = 5,
    this.createdAt,
    this.updatedAt,
    this.addedBy,
  });

  bool get isPriceSet => sellingPrice != null && sellingPrice! > 0;
  bool get isLowStock => quantity <= lowStockThreshold && quantity > 0;
  bool get isOutOfStock => quantity <= 0;

  factory Item.fromMap(Map<String, dynamic> map, String docId) {
    return Item(
      id: docId,
      shopId: map['shopId'] ?? 'default_shop',
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      buyingPrice: (map['buyingPrice'] ?? 0.0).toDouble(),
      sellingPrice: map['sellingPrice'] != null ? (map['sellingPrice'] as num).toDouble() : null,
      lowStockThreshold: map['lowStockThreshold'] ?? 5,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
      addedBy: map['addedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'name': name,
      'quantity': quantity,
      'buyingPrice': buyingPrice,
      'sellingPrice': sellingPrice,
      'lowStockThreshold': lowStockThreshold,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'addedBy': addedBy,
    };
  }

  Item copyWith({
    String? name,
    int? quantity,
    double? buyingPrice,
    double? sellingPrice,
    int? lowStockThreshold,
    DateTime? updatedAt,
  }) {
    return Item(
      id: this.id,
      shopId: this.shopId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
