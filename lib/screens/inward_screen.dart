
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/database_service.dart';
import '../models/product.dart';

class InwardScreen extends StatefulWidget {
  const InwardScreen({super.key});

  @override
  State<InwardScreen> createState() => _InwardScreenState();
}

class _InwardScreenState extends State<InwardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  
  Product? _selectedProduct;
  List<Product> _products = [];
  bool _loading = true;
  bool _submitting = false;
  bool _pdfLoading = false;
  
  // Results
  List<String> _generatedQrCodes = [];
  Map<String, dynamic>? _lastResult;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final products = await DatabaseService().getProducts();
      products.sort((a, b) => a.name.compareTo(b.name));
      if (mounted) {
        setState(() {
          _products = products;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || _selectedProduct == null) {
      if (_selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a product')));
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      final quantity = int.parse(_quantityController.text);
      final result = await DatabaseService().addInwardStock(_selectedProduct!.id!, quantity);
      
      if (result['success']) {
        final qrCodes = List<String>.from(result['qr_codes'] ?? []);
        setState(() {
          _generatedQrCodes = qrCodes;
          _lastResult = result;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${result['message']}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _generatePdf() async {
    if (_generatedQrCodes.isEmpty) return;
    setState(() => _pdfLoading = true);
    
    try {
      final doc = pw.Document();
      final pageFormat = PdfPageFormat(85 * PdfPageFormat.mm, 24 * PdfPageFormat.mm, marginAll: 0);

      // Same layout as RegisterScreen for consistency
      for (var i = 0; i < _generatedQrCodes.length; i += 3) {
        final chunk = _generatedQrCodes.sublist(
          i, (i + 3) > _generatedQrCodes.length ? _generatedQrCodes.length : i + 3
        );

        doc.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (pw.Context context) {
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                children: chunk.map((qrData) {
                  final parts = qrData.split('|');
                  final reelNum = parts.length == 2 ? parts[1] : "?";
                  
                  return pw.Container(
                    width: (85 * PdfPageFormat.mm) / 3, // Full slot width
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text("Reel #$reelNum", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.BarcodeWidget(
                          data: qrData,
                          barcode: pw.Barcode.qrCode(),
                          width: 32,
                          height: 32,
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          _selectedProduct?.name ?? "Unknown",
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                          maxLines: 2,
                          overflow: pw.TextOverflow.clip,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      }

      final fileName = 'qr_inward_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: await doc.save(), filename: fileName);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    } finally {
      setState(() => _pdfLoading = false);
    }
  }

  void _reset() {
    setState(() {
      _generatedQrCodes = [];
      _lastResult = null;
      _quantityController.clear();
      _selectedProduct = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inward Stock', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
      body: _loading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form Card
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Product', 
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF374151))
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<Product>(
                              value: _selectedProduct,
                              items: _products.map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.name, style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF111827))),
                              )).toList(),
                              onChanged: _generatedQrCodes.isNotEmpty ? null : (val) {
                                  setState(() {
                                    _selectedProduct = val;
                                  });
                              },
                              decoration: InputDecoration(
                                hintText: 'Choose a product',
                                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
                              ),
                              hint: const Text('Choose a product'),
                            ),
                            
                            if (_selectedProduct != null) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF), 
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFBFDBFE))
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Current Stock:', style: TextStyle(color: Color(0xFF4B5563))),
                                        Text('${_selectedProduct!.totalStock} pcs', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Packing:', style: TextStyle(color: Color(0xFF4B5563))),
                                        Text('${_selectedProduct!.packingQuantity} pcs / reel', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),
                            Text(
                              'Additional Quantity', 
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF374151))
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              enabled: _generatedQrCodes.isEmpty,
                              decoration: InputDecoration(
                                hintText: 'Enter quantity to add',
                                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
                              ),
                              style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF111827)),
                              validator: (v) {
                                final val = int.tryParse(v ?? '');
                                if (val == null || val <= 0) return 'Invalid quantity';
                                return null;
                              },
                            ),

                            const SizedBox(height: 32),
                            if (_generatedQrCodes.isEmpty)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _submitting ? null : _handleSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _submitting
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Add Stock', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Results Section
                  if (_generatedQrCodes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Card(
                      elevation: 2,
                       color: Colors.white,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       child: Padding(
                         padding: const EdgeInsets.all(20),
                         child: Column(
                           children: [
                             const Icon(Icons.check_circle, color: Colors.green, size: 48),
                             const SizedBox(height: 16),
                             Text(
                               'Success! ${_generatedQrCodes.length} New Reels Generated',
                               style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                               textAlign: TextAlign.center,
                             ),
                             const SizedBox(height: 24),
                             
                             SizedBox(
                               width: double.infinity,
                               child: ElevatedButton.icon(
                                 onPressed: _pdfLoading ? null : _generatePdf,
                                 icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                                 label: Text(_pdfLoading ? 'Generating...' : 'Print Labels (${_generatedQrCodes.length})'),
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: const Color(0xFF059669),
                                   padding: const EdgeInsets.symmetric(vertical: 16),
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                   foregroundColor: Colors.white,
                                 ),
                               ),
                             ),

                             const SizedBox(height: 16),
                             TextButton(
                               onPressed: _reset,
                               child: const Text('Create Another Entry'),
                             ),
                           ],
                         ),
                       ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
