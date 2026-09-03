import 'package:flutter/material.dart';

class FormulaItem {
  final String name;
  final String formula;
  final String description;
  final String example;
  final IconData icon;
  final Color color;

  const FormulaItem({
    required this.name,
    required this.formula,
    required this.description,
    required this.example,
    required this.icon,
    required this.color,
  });
}

class FormulaHelperSheet extends StatefulWidget {
  final ValueChanged<String>? onFormulaSelected;

  const FormulaHelperSheet({
    super.key,
    this.onFormulaSelected,
  });

  @override
  State<FormulaHelperSheet> createState() => _FormulaHelperSheetState();
}

class _FormulaHelperSheetState extends State<FormulaHelperSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<FormulaItem> mathFormulas = [
    FormulaItem(
      name: 'Price × Quantity (Total)',
      formula: '=A2*B2',
      description: 'Multiplies Price column by Quantity/Sale column',
      example: 'A2=250, B2=4 -> Total = 1000',
      icon: Icons.shopping_cart_outlined,
      color: Color(0xFF28C76F),
    ),
    FormulaItem(
      name: 'SUM Range',
      formula: '=SUM(A1:A10)',
      description: 'Calculates the sum total of numbers in range',
      example: '=SUM(A1:A10) -> 1250',
      icon: Icons.add_circle_outline,
      color: Color(0xFF2879FF),
    ),
    FormulaItem(
      name: 'SQRT (Square Root)',
      formula: '=SQRT(A1)',
      description: 'Calculates square root of a number',
      example: '=SQRT(16) -> 4',
      icon: Icons.square_foot,
      color: Color(0xFF8633F5),
    ),
    FormulaItem(
      name: 'POWER',
      formula: '=POWER(A1, 2)',
      description: 'Raises number to a power',
      example: '=POWER(2, 3) -> 8',
      icon: Icons.bolt,
      color: Color(0xFFFF9F43),
    ),
    FormulaItem(
      name: 'ROUND',
      formula: '=ROUND(A1, 2)',
      description: 'Rounds a number to specified decimal places',
      example: '=ROUND(12.345, 2) -> 12.35',
      icon: Icons.rounded_corner,
      color: Color(0xFF00CFE8),
    ),
  ];

  static const List<FormulaItem> logicalFormulas = [
    FormulaItem(
      name: 'IF Statement',
      formula: '=IF(A1>10, "HIGH", "LOW")',
      description: 'Checks condition and returns value based on result',
      example: 'If A1=15 -> "HIGH"',
      icon: Icons.call_split,
      color: Color(0xFF7367F0),
    ),
    FormulaItem(
      name: 'IFERROR',
      formula: '=IFERROR(A1/B1, 0)',
      description: 'Catches errors and returns fallback value',
      example: 'If B1=0 -> 0 instead of #DIV/0!',
      icon: Icons.warning_amber,
      color: Color(0xFFFF4C51),
    ),
    FormulaItem(
      name: 'AND',
      formula: '=AND(A1>0, B1>0)',
      description: 'Returns TRUE if all conditions are met',
      example: 'A1=5, B1=10 -> TRUE',
      icon: Icons.check_circle_outline,
      color: Color(0xFF28C76F),
    ),
    FormulaItem(
      name: 'OR',
      formula: '=OR(A1>0, B1>0)',
      description: 'Returns TRUE if any condition is met',
      example: 'A1=0, B1=5 -> TRUE',
      icon: Icons.done_all,
      color: Color(0xFFFFC107),
    ),
  ];

  static const List<FormulaItem> textFormulas = [
    FormulaItem(
      name: 'Merge 2 Rows / Cells',
      formula: '=A1 & " " & B1',
      description: 'Combines text from 2 rows or cells',
      example: 'A1="John", B1="Doe" -> "John Doe"',
      icon: Icons.merge_type,
      color: Color(0xFF7367F0),
    ),
    FormulaItem(
      name: 'Merge 3 Rows / Cells',
      formula: '=CONCAT(A1, " ", B1, " ", C1)',
      description: 'Combines 3 text cells or rows into 1 string',
      example: 'A1="Order", B1="101", C1="Paid" -> "Order 101 Paid"',
      icon: Icons.view_column_outlined,
      color: Color(0xFF00CFE8),
    ),
    FormulaItem(
      name: 'TEXTJOIN with Delimiter',
      formula: '=TEXTJOIN("-", TRUE, A1, B1, C1)',
      description: 'Joins 3 rows/cells using separator & skipping blanks',
      example: '=TEXTJOIN("-", TRUE, A1, B1, C1) -> "2026-07-25"',
      icon: Icons.link,
      color: Color(0xFFFF4C51),
    ),
    FormulaItem(
      name: 'UPPER',
      formula: '=UPPER(A1)',
      description: 'Converts text to UPPERCASE',
      example: '=UPPER("hello") -> "HELLO"',
      icon: Icons.text_fields,
      color: Color(0xFF8633F5),
    ),
  ];

  static const List<FormulaItem> inventoryFormulas = [
    FormulaItem(
      name: 'Profit (Selling - Cost)',
      formula: '=PROFIT(B2, A2)',
      description: 'Calculates item profit: Selling Price - Cost Price',
      example: 'Cost A2=100, Selling B2=150 -> Profit = 50',
      icon: Icons.trending_up,
      color: Color(0xFF28C76F),
    ),
    FormulaItem(
      name: 'GST / Tax (Round)',
      formula: '=GST(A2, 18)',
      description: 'Calculates 18% GST rounded to 2 decimals',
      example: 'Amount=1000, GST 18% -> Tax = 180',
      icon: Icons.receipt_long,
      color: Color(0xFF2879FF),
    ),
    FormulaItem(
      name: 'Low Stock Alert',
      formula: '=STOCKALERT(A2, 5)',
      description: 'Returns "LOW STOCK" if stock <= reorder level',
      example: 'Stock A2=3, Reorder=5 -> "LOW STOCK"',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFFFF9F43),
    ),
    FormulaItem(
      name: 'Expiry Alert',
      formula: '=EXPIRYALERT(A2)',
      description: 'Checks expiry date against TODAY()',
      example: 'Expiry A2="2026-01-01" -> "EXPIRED"',
      icon: Icons.event_busy,
      color: Color(0xFFFF4C51),
    ),
  ];

  static const List<FormulaItem> statFormulas = [
    FormulaItem(
      name: 'AVERAGE Range',
      formula: '=AVERAGE(A1:A10)',
      description: 'Calculates mean average of range',
      example: '=AVERAGE(A1:A10) -> 125',
      icon: Icons.functions,
      color: Color(0xFF8633F5),
    ),
    FormulaItem(
      name: 'MAX',
      formula: '=MAX(A1:A10)',
      description: 'Returns highest number in range',
      example: '=MAX(10, 50, 30) -> 50',
      icon: Icons.arrow_upward,
      color: Color(0xFFFFC107),
    ),
    FormulaItem(
      name: 'MIN',
      formula: '=MIN(A1:A10)',
      description: 'Returns lowest number in range',
      example: '=MIN(10, 50, 30) -> 10',
      icon: Icons.arrow_downward,
      color: Color(0xFF20C997),
    ),
    FormulaItem(
      name: 'COUNT',
      formula: '=COUNT(A1:A10)',
      description: 'Counts number of numeric cells',
      example: '=COUNT(A1:A10) -> 10',
      icon: Icons.format_list_numbered,
      color: Color(0xFF6F42C1),
    ),
  ];

  static const List<FormulaItem> dateFormulas = [
    FormulaItem(
      name: 'TODAY',
      formula: '=TODAY()',
      description: 'Returns current date (YYYY-MM-DD)',
      example: '=TODAY() -> "2026-07-25"',
      icon: Icons.calendar_today,
      color: Color(0xFF00CFE8),
    ),
    FormulaItem(
      name: 'NOW',
      formula: '=NOW()',
      description: 'Returns current date and time',
      example: '=NOW() -> "2026-07-25 14:30:00"',
      icon: Icons.access_time,
      color: Color(0xFF7367F0),
    ),
    FormulaItem(
      name: 'DATEDIF (Days Between)',
      formula: '=DATEDIF(A1, B1, "D")',
      description: 'Calculates days between two dates',
      example: 'A1="2026-01-01", B1="2026-01-10" -> 9',
      icon: Icons.date_range,
      color: Color(0xFF28C76F),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: (MediaQuery.of(context).size.height * 0.75 - bottomInset).clamp(250.0, MediaQuery.of(context).size.height * 0.75),
        padding: const EdgeInsets.only(top: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          
          // Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.calculate, color: Color(0xFF2848D3), size: 28),
                SizedBox(width: 12),
                Text(
                  'Enterprise Formula Library',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFF2848D3),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF2848D3),
            tabs: const [
              Tab(text: '🔢 Math'),
              Tab(text: '🛍️ Inventory'),
              Tab(text: '🔀 Logical'),
              Tab(text: '🔗 Text Merge'),
              Tab(text: '📈 Stats'),
              Tab(text: '📅 Date & Time'),
            ],
          ),
          const Divider(height: 1),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFormulaList(mathFormulas),
                _buildFormulaList(inventoryFormulas),
                _buildFormulaList(logicalFormulas),
                _buildFormulaList(textFormulas),
                _buildFormulaList(statFormulas),
                _buildFormulaList(dateFormulas),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildFormulaList(List<FormulaItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.formula,
                    style: TextStyle(
                      color: item.color,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'e.g. ${item.example}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            onTap: () {
              if (widget.onFormulaSelected != null) {
                widget.onFormulaSelected!(item.formula);
                Navigator.pop(context);
              }
            },
          ),
        );
      },
    );
  }
}
