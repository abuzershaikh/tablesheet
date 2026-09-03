import 'package:flutter/material.dart';
import '../components/drawer_action_card.dart';

class ViewTab extends StatelessWidget {
  final VoidCallback onThemeCustomizer;
  final VoidCallback onConditionalFormatting;
  final VoidCallback onFreezePanes;
  final VoidCallback onFooterSettings;

  const ViewTab({
    Key? key,
    required this.onThemeCustomizer,
    required this.onConditionalFormatting,
    required this.onFreezePanes,
    required this.onFooterSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THEME & DISPLAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.palette_rounded,
                  color: const Color(0xFF107C41),
                  title: 'Sheet Theme',
                  subtitle: 'Change colors, font & style',
                  onTap: onThemeCustomizer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.style_rounded,
                  color: const Color(0xFFD32F2F),
                  title: 'Conditional Format',
                  subtitle: 'Color rules based on values',
                  onTap: onConditionalFormatting,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.ac_unit_rounded,
                  color: const Color(0xFF0288D1),
                  title: 'Freeze Panes',
                  subtitle: 'Lock top rows or columns',
                  onTap: onFreezePanes,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.functions_rounded,
                  color: const Color(0xFF7B1FA2),
                  title: 'Footer Tally',
                  subtitle: 'Auto-summary calculation bar',
                  onTap: onFooterSettings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


}
