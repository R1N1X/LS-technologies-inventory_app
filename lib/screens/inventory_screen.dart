
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/reel.dart';
import '../models/transaction_record.dart';
import '../services/database_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _products = [];
  bool _loading = true;
  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _loading = true);
    try {
      final products = await _db.getProducts();
      // Sort by created date desc
      products.sort((a, b) => b.createdDate.compareTo(a.createdDate));
      if (mounted) {
        setState(() {
          _products = products;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}" and all its reels?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        final result = await _db.deleteProduct(product.id!);
        if (result['success']) {
          await _fetchProducts();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product deleted successfully')),
            );
          }
        }
      } catch (e) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
         }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _showProductDetails(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ProductDetailModal(product: product),
    );
  }

  Map<String, dynamic> _getStockStatus(Product product) {
    if (product.totalReels == 0) return {'text': 'No Stock', 'color': Colors.grey};
    
    final utilization = (product.totalReels - product.availableReels) / product.totalReels;
    
    if (product.availableReels == 0) {
      return {'text': 'Out of Stock', 'color': const Color(0xFFDC2626)};
    } else if (utilization > 0.75) {
       return {'text': 'Low Stock', 'color': const Color(0xFFF59E0B)};
    } else if (utilization > 0.50) {
       return {'text': 'Medium Stock', 'color': const Color(0xFF3B82F6)};
    } else {
       return {'text': 'Good Stock', 'color': const Color(0xFF10B981)};
    }
  }

  @override
  Widget build(BuildContext context) {
    final outOfStockCount = _products.where((p) => p.availableReels == 0).length;
    final lowStockCount = _products.where((p) {
      if (p.totalReels == 0) return false;
      final utilization = (p.totalReels - p.availableReels) / p.totalReels;
      return utilization > 0.75 && p.availableReels > 0;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Inventory Overview', 
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchProducts,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchProducts,
              child: _products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No inventory found',
                          style: GoogleFonts.inter(fontSize: 20, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/register').then((_) => _fetchProducts()),
                          icon: const Icon(Icons.add),
                          label: const Text('Register New Product'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary Card
                      // Summary Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              offset: const Offset(0, 2),
                              blurRadius: 3.84,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                '📊 Inventory Summary',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildSummaryItem(_products.length.toString(), 'Total Products', const Color(0xFF2563EB)),
                                  _buildSummaryItem(outOfStockCount.toString(), 'Out of Stock', const Color(0xFFDC2626)),
                                  _buildSummaryItem(lowStockCount.toString(), 'Low Stock', const Color(0xFFF59E0B)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Product List
                      ..._products.map((product) {
                        final status = _getStockStatus(product);
                        final utilization = product.totalReels > 0 
                            ? ((product.totalReels - product.availableReels) / product.totalReels * 100)
                            : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                offset: const Offset(0, 2),
                                blurRadius: 3.84,
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () => _showProductDetails(product),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          product.name,
                                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (status['color'] as Color).withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          status['text'],
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _deleteProduct(product),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFDC2626)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildStatItem('Total Stock', '${product.totalStock} pcs', null),
                                      _buildStatItem('Per Reel', '${product.packingQuantity} pcs', null),
                                      _buildStatItem('Available', '${product.availableReels}/${product.totalReels}', status['color']),
                                      _buildStatItem('Utilized', '${utilization.toStringAsFixed(0)}%', status['color']),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Progress Bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: utilization / 100,
                                      backgroundColor: const Color(0xFFE5E7EB),
                                      color: status['color'],
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Created: ${DateFormat('MM/dd/yyyy').format(product.createdDate)}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                      ),
                                      Row(
                                        children: const [
                                          Text('Tap for details', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                          Icon(Icons.chevron_right, size: 14, color: Color(0xFF9CA3AF)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      
                       const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            '✅ All data stored offline',
                            style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
            ),
    );
  }

  Widget _buildSummaryItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color? color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        const SizedBox(height: 2),
        Text(
          value, 
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.bold, 
            color: color ?? const Color(0xFF1F2937)
          )
        ),
      ],
    );
  }
}

class ProductDetailModal extends StatefulWidget {
  final Product product;
  const ProductDetailModal({super.key, required this.product});

  @override
  State<ProductDetailModal> createState() => _ProductDetailModalState();
}

class _ProductDetailModalState extends State<ProductDetailModal> {
  bool _loading = true;
  List<Reel> _reels = [];
  List<OutwardRecord> _outwardHistory = [];
  List<InwardRecord> _inwardHistory = [];

  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _loading = true);
    try {
      final reels = await _db.getReelsByProductId(widget.product.id!);
      final outHistory = await _db.getOutwardRecordsByProductId(widget.product.id!);
      final inHistory = await _db.getInwardRecordsByProductId(widget.product.id!);
      
      if (mounted) {
        setState(() {
          _reels = reels;
          _outwardHistory = outHistory;
          _inwardHistory = inHistory;
        });
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
       initialChildSize: 0.9,
       minChildSize: 0.5,
       maxChildSize: 0.95,
       expand: false,
       builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
             child: Scaffold(
               backgroundColor: const Color(0xFFF8FAFC),
               appBar: AppBar(
                 title: Text(widget.product.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                 automaticallyImplyLeading: false,
                 actions: [
                   IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                 ],
               ),
               body: _loading 
                   ? const Center(child: CircularProgressIndicator())
                   : ListView(
                       controller: scrollController,
                       padding: const EdgeInsets.all(16),
                       children: [
                         // Stats Row
                         Container(
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: Colors.white,
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceAround,
                             children: [
                               _buildDetailStat('Total Stock', '${widget.product.totalStock}'),
                               _buildDetailStat('Available', '${_reels.where((r) => r.status == "available").length}', const Color(0xFF10B981)),
                               _buildDetailStat('Outwarded', '${_reels.where((r) => r.status == "outward").length}', const Color(0xFFF59E0B)),
                             ],
                           ),
                         ),
                         const SizedBox(height: 20),
                         
                         // Outward History
                         _buildSectionHeader('Outward History (${_outwardHistory.length})', Icons.arrow_circle_right_outlined, const Color(0xFFF59E0B)),
                         if (_outwardHistory.isEmpty) 
                            const Padding(padding: EdgeInsets.all(16), child: Text("No outward records yet", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                         ..._outwardHistory.map((record) => Container(
                           margin: const EdgeInsets.only(bottom: 12),
                           decoration: BoxDecoration(
                             color: Colors.white,
                             borderRadius: BorderRadius.circular(12),
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.black.withOpacity(0.02),
                                 blurRadius: 4,
                                 offset: const Offset(0, 2),
                               )
                             ]
                           ),
                           child: ListTile(
                             leading: const CircleAvatar(backgroundColor: Color(0xFFFFF7ED), child: Icon(Icons.arrow_forward, color: Color(0xFFF59E0B))),
                             title: Text('Invoice: ${record.invoiceNumber}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                             subtitle: Text(DateFormat('MM/dd/yy hh:mm a').format(record.outwardDate), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                             trailing: Text('${record.quantity} pcs', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
                           ),
                         )),

                         const SizedBox(height: 20),

                         // Inward History
                         _buildSectionHeader('Inward History (${_inwardHistory.length})', Icons.arrow_circle_down_outlined, const Color(0xFF10B981)),
                         if (_inwardHistory.isEmpty)
                            const Padding(padding: EdgeInsets.all(16), child: Text("No inward records yet", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                         ..._inwardHistory.map((record) => Container(
                           margin: const EdgeInsets.only(bottom: 12),
                           decoration: BoxDecoration(
                             color: Colors.white,
                             borderRadius: BorderRadius.circular(12),
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.black.withOpacity(0.02),
                                 blurRadius: 4,
                                 offset: const Offset(0, 2),
                               )
                             ]
                           ),
                           child: ListTile(
                             leading: const CircleAvatar(backgroundColor: Color(0xFFECFDF5), child: Icon(Icons.arrow_downward, color: Color(0xFF10B981))),
                             title: Text('${record.quantity} pcs added', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                             subtitle: Text(DateFormat('MM/dd/yy hh:mm a').format(record.inwardDate), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                             trailing: Text('${record.numReels} new reels', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280))),
                           ),
                         )),
                         
                         const SizedBox(height: 20),

                         // Reels List
                         _buildSectionHeader('All Reels (${_reels.length})', Icons.qr_code, const Color(0xFF2563EB)),
                         if (_reels.isEmpty)
                            const Padding(padding: EdgeInsets.all(16), child: Text("No reels found", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                          ..._reels.map((reel) {
                           // Parse reel number from qrCodeData (format: ShortID|ReelNumber)
                           String reelNumber = '?';
                           final parts = reel.qrCodeData.split('|');
                           if (parts.length == 2) {
                             reelNumber = parts[1];
                           }
                           final isAvailable = reel.status == 'available';
                           return Container(
                             margin: const EdgeInsets.only(bottom: 12),
                             decoration: BoxDecoration(
                               color: Colors.white,
                               borderRadius: BorderRadius.circular(12),
                               boxShadow: [
                                 BoxShadow(
                                   color: Colors.black.withOpacity(0.02),
                                   blurRadius: 4,
                                   offset: const Offset(0, 2),
                                 )
                               ]
                             ),
                             child: ListTile(
                               title: Text('Reel #$reelNumber', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                               subtitle: Text('${reel.packingQuantity} pcs', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
                               trailing: Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                   borderRadius: BorderRadius.circular(12),
                                 ),
                                 child: Text(
                                   isAvailable ? '✓ Available' : '↗ Outwarded',
                                   style: GoogleFonts.inter(
                                     color: isAvailable ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                     fontWeight: FontWeight.bold,
                                     fontSize: 12
                                   ),
                                 ),
                               ),
                             ),
                           );
                         }),
                       ],
                   ),
             ),
          );
       },
    );
  }

  Widget _buildDetailStat(String label, String value, [Color? color]) {
     return Column(
       children: [
         Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color ?? const Color(0xFF1F2937))),
         Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
       ],
     );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
        ],
      ),
    );
  }
}
