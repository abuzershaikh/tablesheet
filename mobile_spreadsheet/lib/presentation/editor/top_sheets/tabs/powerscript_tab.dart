import 'package:flutter/material.dart';
import '../components/drawer_action_card.dart';

class PowerScriptTab extends StatelessWidget {
  final VoidCallback onOpenPowerScriptStudio;

  const PowerScriptTab({
    Key? key,
    required this.onOpenPowerScriptStudio,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'JAVASCRIPT MACROS & SCRIPTING',
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
                  icon: Icons.code_rounded,
                  color: const Color(0xFF107C41),
                  title: 'PowerScript Studio',
                  subtitle: 'Write JS macros & custom functions',
                  onTap: onOpenPowerScriptStudio,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.play_circle_fill_rounded,
                  color: const Color(0xFF38BDF8),
                  title: 'My Saved Macros',
                  subtitle: 'Run sheet-specific scripts',
                  onTap: onOpenPowerScriptStudio,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
