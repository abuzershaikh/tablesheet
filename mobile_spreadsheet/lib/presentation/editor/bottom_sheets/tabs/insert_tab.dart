import 'package:flutter/material.dart';

class InsertTab extends StatelessWidget {
  const InsertTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            _buildCard([
              _buildOptionTile(Icons.table_chart_outlined, 'Table'),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200, indent: 48),
              _buildOptionTile(Icons.insert_photo_outlined, 'Pictures'),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200, indent: 48),
              _buildOptionTile(Icons.category_outlined, 'Shapes'),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200, indent: 48),
              _buildOptionTile(Icons.bar_chart, 'Charts'),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title, {IconData trailingIcon = Icons.chevron_right}) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF4B5563)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1F2937), fontWeight: FontWeight.w400),
              ),
            ),
            Icon(trailingIcon, color: const Color(0xFF9CA3AF), size: 20),
          ],
        ),
      ),
    );
  }
}
