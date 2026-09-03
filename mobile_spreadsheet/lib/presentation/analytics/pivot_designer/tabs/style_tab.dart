import 'package:flutter/material.dart';
import '../models/pivot_designer_state.dart';
import '../../../../domain/analytics/models/pivot_theme.dart';

class StyleTab extends StatelessWidget {
  final PivotDesignerState state;

  const StyleTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 12, color: Colors.grey.shade700),
              const SizedBox(width: 5),
              Text('Design Themes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: Colors.grey.shade800)),
            ],
          ),
          const SizedBox(height: 6),
          ...PivotThemeMode.values.map((m) {
            final th = PivotTheme.fromMode(m);
            final sel = state.themeMode == m;
            return GestureDetector(
              onTap: () => state.setThemeMode(m),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF1B5E20).withOpacity(0.06) : Colors.white,
                  border: Border.all(color: sel ? const Color(0xFF2E7D32) : Colors.grey.shade200, width: sel ? 1 : 0.5),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [th.headerBgColor, th.accentColor],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_nm(m), style: TextStyle(fontSize: 14, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: const Color(0xFF333333))),
                          Text(_ds(m), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    if (sel) const Icon(Icons.check_circle, size: 13, color: Color(0xFF2E7D32)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.view_agenda_outlined, size: 12, color: Colors.grey.shade700),
              const SizedBox(width: 5),
              Text('Table Formatting', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: Colors.grey.shade800)),
            ],
          ),
          const SizedBox(height: 5),
          _sw('Banded Rows', true),
          _sw('Header Shadow', true),
        ],
      ),
    );
  }

  Widget _sw(String l, bool v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(child: Text(l, style: const TextStyle(fontSize: 14, color: Color(0xFF444444)))),
          SizedBox(
            height: 22,
            width: 32,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch(
                value: v,
                onChanged: (_) {},
                activeColor: const Color(0xFF2E7D32),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _nm(PivotThemeMode m) {
    switch (m) {
      case PivotThemeMode.light: return 'Light Theme';
      case PivotThemeMode.dark: return 'Dark Mode';
      case PivotThemeMode.professionalBlue: return 'Professional Blue';
      case PivotThemeMode.vibrantEmerald: return 'Vibrant Emerald';
      case PivotThemeMode.monochrome: return 'Monochrome';
    }
  }

  String _ds(PivotThemeMode m) {
    switch (m) {
      case PivotThemeMode.light: return 'Clean & minimal';
      case PivotThemeMode.dark: return 'Sleek dark mode';
      case PivotThemeMode.professionalBlue: return 'Corporate & trustworthy';
      case PivotThemeMode.vibrantEmerald: return 'Fresh & energetic';
      case PivotThemeMode.monochrome: return 'Elegant grayscale';
    }
  }
}
