
class Reel {
  final String? id;
  final String productId;
  final String productName;
  final String qrCodeData;
  final String qrCodeImage; // Base64 string
  final int packingQuantity;
  final DateTime inwardDate;
  final String status; // 'available' or 'outward'
  final DateTime createdAt;

  Reel({
    this.id,
    required this.productId,
    required this.productName,
    required this.qrCodeData,
    required this.qrCodeImage,
    required this.packingQuantity,
    required this.inwardDate,
    this.status = 'available',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'qr_code_data': qrCodeData,
      'qr_code_image': qrCodeImage,
      'packing_quantity': packingQuantity,
      'inward_date': inwardDate.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Reel.fromMap(Map<String, dynamic> map) {
    return Reel(
      id: map['id']?.toString(),
      productId: map['product_id'],
      productName: map['product_name'],
      qrCodeData: map['qr_code_data'],
      qrCodeImage: map['qr_code_image'],
      packingQuantity: map['packing_quantity'],
      inwardDate: DateTime.parse(map['inward_date']),
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
