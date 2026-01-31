
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/database_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _totalStockController = TextEditingController();
  final _packingQuantityController = TextEditingController();
  final _inwardDateController = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
  );

  bool _loading = false;
  bool _pdfLoading = false;
  List<String> _generatedQrCodes = [];
  Map<String, dynamic>? _lastCreationResult;

  String _registeredProductName = "";

  int get _calculatedReels {
    final total = int.tryParse(_totalStockController.text) ?? 0;
    final packing = int.tryParse(_packingQuantityController.text) ?? 0;
    if (total > 0 && packing > 0) {
      return (total / packing).ceil();
    }
    return 0;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final name = _productNameController.text.trim();
      final totalStock = int.parse(_totalStockController.text);
      final packing = int.parse(_packingQuantityController.text);

      final result = await DatabaseService().createProduct(name, totalStock, packing);

      if (result['success']) {
        setState(() {
          _generatedQrCodes = List<String>.from(result['qr_codes']);
          _lastCreationResult = result;
          _registeredProductName = name;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(result['message'])),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${result['message']}')),
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
      setState(() => _loading = false);
    }
  }

  Future<void> _generatePdf({bool share = true}) async {
    if (_generatedQrCodes.isEmpty) return;

    setState(() => _pdfLoading = true);
    
    try {
      final doc = pw.Document();

      // dimensions: 85mm x 24mm
      // pdf package uses points. 1mm = 2.835 points.
      // width: 85 * 2.835 = 241 pts
      // height: 24 * 2.835 = 68 pts
      final pageFormat = PdfPageFormat(
        85 * PdfPageFormat.mm, 
        24 * PdfPageFormat.mm,
        marginAll: 0
      );

      // Chunk chunks of 3 for the labels (as requested)
      // Actually, standard logic implies 3 per row on the label?
      // Re-reading register.tsx logic: "PDF will have 3 QRs per label row. Total: ... labels"
      // Wait, "Label dimensions: 85mm x 24mm".
      // "Group QR codes into sets of 3 (one page per label)".
      // So one PAGE implies one LABEL here. The label has 3 QRs physically printed on it.
      // I should replicate this layout.

      for (var i = 0; i < _generatedQrCodes.length; i += 3) {
        final chunk = _generatedQrCodes.sublist(
          i, 
          (i + 3) > _generatedQrCodes.length ? _generatedQrCodes.length : i + 3
        );

        doc.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (pw.Context context) {
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                children: chunk.map((qrData) {
                  final parts = qrData.split('|');
                  final reelNum = parts.length > 3 ? parts[3] : "?";
                  
                  return pw.Container(
                    width: (85 * PdfPageFormat.mm) / 3,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          "Reel #$reelNum", 
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)
                        ),
                        pw.SizedBox(height: 2),
                        pw.BarcodeWidget(
                          data: qrData,
                          barcode: pw.Barcode.qrCode(),
                          width: 28,
                          height: 28,
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          _registeredProductName,
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                          maxLines: 2,
                          overflow: pw.TextOverflow.clip, // or visible
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

      final fileName = 'qr_register_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: await doc.save(), filename: fileName);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    } finally {
      setState(() => _pdfLoading = false);
    }
  }

  void _clear() {
    setState(() {
      _generatedQrCodes = [];
      _lastCreationResult = null;
      _registeredProductName = "";
      _productNameController.clear();
      _totalStockController.clear();
      _packingQuantityController.clear();
      _inwardDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Register New Item', 
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
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
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _productNameController,
                          label: 'Product Name *',
                          placeholder: 'Enter product name',
                          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _totalStockController,
                          label: 'Total Stock Quantity *',
                          placeholder: 'Enter total pieces',
                          keyboardType: TextInputType.number,
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid quantity' : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _packingQuantityController,
                          label: 'Packing Quantity per Reel *',
                          placeholder: 'Enter pieces per reel',
                          keyboardType: TextInputType.number,
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid quantity' : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _inwardDateController,
                          label: 'Inward Date',
                          placeholder: 'YYYY-MM-DD',
                        ),
                        
                        if (_calculatedReels > 0) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Summary', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E40AF))),
                                const SizedBox(height: 8),
                                _buildSummaryRow('Total Stock:', '${_totalStockController.text} pcs'),
                                _buildSummaryRow('Per Reel:', '${_packingQuantityController.text} pcs'),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Reels to Generate:',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF1E40AF)),
                                    ),
                                    Text(
                                      '$_calculatedReels',
                                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E40AF)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _loading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  'Register Product',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_generatedQrCodes.isNotEmpty) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Generated QR Codes (${_generatedQrCodes.length})',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
                              ),
                            ),
                            TextButton(
                              onPressed: _clear,
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFFEE2E2),
                                foregroundColor: const Color(0xFFDC2626),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _pdfLoading ? null : _generatePdf,
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                            label: Text(_pdfLoading ? 'Generating...' : 'Generate Label PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 20, color: Color(0xFF15803D)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Labels are formatted for 85mm x 24mm size.\n3 QR codes will be printed per row.',
                                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF15803D)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _generatedQrCodes.length,
                          itemBuilder: (context, index) {
                            final qrData = _generatedQrCodes[index];
                            final parts = qrData.split('|');
                            final reelNum = parts.length > 3 ? parts[3] : "?";
 
                            final productName = _productNameController.text;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    color: Colors.white,
                                    child: QrImageView(
                                      data: qrData,
                                      version: QrVersions.auto,
                                      size: 80.0,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Reel #$reelNum',
                                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          productName,
                                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF374151)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: placeholder,
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
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
          ),
          style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF111827)),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF4B5563))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        ],
      ),
    );
  }
}
