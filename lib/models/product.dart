
class Product {
  final String? id;
  final String shortId;  // 6-char alphanumeric for QR codes
  final String name;
  final int totalStock;
  final int packingQuantity;
  final DateTime createdDate;
  final int availableReels;
  final int totalReels;

  Product({
    this.id,
    required this.shortId,
    required this.name,
    required this.totalStock,
    required this.packingQuantity,
    required this.createdDate,
    this.availableReels = 0,
    this.totalReels = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'short_id': shortId,
      'name': name,
      'total_stock': totalStock,
      'packing_quantity': packingQuantity,
      'created_date': createdDate.toIso8601String(),
      'available_reels': availableReels,
      'total_reels': totalReels,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString(),
      shortId: map['short_id'] ?? '',
      name: map['name'],
      totalStock: map['total_stock'],
      packingQuantity: map['packing_quantity'],
      createdDate: DateTime.parse(map['created_date']),
      availableReels: map['available_reels'],
      totalReels: map['total_reels'],
    );
  }
}
