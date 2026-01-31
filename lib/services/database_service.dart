
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
            name TEXT,
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

  Future<Map<String, dynamic>> createProduct(String name, int totalStock, int packingQuantity) async {
    final db = await database;
    try {
      // Calculate number of reels
      int numReels = totalStock ~/ packingQuantity;
      if (totalStock % packingQuantity > 0) {
        numReels += 1;
      }

      final now = DateTime.now();
      final productId = _uuid.v4();

      final product = Product(
        id: productId,
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

          // Generate QR Data
          // Format: product_id|YYYY-MM-DD|quantity|reel_number
          final dateFormat = DateFormat('yyyy-MM-dd');
          String qrData = "$productId|${dateFormat.format(now)}|$reelQuantity|${i + 1}";
          
          // NOTE: In offline Flutter app, we will generate the QR Image/Widget on the UI side 
          // based on the qrData. Storing base64 image in SQLite is inefficient.
          // However, to keep model compatibility, we'll store specific indicator or empty string.
          // The UI should generate it.
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
          qrCodes.add(qrData); // Return data instead of image string for UI to render
        }

        return {
          "success": true,
          "product_id": productId,
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
           // Reel number logic: Existing total + i + 1
           String qrData = "$productId|${dateFormat.format(now)}|$reelQuantity|${product.totalReels + i + 1}";
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

  Future<Map<String, dynamic>> processOutward(String qrCodeData, String invoiceNumber) async {
    final db = await database;
    try {
      // Parse QR
      final parts = qrCodeData.split('|');
      if (parts.length != 4) {
        return {"success": false, "message": "Invalid QR code format"};
      }

      String productId = parts[0];
      String quantityStr = parts[2];
      int quantity = int.parse(quantityStr);

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
          productId: productId,
          productName: reel.productName,
          invoiceNumber: invoiceNumber,
          quantity: quantity,
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
        // We need to fetch the current product state first to stay consistent, 
        // OR we can just use raw SQL to decrement.
        // Raw SQL is safer for concurrency (though not a huge issue here locally)
        await txn.rawUpdate('''
          UPDATE products 
          SET available_reels = available_reels - 1 
          WHERE id = ?
        ''', [productId]);

        return {
          "success": true,
          "message": "Outward processed for ${reel.productName}",
          "quantity": quantity,
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
