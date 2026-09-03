import 'package:flutter/material.dart';

class FileTab extends StatelessWidget {
  final VoidCallback onSaveToDevice;
  final VoidCallback onExportCsv;
  final VoidCallback onExportExcel;
  final VoidCallback onExportXlsx;
  final VoidCallback onExportPdf;
  final VoidCallback onRename;
  final VoidCallback onQuickShare;

  const FileTab({
    Key? key,
    required this.onSaveToDevice,
    required this.onExportCsv,
    required this.onExportExcel,
    required this.onExportXlsx,
    required this.onExportPdf,
    required this.onRename,
    required this.onQuickShare,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FILE EXPORT & SAVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 20,
            alignment: WrapAlignment.start,
            children: [
              _buildIconAction(
                icon: Icons.save_rounded,
                color: const Color(0xFF107C41),
                title: 'Save As',
                onTap: onSaveToDevice,
              ),
              _buildIconAction(
                icon: Icons.share_rounded,
                color: const Color(0xFF25D366),
                title: 'Share',
                onTap: onQuickShare,
              ),
              _buildIconAction(
                icon: Icons.ios_share_rounded,
                color: const Color(0xFF107C41),
                title: 'Share Excel',
                onTap: onQuickShare, // Sharing Excel logic can be bound here
              ),
              _buildIconAction(
                icon: Icons.table_chart_outlined,
                color: const Color(0xFF0078D4),
                title: 'CSV',
                onTap: onExportCsv,
              ),
              _buildIconAction(
                icon: Icons.grid_on_outlined,
                color: const Color(0xFF107C41),
                title: 'Excel',
                onTap: onExportExcel,
              ),
              _buildIconAction(
                icon: Icons.description_outlined,
                color: const Color(0xFF5C2D91),
                title: 'XLSX',
                onTap: onExportXlsx,
              ),
              _buildIconAction(
                icon: Icons.picture_as_pdf_outlined,
                color: const Color(0xFFF40F02),
                title: 'PDF',
                onTap: onExportPdf,
              ),
              _buildIconAction(
                icon: Icons.edit_note_rounded,
                color: const Color(0xFF607D8B),
                title: 'Rename',
                onTap: onRename,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconAction({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3), width: 1.2),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
