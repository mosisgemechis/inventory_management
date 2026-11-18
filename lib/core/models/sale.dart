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
      date: _parseDate(map['date'] ?? map['timestamp']),
      userId: map['userId'] ?? map['staffId'],
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ??
        DateTime.tryParse(value.toString().replaceFirst('Timestamp(', '').replaceAll(')', '')) ??
        DateTime.now();
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
      'date': date.toIso8601String(),
      'userId': userId,
    };
  }
}
