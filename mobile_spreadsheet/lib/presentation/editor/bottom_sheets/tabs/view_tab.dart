import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../editor_controller.dart';

class ViewTab extends StatelessWidget {
  const ViewTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    final isRowFrozen = controller.frozenRows > 0;
    final isColFrozen = controller.frozenColumns > 0;
    
    return Container(
      color: const Color(0xFFF3F4F6),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Show / Hide', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
            ),
            _buildCard([
              _buildToggleTile(
                icon: Icons.functions,
                title: 'Formula Bar',
                value: controller.isFormulaBarVisible,
                onChanged: (val) => controller.toggleFormulaBar(),
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200, indent: 48),
              _buildToggleTile(
                icon: Icons.tab_outlined,
                title: 'Sheet Tabs',
                value: controller.isSheetTabsVisible,
                onChanged: (val) => controller.toggleSheetTabs(),
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200, indent: 48),
              _buildToggleTile(
                icon: Icons.grid_4x4,
                title: 'Gridlines',
                value: true, // Mock value for now, or connect to controller later
                onChanged: (val) {},
              ),
            ]),
            
            const SizedBox(height: 20),
            
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Window', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
            ),
            _buildCard([
              ExpansionTile(
                leading: const Icon(Icons.ac_unit, color: Color(0xFF4B5563)),
                title: const Text('Freeze Panes', style: TextStyle(fontSize: 15, color: Color(0xFF1F2937))),
                children: [
                  _buildToggleTile(
                    icon: Icons.horizontal_rule,
                    title: 'Freeze Top Row',
                    value: isRowFrozen,
                    onChanged: (val) => controller.toggleFreezeTopRow(),
                  ),
                  _buildToggleTile(
                    icon: Icons.vertical_align_center,
                    title: 'Freeze First Column',
                    value: isColFrozen,
                    onChanged: (val) => controller.toggleFreezeFirstColumn(),
                  ),
                ],
              ),
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

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF107C41),
            ),
          ),
        ],
      ),
    );
  }
}
