import 'package:flutter/material.dart';
import '../../../domain/entities/spreadsheet_entity.dart';

class MiddleSection extends StatelessWidget {
  final List<SpreadsheetEntity> recentSpreadsheets;
  final Function(SpreadsheetEntity) onSpreadsheetTap;
  final VoidCallback onSeeAllTemplates;
  final VoidCallback onSeeAllSheets;
  final Function(SpreadsheetEntity)? onSpreadsheetMenuTap;

  const MiddleSection({
    super.key,
    required this.recentSpreadsheets,
    required this.onSpreadsheetTap,
    required this.onSeeAllTemplates,
    required this.onSeeAllSheets,
    this.onSpreadsheetMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Templates
          Expanded(
            flex: 9,
            child: _buildTemplatesCard(),
          ),
          const SizedBox(width: 16),
          // Right: Your Sheets
          Expanded(
            flex: 11,
            child: _buildYourSheetsCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F0), // Light green tint
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF28C76F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.description_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Template',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E9B55),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose from\nprofessional templates',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onSeeAllTemplates,
                child: const Icon(Icons.chevron_right, color: Color(0xFF1E9B55), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Template previews
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTemplatePreview('Budget Plan', 1),
              _buildTemplatePreview('Invoice', 2),
              _buildTemplatePreview('To Do List', 3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatePreview(String title, int styleType) {
    return Column(
      children: [
        Container(
          width: 45,
          height: 65,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: _getTemplatePreviewContent(styleType),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Color(0xFF555555),
          ),
        ),
      ],
    );
  }

  Widget _getTemplatePreviewContent(int styleType) {
    if (styleType == 1) { // Budget (Pie chart + rows)
      return Column(
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF28C76F),
              shape: BoxShape.circle,
            ),
          ),
          const Spacer(),
          Container(height: 3, color: Colors.grey[200]),
          const SizedBox(height: 2),
          Container(height: 3, color: Colors.grey[200]),
          const SizedBox(height: 2),
          Container(height: 4, color: const Color(0xFF28C76F).withOpacity(0.3)),
          const SizedBox(height: 2),
        ],
      );
    } else if (styleType == 2) { // Invoice (Header + grid)
      return Column(
        children: [
          Container(height: 8, color: Colors.blue[100]),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) => Container(height: 2, color: Colors.grey[300])),
                )),
                const SizedBox(width: 2),
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) => Container(height: 2, color: Colors.blue[100])),
                )),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 6, color: Colors.grey[300]),
        ],
      );
    } else { // To Do list (Checkboxes)
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (index) => Row(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(border: Border.all(color: Colors.purple[200]!, width: 1), borderRadius: BorderRadius.circular(1))),
            const SizedBox(width: 4),
            Expanded(child: Container(height: 2, color: Colors.purple[100])),
          ],
        )),
      );
    }
  }

  Widget _buildYourSheetsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF2879FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.table_chart, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Sheets',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2879FF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'View and manage\nyour spreadsheets',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onSeeAllSheets,
                child: const Icon(Icons.chevron_right, color: Color(0xFF2879FF), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Sheet List (up to 3)
          if (recentSpreadsheets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No sheets yet', style: TextStyle(color: Colors.grey, fontSize: 12))),
            )
          else
            ...recentSpreadsheets.take(3).map((sheet) => _buildSheetItem(sheet)).toList(),
        ],
      ),
    );
  }

  Widget _buildSheetItem(SpreadsheetEntity sheet) {
    // Format date nicely
    final dateStr = '${sheet.updatedAt.day} ${_getMonth(sheet.updatedAt.month)} ${sheet.updatedAt.year}';
    // Dummy size for now, as entity doesn't have size
    final sizeStr = '${(sheet.name.length * 2) + 12} KB';

    return GestureDetector(
      onTap: () => onSpreadsheetTap(sheet),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.28),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sheet.name.isEmpty ? 'Untitled' : sheet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dateStr  •  $sizeStr',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => onSpreadsheetMenuTap?.call(sheet),
              child: const Icon(Icons.more_horiz, color: Colors.grey, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
