import 'package:flutter/material.dart';
import 'number_format_model.dart';

/// Excel-style Number Format Exposed Dropdown Menu.
/// Shows the current format of the selected cell and lets the user change it.
class NumberFormatDropdown extends StatefulWidget {
  final CellFormat currentFormat;
  final ValueChanged<CellFormat> onFormatChanged;

  const NumberFormatDropdown({
    Key? key,
    required this.currentFormat,
    required this.onFormatChanged,
  }) : super(key: key);

  @override
  State<NumberFormatDropdown> createState() => _NumberFormatDropdownState();
}

class _NumberFormatDropdownState extends State<NumberFormatDropdown> {
  static const _allFormats = CellFormat.values;

  IconData _iconForFormat(CellFormat fmt) {
    switch (fmt) {
      case CellFormat.currency:
      case CellFormat.accounting:
        return Icons.currency_rupee_rounded;
      case CellFormat.percentage:
        return Icons.percent_rounded;
      case CellFormat.shortDate:
      case CellFormat.longDate:
        return Icons.calendar_today_rounded;
      case CellFormat.time:
        return Icons.access_time_rounded;
      case CellFormat.text:
        return Icons.text_fields_rounded;
      case CellFormat.scientific:
        return Icons.science_rounded;
      default:
        return Icons.tag_rounded;
    }
  }

  Color _colorForFormat(CellFormat fmt) {
    switch (fmt) {
      case CellFormat.currency:
      case CellFormat.accounting:
        return const Color(0xFF107C41);
      case CellFormat.percentage:
        return const Color(0xFF0078D4);
      case CellFormat.shortDate:
      case CellFormat.longDate:
        return const Color(0xFF8764B8);
      case CellFormat.time:
        return const Color(0xFFD83B01);
      case CellFormat.scientific:
        return const Color(0xFF004B50);
      case CellFormat.text:
        return const Color(0xFF605E5C);
      default:
        return const Color(0xFF323130);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD2D0CE), width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showFormatMenu(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconForFormat(widget.currentFormat),
                  size: 16,
                  color: _colorForFormat(widget.currentFormat),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.currentFormat.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _colorForFormat(widget.currentFormat),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down_rounded, size: 20, color: Color(0xFF605E5C)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFormatMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<CellFormat>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: _allFormats.map((fmt) {
        final bool isSelected = fmt == widget.currentFormat;
        return PopupMenuItem<CellFormat>(
          value: fmt,
          height: 44,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? _colorForFormat(fmt).withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _iconForFormat(fmt),
                  size: 18,
                  color: _colorForFormat(fmt),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        fmt.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: const Color(0xFF201F1E),
                        ),
                      ),
                      Text(
                        _exampleFor(fmt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF605E5C),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_rounded, size: 18, color: _colorForFormat(fmt)),
              ],
            ),
          ),
        );
      }).toList(),
    ).then((selected) {
      if (selected != null) {
        widget.onFormatChanged(selected);
      }
    });
  }

  String _exampleFor(CellFormat fmt) {
    switch (fmt) {
      case CellFormat.general:    return '1234.5';
      case CellFormat.number:     return '1,234.50';
      case CellFormat.currency:   return '₹1,234.50';
      case CellFormat.accounting: return '₹ 1,234.50';
      case CellFormat.shortDate:  return '12-08-2025';
      case CellFormat.longDate:   return 'Tuesday, August 12, 2025';
      case CellFormat.time:       return '03:30:00 PM';
      case CellFormat.percentage: return '25%';
      case CellFormat.fraction:   return '3/4';
      case CellFormat.scientific: return '1.23457E+08';
      case CellFormat.text:       return '12345 (as text)';
      case CellFormat.custom:     return 'Custom pattern...';
    }
  }
}
