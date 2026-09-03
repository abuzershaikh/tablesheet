import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/storage/invoice_config_storage.dart';
import '../../../domain/services/pdf/pdf_invoice_generator.dart';
import '../../invoice/invoice_customizer_screen.dart';

class QuickShareDialog extends StatelessWidget {
  final Map<String, String> rowData;
  final int rowIndex;

  const QuickShareDialog({
    super.key,
    required this.rowData,
    required this.rowIndex,
  });

  static void show(BuildContext context, Map<String, String> rowData, int rowIndex) {
    showDialog(
      context: context,
      builder: (ctx) => QuickShareDialog(rowData: rowData, rowIndex: rowIndex),
    );
  }

  String _formatRowSummary() {
    final buffer = StringBuffer();
    buffer.writeln('📋 *Row #${rowIndex + 1} Transaction Summary*');
    rowData.forEach((key, val) {
      if (val.trim().isNotEmpty) {
        buffer.writeln('• *${key.trim()}*: $val');
      }
    });
    buffer.writeln('\nSent via Mobile Spreadsheet');
    return buffer.toString();
  }

  void _shareToWhatsApp(BuildContext context) async {
    final text = _formatRowSummary();
    final url = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        // Fallback to native share plus
        Share.share(text, subject: 'Transaction Summary');
      }
    } catch (_) {
      Share.share(text, subject: 'Transaction Summary');
    }
  }

  void _shareAsPdf(BuildContext context) async {
    final config = await InvoiceConfigStorage.loadConfig();
    final pdfBytes = await PdfInvoiceGenerator.generateInvoicePdf(
      config: config,
      rowData: rowData,
      rowIndex: rowIndex,
    );

    final partyName = rowData.values.firstWhere((v) => v.isNotEmpty, orElse: () => 'Customer');
    final filename = 'Invoice_${rowIndex + 1}_$partyName.pdf';

    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  void _shareToEmail(BuildContext context) async {
    final partyName = rowData.values.firstWhere((v) => v.isNotEmpty, orElse: () => 'Customer');
    final subject = 'Invoice / Receipt #${rowIndex + 1} for $partyName';
    final body = _formatRowSummary();

    final mailtoUrl = Uri.parse('mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    try {
      if (await canLaunchUrl(mailtoUrl)) {
        await launchUrl(mailtoUrl);
      } else {
        Share.share(body, subject: subject);
      }
    } catch (_) {
      Share.share(body, subject: subject);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2879FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share, color: Color(0xFF2879FF), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Row #${rowIndex + 1} Data',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const Text(
                        'Select direct share target',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Share Actions List
            _buildShareOption(
              context: context,
              icon: Icons.chat_bubble,
              iconColor: const Color(0xFF25D366),
              title: 'WhatsApp Share',
              subtitle: 'Send instant transaction text & details',
              onTap: () {
                Navigator.of(context).pop();
                _shareToWhatsApp(context);
              },
            ),
            const SizedBox(height: 10),
            _buildShareOption(
              context: context,
              icon: Icons.picture_as_pdf,
              iconColor: const Color(0xFFEA5455),
              title: 'Share Custom PDF Invoice',
              subtitle: 'Formatted into your custom invoice layout',
              onTap: () {
                Navigator.of(context).pop();
                _shareAsPdf(context);
              },
            ),
            const SizedBox(height: 10),
            _buildShareOption(
              context: context,
              icon: Icons.email_rounded,
              iconColor: const Color(0xFFFF9F43),
              title: 'Share via Email (Gmail)',
              subtitle: 'Autofill subject & row details in Gmail',
              onTap: () {
                Navigator.of(context).pop();
                _shareToEmail(context);
              },
            ),

            const Divider(height: 24),

            // Customize Invoice Button
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InvoiceCustomizerScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2879FF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2879FF).withOpacity(0.2)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.tune, size: 18, color: Color(0xFF2879FF)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Customize Invoice & PDF Layout',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2879FF)),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: Color(0xFF2879FF)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
