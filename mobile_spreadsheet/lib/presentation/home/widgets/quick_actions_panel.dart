import 'package:flutter/material.dart';

class QuickActionsPanel extends StatelessWidget {
  final VoidCallback onNewSheet;
  final VoidCallback onImportFile;
  final VoidCallback onCloudSheets;

  const QuickActionsPanel({
    super.key,
    required this.onNewSheet,
    required this.onImportFile,
    required this.onCloudSheets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionItem(
            icon: Icons.add,
            color: const Color(0xFF28C76F),
            title: 'New Sheet',
            subtitle: 'Create blank sheet',
            onTap: onNewSheet,
          ),
          _buildActionItem(
            icon: Icons.file_upload_outlined,
            color: const Color(0xFF7367F0),
            title: 'Import File',
            subtitle: 'Excel, CSV & more',
            onTap: onImportFile,
          ),
          _buildActionItem(
            icon: Icons.cloud_outlined,
            color: const Color(0xFF00CFE8),
            title: 'Cloud Sheets',
            subtitle: 'Open from cloud',
            onTap: onCloudSheets,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
