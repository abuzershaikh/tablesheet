import 'package:flutter/material.dart';

class ParsedVoucherData {
  final String receiptNo;
  final String date;
  final String voucherType;
  final String partyName;
  final String narration;
  final String amount;
  final String paymentMode;

  ParsedVoucherData({
    required this.receiptNo,
    required this.date,
    required this.voucherType,
    required this.partyName,
    required this.narration,
    required this.amount,
    required this.paymentMode,
  });
}

class SmartTextParserDialog extends StatefulWidget {
  final Function(ParsedVoucherData parsedData) onApply;

  const SmartTextParserDialog({
    super.key,
    required this.onApply,
  });

  static void show(BuildContext context, Function(ParsedVoucherData parsedData) onApply) {
    showDialog(
      context: context,
      builder: (ctx) => SmartTextParserDialog(onApply: onApply),
    );
  }

  @override
  State<SmartTextParserDialog> createState() => _SmartTextParserDialogState();
}

class _SmartTextParserDialogState extends State<SmartTextParserDialog> {
  final TextEditingController _textController = TextEditingController();
  ParsedVoucherData? _parsedResult;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parseText(String text) {
    if (text.trim().isEmpty) {
      setState(() => _parsedResult = null);
      return;
    }

    final lower = text.toLowerCase();

    // 1. Amount Extraction (matches numbers like 5000, 2,500, ₹1000)
    final amountRegex = RegExp(r'(?:₹|rs\.?|inr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false);
    final amountMatch = amountRegex.firstMatch(text);
    String amountStr = '0';
    if (amountMatch != null && amountMatch.group(1) != null) {
      amountStr = amountMatch.group(1)!.replaceAll(',', '');
    }

    // 2. Voucher Type Detection
    String voucherType = 'Sales';
    if (lower.contains('purchase') || lower.contains('khareed') || lower.contains('kharid')) {
      voucherType = 'Purchase';
    } else if (lower.contains('payment') || lower.contains('kharch') || lower.contains('gaye') || lower.contains('diya')) {
      voucherType = 'Payment';
    } else if (lower.contains('receipt') || lower.contains('jama') || lower.contains('aaye') || lower.contains('liya')) {
      voucherType = 'Receipt';
    } else if (lower.contains('sales') || lower.contains('sell') || lower.contains('bikhri') || lower.contains('bikri')) {
      voucherType = 'Sales';
    }

    // 3. Payment Mode Detection
    String paymentMode = 'Cash';
    if (lower.contains('credit') || lower.contains('udhaar') || lower.contains('udhar') || lower.contains('baki')) {
      paymentMode = 'Credit';
    } else if (lower.contains('bank') || lower.contains('upi') || lower.contains('gpay') || lower.contains('paytm') || lower.contains('online')) {
      paymentMode = 'Bank/UPI';
    } else if (lower.contains('cash') || lower.contains('nagad')) {
      paymentMode = 'Cash';
    }

    // 4. Party Name & Narration Parsing
    // Remove amount and keywords to find party name
    String cleaned = text
        .replaceAll(RegExp(r'(?:₹|rs\.?|inr)?\s*[0-9,]+(?:\.[0-9]{1,2})?', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(sales|purchase|payment|receipt|cash|bank|upi|credit|udhaar|udhar|baki|nagad|kharch|gaye|aaye|jama|diya|liya)\b', caseSensitive: false), '')
        .trim();

    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    String partyName = words.isNotEmpty ? words.first : 'Customer';
    String narration = words.length > 1 ? words.sublist(1).join(' ') : (text.length > 30 ? text.substring(0, 30) : text);

    if (partyName.isEmpty) partyName = 'Party';
    if (narration.isEmpty) narration = text;

    setState(() {
      _parsedResult = ParsedVoucherData(
        receiptNo: '#${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        date: DateTime.now().toString().split(' ').first,
        voucherType: voucherType,
        partyName: _capitalize(partyName),
        narration: narration,
        amount: amountStr,
        paymentMode: paymentMode,
      );
    });
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF28C76F).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology, color: Color(0xFF28C76F), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WhatsApp Smart Parser',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        'Paste message (e.g. "Ramesh 5000 udhaar sales")',
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

            // Input Text Field
            TextField(
              controller: _textController,
              onChanged: _parseText,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Paste WhatsApp text or type entry...\ne.g. Ramesh 5000 cash sales\ne.g. Purchased stationery 1200 bank',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Real-time Extraction Preview
            if (_parsedResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2879FF).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2879FF).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Smart Extraction:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2879FF)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildChip('Party: ${_parsedResult!.partyName}', const Color(0xFF2879FF)),
                        const SizedBox(width: 6),
                        _buildChip('Amount: ₹${_parsedResult!.amount}', const Color(0xFF28C76F)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildChip('Type: ${_parsedResult!.voucherType}', const Color(0xFFFF9F43)),
                        const SizedBox(width: 6),
                        _buildChip('Mode: ${_parsedResult!.paymentMode}', const Color(0xFF7367F0)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _parsedResult != null
                        ? () {
                            widget.onApply(_parsedResult!);
                            Navigator.of(context).pop();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28C76F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Fill in Sheet'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
