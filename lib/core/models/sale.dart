import 'package:cloud_firestore/cloud_firestore.dart';

class Sale {
  final String id;
  final String shopId;
  final String itemId;
  final String itemName;
  final int quantity;
  final double sellingPriceAtTime;
  final double buyingPriceAtTime;
  final double totalPrice;
  final DateTime date;
  final String? userId;

  Sale({
    required this.id,
    required this.shopId,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.sellingPriceAtTime,
    required this.buyingPriceAtTime,
    required this.totalPrice,
    required this.date,
    this.userId,
  });

  double get profitPerItem => sellingPriceAtTime - buyingPriceAtTime;
  double get totalProfit => profitPerItem * quantity;

  factory Sale.fromMap(Map<String, dynamic> map, String docId) {
    return Sale(
      id: docId,
      shopId: map['shopId'] ?? 'default_shop',
      itemId: map['itemId'] ?? map['medicineId'] ?? '',
      itemName: map['itemName'] ?? map['medicineName'] ?? '',
      quantity: map['quantity'] ?? 0,
      sellingPriceAtTime: (map['sellingPriceAtTime'] ?? 0.0).toDouble(),
      buyingPriceAtTime: (map['buyingPriceAtTime'] ?? 0.0).toDouble(),
      totalPrice: (map['totalPrice'] ?? 0.0).toDouble(),
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : (map['timestamp'] != null ? (map['timestamp'] as Timestamp).toDate() : DateTime.now()),
      userId: map['userId'] ?? map['staffId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'sellingPriceAtTime': sellingPriceAtTime,
      'buyingPriceAtTime': buyingPriceAtTime,
      'totalPrice': totalPrice,
      'date': FieldValue.serverTimestamp(),
      'userId': userId,
    };
  }
}
