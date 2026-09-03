import 'package:flutter/material.dart';
import '../../editor/widgets/formula_helper_sheet.dart';
import 'package:mobile_spreadsheet/presentation/data_filter/data_filter_screen.dart';
import '../../invoice/invoice_studio_screen.dart';

class ToolsSection extends StatelessWidget {
  const ToolsSection({super.key});

  void _showFormulaHelper(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FormulaHelperSheet(),
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title - Coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Tools & More',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildToolItem(
                  icon: Icons.picture_as_pdf,
                  color: const Color(0xFF2879FF),
                  title: 'Invoice & PDF Studio',
                  subtitle: 'Custom PDF Maker',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const InvoiceStudioScreen()),
                    );
                  },
                ),
                _buildToolItem(
                  icon: Icons.calculate_outlined,
                  color: const Color(0xFF28C76F),
                  title: 'Formula Helper',
                  subtitle: 'Useful formulas',
                  onTap: () => _showFormulaHelper(context),
                ),
                _buildToolItem(
                  icon: Icons.functions,
                  color: const Color(0xFF8633F5),
                  title: 'Function Library',
                  subtitle: '500+ functions',
                  onTap: () => _showFormulaHelper(context),
                ),
                _buildToolItem(
                  icon: Icons.bar_chart,
                  color: const Color(0xFFFFC107),
                  title: 'Chart Maker',
                  subtitle: 'Visualize data',
                  onTap: () => _showComingSoon(context, 'Chart Maker'),
                ),
                _buildToolItem(
                  icon: Icons.filter_alt_outlined,
                  color: const Color(0xFFFF4C51),
                  title: 'Data Filter',
                  subtitle: 'Sort & filter data',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DataFilterScreen()),
                    );
                  },
                ),
                _buildToolItem(
                  icon: Icons.lock_outline,
                  color: const Color(0xFF2879FF),
                  title: 'Protect Sheet',
                  subtitle: 'Secure your data',
                  onTap: () => _showComingSoon(context, 'Protect Sheet'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
