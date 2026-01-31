
class OutwardRecord {
  final String? id;
  final String reelId;
  final String productId;
  final String productName;
  final String invoiceNumber;
  final int quantity;
  final DateTime outwardDate;

  OutwardRecord({
    this.id,
    required this.reelId,
    required this.productId,
    required this.productName,
    required this.invoiceNumber,
    required this.quantity,
    required this.outwardDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reel_id': reelId,
      'product_id': productId,
      'product_name': productName,
      'invoice_number': invoiceNumber,
      'quantity': quantity,
      'outward_date': outwardDate.toIso8601String(),
    };
  }

  factory OutwardRecord.fromMap(Map<String, dynamic> map) {
    return OutwardRecord(
      id: map['id']?.toString(),
      reelId: map['reel_id'],
      productId: map['product_id'],
      productName: map['product_name'],
      invoiceNumber: map['invoice_number'],
      quantity: map['quantity'],
      outwardDate: DateTime.parse(map['outward_date']),
    );
  }
}

class InwardRecord {
  final String? id;
  final String productId;
  final int quantity;
  final int numReels;
  final DateTime inwardDate;

  InwardRecord({
    this.id,
    required this.productId,
    required this.quantity,
    required this.numReels,
    required this.inwardDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'quantity': quantity,
      'num_reels': numReels,
      'inward_date': inwardDate.toIso8601String(),
    };
  }

  factory InwardRecord.fromMap(Map<String, dynamic> map) {
    return InwardRecord(
      id: map['id']?.toString(),
      productId: map['product_id'],
      quantity: map['quantity'],
      numReels: map['num_reels'],
      inwardDate: DateTime.parse(map['inward_date']),
    );
  }
}
