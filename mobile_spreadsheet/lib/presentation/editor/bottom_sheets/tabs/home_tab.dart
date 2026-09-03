import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../editor_controller.dart';
import 'package:mobile_spreadsheet/domain/services/formatting_action_service.dart';

class HomeTab extends StatelessWidget {
  final VoidCallback? onFormatApplied;
  
  const HomeTab({Key? key, this.onFormatApplied}) : super(key: key);

  String _toHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2, 8).toUpperCase()}';
  }

  void _applyFormat(EditorController controller, String method, String arg) {
    final selection = controller.currentSelection;
    if (selection == null) return;
    FormattingActionService.applyFormat(
        selection.minRow, selection.minCol, selection.maxRow, selection.maxCol, method, arg);
    onFormatApplied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    
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
              child: Text('Text Style', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  // Row 2: Formatting (B, I, U, S)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFormatIcon('B', FontWeight.bold, FontStyle.normal, TextDecoration.none, () {
                          _applyFormat(controller, 'setFontWeight', 'bold');
                        }),
                        _buildFormatIcon('I', FontWeight.normal, FontStyle.italic, TextDecoration.none, () {
                          _applyFormat(controller, 'setFontStyle', 'italic');
                        }),
                        _buildFormatIcon('U', FontWeight.normal, FontStyle.normal, TextDecoration.underline, () {
                          _applyFormat(controller, 'setFontLine', 'underline');
                        }),
                        _buildFormatIcon('S', FontWeight.normal, FontStyle.normal, TextDecoration.lineThrough, () {
                          _applyFormat(controller, 'setFontLine', 'line-through');
                        }),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                  
                  // Row 4: Text Colors
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _colorDot(Colors.black, controller, isText: true),
                        _colorDot(const Color(0xFF3B82F6), controller, isText: true), // Blue
                        _colorDot(const Color(0xFF10B981), controller, isText: true), // Green
                        _colorDot(const Color(0xFFF59E0B), controller, isText: true), // Yellow
                        _colorDot(const Color(0xFFF97316), controller, isText: true), // Orange
                        _colorDot(const Color(0xFFEC4899), controller, isText: true), // Pink
                        _colorDot(const Color(0xFF8B5CF6), controller, isText: true), // Purple
                        const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Cell Color', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _noColorDot(controller),
                  _colorDot(const Color(0xFFBFDBFE), controller, isText: false), // Light Blue
                  _colorDot(const Color(0xFFA7F3D0), controller, isText: false), // Light Green
                  _colorDot(const Color(0xFFFDE68A), controller, isText: false), // Light Yellow
                  _colorDot(const Color(0xFFFED7AA), controller, isText: false), // Light Orange
                  _colorDot(const Color(0xFFFBCFE8), controller, isText: false), // Light Pink
                  _colorDot(const Color(0xFFDDD6FE), controller, isText: false), // Light Purple
                  const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 20),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Table Formats', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
            ),
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildTableStyleOption(
                    name: 'Blue Table',
                    headerColor: const Color(0xFF4285F4),
                    headerText: '#FFFFFF',
                    oddColor: '#F8F9FA',
                    evenColor: '#FFFFFF',
                    controller: controller,
                  ),
                  _buildTableStyleOption(
                    name: 'Green Table',
                    headerColor: const Color(0xFF34A853),
                    headerText: '#FFFFFF',
                    oddColor: '#F1F8F4',
                    evenColor: '#FFFFFF',
                    controller: controller,
                  ),
                  _buildTableStyleOption(
                    name: 'Dark Table',
                    headerColor: const Color(0xFF202124),
                    headerText: '#FFFFFF',
                    oddColor: '#3C4043',
                    evenColor: '#202124',
                    controller: controller,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Clear (Standalone Card)
            _buildCard([
              _buildOptionTile(Icons.cleaning_services_outlined, 'Clear Format', onTap: () {
                final selection = controller.currentSelection;
                if (selection != null) {
                  FormattingActionService.clearFormat(
                      selection.minRow, selection.minCol, selection.maxRow, selection.maxCol);
                  onFormatApplied?.call();
                }
              }),
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

  Widget _buildOptionTile(IconData icon, String title, {IconData trailingIcon = Icons.chevron_right, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
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

  Widget _buildFormatIcon(String text, FontWeight weight, FontStyle style, TextDecoration decoration, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: weight,
            fontStyle: style,
            decoration: decoration,
            color: const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _colorDot(Color color, EditorController controller, {required bool isText}) {
    return GestureDetector(
      onTap: () {
        _applyFormat(controller, isText ? 'setFontColor' : 'setBackground', _toHex(color));
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
  
  Widget _noColorDot(EditorController controller) {
    return GestureDetector(
      onTap: () {
        _applyFormat(controller, 'setBackground', '#FFFFFF');
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildTableStyleOption({
    required String name,
    required Color headerColor,
    required String headerText,
    required String oddColor,
    required String evenColor,
    required EditorController controller,
  }) {
    return GestureDetector(
      onTap: () {
        final selection = controller.currentSelection;
        if (selection != null) {
          FormattingActionService.applyTableStyle(
              selection.minRow, selection.minCol, selection.maxRow, selection.maxCol, 
              _toHex(headerColor), headerText, oddColor, evenColor);
          onFormatApplied?.call();
        }
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: headerColor.withOpacity(0.1),
          border: Border.all(color: headerColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold, color: headerColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
