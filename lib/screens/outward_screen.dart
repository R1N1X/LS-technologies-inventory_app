
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/database_service.dart';
import '../models/product.dart';

class ScannedItem {
  final String qrData;
  final Product product;
  final int reelNumber;

  ScannedItem({
    required this.qrData,
    required this.product,
    required this.reelNumber,
  });
}

class OutwardScreen extends StatefulWidget {
  const OutwardScreen({super.key});

  @override
  State<OutwardScreen> createState() => _OutwardScreenState();
}

class _OutwardScreenState extends State<OutwardScreen> {
  final _invoiceController = TextEditingController();
  final _poController = TextEditingController();
  final _customerController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  final List<ScannedItem> _scannedItems = [];
  bool _processing = false;
  bool _pdfLoading = false;
  bool _cameraActive = true;
  final _db = DatabaseService();

  @override
  void dispose() {
    _invoiceController.dispose();
    _poController.dispose();
    _customerController.dispose();
    _scannerController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playBeep() async {
    try {
      // Play beep from local asset file
      await _audioPlayer.play(AssetSource('sounds/beep_2.mp3'));
    } catch (e) {
      // Ignore if beep fails
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_processing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final code = barcodes.first.rawValue;
      if (code != null) {
        // Prevent duplicates in current session
        if (_scannedItems.any((item) => item.qrData == code)) {
          return;
        }

        // Temporarily set processing to avoid rapid duplicates
        setState(() => _processing = true);

        try {
          // REAL-TIME VALIDATION using validateReel
          final validation = await _db.validateReel(code);
          
          if (validation['valid'] == true) {
            final Product product = validation['product'];
            final int reelNum = validation['reelNumber'];
            
            if (mounted) {
              // Play success beep
              _playBeep();
              
              setState(() {
                _scannedItems.add(ScannedItem(
                  qrData: code,
                  product: product,
                  reelNumber: reelNum
                ));
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✓ Added Reel #$reelNum of ${product.name}'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          } else {
            // Show error immediately at scan time (Item 6 requirement)
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✗ ${validation['message']}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _processing = false);
          }
        }
      }
    }
  }

  Future<void> _submitAndGeneratePdf() async {
    if (_invoiceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter invoice number')));
      return;
    }
    if (_scannedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scan at least one reel')));
      return;
    }

    setState(() => _processing = true);

    try {
      // 1. Process Outward for all items
      int successCount = 0;
      List<String> errors = [];

      for (var item in _scannedItems) {
        try {
           final result = await _db.processOutward(
             item.qrData, 
             _invoiceController.text.trim()
           );
           if (result['success']) {
             successCount++;
           } else {
             errors.add("Reel #${item.reelNumber}: ${result['message']}");
           }
        } catch (e) {
             errors.add("Reel #${item.reelNumber}: $e");
        }
      }

      if (errors.isNotEmpty) {
         if (mounted) {
           await showDialog(
             context: context,
             builder: (ctx) => AlertDialog(
               title: const Text('Partial Error'),
               content: SingleChildScrollView(child: Text(errors.join('\n'))),
               actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
             )
           );
         }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All items processed successfully! Generating PDF...')));
        }
        // 2. Generate PDF
        await _generatePdf();
        
        // 3. Clear (only if PDF generation triggers sharing, we might want to clear after return)
        setState(() {
          _scannedItems.clear();
          _invoiceController.clear();
          _poController.clear();
          _customerController.clear();
        });
      }

    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
  
  Future<void> _generatePdf() async {
    setState(() => _pdfLoading = true);
    try {
      final doc = pw.Document();
      final invoice = _invoiceController.text.trim();
      final po = _poController.text.trim();
      final customer = _customerController.text.trim();

      // Label size: 85mm width x 32mm height (Landscape strip look)
      final pageFormat = PdfPageFormat(85 * PdfPageFormat.mm, 32 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm);

      for (var item in _scannedItems) {
        doc.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (context) {
              return pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                   // Left: QR Code
                   pw.Container(
                     width: 26 * PdfPageFormat.mm,
                     height: 26 * PdfPageFormat.mm,
                     alignment: pw.Alignment.center,
                     child: pw.BarcodeWidget(
                       data: item.qrData,
                       barcode: pw.Barcode.qrCode(),
                       width: 24 * PdfPageFormat.mm,
                       height: 24 * PdfPageFormat.mm,
                     ),
                   ),
                   pw.SizedBox(width: 3 * PdfPageFormat.mm),
                   
                   // Right: Details
                   pw.Expanded(
                     child: pw.Column(
                       crossAxisAlignment: pw.CrossAxisAlignment.start,
                       mainAxisAlignment: pw.MainAxisAlignment.center,
                       children: [
                         // Product Name
                         pw.Text(
                           item.product.name,
                           style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                           maxLines: 1,
                           overflow: pw.TextOverflow.clip,
                         ),
                         pw.SizedBox(height: 2),
                         // Reel Info
                         pw.Text(
                           "Reel #${item.reelNumber} | Qty: ${item.product.packingQuantity}",
                           style: const pw.TextStyle(fontSize: 7),
                         ),
                         pw.SizedBox(height: 4),
                         pw.Divider(thickness: 0.5, height: 1),
                         pw.SizedBox(height: 2),
                         // Customer
                         pw.Text(
                           customer.isNotEmpty ? customer : "Customer",
                           style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                         ),
                         // Invoice/PO
                         pw.Text(
                           "PO: $po | Inv: $invoice",
                           style: const pw.TextStyle(fontSize: 7),
                           maxLines: 1,
                           overflow: pw.TextOverflow.clip,
                         ),
                       ],
                     ),
                   ),
                 ],
               );
            },
          ),
        );
      }

      final fileName = 'qr_outward_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: await doc.save(), filename: fileName);

    } catch (e) {
       debugPrint("PDF Error: $e");
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  void _removeScannedItem(int index) {
    setState(() {
      _scannedItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Outward Processing', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_cameraActive ? Icons.camera_alt : Icons.camera_alt_outlined),
            onPressed: () => setState(() => _cameraActive = !_cameraActive),
          )
        ],
      ),
      body: Column(
        children: [
          // Scanner (Collapsible)
          if (_cameraActive)
            SizedBox(
              height: 250,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetect,
                  ),
                  Center(
                    child: Opacity(
                      opacity: 0.5,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.qr_code_2, size: 80, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTextField(
                           controller: _invoiceController,
                           label: "Invoice Number *",
                           icon: Icons.receipt,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(controller: _poController, label: "PO Number")),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField(controller: _customerController, label: "Customer / User")),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Scanned Items (${_scannedItems.length})', 
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))
                  ),
                  const SizedBox(height: 16),

                  if (_scannedItems.isEmpty)
                     Container(
                       padding: const EdgeInsets.all(32),
                       alignment: Alignment.center,
                       decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(16),
                         border: Border.all(color: const Color(0xFFE5E7EB)),
                       ),
                       child: Column(
                         children: [
                           const Icon(Icons.qr_code_scanner, size: 48, color: Color(0xFF9CA3AF)),
                           const SizedBox(height: 12),
                           Text(
                             'No items scanned yet', 
                             style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF6B7280)),
                           ),
                         ],
                       ),
                     )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _scannedItems.length,
                      itemBuilder: (context, index) {
                        final item = _scannedItems[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4, 
                                offset: const Offset(0, 2)
                              )
                            ]
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.check_circle, color: Color(0xFF059669)),
                            ),
                            title: Text(item.product.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
                            subtitle: Text('Reel #${item.reelNumber} | Qty: ${item.product.packingQuantity}', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280))),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: Color(0xFFEF4444)),
                              onPressed: () => _removeScannedItem(index),
                            ),
                          ),
                        );
                      },
                    ),
                  
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: (_scannedItems.isNotEmpty && !_processing) ? _submitAndGeneratePdf : null,
                    icon: _processing 
                       ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                       : const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(_processing ? 'Processing...' : 'Submit & Generate PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFA7F3D0).withOpacity(0.5)
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF374151)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF9CA3AF)) : null,
            hintText: 'Enter value',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
            ),
          ),
          style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF111827)),
        ),
      ],
    );
  }
}
