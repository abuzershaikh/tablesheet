import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../entities/invoice_template_config.dart';

class PdfInvoiceGenerator {
  PdfInvoiceGenerator._();

  /// Generate PDF document bytes for a given row's data and user's template config
  static Future<Uint8List> generateInvoicePdf({
    required InvoiceTemplateConfig config,
    required Map<String, String> rowData,
    required int rowIndex,
  }) async {
    final pdf = pw.Document();

    final receiptNo = _extractValue(rowData, ['receipt no.', 'receipt #', 'invoice no.', 'id']) ?? '#${1000 + rowIndex + 1}';
    final date = _extractValue(rowData, ['date', 'time', 'created at']) ?? DateTime.now().toString().split(' ').first;
    final partyName = _extractValue(rowData, ['party name', 'customer', 'supplier', 'name']) ?? 'Valued Customer';
    final narration = _extractValue(rowData, ['item / narration', 'narration', 'description', 'item']) ?? 'General Items';
    final amountStr = _extractValue(rowData, ['amount (₹)', 'amount', 'total', 'price']) ?? '0';
    final paymentMode = _extractValue(rowData, ['payment mode', 'mode', 'payment']) ?? 'Cash';
    final voucherType = _extractValue(rowData, ['voucher type', 'type']) ?? 'Sales';

    final rawAmount = double.tryParse(amountStr.replaceAll('₹', '').replaceAll(',', '').trim()) ?? 0.0;
    final taxAmount = (rawAmount * config.taxPercentage) / 100.0;
    final grandTotal = rawAmount + taxAmount;

    final primaryPdfColor = PdfColor.fromInt(config.primaryColorHex);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: primaryPdfColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          config.businessName.toUpperCase(),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          config.businessAddress,
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                        ),
                        pw.Text(
                          'Phone: ${config.phone} | Email: ${config.email}',
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                        ),
                        if (config.gstNo.isNotEmpty)
                          pw.Text(
                            'GSTIN: ${config.gstNo}',
                            style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                          ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(
                          color: primaryPdfColor,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Invoice & Bill To Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILLED TO:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(partyName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Payment Mode: $paymentMode', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Invoice No: $receiptNo', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Type: $voucherType', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Particulars Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Item / Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount (${config.currencySymbol})', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  // Item Row
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('1', style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(narration, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${config.currencySymbol}${rawAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // Summary & Tax Breakdown
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        _buildSummaryRow('Subtotal', '${config.currencySymbol}${rawAmount.toStringAsFixed(2)}'),
                        _buildSummaryRow('Tax (${config.taxPercentage}%)', '${config.currencySymbol}${taxAmount.toStringAsFixed(2)}'),
                        pw.Divider(thickness: 1),
                        _buildSummaryRow(
                          'Grand Total',
                          '${config.currencySymbol}${grandTotal.toStringAsFixed(2)}',
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Terms & Footer Note
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text(config.termsAndConditions, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(height: 30, width: 80, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300))),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  config.footerNote,
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static String? _extractValue(Map<String, String> data, List<String> targetKeys) {
    for (final entry in data.entries) {
      final keyLower = entry.key.toLowerCase().trim();
      for (final t in targetKeys) {
        if (keyLower.contains(t)) {
          return entry.value.isNotEmpty ? entry.value : null;
        }
      }
    }
    return null;
  }
}
