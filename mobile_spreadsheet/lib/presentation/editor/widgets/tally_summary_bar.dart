import 'package:flutter/material.dart';

class TallySummaryBar extends StatefulWidget {
  final double totalCash;
  final double totalSales;
  final double totalPurchases;
  final double totalPayments;
  final double totalReceipts;

  const TallySummaryBar({
    super.key,
    required this.totalCash,
    required this.totalSales,
    required this.totalPurchases,
    required this.totalPayments,
    required this.totalReceipts,
  });

  @override
  State<TallySummaryBar> createState() => _TallySummaryBarState();
}

class _TallySummaryBarState extends State<TallySummaryBar> {
  bool _accountantMode = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Tally dark theme banner
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Tally Icon
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF28C76F).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance, color: Color(0xFF28C76F), size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Tally Engine',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),

              // Accountant Dr / Cr Toggle
              InkWell(
                onTap: () => setState(() => _accountantMode = !_accountantMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accountantMode ? const Color(0xFF2879FF) : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _accountantMode ? Icons.receipt_long : Icons.toggle_off_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _accountantMode ? 'Dr. / Cr. Mode' : 'Standard View',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Metric Badges Row
          if (!_accountantMode)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMetricBadge('Cash/Bank Balance', '₹${widget.totalCash.toStringAsFixed(2)}', const Color(0xFF28C76F)),
                  const SizedBox(width: 8),
                  _buildMetricBadge('Total Sales', '₹${widget.totalSales.toStringAsFixed(2)}', const Color(0xFF2879FF)),
                  const SizedBox(width: 8),
                  _buildMetricBadge('Total Receipts', '₹${widget.totalReceipts.toStringAsFixed(2)}', const Color(0xFF00CFE8)),
                  const SizedBox(width: 8),
                  _buildMetricBadge('Total Payments', '₹${widget.totalPayments.toStringAsFixed(2)}', const Color(0xFFFF9F43)),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMetricBadge('Dr. (Debit - Inflows)', '₹${(widget.totalReceipts + widget.totalSales).toStringAsFixed(2)}', const Color(0xFF28C76F)),
                  const SizedBox(width: 8),
                  _buildMetricBadge('Cr. (Credit - Outflows)', '₹${(widget.totalPayments + widget.totalPurchases).toStringAsFixed(2)}', const Color(0xFFEA5455)),
                  const SizedBox(width: 8),
                  _buildMetricBadge('Net Profit/Loss', '₹${(widget.totalSales - widget.totalPurchases).toStringAsFixed(2)}', const Color(0xFFFF9F43)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricBadge(String title, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withOpacity(0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: accentColor),
          ),
        ],
      ),
    );
  }
}
