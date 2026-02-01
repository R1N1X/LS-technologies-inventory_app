
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/reel.dart';
import '../models/transaction_record.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  final _uuid = const Uuid();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'inventory_app.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products(
            id TEXT PRIMARY KEY,
            short_id TEXT,
            name TEXT UNIQUE,
            total_stock INTEGER,
            packing_quantity INTEGER,
            created_date TEXT,
            available_reels INTEGER,
            total_reels INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE reels(
            id TEXT PRIMARY KEY,
            product_id TEXT,
            product_name TEXT,
            qr_code_data TEXT,
            qr_code_image TEXT,
            packing_quantity INTEGER,
            inward_date TEXT,
            status TEXT,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE outward_records(
            id TEXT PRIMARY KEY,
            reel_id TEXT,
            product_id TEXT,
            product_name TEXT,
            invoice_number TEXT,
            quantity INTEGER,
            outward_date TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE inward_records(
            id TEXT PRIMARY KEY,
            product_id TEXT,
            quantity INTEGER,
            num_reels INTEGER,
            inward_date TEXT
          )
        ''');
      },
    );
  }

  // --- Product Operations ---

  // Generate a short 6-character alphanumeric ID
  String _generateShortId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String result = '';
    int seed = random;
    for (int i = 0; i < 6; i++) {
      result += chars[seed % chars.length];
      seed = seed ~/ chars.length + (i + 1) * 7;
    }
    return result;
  }

  Future<Map<String, dynamic>> createProduct(String name, int totalStock, int packingQuantity) async {
    final db = await database;
    try {
      // Check for duplicate product name
      final existing = await db.query('products', where: 'name = ?', whereArgs: [name]);
      if (existing.isNotEmpty) {
        return {"success": false, "message": "Product with name '$name' already exists"};
      }

      // Calculate number of reels
      int numReels = totalStock ~/ packingQuantity;
      if (totalStock % packingQuantity > 0) {
        numReels += 1;
      }

      final now = DateTime.now();
      final productId = _uuid.v4();
      final shortId = _generateShortId();

      final product = Product(
        id: productId,
        shortId: shortId,
        name: name,
        totalStock: totalStock,
        packingQuantity: packingQuantity,
        createdDate: now,
        availableReels: numReels,
        totalReels: numReels,
      );

      // Start transaction
      return await db.transaction((txn) async {
        await txn.insert('products', product.toMap());

        List<Reel> reels = [];
        List<String> qrCodes = [];

        for (int i = 0; i < numReels; i++) {
          int reelQuantity;
          if (i == numReels - 1) {
            int remaining = totalStock % packingQuantity;
            reelQuantity = remaining > 0 ? remaining : packingQuantity;
          } else {
            reelQuantity = packingQuantity;
          }

          // NEW SIMPLIFIED QR FORMAT: ShortID|ReelNumber
          String qrData = "$shortId|${i + 1}";
          String qrImage = ""; 

          final reel = Reel(
            id: _uuid.v4(),
            productId: productId,
            productName: name,
            qrCodeData: qrData,
            qrCodeImage: qrImage,
            packingQuantity: reelQuantity,
            inwardDate: now,
            status: 'available',
            createdAt: now,
          );

          await txn.insert('reels', reel.toMap());
          reels.add(reel);
          qrCodes.add(qrData);
        }

        return {
          "success": true,
          "product_id": productId,
          "short_id": shortId,
          "message": "Product created with $numReels reels",
          "reels": numReels,
          "qr_codes": qrCodes 
        };
      });
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<Product?> getProduct(String id) async {
    final db = await database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<Map<String, dynamic>> deleteProduct(String id) async {
     final db = await database;
     try {
       await db.delete('products', where: 'id = ?', whereArgs: [id]);
       await db.delete('reels', where: 'product_id = ?', whereArgs: [id]);
       await db.delete('outward_records', where: 'product_id = ?', whereArgs: [id]);
       await db.delete('inward_records', where: 'product_id = ?', whereArgs: [id]);
       return {"success": true, "message": "Product deleted"};
     } catch (e) {
       return {"success": false, "message": e.toString()};
     }
  }

  // --- Reel Operations ---

  Future<List<Reel>> getReelsByProductId(String productId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reels', 
      where: 'product_id = ?', 
      whereArgs: [productId]
    );
    return List.generate(maps.length, (i) => Reel.fromMap(maps[i]));
  }

  // --- Inward Operations ---

  Future<Map<String, dynamic>> addInwardStock(String productId, int additionalQuantity) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> productMaps = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (productMaps.isEmpty) {
        return {"success": false, "message": "Product not found"};
      }

      final product = Product.fromMap(productMaps.first);
      final int packingQuantity = product.packingQuantity;

      // Calculate new reels
      int numNewReels = additionalQuantity ~/ packingQuantity;
      if (additionalQuantity % packingQuantity > 0) {
        numNewReels += 1;
      }

      final now = DateTime.now();
      
      return await db.transaction((txn) async {
        List<String> qrCodes = [];
        
        // Add new reels
        for (int i = 0; i < numNewReels; i++) {
           int reelQuantity;
           if (i == numNewReels - 1) {
             int remaining = additionalQuantity % packingQuantity;
             reelQuantity = remaining > 0 ? remaining : packingQuantity;
           } else {
             reelQuantity = packingQuantity;
           }

           final dateFormat = DateFormat('yyyy-MM-dd');
           // NEW SIMPLIFIED QR FORMAT: ShortID|ReelNumber
           String qrData = "${product.shortId}|${product.totalReels + i + 1}";
           String qrImage = "";

           final reel = Reel(
             id: _uuid.v4(),
             productId: productId,
             productName: product.name,
             qrCodeData: qrData,
             qrCodeImage: qrImage,
             packingQuantity: reelQuantity,
             inwardDate: now,
             status: 'available',
             createdAt: now,
           );

           await txn.insert('reels', reel.toMap());
           qrCodes.add(qrData);
        }

        // Update Product
        await txn.update(
          'products',
          {
            'total_stock': product.totalStock + additionalQuantity,
            'available_reels': product.availableReels + numNewReels,
            'total_reels': product.totalReels + numNewReels,
          },
          where: 'id = ?',
          whereArgs: [productId],
        );

        // Record Inward
        final inwardRecord = InwardRecord(
          id: _uuid.v4(),
          productId: productId,
          quantity: additionalQuantity,
          numReels: numNewReels,
          inwardDate: now,
        );
        await txn.insert('inward_records', inwardRecord.toMap());

        return {
          "success": true,
          "message": "Added $numNewReels new reels for ${product.name}",
          "new_reels": numNewReels,
          "qr_codes": qrCodes
        };
      });

    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  Future<List<InwardRecord>> getInwardRecordsByProductId(String productId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inward_records',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'inward_date DESC'
    );
    return List.generate(maps.length, (i) => InwardRecord.fromMap(maps[i]));
  }

  // --- Outward Operations ---

  /// Validate a reel at scan time (for real-time feedback)
  Future<Map<String, dynamic>> validateReel(String qrCodeData) async {
    final db = await database;
    try {
      // Parse new format: ShortID|ReelNumber
      final parts = qrCodeData.split('|');
      if (parts.length != 2) {
        return {"valid": false, "message": "Invalid QR code format"};
      }

      String shortId = parts[0];
      int reelNum = int.tryParse(parts[1]) ?? 0;

      // Find product by shortId
      final productMaps = await db.query('products', where: 'short_id = ?', whereArgs: [shortId]);
      if (productMaps.isEmpty) {
        return {"valid": false, "message": "Product not found for this QR"};
      }

      final product = Product.fromMap(productMaps.first);

      // Find Reel by qr_code_data
      final reelMaps = await db.query(
        'reels',
        where: 'qr_code_data = ? AND status = ?',
        whereArgs: [qrCodeData, 'available'],
      );

      if (reelMaps.isEmpty) {
        return {"valid": false, "message": "Reel not found or already processed"};
      }

      final reel = Reel.fromMap(reelMaps.first);
      return {
        "valid": true,
        "product": product,
        "reel": reel,
        "reelNumber": reelNum,
      };
    } catch (e) {
      return {"valid": false, "message": e.toString()};
    }
  }

  Future<Map<String, dynamic>> processOutward(String qrCodeData, String invoiceNumber) async {
    final db = await database;
    try {
      // Parse new format: ShortID|ReelNumber
      final parts = qrCodeData.split('|');
      if (parts.length != 2) {
        return {"success": false, "message": "Invalid QR code format"};
      }

      String shortId = parts[0];

      // Find product by shortId
      final productMaps = await db.query('products', where: 'short_id = ?', whereArgs: [shortId]);
      if (productMaps.isEmpty) {
        return {"success": false, "message": "Product not found"};
      }
      final product = Product.fromMap(productMaps.first);

      // Find Reel
      final List<Map<String, dynamic>> reelMaps = await db.query(
        'reels',
        where: 'qr_code_data = ? AND status = ?',
        whereArgs: [qrCodeData, 'available'],
      );

      if (reelMaps.isEmpty) {
        return {"success": false, "message": "Reel not found or already processed"};
      }

      final reel = Reel.fromMap(reelMaps.first);

      return await db.transaction((txn) async {
        // Create Outward Record
        final outwardRecord = OutwardRecord(
          id: _uuid.v4(),
          reelId: reel.id!,
          productId: product.id!,
          productName: reel.productName,
          invoiceNumber: invoiceNumber,
          quantity: reel.packingQuantity,
          outwardDate: DateTime.now(),
        );

        await txn.insert('outward_records', outwardRecord.toMap());

        // Update Reel Status
        await txn.update(
          'reels',
          {'status': 'outward'},
          where: 'id = ?',
          whereArgs: [reel.id],
        );

        // Update Product Stats
        await txn.rawUpdate('''
          UPDATE products 
          SET available_reels = available_reels - 1 
          WHERE id = ?
        ''', [product.id]);

        return {
          "success": true,
          "message": "Outward processed for ${reel.productName}",
          "quantity": reel.packingQuantity,
          "invoice_number": invoiceNumber
        };
      });

    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  Future<List<OutwardRecord>> getOutwardRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'outward_records',
      orderBy: 'outward_date DESC'
    );
    return List.generate(maps.length, (i) => OutwardRecord.fromMap(maps[i]));
  }

  Future<List<OutwardRecord>> getOutwardRecordsByProductId(String productId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'outward_records',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'outward_date DESC'
    );
    return List.generate(maps.length, (i) => OutwardRecord.fromMap(maps[i]));
  }
}
