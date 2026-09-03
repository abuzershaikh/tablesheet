import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../domain/entities/invoice_template_config.dart';
import '../../data/storage/invoice_config_storage.dart';
import '../../domain/services/pdf/pdf_invoice_generator.dart';
import 'invoice_customizer_screen.dart';

class InvoiceStudioScreen extends StatefulWidget {
  const InvoiceStudioScreen({super.key});

  @override
  State<InvoiceStudioScreen> createState() => _InvoiceStudioScreenState();
}

class _InvoiceStudioScreenState extends State<InvoiceStudioScreen> {
  InvoiceTemplateConfig _config = const InvoiceTemplateConfig();
  bool _isLoading = true;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _loadConfigAndBuildPdf();
  }

  Future<void> _loadConfigAndBuildPdf() async {
    final loaded = await InvoiceConfigStorage.loadConfig();
    final sampleData = {
      'Receipt No.': '#1001',
      'Date': DateTime.now().toString().split(' ').first,
      'Party Name': 'Ramesh Kumar & Sons',
      'Item / Narration': 'Bulk Goods & Wholesale Supplies',
      'Amount (₹)': '25000',
      'Payment Mode': 'Bank/UPI',
      'Voucher Type': 'Sales',
    };

    final bytes = await PdfInvoiceGenerator.generateInvoicePdf(
      config: loaded,
      rowData: sampleData,
      rowIndex: 0,
    );

    setState(() {
      _config = loaded;
      _pdfBytes = bytes;
      _isLoading = false;
    });
  }

  void _openCustomizer() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const InvoiceCustomizerScreen()),
    );
    _loadConfigAndBuildPdf();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Invoice & PDF Studio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFF2879FF)),
            tooltip: 'Customize Layout',
            onPressed: _openCustomizer,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Configuration Summary Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(_config.primaryColorHex).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.picture_as_pdf, color: Color(_config.primaryColorHex), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _config.businessName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tax Rate: ${_config.taxPercentage}% | Currency: ${_config.currencySymbol} | GST: ${_config.gstNo.isNotEmpty ? _config.gstNo : "N/A"}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _openCustomizer,
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('Edit Format'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2879FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Live PDF Preview Canvas
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.remove_red_eye_outlined, size: 16, color: Color(0xFF2879FF)),
                      SizedBox(width: 6),
                      Text(
                        'Live PDF Output Preview (Uses Open-Source PDF Engine):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _pdfBytes != null
                        ? PdfPreview(
                            build: (format) => _pdfBytes!,
                            allowPrinting: true,
                            allowSharing: true,
                            canChangePageFormat: false,
                            initialPageFormat: PdfPageFormat.a4,
                            pdfFileName: '${_config.businessName}_Sample_Invoice.pdf',
                          )
                        : const Center(child: Text('Generating Live PDF...')),
                  ),
                ),
              ],
            ),
    );
  }
}
