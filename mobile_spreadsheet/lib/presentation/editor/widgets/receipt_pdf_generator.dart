import 'package:flutter/material.dart';

class ReceiptPdfDialog extends StatelessWidget {
  final Map<String, String> rowData; // column header -> cell value
  final int rowIndex;

  const ReceiptPdfDialog({
    super.key,
    required this.rowData,
    required this.rowIndex,
  });

  static void show(BuildContext context, Map<String, String> rowData, int rowIndex) {
    showDialog(
      context: context,
      builder: (ctx) => ReceiptPdfDialog(rowData: rowData, rowIndex: rowIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receiptNo = _getValue(['receipt no.', 'receipt #', 'invoice no.', 'id']) ?? '#${1000 + rowIndex + 1}';
    final date = _getValue(['date', 'created at', 'time']) ?? DateTime.now().toString().split(' ').first;
    final voucherType = _getValue(['voucher type', 'type', 'category']) ?? 'Voucher';
    final partyName = _getValue(['party name', 'customer', 'supplier', 'name']) ?? 'Valued Customer';
    final narration = _getValue(['item / narration', 'narration', 'description', 'item']) ?? 'Business Transaction';
    final amount = _getValue(['amount (₹)', 'amount', 'total', 'price']) ?? '₹0.00';
    final paymentMode = _getValue(['payment mode', 'mode', 'payment']) ?? 'Cash';

    final isIncome = voucherType.toLowerCase() == 'sales' || voucherType.toLowerCase() == 'receipt';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Badge & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isIncome ? const Color(0xFF28C76F).withOpacity(0.15) : const Color(0xFFFF9F43).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                          size: 14,
                          color: isIncome ? const Color(0xFF28C76F) : const Color(0xFFFF9F43),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          voucherType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isIncome ? const Color(0xFF28C76F) : const Color(0xFFFF9F43),
                          ),
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

              const SizedBox(height: 12),

              // Printable Voucher / Invoice Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Business Brand Header
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2848D3), Color(0xFF2879FF)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'OFFICIAL VOUCHER',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Tally Digital Receipt',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24, thickness: 1),

                    // Receipt Info Grid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailItem('Voucher No.', receiptNo),
                        _buildDetailItem('Date', date),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailItem('Party Name', partyName),
                        _buildDetailItem('Payment Mode', paymentMode),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Particulars / Narration
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Item / Narration:',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            narration,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Amount Total Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2848D3).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2848D3)),
                          ),
                          Text(
                            amount.startsWith('₹') ? amount : '₹$amount',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2848D3)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Thank you for your business!',
                        style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Receipt PDF generated successfully!')),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Save PDF'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Sharing Receipt $receiptNo for $partyName...')),
                        );
                      },
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share Receipt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2879FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  String? _getValue(List<String> possibleKeys) {
    for (final entry in rowData.entries) {
      final keyLower = entry.key.toLowerCase().trim();
      for (final target in possibleKeys) {
        if (keyLower.contains(target)) {
          return entry.value.isNotEmpty ? entry.value : null;
        }
      }
    }
    return null;
  }
}
